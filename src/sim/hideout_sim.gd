class_name HideoutSim
extends RefCounted
## The disturbed Burnt One hideout (iteration 014, an approved situational hunt
## trigger): an ordinary-looking house where one or two Burnt Ones hide. It is
## not a nest and nothing respawns.
##
##  * Noise made inside the house (searching, running, fighting, gunshots) adds up
##    as "disturbance" in the hideout entity's state (ZombieSim.make_noise → noted).
##  * Past the threshold the hidden ones emerge (once, host only): persistent Burnt
##    Ones at the authored hiding places, hunting the nearest player inside.
##  * Inside a side-view building Burnt Ones follow floors and take the stairs
##    (SideSection.chase_step). If their target flees outside, they make for the
##    door and follow through it, then hunt under the ordinary outdoor AI (sight,
##    hearing, losing the target, giving up).
##  * The hideout is "cleared" when its Burnt Ones are dead. Its state (disturbance,
##    triggered, cleared, ids) is saved; so are the Burnt Ones themselves.
## Every other building, the cabin and the bunkers keep the existing rules.

static func is_hideout(def: Dictionary) -> bool:
	return str(def.get("type", "")) == "hideout"


## Called for every noise (before it leaks to the street). Host.
static func noted(world: WorldState, region_id: String, attention: float) -> void:
	var r := world.region(region_id)
	if r == null:
		return
	for eid in Content.entity_ids(r.def_id):
		var d := r.entity_def(eid)
		if not is_hideout(d):
			continue
		var st := r.entity_state(eid)
		if bool(st.get("triggered", false)):
			continue
		r.set_fields(eid, {"disturbance": snappedf(float(st.get("disturbance", 0.0)) + attention, 0.001)})


static func step(world: WorldState, _ticks: int) -> Array:
	var out: Array = []
	var seen := {}
	for p in world.online_players():
		if seen.has(p.region_id):
			continue
		seen[p.region_id] = true
		var r := world.region(p.region_id)
		if r == null:
			continue
		for eid in Content.entity_ids(r.def_id):
			var d := r.entity_def(eid)
			if not is_hideout(d):
				continue
			var st := r.entity_state(eid)
			if not bool(st.get("triggered", false)) and float(st.get("disturbance", 0.0)) >= float(d.get("threshold", 0.9)):
				out.append(_trigger(world, r, eid, d))
			elif bool(st.get("triggered", false)) and not bool(st.get("cleared", false)) and _all_gone(world, st):
				r.set_fields(eid, {"cleared": true})
				out.append(WorldActions._changed(r, eid, "hideout_cleared"))
	# Burnt Ones following their quarry out through a door are handled every tick.
	for z in world.zombies.values():
		if not z.is_dead() and z.ai == ZombieState.AI.CHASE:
			var tr := follow_out(world, z)
			if not tr.is_empty():
				out.append(tr)
	return out


static func _all_gone(world: WorldState, st: Dictionary) -> bool:
	for zid in st.get("zombies", []):
		var z: ZombieState = world.zombies.get(str(zid))
		if z != null and not z.is_dead():
			return false
	return true


static func _trigger(world: WorldState, r: RegionState, eid: String, d: Dictionary) -> Dictionary:
	var target: PlayerState = null
	var ids: Array = []
	var events: Array = []
	for lair in d.get("lairs", []):
		var pos := SideSection.rest(r, Vector2(float(lair[0]), float(lair[1])))
		var z := ZombieSim.spawn(world, r.region_id, pos, true)
		var best := INF
		for p in world.online_players():
			if p.region_id == r.region_id and not p.dead and p.position.distance_to(pos) < best:
				best = p.position.distance_to(pos)
				target = p
		if target != null:
			z.target_player = target.player_id
			z.last_known = target.position
			z.goal = target.position
			z.ai = ZombieState.AI.CHASE
			z.burst = 2.5
		ids.append(z.zombie_id)
		events.append({"kind": "screech", "zombie_id": z.zombie_id, "region_id": r.region_id, "x": pos.x, "y": pos.y})
	r.set_fields(eid, {"triggered": true, "zombies": ids, "triggered_tick": world.tick})
	SessionLog.info("hideout", "disturbed", {"region": r.region_id, "burnt_ones": ids.size()})
	var res := WorldActions._changed(r, eid, "hideout_triggered")
	res["events"] = events
	if target != null:
		res["private_notice"] = {"player_id": target.player_id, "key": "HIDEOUT_DISTURBED", "args": []}
	return res


## Inside a building: has this Burnt One's quarry fled to the street through the
## door? Then its goal becomes that door (true).
static func door_goal(world: WorldState, z: ZombieState) -> bool:
	var door := _fled_door(world, z)
	if door.is_empty():
		return false
	z.goal = Content.entity_position(door)
	return true


static func _fled_door(world: WorldState, z: ZombieState) -> Dictionary:
	var r := world.region(z.region_id)
	if r == null or not SideSection.always_side(r) or z.target_player == "":
		return {}
	var p: PlayerState = world.players.get(z.target_player)
	var surf: Dictionary = r.definition().get("surface", {})
	if p == null or not p.online or p.dead or p.region_id != str(surf.get("region", "")):
		return {}
	return _exit_of(r, p.region_id)


## A Burnt One that reached the door after its fleeing quarry follows through it.
## Returns a result when it crossed (else {}).
static func follow_out(world: WorldState, z: ZombieState) -> Dictionary:
	var door := _fled_door(world, z)
	if door.is_empty():
		return {}
	var r := world.region(z.region_id)
	var p: PlayerState = world.players.get(z.target_player)
	var surf: Dictionary = r.definition().get("surface", {})
	var at := Content.entity_position(door)
	if z.position.distance_to(at) > 48.0:
		return {}
	var out_pos: Array = door.get("target", {}).get("position", surf.get("position", [0, 0]))
	z.region_id = p.region_id
	z.position = Vector2(float(out_pos[0]), float(out_pos[1])) + Vector2(0, 12)
	z.path.clear()
	z.last_known = p.position
	z.goal = p.position
	SessionLog.info("hideout", "followed_outside", {"zombie": z.zombie_id, "region": p.region_id})
	var res := WorldActions._ok()
	res["events"] = [{"kind": "zombie_through_door", "zombie_id": z.zombie_id, "region_id": p.region_id, "x": z.position.x, "y": z.position.y}]
	return res


static func _exit_of(r: RegionState, to_region: String) -> Dictionary:
	for eid in Content.entity_ids(r.def_id):
		var d := r.entity_def(eid)
		if str(d.get("type", "")) == "portal" and str(d.get("target", {}).get("region", "")) == to_region:
			return d
	return {}
