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
			return _changed(region, entity_id, "action")
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
	if chops < int(def.get("chops", 5)):
		region.set_fields(eid, {"chops": chops})
		return _changed(region, eid, "chop")
	# The felling blow: the tree's wood goes to whoever landed it, once.
	region.set_fields(eid, {"chops": chops, "felled": true})
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
		"transition": {}, "notice": {}}


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
