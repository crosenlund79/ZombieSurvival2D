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
	if p.position.distance_to(Content.entity_position(def)) > reach:
		return _fail("ACTION_TOO_FAR")
	var state := region.entity_state(entity_id)
	match str(def.get("type", "")):
		"door":
			if expected_rev != region.rev(entity_id):
				return _fail("ACTION_STALE")
			region.set_fields(entity_id, {"open": not bool(state.get("open", false))})
			ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "door")
			return _changed(region, entity_id, "action")
		"weapon_rack":
			if p.weapon == str(def.get("weapon", "club")):
				return _fail("ACTION_ALREADY_ARMED")
			p.weapon = str(def.get("weapon", "club"))
			var wr := _ok()
			wr["vitals"] = [p.player_id]
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
	return _fail("ACTION_NOT_SUPPORTED")


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


## Called by Simulation when a construction's time is up.
static func complete_construction(world: WorldState, region_id: String, eid: String) -> Dictionary:
	var region := world.region(region_id)
	if region != null and eid.begins_with("terrain:"):
		return _complete_terrain(world, region, eid)
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
	var res := _ok()
	res["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": p.position}
	return res


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
	if p.carrying("wood") >= CARRY_LIMIT:
		return _fail("ACTION_CARRY_FULL", [CARRY_LIMIT])
	world.cooldowns[key] = world.tick
	var chops := int(state.get("chops", 0)) + 1
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "chop")
	if chops < int(def.get("chops", 5)):
		region.set_fields(eid, {"chops": chops})
		return _changed(region, eid, "chop")
	# The felling blow: the tree's wood goes to whoever landed it, once.
	region.set_fields(eid, {"chops": chops, "felled": true})
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "fell")
	var gained := mini(int(def.get("wood", 4)), CARRY_LIMIT - p.carrying("wood"))
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
			if p.position.distance_to(center) > DIG_REACH:
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
			if p.position.distance_to(center) > SUPPORT_REACH:
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

const WEAPONS := {
	"": {"damage": 12.0, "range": 54.0, "cooldown_ticks": 5},
	"club": {"damage": 34.0, "range": 74.0, "cooldown_ticks": 6},
}
const ARC_COS := 0.42  # ~65 degrees either side of the swing direction


## A melee swing toward `aim`. The host picks the closest zombie in reach and
## in the swing arc with a clear line (no hitting through walls or fences).
static func request_attack(world: WorldState, player_id: String, aim: Vector2) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online or p.dead:
		return _fail("ACTION_DEAD")
	var w: Dictionary = WEAPONS.get(p.weapon, WEAPONS[""])
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
	return res


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
		"transition": {}, "notice": {}, "events": [], "vitals": [], "terrain": []}


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
