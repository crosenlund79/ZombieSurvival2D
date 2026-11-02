class_name NpcSim
extends RefCounted
## Host-only survivor simulation (content/npcs.json). Clients only display
## replicated rows. World data is the truth, so work continues while nobody
## views the bunker, and a reload can never double-process: every work step
## changes storage and machine state in the same host step.
##
## Recruitment: the survivor waits at a point of interest ("waiting"). Talking
## to them ("met") tells you what they need; handing it over recruits them
## ("travelling"): they walk home off-screen and arrive in the bunker after a
## while ("home"). A settlement needs a shelter first.
## Jobs (use only real resources and machines; nothing is created for free):
##   water — fill the purifier from shelter storage, collect clean water into storage
##   farm  — water planters from storage clean water, harvest ripe crops into storage
## Upkeep: once per game day the settlement feeds the survivor (1 food + 1
## clean water from shared storage). Unfed survivors work at half speed.
## During an active defence event the survivor stops work and shelters.

const PATH := "res://content/npcs.json"
const JOBS: Array[String] = ["", "water", "farm"]
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"npcs": {}}
	return _data


static func defn(id: String) -> Dictionary:
	return data().get("npcs", {}).get(id, {})


static func c(key: String, fallback: Variant) -> Variant:
	return data().get("tuning", {}).get(key, fallback)


## Creates authored survivors that do not exist yet (new worlds and old saves).
static func ensure(world: WorldState) -> void:
	for id in data().get("npcs", {}):
		if world.npcs.has(id):
			continue
		var d := defn(id)
		if world.region(str(d.get("region", ""))) == null:
			continue
		var n := NpcState.new()
		n.npc_id = id
		n.name = str(d.get("name", id))
		n.desc_key = str(d.get("desc_key", ""))
		n.region_id = str(d["region"])
		var p: Array = d.get("position", [0, 0])
		n.position = Vector2(float(p[0]), float(p[1]))
		n.goal = n.position
		n.upkeep_tick = world.tick
		world.npcs[id] = n


static func wants(n: NpcState) -> Dictionary:
	return defn(n.npc_id).get("wants", {})


# ---------------------------------------------------------------- requests

## talk (meet / recruit by handing over what they need), assign <job>.
static func request(world: WorldState, player_id: String, npc_id: String, action: String, arg: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	var n: NpcState = world.npcs.get(npc_id, null)
	if p == null or n == null or not p.online:
		return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
	if p.dead:
		return WorldActions._fail("ACTION_DEAD")
	var res := WorldActions._ok()
	res["npcs"] = true
	match action:
		"talk":
			if p.region_id != n.region_id or p.position.distance_to(n.position) > 110.0:
				return WorldActions._fail("ACTION_TOO_FAR")
			match n.recruit:
				"waiting":
					n.recruit = "met"
					res["notice"] = {"key": "NPC_MET", "args": [n.name, Items.describe(wants(n))]}
					res["events"] = [{"kind": "npc_met", "npc_id": npc_id}]
					_discover(world, "survivor_" + npc_id, res)
				"met":
					if world.bunkers.is_empty():
						return WorldActions._fail("NPC_NEEDS_SHELTER", [n.name])
					var bags: Array = [p.carried]
					var short := Inv.missing(bags, wants(n))
					if not short.is_empty():
						return WorldActions._fail("NPC_STILL_NEEDS", [n.name, Items.describe(short)])
					Inv.pay(bags, wants(n))
					var ids := world.bunkers.keys()
					ids.sort()
					n.bunker_id = str(ids[0])
					n.recruit = "travelling"
					n.activity = "travelling"
					n.arrive_tick = world.tick + int(float(c("travel_seconds", 60)) * Simulation.TICK_RATE)
					n.region_id = ""
					n.upkeep_tick = world.tick
					res["players"] = [p.player_id]
					res["notice"] = {"key": "NPC_RECRUITED", "args": [n.name]}
					res["events"] = [{"kind": "npc_recruited", "npc_id": npc_id}]
					SessionLog.info("settlement", "recruited", {"npc": npc_id, "by": player_id.substr(0, 6), "bunker": n.bunker_id})
				_:
					res["notice"] = {"key": "NPC_GREETING", "args": [n.name, TranslationServer.translate("JOB_" + (n.job if n.job != "" else "NONE").to_upper())]}
			return res
		"assign":
			if n.recruit != "home" and n.recruit != "travelling":
				return WorldActions._fail("NPC_NOT_RECRUITED", [n.name])
			if not (arg in JOBS):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			n.job = arg
			n.status = ""
			n.work_timer = 0.0
			n.path.clear()
			res["notice"] = {"key": "NPC_ASSIGNED", "args": [n.name, TranslationServer.translate("JOB_" + (arg if arg != "" else "NONE").to_upper())]}
			SessionLog.info("settlement", "assigned", {"npc": npc_id, "job": arg, "by": player_id.substr(0, 6)})
			return res
	return WorldActions._fail("ACTION_NOT_SUPPORTED")


static func _discover(world: WorldState, key: String, res: Dictionary) -> void:
	var d: Dictionary = world.meta.get("discoveries", {})
	if not d.has(key):
		d[key] = world.tick
		world.meta["discoveries"] = d
		res["meta"] = true


# ---------------------------------------------------------------- simulation

static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	if world.npcs.is_empty():
		return results
	var seconds := float(ticks) / Simulation.TICK_RATE
	var changed := false
	for n in world.npcs.values():
		match n.recruit:
			"travelling":
				if world.tick >= n.arrive_tick and _arrive(world, n):
					changed = true
					var ar := WorldActions._ok()
					ar["events"] = [{"kind": "npc_arrived", "npc_id": n.npc_id, "name": n.name}]
					results.append(ar)
			"home":
				changed = _upkeep(world, n, results) or changed
				changed = _live(world, n, seconds, results) or changed
	if changed:
		var r := WorldActions._ok()
		r["npcs"] = true
		results.append(r)
	return results


static func dev_recruit(world: WorldState, id: String) -> Dictionary:
	ensure(world)
	var n: NpcState = world.npcs.get(id)
	if n == null:
		return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
	if world.bunkers.is_empty():
		return WorldActions._fail("NPC_NEEDS_SHELTER", [n.name])
	var ids := world.bunkers.keys()
	ids.sort()
	n.bunker_id = str(ids[0])
	n.recruit = "travelling"
	n.arrive_tick = world.tick
	_arrive(world, n)
	n.upkeep_tick = world.tick
	var res := WorldActions._ok()
	res["npcs"] = true
	return res


static func _arrive(world: WorldState, n: NpcState) -> bool:
	var b := world.bunker(n.bunker_id)
	if b == null:
		return false
	n.region_id = b.level_region(-1)
	var reg := world.region(n.region_id)
	n.position = Content.entity_position(reg.entity_def("ladder_up")) + Vector2(0, 80)
	n.goal = n.position
	n.recruit = "home"
	n.activity = "idle"
	SessionLog.info("settlement", "arrived", {"npc": n.npc_id, "region": n.region_id})
	return true


## Once per game day: 1 food + 1 clean water from shared storage.
static func _upkeep(world: WorldState, n: NpcState, results: Array) -> bool:
	var day := int(float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	if world.tick - n.upkeep_tick < day:
		return false
	n.upkeep_tick += day
	var b := world.bunker(n.bunker_id)
	if b == null:
		return false
	var food := ""
	for f in ["potato", "canned_food"]:
		if b.amount(f) > 0:
			food = f
			break
	var ok := food != "" and b.amount("water_clean") > 0
	if ok:
		Inv.pay([b.resources], {food: 1, "water_clean": 1})
		var r := WorldActions._ok()
		r["bunkers"] = [b.bunker_id]
		results.append(r)
	n.fed = ok
	SessionLog.info("settlement", "upkeep", {"npc": n.npc_id, "fed": ok, "food": food})
	return true


static func _live(world: WorldState, n: NpcState, seconds: float, results: Array) -> bool:
	var reg := world.region(n.region_id)
	if reg == null:
		return false
	var before := [n.activity, n.status, n.position.round()]
	if EventSim.phase(world) == "active":
		n.activity = "sheltering"
		n.status = "NPC_STATUS_SHELTERING"
		_walk(world, n, reg, _shelter_spot(reg), seconds)
		return before != [n.activity, n.status, n.position.round()]
	if n.job == "":
		n.status = ""
		_idle(world, n, reg, seconds)
	else:
		var task := _next_task(world, n, reg)
		if task.is_empty():
			n.activity = "idle"
			_idle(world, n, reg, seconds)
		else:
			n.status = ""
			var at: Vector2 = task["pos"]
			if n.position.distance_to(at) > 70.0:
				n.activity = "walking"
				_walk(world, n, reg, at, seconds)
			else:
				n.activity = "working"
				n.work_timer += seconds * (1.0 if n.fed else 0.5)
				if n.work_timer >= float(c("work_seconds", 4)):
					n.work_timer = 0.0
					var r: Dictionary = _do(world, n, reg, task)
					if not r.is_empty():
						results.append(r)
	return before != [n.activity, n.status, n.position.round()]


## The next useful thing to do for the job, or {} with n.status explaining why not.
static func _next_task(world: WorldState, n: NpcState, reg: RegionState) -> Dictionary:
	var b := world.bunker(n.bunker_id)
	if b == null:
		return {}
	var powered := InfraSim.is_powered(world, reg.region_id)
	match n.job:
		"water":
			for eid in Content.entity_ids(reg.def_id):
				if str(reg.entity_def(eid).get("type", "")) != "purifier":
					continue
				var st := reg.entity_state(eid)
				var pos := Content.entity_position(reg.entity_def(eid))
				if int(st.get("output", 0)) > 0:
					return {"kind": "collect", "eid": eid, "pos": pos}
				if int(st.get("input", 0)) < int(InfraSim.c("purifier_input_capacity", 6)) and b.amount("water_dirty") > 0:
					return {"kind": "fill", "eid": eid, "pos": pos}
				if int(st.get("input", 0)) > 0 and not powered:
					n.status = "NPC_STATUS_NO_POWER"
				elif int(st.get("input", 0)) == 0 and b.amount("water_dirty") == 0:
					n.status = "NPC_STATUS_NO_DIRTY_WATER"
				else:
					n.status = "NPC_STATUS_WAITING"
				return {}
			n.status = "NPC_STATUS_NO_PURIFIER"
		"farm":
			var any := false
			var why := "NPC_STATUS_WAITING"
			for oid in reg.objects:
				var o: Dictionary = reg.objects[oid]
				if not bool(Build.def(str(o.get("def", ""))).get("farm", false)) or not Build.is_built(o):
					continue
				any = true
				var pos2 := Build.footprint(reg, o).get_center() + Vector2(0, 40)
				if str(o.get("crop", "")) == "ripe":
					return {"kind": "harvest", "oid": oid, "pos": pos2}
				if int(o.get("water", 0)) == 0 and str(o.get("crop", "")) == "":
					if b.amount("water_clean") > 0:
						return {"kind": "water", "oid": oid, "pos": pos2}
					why = "NPC_STATUS_NO_CLEAN_WATER"
				elif str(o.get("crop", "")) == "growing" and not powered:
					why = "NPC_STATUS_NO_POWER"
			n.status = why if any else "NPC_STATUS_NO_PLANTER"
	return {}


static func _do(world: WorldState, n: NpcState, reg: RegionState, task: Dictionary) -> Dictionary:
	var b := world.bunker(n.bunker_id)
	var res := WorldActions._ok()
	res["bunkers"] = [b.bunker_id]
	match str(task["kind"]):
		"collect":
			var st := reg.entity_state(task["eid"])
			var out := int(st.get("output", 0))
			reg.set_fields(task["eid"], {"output": 0})
			b.resources["water_clean"] = b.amount("water_clean") + out
			res["changes"] = [{"region_id": reg.region_id, "entity_id": task["eid"], "cause": "collected"}]
		"fill":
			var st2 := reg.entity_state(task["eid"])
			var room := int(InfraSim.c("purifier_input_capacity", 6)) - int(st2.get("input", 0))
			var moved := Items.move(b.resources, {}, "water_dirty", room)
			reg.set_fields(task["eid"], {"input": int(st2.get("input", 0)) + moved})
			res["changes"] = [{"region_id": reg.region_id, "entity_id": task["eid"], "cause": "filled"}]
		"harvest":
			var o: Dictionary = reg.objects[task["oid"]]
			FarmSim.harvest_to(world, o, b.resources)
			res["objects"] = [[reg.region_id, task["oid"]]]
		"water":
			var o2: Dictionary = reg.objects[task["oid"]]
			Inv.pay([b.resources], {"water_clean": 1})
			o2["water"] = int(o2.get("water", 0)) + 1
			res["objects"] = [[reg.region_id, task["oid"]]]
	res["events"] = [{"kind": "npc_work", "npc_id": n.npc_id, "task": task["kind"]}]
	return res


static func _idle(world: WorldState, n: NpcState, reg: RegionState, seconds: float) -> void:
	n.timer -= seconds
	if n.position.distance_to(n.goal) > 8.0:
		n.activity = "walking"
		_walk(world, n, reg, n.goal, seconds)
		return
	n.activity = "resting" if EnvSim.is_night(world) else "idle"
	if n.timer <= 0.0:
		n.timer = world.sim_rng().randf_range(4.0, 9.0)
		var cells := _open_cells(world, reg)
		if not cells.is_empty():
			n.goal = Terrain.cell_center(reg, cells[world.sim_rng().randi() % cells.size()])


static func _shelter_spot(reg: RegionState) -> Vector2:
	var ladder := Content.entity_position(reg.entity_def("ladder_up"))
	var best := ladder + Vector2(0, 80)
	for c2 in Terrain.open_cells(reg):
		var p := Terrain.cell_center(reg, c2)
		if p.distance_to(ladder) > best.distance_to(ladder):
			best = p
	return best


## Open, unobstructed floor cells (no solid structures).
static func _open_cells(world: WorldState, reg: RegionState) -> Array:
	var solid := _solid(reg)
	var out := []
	for c2 in Terrain.open_cells(reg):
		if not solid.has(c2):
			out.append(c2)
	return out


static func _solid(reg: RegionState) -> Dictionary:
	var solid := {}
	for oid in reg.objects:
		var o: Dictionary = reg.objects[oid]
		if Build.blocks(o):
			solid[Terrain.cell_of(reg, Build.footprint(reg, o).get_center())] = true
	return solid


## Walks on the bunker cell grid (breadth-first path around solid structures).
static func _walk(world: WorldState, n: NpcState, reg: RegionState, to: Vector2, seconds: float) -> void:
	var speed := float(c("speed", 70)) * seconds
	if not Terrain.has_terrain(reg):
		n.position = n.position.move_toward(to, speed)
		return
	var goal_cell := Terrain.cell_of(reg, to)
	if n.path.is_empty() or Terrain.cell_of(reg, n.path[n.path.size() - 1]) != goal_cell:
		n.path = _path(reg, Terrain.cell_of(reg, n.position), goal_cell)
		if n.path.is_empty():
			n.position = n.position.move_toward(to, speed * 0.25)
			return
	while speed > 0.0 and not n.path.is_empty():
		var nxt: Vector2 = n.path[0]
		var d := n.position.distance_to(nxt)
		if d <= speed:
			n.position = nxt
			speed -= d
			n.path.pop_front()
		else:
			n.facing = (nxt - n.position).normalized()
			n.position = n.position.move_toward(nxt, speed)
			speed = 0.0
	if n.path.is_empty() and n.position.distance_to(to) > 2.0:
		n.position = n.position.move_toward(to, speed + 1.0)


static func _path(reg: RegionState, from: Vector2i, to: Vector2i) -> Array:
	var solid := _solid(reg)
	solid.erase(to)
	if from == to:
		return [Terrain.cell_center(reg, to)]
	var prev := {from: from}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + dv
			if prev.has(nb) or solid.has(nb) or not Terrain.is_open(reg, nb):
				continue
			prev[nb] = cur
			queue.append(nb)
	if not prev.has(to):
		return []
	var out: Array = []
	var c2 := to
	while c2 != from:
		out.push_front(Terrain.cell_center(reg, c2))
		c2 = prev[c2]
	return out


## Snapshot rows for clients: [id, region, x, y, activity, job, status, recruit, name].
static func rows(world: WorldState) -> Array:
	var out := []
	for n in world.npcs.values():
		out.append([n.npc_id, n.region_id, snappedf(n.position.x, 0.1), snappedf(n.position.y, 0.1), n.activity, n.job,
			n.status, n.recruit, n.name, n.fed])
	return out


static func apply_rows(world: WorldState, rows_in: Array) -> void:
	for r in rows_in:
		var id := str(r[0])
		var n: NpcState = world.npcs.get(id)
		if n == null:
			n = NpcState.new()
			n.npc_id = id
			world.npcs[id] = n
		n.region_id = str(r[1])
		n.position = Vector2(float(r[2]), float(r[3]))
		n.activity = str(r[4])
		n.job = str(r[5])
		n.status = str(r[6])
		n.recruit = str(r[7])
		n.name = str(r[8])
		n.fed = bool(r[9])
