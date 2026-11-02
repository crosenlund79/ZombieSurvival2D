class_name EventSim
extends RefCounted
## Host-only regional threat and the homestead defence event, on the shared clock.
##
## Heat (world.meta.heat[region]) is a slow regional memory of disturbance: it
## rises with noise (attention) and zombie kills in a surface region and
## decays with a half-life. Higher heat means more wandering zombies in that
## region (extra transient wanderers, also more at night). Home heat
## (world.meta.home_heat) counts only disturbance near the homestead,
## including bunker noise that leaks up through the hatch (a steel hatch leaks
## far less). Zombies never learn where players are from this: heat only
## changes how many roam and whether a horde comes to the homestead.
##
## Defence event (world.meta.siege): when home heat passes a threshold (and
## the grace period and cooldown allow) a warning is given; after the warning
## a horde of real zombies walks to the homestead yard and attacks exposed
## structures (barricades, gate, crates, rain collector...) and anyone outside.
## It ends when the horde is beaten ("repelled") or when time runs out and the
## survivors drift off ("dispersed"). Then a cooldown applies and home heat
## drops. Phases: idle -> warning -> active -> idle (cooldown_until).
## Persistence: heat and the event record are saved; a horde is transient, so
## an active event resumes after loading with its remaining count respawned
## (never duplicated: the event id and remaining count come from the save).

const TUNING_PATH := "res://content/tuning/threat.json"
static var _cfg: Dictionary = {}


static func c(key: String, fallback: Variant) -> Variant:
	if _cfg.is_empty():
		var d = SafeFile.read_json(TUNING_PATH)
		_cfg = d if d is Dictionary else {}
	return _cfg.get(key, fallback)


static func heat(world: WorldState, region_id: String) -> float:
	return float(world.meta.get("heat", {}).get(region_id, 0.0))


static func home_heat(world: WorldState) -> float:
	return float(world.meta.get("home_heat", 0.0))


static func siege(world: WorldState) -> Dictionary:
	return world.meta.get("siege", {"phase": "idle", "id": 0})


static func phase(world: WorldState) -> String:
	return str(siege(world).get("phase", "idle"))


static func home_anchor() -> Vector2:
	var a: Array = c("home_anchor", [1270, 760])
	return Vector2(float(a[0]), float(a[1]))


## 0 calm, 1 unsettled, 2 dangerous, 3 overrun.
static func heat_level(world: WorldState, region_id: String) -> int:
	var h := heat(world, region_id)
	var lv := 0
	for t in c("heat_levels", [15, 40, 70]):
		if h >= float(t):
			lv += 1
	return lv


# ---------------------------------------------------------------- inputs

## Called by ZombieSim for every processed noise event in a zombie region.
static func on_noise(world: WorldState, region_id: String, pos: Vector2, attention: float) -> void:
	var hm: Dictionary = world.meta.get("heat", {})
	hm[region_id] = minf(100.0, float(hm.get(region_id, 0.0)) + attention * float(c("heat_per_attention", 0.9)))
	world.meta["heat"] = hm
	if region_id == str(c("home_region", "homestead")) and pos.distance_to(home_anchor()) <= float(c("home_radius", 700)):
		world.meta["home_heat"] = minf(100.0, home_heat(world) + attention * float(c("home_heat_per_attention", 1.6)))


static func on_kill(world: WorldState, region_id: String) -> void:
	var hm: Dictionary = world.meta.get("heat", {})
	hm[region_id] = minf(100.0, float(hm.get(region_id, 0.0)) + float(c("heat_per_kill", 1.5)))
	world.meta["heat"] = hm


## Noise made where no zombies live (farmhouse, bunker levels) partly escapes
## to the surface region the place belongs to. Returns [region, pos, scale] or [].
static func leak_target(world: WorldState, region_id: String) -> Array:
	var b := world.bunker_for_region(region_id)
	var r := world.region(region_id)
	if r == null:
		return []
	var scale := 1.0
	var entrance := region_id
	if b != null and not BunkerState.parse_region_id(region_id).is_empty():
		entrance = b.entrance_region
		var hatch := world.region(b.entrance_region)
		var st := hatch.entity_state(b.entrance_entity) if hatch != null else {}
		var leak: Dictionary = c("bunker_leak", {}).get(str(st.get("tier", "wood")), {"open": 0.55, "closed": 0.3})
		scale = float(leak.get("open" if bool(st.get("open", false)) else "closed", 0.3))
		var parsed := BunkerState.parse_region_id(region_id)
		scale *= pow(float(c("leak_per_depth", 0.6)), absi(int(parsed["depth"])) - 1)
	var er := world.region(entrance)
	if er == null:
		return []
	var surf: Dictionary = er.definition().get("surface", {})
	if surf.is_empty():
		return []
	scale *= float(c("building_leak", 0.6)) if b == null else 1.0
	var p: Array = surf.get("position", [0, 0])
	return [str(surf.get("region", "")), Vector2(float(p[0]), float(p[1])), scale]


# ---------------------------------------------------------------- step

static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	var seconds := float(ticks) / Simulation.TICK_RATE
	var k := pow(0.5, seconds / (float(c("heat_half_life_minutes", 10)) * 60.0))
	var hm: Dictionary = world.meta.get("heat", {})
	for rid in hm.keys():
		hm[rid] = float(hm[rid]) * k
		if float(hm[rid]) < 0.05:
			hm.erase(rid)
	world.meta["heat"] = hm
	world.meta["home_heat"] = home_heat(world) * pow(0.5, seconds / (float(c("home_heat_half_life_minutes", 8)) * 60.0))
	if not world.threat.enabled:
		return results
	if world.tick % (5 * Simulation.TICK_RATE) < ticks:
		_wanderers(world)
	_siege(world, results)
	return results


## Extra transient wanderers per region from heat and darkness.
static func _wanderers(world: WorldState) -> void:
	var bonus: Array = c("population_bonus", [0, 1, 3, 5])
	for rid in world.regions:
		var zc := ZombieSim.region_cfg(rid, world)
		if zc.is_empty():
			continue
		var want := int(bonus[clampi(heat_level(world, rid), 0, bonus.size() - 1)]) + EnvSim.extra_population(world)
		var extras: Array = []
		for z in world.zombies.values():
			if z.region_id == rid and z.extra and not z.is_dead() and not z.leaving:
				extras.append(z)
		var spots: Array = zc.get("entries", [])
		if extras.size() < want and not spots.is_empty():
			for sp in spots:
				var pos := Vector2(float(sp[0]), float(sp[1]))
				if ZombieSim._far_from_players(world, rid, pos, float(ZombieSim.c("min_spawn_distance_from_players", 720))):
					var z2 := ZombieSim.spawn(world, rid, pos, false)
					z2.extra = true
					z2.goal = pos + (Vector2(1200, 850) - pos).normalized() * 300.0
					break
		elif extras.size() > want:
			var z3: ZombieState = extras[0]
			if z3.ai == ZombieState.AI.WANDER:
				_send_off(world, z3)


static func _send_off(world: WorldState, z: ZombieState) -> void:
	var best := Vector2.INF
	for e in ZombieSim.region_cfg(z.region_id, world).get("entries", []):
		var ep := Vector2(float(e[0]), float(e[1]))
		if best == Vector2.INF or ep.distance_to(z.position) < best.distance_to(z.position):
			best = ep
	if best != Vector2.INF:
		z.leaving = true
		z.siege = false
		z.target_struct = ""
		z.ai = ZombieState.AI.WANDER
		z.goal = best
		z.timer = 0.0
		z.path.clear()


static func _siege(world: WorldState, results: Array) -> void:
	var s := siege(world)
	var ph := str(s.get("phase", "idle"))
	match ph:
		"idle":
			if world.tick < int(float(c("first_siege_after_minutes", 15)) * 60.0 * Simulation.TICK_RATE):
				return
			if world.tick < int(s.get("cooldown_until", 0)) or home_heat(world) < float(c("siege_threshold", 55)):
				return
			start_warning(world, float(c("siege_warning_seconds", 60)), results)
		"warning":
			if world.tick >= int(s.get("ends", 0)):
				_begin_attack(world, results)
		"active":
			var alive := 0
			for z in world.zombies.values():
				if z.siege and not z.is_dead():
					alive += 1
					_drive(world, z)
			if alive != int(s.get("remaining", 0)):
				s["remaining"] = alive
				world.meta["siege"] = s
				var r0 := WorldActions._ok()
				r0["meta"] = true
				results.append(r0)
			if alive == 0:
				_finish(world, "repelled", results)
			elif world.tick >= int(s.get("ends", 0)):
				for z2 in world.zombies.values():
					if z2.siege:
						_send_off(world, z2)
				_finish(world, "dispersed", results)


static func start_warning(world: WorldState, warning_seconds: float, results: Array) -> void:
	var s := siege(world)
	s["phase"] = "warning"
	s["id"] = int(s.get("id", 0)) + 1
	s["ends"] = world.tick + int(warning_seconds * Simulation.TICK_RATE)
	var online := maxi(1, world.online_players().size())
	s["size"] = int(c("siege_size", 6)) + int(c("siege_size_per_extra_player", 2)) * (online - 1)
	s["remaining"] = s["size"]
	s.erase("outcome")
	world.meta["siege"] = s
	SessionLog.info("threat", "siege_warning", {"id": s["id"], "size": s["size"], "home_heat": snappedf(home_heat(world), 0.1)})
	var res := WorldActions._ok()
	res["meta"] = true
	res["events"] = [{"kind": "siege_warning", "seconds": warning_seconds}]
	results.append(res)


static func _begin_attack(world: WorldState, results: Array) -> void:
	var s := siege(world)
	s["phase"] = "active"
	s["ends"] = world.tick + int(float(c("siege_duration_seconds", 180)) * Simulation.TICK_RATE)
	world.meta["siege"] = s
	spawn_horde(world, int(s.get("remaining", s.get("size", 6))))
	SessionLog.info("threat", "siege_started", {"id": s["id"], "zombies": s["remaining"]})
	var res := WorldActions._ok()
	res["meta"] = true
	res["events"] = [{"kind": "siege_started", "count": s["remaining"]}]
	results.append(res)


## Spawns the horde at the home region's edges (also used to resume after loading).
static func spawn_horde(world: WorldState, count: int) -> void:
	var rid := str(c("home_region", "homestead"))
	var entries: Array = ZombieSim.region_cfg(rid, world).get("entries", [])
	if entries.is_empty():
		return
	var anchor := home_anchor()
	var cands: Array = []
	for e in entries:
		cands.append(Vector2(float(e[0]), float(e[1])))
	cands.sort_custom(func(a, b): return a.distance_to(anchor) > b.distance_to(anchor))
	for i in count:
		var pos: Vector2 = cands[i % mini(4, cands.size())] + Vector2(float(i % 3) * 30.0, float(i % 2) * 30.0)
		var z := ZombieSim.spawn(world, rid, pos, false)
		z.siege = true
		z.ai = ZombieState.AI.INVESTIGATE
		z.goal = anchor
		z.last_known = anchor


## Keeps an idle horde zombie on task: walk to the homestead and wreck what is built there.
static func _drive(world: WorldState, z: ZombieState) -> void:
	if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.WINDUP, ZombieState.AI.RECOVER, ZombieState.AI.STAGGER] or z.target_struct != "":
		return
	var anchor := home_anchor()
	if z.position.distance_to(anchor) > 160.0:
		if z.ai != ZombieState.AI.INVESTIGATE or z.goal.distance_to(anchor) > 200.0:
			z.ai = ZombieState.AI.INVESTIGATE
			z.goal = anchor + Vector2(world.sim_rng().randf_range(-80, 80), world.sim_rng().randf_range(-60, 60))
			z.last_known = anchor
			z.timer = 0.0
			z.leaving = false
		return
	var t := exposed_target(world, z.region_id, z.position)
	if t != "":
		z.target_struct = t
		z.stuck = 0.0


## The nearest exposed structure near the homestead a horde zombie goes for.
static func exposed_target(world: WorldState, region_id: String, from: Vector2) -> String:
	var r := world.region(region_id)
	if r == null:
		return ""
	var best := ""
	var best_d := float(c("siege_target_radius", 520))
	for oid in r.objects:
		var o: Dictionary = r.objects[oid]
		if not Build.blocks(o):
			continue
		var d := Build.edge_distance(Build.footprint(r, o), from)
		if d < best_d:
			best_d = d
			best = "o:" + oid
	for eid in Content.entity_ids(r.def_id):
		var ed := r.entity_def(eid)
		if ed.has("structure") and not bool(r.entity_state(eid).get("open", false)):
			var d2 := Content.entity_position(ed).distance_to(from)
			if d2 < best_d:
				best_d = d2
				best = "e:" + eid
	return best


static func _finish(world: WorldState, outcome: String, results: Array) -> void:
	var s := siege(world)
	s["phase"] = "idle"
	s["outcome"] = outcome
	s["remaining"] = 0
	s["cooldown_until"] = world.tick + int(float(c("siege_cooldown_minutes", 25)) * 60.0 * Simulation.TICK_RATE)
	world.meta["siege"] = s
	world.meta["home_heat"] = home_heat(world) * float(c("home_heat_after_siege", 0.3))
	SessionLog.info("threat", "siege_ended", {"id": s.get("id"), "outcome": outcome})
	var res := WorldActions._ok()
	res["meta"] = true
	res["events"] = [{"kind": "siege_" + outcome}]
	results.append(res)


## After loading: an event that was active continues with its saved remaining horde.
static func resume_after_load(world: WorldState) -> void:
	var s := siege(world)
	if str(s.get("phase", "")) == "active":
		var alive := 0
		for z in world.zombies.values():
			if z.siege and not z.is_dead():
				alive += 1
		if alive == 0 and int(s.get("remaining", 0)) > 0:
			spawn_horde(world, int(s["remaining"]))
			SessionLog.info("threat", "siege_resumed", {"id": s.get("id"), "zombies": s["remaining"]})
