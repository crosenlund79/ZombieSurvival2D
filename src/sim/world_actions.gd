class_name WorldActions
extends RefCounted
## Host-side rules for requests that change the shared world.
## Every request is validated here (identity, region, range, object state,
## resources, staleness) before the world is changed. Clients never call this.
##
## Results are dictionaries:
##   ok, reason, reason_args            — refusal reason (translation key) for the requester
##   changes:     [{region_id, entity_id, cause}]  entities whose state changed
##   bunkers:     [bunker_id]           bunkers whose data changed (levels/resources)
##   players:     [player_id]           players whose carried resources changed
##   transition:  {player_id, region_id, position} or {}   a player moved to another region
##   notice:      {key, args} or {}     feedback for the requester only

const RANGE_TOLERANCE := 24.0
const MAX_PLAYER_SPEED := 260.0     # px/s, shared with the local avatar
const MOVE_SLACK := 48.0
const CARRY_LIMIT := 30             # wood a player can carry before depositing
const CHOP_COOLDOWN_TICKS := 3      # 0.3 s between chops per player
const ARRIVE_OFFSET := Vector2(0, 64)
const DEFAULT_TEST_LEVEL := "bunker_concrete"
const TEST_RIFLE := "military_rifle"


static func request_interact(world: WorldState, player_id: String, entity_id: String, expected_rev: int) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online:
		return _fail("ACTION_UNKNOWN_PLAYER")
	if p.dead:
		return _fail("ACTION_DEAD")
	var region := world.region(p.region_id)
	if region == null or not region.has_entity(entity_id):
		return _fail("ACTION_UNKNOWN_OBJECT")
	var def := region.entity_def(entity_id)
	var reach := float(def.get("interact_range", 80.0)) + RANGE_TOLERANCE
	if not SideSection.in_reach(region, p.position, Content.entity_position(def), reach):
		return _fail("ACTION_TOO_FAR")
	var state := region.entity_state(entity_id)
	if LockSim.is_locked(region, entity_id):
		return _fail("ACTION_LOCKED")  # iteration 015 D: a key or the lockpick first
	match str(def.get("type", "")):
		"door":
			if expected_rev != region.rev(entity_id):
				return _fail("ACTION_STALE")
			region.set_fields(entity_id, {"open": not bool(state.get("open", false))})
			ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "door")
			return _changed(region, entity_id, "action")
		"weapon_rack":
			# One club per player from the rack (it never runs out).
			var wid := str(def.get("weapon", "club"))
			for g in p.gear:
				if str(g.get("item", "")) == wid:
					return _fail("ACTION_ALREADY_ARMED")
			if Inv.free_slots(p) <= 0:
				return _fail("ACTION_CARRY_FULL", [Items.carry_slots()])
			var club := Inv.new_gear(world, wid)
			p.gear.append(club)
			if str(p.equipped.get("hand", "")) == "":
				p.equipped["hand"] = club["uid"]
			var wr := _ok()
			wr["vitals"] = [p.player_id]
			wr["players"] = [p.player_id]
			wr["notice"] = {"key": "WEAPON_TAKEN", "args": []}
			return wr
		"shelter_site":
			return _shelter(world, region, entity_id, def, state, expected_rev)
		"portal":
			return _portal(world, p, region, entity_id, def, state)
		"tree":
			return _chop(world, p, region, entity_id, def, state)
		"stockpile":
			return _deposit(world, p, region, def)
		"support_site":
			return _support(world, region, entity_id, def, state, expected_rev)
		"loot":
			return _loot(world, p, region, entity_id, def)
		"container":
			return ScavengeSim.request(world, p, region, entity_id, def)
		"starter_bag":
			return _starter_bag(world, p, region, entity_id, def, state)
		"bed":
			return SleepSim.request(world, p)
	return _fail("ACTION_NOT_SUPPORTED")


## The bag beside the burned shed: every player (including anyone who joins
## later) can take one personal starter kit from it, exactly once. Claims are
## stored per player in the bag's own state, so it saves, replicates and never
## hands out shared-world loot twice.
static func _starter_bag(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary, state: Dictionary) -> Dictionary:
	var taken: Array = (state.get("taken_by", []) as Array).duplicate()
	if taken.has(p.player_id):
		return _fail(str(def.get("empty_key", "ACTION_BAG_EMPTY")))
	var kit: Dictionary = (def.get("kit", {}) as Dictionary).duplicate()
	if bool(world.meta.get("test_rifle", false)):
		# iteration 015 E test start: an assault rifle (loaded) and spare rounds
		kit[TEST_RIFLE] = 1
		kit["rifle_rounds"] = int(kit.get("rifle_rounds", 0)) + 60
	var need := 0
	for item in kit:
		if Items.is_stack(str(item)):
			need += ceili(float(kit[item]) / float(maxi(1, Items.stack_limit(str(item)))))
		else:
			need += int(kit[item])
	if Inv.free_slots(p) < need:
		return _fail("ACTION_NEED_SLOTS", [need])
	var found: Array[String] = []
	for item in kit:
		if not Items.is_stack(str(item)):
			for i in int(kit[item]):
				var ng := Inv.new_gear(world, str(item))
				if Firearms.is_firearm(str(item)):
					ng["loaded"] = int(Firearms.spec(str(item)).get("capacity", 0))
				p.gear.append(ng)
		else:
			p.carried[item] = p.carrying(item) + int(kit[item])
		found.append(TranslationServer.translate(Items.name_key(str(item))))
	taken.append(p.player_id)
	region.set_fields(eid, {"taken_by": taken})
	var res := _changed(region, eid, "looted")
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	res["notice"] = {"key": str(def.get("taken_key", "STARTER_BAG_TAKEN")), "args": [", ".join(found)]}
	return res


# ------------------------------------------------------------------ shelter

static func _shelter(world: WorldState, region: RegionState, eid: String, def: Dictionary, state: Dictionary, expected_rev: int) -> Dictionary:
	if expected_rev != region.rev(eid):
		return _fail("ACTION_STALE")
	match str(state.get("stage", "none")):
		"none":
			var ticks := Simulation.seconds_to_ticks(float(def.get("build_seconds", 8.0)))
			region.set_fields(eid, {"stage": "building", "started": world.tick, "ticks": ticks})
			world.add_job(region.region_id, eid, world.tick + ticks)
			return _changed(region, eid, "build_started")
		"building":
			return _fail("ACTION_BUSY")
		"built":
			region.set_fields(eid, {"open": not bool(state.get("open", false))})
			return _changed(region, eid, "action")
	return _fail("ACTION_NOT_SUPPORTED")


## Shelter sites authored as already built (the Ashgrove town house cellar)
## get their bunker the first time a world runs with them. Idempotent; host only.
static func ensure_prebuilt_shelters(world: WorldState) -> int:
	var made := 0
	for rid in Content.region_ids():
		var region := world.region(rid)
		if region == null:
			continue
		for eid in Content.entity_ids(region.def_id):
			var def := region.entity_def(eid)
			if str(def.get("type", "")) != "shelter_site" or world.bunker(eid) != null:
				continue
			if str(region.entity_state(eid).get("stage", "none")) == "built":
				world.create_bunker(eid, rid, str(def.get("level_template", "bunker_earth")))
				made += 1
	if made > 0:
		SessionLog.info("world", "prebuilt_shelters", {"count": made})
	return made


## Called by Simulation when a construction's time is up.
static func complete_construction(world: WorldState, region_id: String, eid: String) -> Dictionary:
	var region := world.region(region_id)
	if region != null and eid.begins_with("terrain:"):
		return _complete_terrain(world, region, eid)
	if region != null and eid.begins_with("object:"):
		return Build.complete(world, region, eid.substr(7))
	if region != null and eid.begins_with("craft:"):
		return Craft.complete(world, region, eid.substr(6))
	if region == null or not region.has_entity(eid):
		return _fail("ACTION_UNKNOWN_OBJECT")
	var state := region.entity_state(eid)
	if str(state.get("stage", "")) != "building":
		return _fail("ACTION_NOT_SUPPORTED")
	var def := region.entity_def(eid)
	var res := _changed(region, eid, "completed")
	match str(def.get("type", "")):
		"shelter_site":
			region.set_fields(eid, {"stage": "built", "open": false})
			var b := world.create_bunker(eid, region_id, str(def.get("level_template", "bunker_earth")))
			res["bunkers"] = [b.bunker_id]
		"support_site":
			region.set_fields(eid, {"stage": "reinforced"})
		_:
			return _fail("ACTION_NOT_SUPPORTED")
	return res


# ------------------------------------------------------------------ portals

static func _portal(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary, state: Dictionary) -> Dictionary:
	if not bool(state.get("enabled", true)):
		return _fail("ACTION_NOT_AVAILABLE")
	var needs := str(def.get("requires_open", ""))
	if needs != "" and not bool(region.entity_state(needs).get("open", false)):
		return _fail("ACTION_CLOSED")
	var t := resolve_portal(world, region, def)
	if t.is_empty():
		return _fail("ACTION_NOT_AVAILABLE")
	p.region_id = t["region_id"]
	p.position = t["position"]
	if SideSection.side_for(world, p):
		p.position = SideSection.rest(world.region(p.region_id), p.position)  # feet on the floor
	var res := _ok()
	res["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": p.position}
	# Arriving somewhere new for the first time records a world discovery.
	var key := str(world.region_def(p.region_id).get("discovery", ""))
	if key != "" and discover(world, key):
		res["meta"] = true
		res["notice"] = {"key": "DISCOVERED_REGION", "args": [TranslationServer.translate(str(world.region_def(p.region_id).get("display_key", "")))]}
	return res


## Iteration 015: walking off a region edge into its geographic neighbour (WorldGeo).
## Host. Returns a result with the transition, or {} when the position does not cross.
static func edge_travel(world: WorldState, p: PlayerState) -> Dictionary:
	if p.vehicle_id != "" or p.dead:
		return {}
	var cr := WorldGeo.crossing(p.region_id, p.position)
	if cr.is_empty() or world.region(str(cr["region"])) == null:
		return {}
	var from := p.region_id
	p.region_id = str(cr["region"])
	p.position = cr["position"]
	var res := _ok()
	res["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": p.position}
	res["roster"] = true
	var key := str(world.region_def(p.region_id).get("discovery", ""))
	if key != "" and discover(world, key):
		res["meta"] = true
		res["notice"] = {"key": "DISCOVERED_REGION", "args": [TranslationServer.translate(str(world.region_def(p.region_id).get("display_key", "")))]}
	SessionLog.info("world", "edge_travel", {"player": p.player_id.substr(0, 6), "from": from, "to": p.region_id,
		"at": [roundi(p.position.x), roundi(p.position.y)]})
	return res


## Records a discovery once. Returns true when it is new.
static func discover(world: WorldState, key: String) -> bool:
	var d: Dictionary = world.meta.get("discoveries", {})
	if d.has(key):
		return false
	d[key] = world.tick
	world.meta["discoveries"] = d
	SessionLog.info("world", "discovery", {"key": key, "tick": world.tick})
	return true


## Where a portal leads: {region_id, position} or {} if the destination does not exist (yet).
## target forms: {"region", "position"} (static), {"bunker_of": site_id, "depth": n},
## {"bunker": "up"} / {"bunker": "down"} (relative to the bunker level the portal is in).
static func resolve_portal(world: WorldState, region: RegionState, def: Dictionary) -> Dictionary:
	var t: Dictionary = def.get("target", {})
	if t.has("region"):
		var pos: Array = t.get("position", [0, 0])
		if world.region(str(t["region"])) == null:
			return {}
		return {"region_id": str(t["region"]), "position": Vector2(float(pos[0]), float(pos[1]))}
	if t.has("bunker_of"):
		var b := world.bunker(str(t["bunker_of"]))
		var depth := int(t.get("depth", -1))
		if b == null or not b.has_level(depth):
			return {}
		return _arrive_at(world, b.level_region(depth), "ladder_up")
	if t.has("bunker"):
		var parsed := BunkerState.parse_region_id(region.region_id)
		if parsed.is_empty():
			return {}
		var b2 := world.bunker(parsed["bunker_id"])
		if b2 == null:
			return {}
		var depth2: int = parsed["depth"]
		if str(t["bunker"]) == "up":
			if depth2 == -1:
				var entrance := world.region(b2.entrance_region)
				if entrance == null:
					return {}
				return {"region_id": b2.entrance_region,
					"position": Content.entity_position(entrance.entity_def(b2.entrance_entity)) + ARRIVE_OFFSET}
			if not b2.has_level(depth2 + 1):
				return {}
			return _arrive_at(world, b2.level_region(depth2 + 1), "ladder_down")
		if not b2.has_level(depth2 - 1):
			return {}
		return _arrive_at(world, b2.level_region(depth2 - 1), "ladder_up")
	return {}


static func _arrive_at(world: WorldState, region_id: String, entity_id: String) -> Dictionary:
	var r := world.region(region_id)
	if r == null or not r.has_entity(entity_id):
		return {}
	return {"region_id": region_id, "position": Content.entity_position(r.entity_def(entity_id)) + ARRIVE_OFFSET}


# ------------------------------------------------------------------ trees and wood

static func _chop(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary, state: Dictionary) -> Dictionary:
	if bool(state.get("felled", false)):
		return _fail("ACTION_ALREADY_FELLED")
	var key := p.player_id + ":chop"
	if world.tick - int(world.cooldowns.get(key, -1000)) < CHOP_COOLDOWN_TICKS:
		return _fail("ACTION_TOO_FAST")
	if Inv.room_for(p, "wood") <= 0:
		return _fail("ACTION_CARRY_FULL", [Items.carry_slots()])
	world.cooldowns[key] = world.tick
	# Better tools count for several chops per blow (hatchet x2, felling axe x4).
	var tool := Items.info(p.weapon) if p.weapon != "" else Items.bare_hands()
	var chops := int(state.get("chops", 0)) + int(tool.get("chop", 1))
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "chop")
	var worn := wear_hand(p, 0.5)
	if chops < int(def.get("chops", 5)):
		region.set_fields(eid, {"chops": chops})
		var rc := _changed(region, eid, "chop")
		if worn:
			rc["players"] = [p.player_id]
		return rc
	# The felling blow: the tree's wood goes to whoever landed it, once.
	region.set_fields(eid, {"chops": chops, "felled": true})
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "fell")
	var gained := mini(int(def.get("wood", 4)) + int(tool.get("wood_bonus", 0)), Inv.room_for(p, "wood"))
	p.carried["wood"] = p.carrying("wood") + gained
	var res := _changed(region, eid, "felled")
	res["players"] = [p.player_id]
	res["notice"] = {"key": "WOOD_GAINED", "args": [gained, p.carrying("wood")]}
	return res


static func _deposit(world: WorldState, p: PlayerState, region: RegionState, def: Dictionary) -> Dictionary:
	var b: BunkerState = null
	if def.has("bunker_of"):
		b = world.bunker(str(def["bunker_of"]))
	else:
		b = world.bunker_for_region(region.region_id)
	if b == null:
		return _fail("ACTION_NO_SHELTER")
	var amount := p.carrying("wood")
	if amount <= 0:
		return _fail("ACTION_NOTHING_TO_DEPOSIT")
	b.resources["wood"] = b.amount("wood") + amount
	p.carried["wood"] = 0
	var res := _ok()
	res["bunkers"] = [b.bunker_id]
	res["players"] = [p.player_id]
	res["notice"] = {"key": "WOOD_DEPOSITED", "args": [amount, b.amount("wood")]}
	return res


static func _support(world: WorldState, region: RegionState, eid: String, def: Dictionary, state: Dictionary, expected_rev: int) -> Dictionary:
	match str(state.get("stage", "exposed")):
		"building":
			return _fail("ACTION_BUSY")
		"reinforced":
			return _fail("ACTION_ALREADY_DONE")
	if expected_rev != region.rev(eid):
		return _fail("ACTION_STALE")
	var b := world.bunker_for_region(region.region_id)
	if b == null:
		return _fail("ACTION_NO_SHELTER")
	var cost := int(def.get("wood_cost", 4))
	if b.amount("wood") < cost:
		return _fail("ACTION_NEED_WOOD", [cost, b.amount("wood")])
	# Spend first, in the same step as the state change: a second request sees
	# stage "building" and is refused, so the wood can never be spent twice.
	b.resources["wood"] = b.amount("wood") - cost
	var ticks := Simulation.seconds_to_ticks(float(def.get("build_seconds", 3.0)))
	region.set_fields(eid, {"stage": "building", "started": world.tick, "ticks": ticks})
	world.add_job(region.region_id, eid, world.tick + ticks)
	var res := _changed(region, eid, "build_started")
	res["bunkers"] = [b.bunker_id]
	return res


# ------------------------------------------------------------------ items, scavenging, machines

## Scavenging spots restock after their documented game-time interval, so the
## prototype can always be replayed (renewable fuel and water).
static func loot_ready(world: WorldState, region: RegionState, eid: String) -> bool:
	if world == null or region == null:
		return false
	var at := int(region.entity_state(eid).get("looted_at", -1))
	if at < 0:
		return true
	if bool(region.entity_def(eid).get("unique", false)):
		return false  # one-of-a-kind finds never come back
	var mins := float(region.entity_def(eid).get("restock_minutes", 15))
	return world.tick - at >= int(mins * 60.0 * Simulation.TICK_RATE)


static func _loot(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary) -> Dictionary:
	if not loot_ready(world, region, eid):
		return _fail("ACTION_LOOT_GONE" if bool(def.get("unique", false)) else "ACTION_LOOT_EMPTY")
	var loot: Dictionary = def.get("loot", {})
	var gear: Array = def.get("gear", [])
	var need := gear.size()
	for item in loot:
		need += int(loot[item])
	if Inv.free_slots(p) < need:
		return _fail("ACTION_NEED_SLOTS", [need])
	var found: Array[String] = []
	for item in loot:
		p.carried[item] = p.carrying(item) + int(loot[item])
		found.append("%d %s" % [int(loot[item]), TranslationServer.translate(Items.name_key(item))])
	for g in gear:
		p.gear.append(Inv.new_gear(world, str(g)))
		found.append(TranslationServer.translate(Items.name_key(str(g))))
	region.set_fields(eid, {"looted_at": world.tick})
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "door")
	var res := _changed(region, eid, "looted")
	res["players"] = [p.player_id]
	res["notice"] = {"key": "LOOT_FOUND", "args": [", ".join(found)]}
	if def.has("discovery") and discover(world, str(def["discovery"])):
		res["meta"] = true
		res["notice"] = {"key": "DISCOVERY_FOUND", "args": [", ".join(found)]}
	return res


## Panel actions on storage, generator and purifier (host-validated; every
## transfer moves items between two bags in one step, so nothing duplicates).
static func request_entity_action(world: WorldState, player_id: String, eid: String, action: String, arg: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online or p.dead:
		return _fail("ACTION_UNKNOWN_PLAYER")
	var region := world.region(p.region_id)
	if region == null or not region.has_entity(eid):
		return _fail("ACTION_UNKNOWN_OBJECT")
	var def := region.entity_def(eid)
	if not SideSection.in_reach(region, p.position, Content.entity_position(def), float(def.get("interact_range", 80.0)) + RANGE_TOLERANCE + 40.0):
		return _fail("ACTION_TOO_FAR")
	var b := world.bunker_for_region(region.region_id)
	var store: Dictionary = b.resources if b != null else {}
	var st := region.entity_state(eid)
	var res := _ok()
	res["players"] = [p.player_id]
	if b != null:
		res["bunkers"] = [b.bunker_id]
	if action == "key" or action == "pick" or action == "status":
		return LockSim.request(world, p, region, eid, action, arg)
	if ScavengeSim.is_container(def):
		if action != "take":
			return _fail("ACTION_NOT_SUPPORTED")
		return ScavengeSim.take(world, p, region, eid, arg)
	if action == "repair" and def.has("structure"):
		return Build.repair_entity(world, p, region, eid)
	if action == "upgrade" and str(def.get("type", "")) == "shelter_site":
		return _upgrade_hatch(world, p, region, eid, def)
	match str(def.get("type", "")) + ":" + action:
		"storage:store":
			if Items.move(p.carried, store, arg, 9999) <= 0:
				return _fail("ACTION_NOTHING_TO_DEPOSIT")
		"storage:store_all":
			# Iteration 013: unload everything carried into shelter storage in one go.
			var moved_all := 0
			for item in p.carried.keys():
				moved_all += Items.move(p.carried, store, str(item), 9999)
			if moved_all <= 0:
				return _fail("ACTION_NOTHING_TO_DEPOSIT")
		"storage:take":
			if Items.move(store, p.carried, arg, mini(1, Inv.room_for(p, arg))) <= 0:
				return _fail("ACTION_CARRY_FULL" if Items.amount(store, arg) > 0 else "ACTION_NOTHING_THERE", [Items.carry_slots()])
		"generator:fuel":
			var cap := float(InfraSim.c("generator_fuel_capacity", 4))
			if float(st.get("fuel", 0.0)) > cap - 1.0:
				return _fail("ACTION_TANK_FULL")
			var src := p.carried if Items.amount(p.carried, "fuel") > 0 else store
			if Items.amount(src, "fuel") <= 0:
				return _fail("ACTION_NEED_FUEL")
			src["fuel"] = Items.amount(src, "fuel") - 1
			if int(src["fuel"]) == 0:
				src.erase("fuel")
			region.set_fields(eid, {"fuel": float(st.get("fuel", 0.0)) + 1.0})
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "fuelled"}]
		"generator:fit_part":
			# The tuned carburetor (a unique find) halves fuel use, permanently.
			if bool(st.get("efficient", false)):
				return _fail("ACTION_ALREADY_DONE")
			var ci := -1
			for i in p.gear.size():
				if str(p.gear[i].get("item", "")) == "carburetor":
					ci = i
			if ci < 0:
				return _fail("ACTION_NEED_PART")
			p.gear.remove_at(ci)
			region.set_fields(eid, {"efficient": true})
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "upgraded"}]
			res["notice"] = {"key": "GEN_PART_FITTED", "args": []}
		"generator:toggle":
			var running := not bool(st.get("running", false))
			if running and float(st.get("fuel", 0.0)) <= 0.0:
				return _fail("ACTION_NEED_FUEL")
			region.set_fields(eid, {"running": running})
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "started" if running else "stopped"}]
		"purifier:fill":
			var room := int(InfraSim.c("purifier_input_capacity", 6)) - int(st.get("input", 0))
			var moved := 0
			for src2 in [p.carried, store]:
				var n := mini(room - moved, Items.amount(src2, "water_dirty"))
				if n > 0:
					src2["water_dirty"] = Items.amount(src2, "water_dirty") - n
					if int(src2["water_dirty"]) == 0:
						src2.erase("water_dirty")
					moved += n
			if moved <= 0:
				return _fail("ACTION_NEED_DIRTY_WATER" if room > 0 else "ACTION_TANK_FULL")
			region.set_fields(eid, {"input": int(st.get("input", 0)) + moved})
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "filled"}]
		"purifier:collect":
			var n2 := mini(int(st.get("output", 0)), Inv.room_for(p, "water_clean"))
			if n2 <= 0:
				return _fail("ACTION_NOTHING_THERE" if int(st.get("output", 0)) == 0 else "ACTION_CARRY_FULL", [Items.carry_slots()])
			p.carried["water_clean"] = p.carrying("water_clean") + n2
			region.set_fields(eid, {"output": int(st.get("output", 0)) - n2})
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "collected"}]
		"purifier:drink_tap":
			if int(st.get("output", 0)) <= 0:
				return _fail("ACTION_NOTHING_THERE")
			region.set_fields(eid, {"output": int(st.get("output", 0)) - 1})
			_drink_effect(p)
			res["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": "collected"}]
			res["vitals"] = [p.player_id]
			res["events"] = [{"kind": "drank", "player_id": p.player_id}]
		_:
			return _fail("ACTION_NOT_SUPPORTED")
	return res


## The shelter hatch can be upgraded (wood -> steel). A stronger hatch keeps
## more bunker noise from reaching the surface (EventSim noise leak).
static func _upgrade_hatch(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary) -> Dictionary:
	var st := region.entity_state(eid)
	if str(st.get("stage", "")) != "built":
		return _fail("ACTION_NOT_AVAILABLE")
	var ups: Dictionary = def.get("upgrades", {})
	var cur := str(st.get("tier", "wood"))
	var next := str(ups.get(cur, {}).get("to", ""))
	if next == "":
		return _fail("ACTION_ALREADY_DONE")
	var cost: Dictionary = ups[cur].get("cost", {})
	var bags := Inv.sources(world, p)
	var short := Inv.missing(bags, cost)
	if not short.is_empty():
		return _fail("ACTION_NEED_MATERIALS", [Items.describe(short)])
	var touched := Inv.uses_storage(p, cost)
	Inv.pay(bags, cost)
	region.set_fields(eid, {"tier": next})
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "build")
	var res := _changed(region, eid, "upgraded")
	res["players"] = [p.player_id]
	if touched:
		res["bunkers"] = [world.bunker_for_region(region.region_id).bunker_id]
	res["notice"] = {"key": "HATCH_UPGRADED", "args": []}
	var pos := Content.entity_position(def)
	res["events"] = [{"kind": "upgraded", "region_id": region.region_id, "eid": eid, "x": pos.x, "y": pos.y}]
	return res


## Drink one clean water from what the player carries.
static func request_drink(world: WorldState, player_id: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or p.dead:
		return _fail("ACTION_UNKNOWN_PLAYER")
	if p.carrying("water_clean") <= 0:
		if p.carrying("water_bottle") > 0:  # the starter kit's large bottle
			return Inv.request(world, player_id, "use", "water_bottle")
		return _fail("ACTION_NO_CLEAN_WATER")
	p.carried["water_clean"] = p.carrying("water_clean") - 1
	if int(p.carried["water_clean"]) == 0:
		p.carried.erase("water_clean")
	_drink_effect(p)
	var res := _ok()
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	res["events"] = [{"kind": "drank", "player_id": p.player_id}]
	return res


static func _drink_effect(p: PlayerState) -> void:
	p.hydration = minf(100.0, p.hydration + float(InfraSim.c("hydration_per_drink", 40)))


# ------------------------------------------------------------------ excavation

const DIG_REACH := 120.0
const SUPPORT_REACH := 90.0


## action "dig": excavate a solid cell. action "support": place a timber
## support on an open cell (wood from the bunker stockpile). Host-validated.
static func request_terrain(world: WorldState, player_id: String, action: String, cell: Vector2i) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online or p.dead:
		return _fail("ACTION_UNKNOWN_PLAYER")
	var region := world.region(p.region_id)
	if not Terrain.has_terrain(region):
		return _fail("ACTION_NOT_SUPPORTED")
	var center := Terrain.cell_center(region, cell)
	var cfgd := Terrain.cfg(region)
	var k := Terrain.key(cell)
	var res := _ok()
	res["terrain"] = [region.region_id]
	match action:
		"dig":
			if not SideSection.in_reach(region, p.position, center, DIG_REACH):
				return _fail("ACTION_TOO_FAR")
			var problem := Terrain.dig_problem(region, cell)
			if problem != "":
				return _fail(problem)
			var ticks := Simulation.seconds_to_ticks(float(cfgd.get("dig_seconds", 2.0)))
			var dig: Dictionary = region.terrain.get("digging", {})
			dig[k] = {"started": world.tick, "ticks": ticks}
			region.terrain["digging"] = dig
			world.add_job(region.region_id, "terrain:dig:" + k, world.tick + ticks)
			ZombieSim.make_noise(world, region.region_id, center, "dig")
			res["events"] = [{"kind": "dig_started", "region_id": region.region_id, "cell": k}]
			return res
		"support":
			if not SideSection.in_reach(region, p.position, center, SUPPORT_REACH):
				return _fail("ACTION_TOO_FAR")
			var problem2 := Terrain.support_problem(region, cell)
			if problem2 != "":
				return _fail(problem2)
			var b := world.bunker_for_region(region.region_id)
			if b == null:
				return _fail("ACTION_NO_SHELTER")
			var cost := int(cfgd.get("support_wood", 4))
			if b.amount("wood") < cost:
				return _fail("ACTION_NEED_WOOD", [cost, b.amount("wood")])
			b.resources["wood"] = b.amount("wood") - cost  # spent in the same step: never twice
			var ticks2 := Simulation.seconds_to_ticks(float(cfgd.get("support_seconds", 3.0)))
			var sup: Dictionary = region.terrain.get("supports", {})
			sup[k] = {"stage": "building", "started": world.tick, "ticks": ticks2}
			region.terrain["supports"] = sup
			world.add_job(region.region_id, "terrain:support:" + k, world.tick + ticks2)
			res["bunkers"] = [b.bunker_id]
			res["events"] = [{"kind": "support_started", "region_id": region.region_id, "cell": k}]
			return res
	return _fail("ACTION_NOT_SUPPORTED")


static func _complete_terrain(world: WorldState, region: RegionState, job: String) -> Dictionary:
	var parts := job.split(":")
	var kind := parts[1]
	var k := parts[2]
	var res := _ok()
	res["terrain"] = [region.region_id]
	if kind == "dig":
		var dig: Dictionary = region.terrain.get("digging", {})
		if not dig.has(k):
			return _fail("ACTION_NOT_SUPPORTED")
		dig.erase(k)
		var dug: Dictionary = region.terrain.get("dug", {})
		dug[k] = true
		region.terrain["dug"] = dug
		res["events"] = [{"kind": "dug", "region_id": region.region_id, "cell": k}]
	elif kind == "support":
		var sup: Dictionary = region.terrain.get("supports", {})
		if not sup.has(k) or str(sup[k].get("stage", "")) != "building":
			return _fail("ACTION_NOT_SUPPORTED")
		sup[k] = {"stage": "reinforced"}
		res["events"] = [{"kind": "support_done", "region_id": region.region_id, "cell": k}]
	return res


# ------------------------------------------------------------------ combat

## Melee numbers of what the player holds (content/items.json; bare hands otherwise).
static func weapon_stats(p: PlayerState) -> Dictionary:
	var item := p.weapon
	return Items.info(item) if item != "" else Items.bare_hands()
const ARC_COS := 0.42  # ~65 degrees either side of the swing direction


## A melee swing toward `aim`. The host picks the closest zombie in reach and
## in the swing arc with a clear line (no hitting through walls or fences).
static func request_attack(world: WorldState, player_id: String, aim: Vector2) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online or p.dead:
		return _fail("ACTION_DEAD")
	var gun := Firearms.held(p)
	if not gun.is_empty():
		return Firearms.fire(world, p, gun, aim)  # iteration 014: firearms
	var w: Dictionary = weapon_stats(p)
	var key := player_id + ":attack"
	if world.tick - int(world.cooldowns.get(key, -1000)) < int(w["cooldown_ticks"]):
		return _fail("ACTION_TOO_FAST")
	world.cooldowns[key] = world.tick
	aim = aim.normalized() if aim.length() > 0.01 else Vector2.DOWN
	var res := _ok()
	res["events"] = [{"kind": "swing", "player_id": player_id, "aim": aim}]
	ZombieSim.make_noise(world, p.region_id, p.position, "melee")
	var region := world.region(p.region_id)
	var best: ZombieState = null
	var best_d := INF
	for z in world.zombies.values():
		if z.region_id != p.region_id or z.is_dead():
			continue
		var to: Vector2 = z.position - p.position
		var d := to.length()
		if d > float(w["range"]):
			continue
		if d > 26.0 and aim.dot(to / d) < ARC_COS:
			continue
		var grid := NavGrid.for_def(region.def_id)
		if not grid.clear_line(p.position, z.position, NavGrid.dynamic_blocked(world, p.region_id, grid)):
			continue
		if d < best_d:
			best_d = d
			best = z
	if best != null:
		var hit := ZombieSim.damage_zombie(world, best, float(w["damage"]), p, aim * 16.0)
		res["events"].append_array(hit["events"])
		if wear_hand(p, 1.0):
			res["players"] = [p.player_id]
			res["vitals"] = [p.player_id]
	else:
		# iteration 015 E: wolves and bears can be fought off
		var an := WildlifeSim.target_for(world, p, aim, float(w["range"]) + 20.0, ARC_COS)
		if an != null:
			res["events"].append_array(WildlifeSim.damage(world, an, float(w["damage"]), p))
			if wear_hand(p, 1.0):
				res["players"] = [p.player_id]
				res["vitals"] = [p.player_id]
	return res


## Uses up a little of the held tool's condition. Returns true when it changed
## (the inventory must be republished). A broken item works like bare hands
## until it is repaired at a workbench.
static func wear_hand(p: PlayerState, amount: float) -> bool:
	var g := p.equipped_gear("hand")
	if g.is_empty() or float(g.get("cond", 0)) <= 0.0:
		return false
	g["cond"] = maxf(0.0, float(g["cond"]) - amount)
	return true


# ------------------------------------------------------------------ developer

## Creates one new level below the deepest level of the player's bunker.
static func dev_create_level(world: WorldState, player_id: String, template_id: String = DEFAULT_TEST_LEVEL) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null:
		return _fail("ACTION_UNKNOWN_PLAYER")
	var b := world.bunker_for_region(p.region_id)
	if b == null and not world.bunkers.is_empty():
		var ids := world.bunkers.keys()
		ids.sort()
		b = world.bunkers[ids[0]]
	if b == null:
		return _fail("DEV_NO_SHELTER")
	var above := b.deepest()
	var depth := above - 1
	var rid := world.add_level(b, depth, template_id)
	if rid == "":
		return _fail("DEV_LEVEL_FAILED")
	var res := _ok()
	res["bunkers"] = [b.bunker_id]
	var upper := world.region(b.level_region(above))
	if upper != null and upper.has_entity("ladder_down"):
		upper.set_fields("ladder_down", {"enabled": true})
		res["changes"] = [{"region_id": upper.region_id, "entity_id": "ladder_down", "cause": "level_created"}]
	res["notice"] = {"key": "DEV_LEVEL_CREATED", "args": [depth]}
	res["new_region"] = rid
	return res


# ------------------------------------------------------------------ helpers

static func is_plausible_move(from: Vector2, to: Vector2, dt_sec: float) -> bool:
	return from.distance_to(to) <= MAX_PLAYER_SPEED * dt_sec * 1.5 + MOVE_SLACK


static func _ok() -> Dictionary:
	return {"ok": true, "reason": "", "reason_args": [], "changes": [], "bunkers": [], "players": [],
		"transition": {}, "notice": {}, "events": [], "vitals": [], "terrain": [], "objects": []}


static func _changed(region: RegionState, eid: String, cause: String) -> Dictionary:
	var r := _ok()
	r["changes"] = [{"region_id": region.region_id, "entity_id": eid, "cause": cause}]
	return r


static func _fail(reason: String, args: Array = []) -> Dictionary:
	var r := _ok()
	r["ok"] = false
	r["reason"] = reason
	r["reason_args"] = args
	return r
