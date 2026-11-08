class_name LockSim
extends RefCounted
## Locked doors and containers (iteration 015 D), host-authoritative.
##
## Content: an entity with "lock": {"level": 1..3, "key": item id (optional)} starts
## locked (entity state "locked"). Unlocking persists like any entity state.
##  * a key: carrying the lock's key item opens it at once (keys are not used up);
##  * picking: a short skill game. A lock has 2–4 pins (level + 1); each pin has a
##    hidden sweet angle (0..1, from the world seed and the lock's id) and a window
##    that narrows with the level. The client turns the pick at an angle; the host
##    decides: inside the window the pin sets, otherwise the pick takes wear in
##    proportion to how far off it was (and may break, which drops the pins).
##    Every turn is a host request, so nothing is decided on the client.
##    Progress per player and lock is runtime only (a pick jammed halfway resets).
## Requires a "lockpick" in the gear. No separate skill yet (extensible later).

const WINDOW := {1: 0.13, 2: 0.085, 3: 0.055}
const PICK_ITEM := "lockpick"


static func lock_def(def: Dictionary) -> Dictionary:
	return def.get("lock", {}) if def.get("lock") is Dictionary else {}


static func is_locked(region: RegionState, eid: String) -> bool:
	if lock_def(region.entity_def(eid)).is_empty():
		return false
	var st := region.entity_state(eid)
	if bool(st.get("searched", false)):
		return false  # a container searched before it had a lock (older saves) stays open
	return bool(st.get("locked", true))


static func level(def: Dictionary) -> int:
	return clampi(int(lock_def(def).get("level", 1)), 1, 3)


static func pins(def: Dictionary) -> int:
	return level(def) + 1


static func window(def: Dictionary) -> float:
	return float(WINDOW[level(def)])


## The hidden sweet angle of pin `i` (host and tests).
static func sweet(world: WorldState, eid: String, i: int) -> float:
	var rng := world.make_rng("lock:%s:%d" % [eid, i])
	return rng.randf_range(0.08, 0.92)


static func _key(pid: String, eid: String) -> String:
	return pid + ":pick:" + eid


static func progress(world: WorldState, pid: String, eid: String) -> int:
	return int(world.cooldowns.get(_key(pid, eid), 0))


## Host: a lock action on entity `eid` ("key", "pick" with arg = angle 0..1, or "status").
static func request(world: WorldState, p: PlayerState, region: RegionState, eid: String, action: String, arg: String) -> Dictionary:
	var def := region.entity_def(eid)
	if lock_def(def).is_empty():
		return WorldActions._fail("ACTION_NOT_SUPPORTED")
	if not is_locked(region, eid):
		return WorldActions._fail("ACTION_NOT_LOCKED")
	var reach := float(def.get("interact_range", 72.0)) + WorldActions.RANGE_TOLERANCE + 40.0
	if not SideSection.in_reach(region, p.position, Content.entity_position(def), reach):
		return WorldActions._fail("ACTION_TOO_FAR")
	match action:
		"key":
			var k := str(lock_def(def).get("key", ""))
			if k == "" or not (p.carrying(k) > 0 or p.has_gear_item(k)):
				return WorldActions._fail("ACTION_NO_KEY")
			return _unlock(world, p, region, eid, "key")
		"pick":
			return _turn(world, p, region, eid, clampf(str(arg).to_float(), 0.0, 1.0))
		"status":
			# the panel opening: how many pins this player already has set here
			var st := WorldActions._ok()
			st["players"] = [p.player_id]
			st["lock"] = {"entity_id": eid, "set": progress(world, p.player_id, eid), "pins": pins(def), "closeness": 0.0, "result": "status"}
			return st
	return WorldActions._fail("ACTION_NOT_SUPPORTED")


static func _turn(world: WorldState, p: PlayerState, region: RegionState, eid: String, angle: float) -> Dictionary:
	var def := region.entity_def(eid)
	var gi := -1
	for i in p.gear.size():
		if str(p.gear[i].get("item", "")) == PICK_ITEM:
			gi = i
			break
	if gi < 0:
		return WorldActions._fail("ACTION_NO_LOCKPICK")
	var key := p.player_id + ":pick_turn"
	if world.tick - int(world.cooldowns.get(key, -100)) < 2:
		return WorldActions._fail("ACTION_TOO_FAST")
	world.cooldowns[key] = world.tick
	var pin := progress(world, p.player_id, eid)
	var off := absf(angle - sweet(world, eid, pin))
	var res := WorldActions._ok()
	res["players"] = [p.player_id]
	var total := pins(def)
	if off <= window(def):
		pin += 1
		world.cooldowns[_key(p.player_id, eid)] = pin
		res["lock"] = {"entity_id": eid, "set": pin, "pins": total, "closeness": 1.0, "result": "set"}
		res["events"] = [{"kind": "lock_pin", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid}]
		if pin >= total:
			var u := _unlock(world, p, region, eid, "pick")
			u["lock"] = {"entity_id": eid, "set": total, "pins": total, "closeness": 1.0, "result": "open"}
			return u
		return res
	# a miss: the pick takes wear (more the further off), and may snap
	var g: Dictionary = p.gear[gi]
	var top := float(Items.info(PICK_ITEM).get("durability", 100))
	g["cond"] = float(g.get("cond", top)) - top * (0.08 + 0.35 * off) * (0.8 + 0.2 * level(def))
	var closeness := clampf(1.0 - off / 0.5, 0.0, 1.0)
	res["lock"] = {"entity_id": eid, "set": pin, "pins": total, "closeness": closeness, "result": "miss"}
	res["events"] = [{"kind": "lock_miss", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid}]
	if float(g["cond"]) <= 0.0:
		p.gear.remove_at(gi)
		Inv.unequip_uid(p, str(g.get("uid", "")))
		world.cooldowns.erase(_key(p.player_id, eid))
		res["lock"]["result"] = "broken"
		res["lock"]["set"] = 0
		res["private_notice"] = {"player_id": p.player_id, "key": "LOCKPICK_BROKE", "args": []}
		res["events"] = [{"kind": "lock_break", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid}]
		SessionLog.info("lock", "pick_broke", {"entity": eid, "player": p.player_id.substr(0, 6)})
	return res


static func _unlock(world: WorldState, p: PlayerState, region: RegionState, eid: String, how: String) -> Dictionary:
	region.set_fields(eid, {"locked": false})
	world.cooldowns.erase(_key(p.player_id, eid))
	var res := WorldActions._changed(region, eid, "unlocked")
	res["players"] = [p.player_id]
	res["private_notice"] = {"player_id": p.player_id, "key": "UNLOCKED_KEY" if how == "key" else "UNLOCKED_PICK", "args": []}
	res["events"] = [{"kind": "lock_open", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid}]
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(region.entity_def(eid)), "door")
	SessionLog.info("lock", "unlocked", {"entity": eid, "player": p.player_id.substr(0, 6), "how": how})
	return res
