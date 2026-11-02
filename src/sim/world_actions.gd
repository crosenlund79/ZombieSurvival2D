class_name WorldActions
extends RefCounted
## Host-side rules for requests that change the shared world.
## Every request is validated here (identity, region, range, staleness)
## before the world is changed. Clients never call this directly.

const RANGE_TOLERANCE := 24.0
const MAX_PLAYER_SPEED := 260.0     # px/s, shared with the local avatar
const MOVE_SLACK := 48.0


## Returns {ok, reason, region_id, entity_id, state, rev}.
## expected_rev: the revision the requester saw. If someone else changed the
## object first, the request is refused as stale instead of undoing their change.
static func request_interact(world: WorldState, player_id: String, entity_id: String, expected_rev: int) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online:
		return _fail("ACTION_UNKNOWN_PLAYER")
	var region := world.region(p.region_id)
	if region == null or not region.has_entity(entity_id):
		return _fail("ACTION_UNKNOWN_OBJECT")
	var def := Content.entity_def(p.region_id, entity_id)
	var reach := float(def.get("interact_range", 80.0)) + RANGE_TOLERANCE
	if p.position.distance_to(Content.entity_position(def)) > reach:
		return _fail("ACTION_TOO_FAR")
	if expected_rev != region.rev(entity_id):
		return _fail("ACTION_STALE")
	match str(def.get("type", "")):
		"door":
			var state := region.entity_state(entity_id)
			region.set_fields(entity_id, {"open": not bool(state.get("open", false))})
		_:
			return _fail("ACTION_NOT_SUPPORTED")
	return {"ok": true, "reason": "", "region_id": p.region_id, "entity_id": entity_id,
		"state": region.entity_state(entity_id), "rev": region.rev(entity_id)}


static func is_plausible_move(from: Vector2, to: Vector2, dt_sec: float) -> bool:
	return from.distance_to(to) <= MAX_PLAYER_SPEED * dt_sec * 1.5 + MOVE_SLACK


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
