class_name HordeSim
extends RefCounted
## Roaming Burnt One hordes (iteration 015 E), host-only, on the shared clock.
##
## A horde is a loose group of transient Burnt Ones (ZombieState.horde = its id)
## that gathers at the edge of an outdoor region, out of every player's sight,
## and drifts toward people: the loudest recent noise zone in that region, else
## close to a player. Members use the normal AI (they investigate the horde's
## goal; anyone who sees a player chases). Bounded escalation:
##   * a horde can only form where players are, in an outdoor region, at most
##     `max_hordes` at once (one per region) and not within `cooldown_seconds`
##     of the last one there;
##   * the chance is checked every `check_seconds` — small by day, larger at night
##     and when the region is loud (attention), so making noise invites one;
##   * size grows with days survived and with loudness, but never past `max_size`,
##     and the global ceiling (`max_active` in zombies.json, plus `extra_cap`)
##     always holds;
##   * after `life_seconds`, or once most members are dead, the horde breaks up:
##     the living walk back out and vanish when nobody is near.
## Transient: hordes and their members are never saved (a reload starts calm).
## Developer: "dev horde" forms one now near the player; "dev hordes 0/1" turns
## automatic hordes off/on (transient, default from tuning "enabled").

const DEFAULTS := {"enabled": true, "check_seconds": 90, "chance_day": 0.04, "chance_night": 0.16,
	"chance_per_attention": 0.05, "first_day": 1, "size": [4, 6], "growth_per_day": 1, "loud_bonus": 3,
	"max_size": 12, "max_hordes": 2, "cooldown_seconds": 600, "life_seconds": 420,
	"min_spawn_distance": 1000, "gather_distance": 1250, "retarget_seconds": 12, "break_fraction": 0.3, "extra_cap": 12}


static func cfg(key: String) -> Variant:
	var h: Dictionary = ZombieSim.c("horde", {})
	return h.get(key, DEFAULTS.get(key))


static func enabled(world: WorldState) -> bool:
	return world.threat.hordes_on if world.threat.hordes_on_set else bool(cfg("enabled"))


static func active(world: WorldState) -> Dictionary:
	return world.threat.hordes


## Host, every tick from Simulation (cheap: real work every second).
static func step(world: WorldState, _ticks: int) -> Array:
	var out: Array = []
	if not world.threat.enabled:
		world.threat.hordes.clear()
		return out
	if world.tick < int(world.threat.horde_clock.get("next", 0)):
		return out
	world.threat.horde_clock["next"] = world.tick + int(Simulation.TICK_RATE)
	_maintain(world, out)
	var every := int(float(cfg("check_seconds")) * Simulation.TICK_RATE)
	if not world.threat.horde_clock.has("check"):
		world.threat.horde_clock["check"] = world.tick + every
	if enabled(world) and every > 0 and world.tick >= int(world.threat.horde_clock["check"]):
		world.threat.horde_clock["check"] = world.tick + every
		for rid in _candidate_regions(world):
			if _roll(world, rid):
				var r := form(world, rid, false)
				if bool(r.get("ok", false)):
					out.append(r)
	return out


## Outdoor regions with a living player on foot or in a car, sorted.
static func _candidate_regions(world: WorldState) -> Array:
	var seen := {}
	for p in world.online_players():
		if not p.dead and WorldGeo.is_outdoor(world.region_def(p.region_id)) and not ZombieSim.region_cfg(p.region_id, world).is_empty():
			seen[p.region_id] = true
	var ids := seen.keys()
	ids.sort()
	return ids


static func _roll(world: WorldState, rid: String) -> bool:
	if world.threat.hordes.size() >= int(cfg("max_hordes")):
		return false
	for h in world.threat.hordes.values():
		if str(h["region"]) == rid:
			return false
	if EnvSim.day_number(world) < int(cfg("first_day")):
		return false
	var last := int(world.threat.horde_last.get(rid, -1000000))
	if world.tick - last < int(float(cfg("cooldown_seconds")) * Simulation.TICK_RATE):
		return false
	var chance := float(cfg("chance_night")) if EnvSim.is_night(world) else float(cfg("chance_day"))
	chance += float(cfg("chance_per_attention")) * _loudness(world, rid)
	var rng := world.make_rng("horde:%s:%d" % [rid, world.tick])
	return rng.randf() < clampf(chance, 0.0, 0.9)


## The highest attention in a region right now (0 = quiet).
static func _loudness(world: WorldState, rid: String) -> float:
	var best := 0.0
	for key in world.threat.zones:
		if str(key).begins_with(rid + "|"):
			best = maxf(best, float(world.threat.zones[key]))
	return best


## How many a new horde in `rid` gets (bounded).
static func size_for(world: WorldState, rid: String) -> int:
	var sz: Array = cfg("size")
	var rng := world.make_rng("horde_size:%s:%d" % [rid, world.tick])
	var n := rng.randi_range(int(sz[0]), int(sz[1]))
	n += int(cfg("growth_per_day")) * maxi(0, EnvSim.day_number(world) - 1)
	n += int(cfg("loud_bonus")) if _loudness(world, rid) >= 3.5 else 0
	return clampi(n, 1, int(cfg("max_size")))


## Forms a horde in region `rid` (host). `forced`: the developer command, which
## skips the chance and the cooldown but not the caps.
static func form(world: WorldState, rid: String, forced: bool) -> Dictionary:
	var region := world.region(rid)
	if region == null or not WorldGeo.is_outdoor(world.region_def(rid)):
		return WorldActions._fail("DEV_HORDE_NOT_HERE")
	if world.threat.hordes.size() >= int(cfg("max_hordes")):
		return WorldActions._fail("DEV_HORDE_LIMIT")
	var cap := int(ZombieSim.c("max_active", 16)) + int(cfg("extra_cap"))
	var alive := 0
	for z in world.zombies.values():
		if not z.is_dead():
			alive += 1
	var n := mini(size_for(world, rid), cap - alive)
	if n <= 0:
		return WorldActions._fail("DEV_HORDE_LIMIT")
	var goal := _goal(world, rid)
	var start := _start_point(world, rid, goal)
	if start == Vector2.INF:
		return WorldActions._fail("DEV_HORDE_NOT_HERE")
	world.threat.horde_seq += 1
	var hid := "h%d" % world.threat.horde_seq
	var grid := NavGrid.for_def(region.def_id)
	var members: Array = []
	var rng := world.make_rng("horde_spread:" + hid)
	for i in n:
		var pos := start + Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
		if grid != null and grid.is_blocked(grid.to_cell(pos), {}):
			pos = start
		var z := ZombieSim.spawn(world, rid, pos, false)
		z.horde = hid
		z.extra = true
		ZombieSim._investigate(world, z, goal + Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 120)))
		members.append(z.zombie_id)
	world.threat.hordes[hid] = {"id": hid, "region": rid, "members": members, "size": n, "goal": goal,
		"born": world.tick, "retarget": world.tick, "breaking": false}
	world.threat.horde_last[rid] = world.tick
	SessionLog.info("horde", "formed", {"id": hid, "region": rid, "size": n, "forced": forced})
	var res := WorldActions._ok()
	res["events"] = [{"kind": "horde_forming", "region_id": rid, "x": start.x, "y": start.y, "size": n}]
	res["broadcast_notice"] = {"key": "HORDE_COMING", "args": []}
	return res


## Where the horde heads: the loudest zone in the region, else near a player.
static func _goal(world: WorldState, rid: String) -> Vector2:
	var best := 0.6
	var goal := Vector2.INF
	for key in world.threat.zones:
		if str(key).begins_with(rid + "|") and float(world.threat.zones[key]) > best:
			best = float(world.threat.zones[key])
			goal = ThreatState.zone_center(str(key))
	if goal != Vector2.INF:
		return goal
	var ps: Array = []
	for p in world.online_players():
		if p.region_id == rid and not p.dead:
			ps.append(p)
	if ps.is_empty():
		var b: Array = world.region_def(rid).get("bounds", [0, 0, 2000, 2000])
		return Vector2(float(b[2]) * 0.5, float(b[3]) * 0.5)
	ps.sort_custom(func(a, b): return a.player_id < b.player_id)
	var rng := world.make_rng("horde_goal:%s:%d" % [rid, world.tick])
	var p0: PlayerState = ps[rng.randi() % ps.size()]
	return p0.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(150, 420)


## A walkable point at the region's edge, far from every player, nearest the goal side.
static func _start_point(world: WorldState, rid: String, goal: Vector2) -> Vector2:
	var b: Array = world.region_def(rid).get("bounds", [0, 0, 2000, 2000])
	var rect := Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3])).grow(-140.0)
	var grid := NavGrid.for_def(world.region(rid).def_id)
	var cands: Array = []
	var entries: Array = ZombieSim.region_cfg(rid, world).get("entries", [])
	for e in entries:
		cands.append(Vector2(float(e[0]), float(e[1])))
	# gather in the woods some way off the goal (still out of sight), else at the edges
	for i in 16:
		var ring := goal + Vector2.from_angle(TAU * float(i) / 16.0) * float(cfg("gather_distance"))
		if rect.has_point(ring):
			cands.append(ring)
	for i in 24:
		var t := float(i) / 24.0
		cands.append(Vector2(rect.position.x + rect.size.x * t, rect.position.y))
		cands.append(Vector2(rect.position.x + rect.size.x * t, rect.end.y))
		cands.append(Vector2(rect.position.x, rect.position.y + rect.size.y * t))
		cands.append(Vector2(rect.end.x, rect.position.y + rect.size.y * t))
	# out of sight: further than a player's full daylight view (the host has no
	# view polygons, so distance stands in for PlayerSight)
	var min_d := maxf(float(cfg("min_spawn_distance")), 980.0)
	var best := Vector2.INF
	var bd := INF
	for c in cands:
		var cv: Vector2 = c
		if grid != null and grid.is_blocked(grid.to_cell(cv), {}):
			continue
		if not ZombieSim._far_from_players(world, rid, cv, min_d):
			continue
		var d := cv.distance_to(goal)
		if d < bd:
			bd = d
			best = cv
	return best


## Keeps hordes moving, retargets them and breaks them up (host, once a second).
static func _maintain(world: WorldState, out: Array) -> void:
	for hid in world.threat.hordes.keys():
		var h: Dictionary = world.threat.hordes[hid]
		var living: Array = []
		for zid in h["members"]:
			var z: ZombieState = world.zombies.get(str(zid))
			if z != null and not z.is_dead():
				living.append(z)
		var age := float(world.tick - int(h["born"])) / Simulation.TICK_RATE
		if not bool(h["breaking"]) and (age > float(cfg("life_seconds")) or living.size() <= int(ceil(float(h["size"]) * float(cfg("break_fraction"))))):
			h["breaking"] = true
			for z in living:
				z.horde = ""  # ordinary reinforcements now
				if z.ai != ZombieState.AI.CHASE:
					_send_off(world, z)
			SessionLog.info("horde", "breaking_up", {"id": hid, "left": living.size()})
		if living.is_empty():
			world.threat.hordes.erase(hid)
			continue
		if bool(h["breaking"]):
			if age > float(cfg("life_seconds")) + 120.0:
				for z in living:
					if z.ai != ZombieState.AI.CHASE and not z.leaving:
						_send_off(world, z)
			continue
		if world.tick - int(h["retarget"]) >= int(float(cfg("retarget_seconds")) * Simulation.TICK_RATE):
			h["retarget"] = world.tick
			var goal := _goal(world, str(h["region"]))
			h["goal"] = goal
			var rng := world.make_rng("horde_re:%s:%d" % [hid, world.tick])
			for z in living:
				if z.ai == ZombieState.AI.WANDER or (z.ai == ZombieState.AI.INVESTIGATE and z.timer <= 0.0):
					ZombieSim._investigate(world, z, goal + Vector2(rng.randf_range(-140, 140), rng.randf_range(-140, 140)))


## Walks a Burnt One back to the nearest way off the map (it vanishes there).
static func _send_off(world: WorldState, z: ZombieState) -> void:
	var best := Vector2.INF
	for e in ZombieSim.region_cfg(z.region_id, world).get("entries", []):
		var ep := Vector2(float(e[0]), float(e[1]))
		if best == Vector2.INF or ep.distance_to(z.position) < best.distance_to(z.position):
			best = ep
	if best == Vector2.INF:
		return
	z.ai = ZombieState.AI.WANDER
	z.leaving = true
	z.goal = best
	z.timer = 0.0
	z.path.clear()


## Developer status lines (F3).
static func lines(world: WorldState) -> Array[String]:
	var out: Array[String] = []
	for h in world.threat.hordes.values():
		var n := 0
		for zid in h["members"]:
			var z: ZombieState = world.zombies.get(str(zid))
			if z != null and not z.is_dead():
				n += 1
		out.append("%s %s %d/%d%s" % [h["id"], h["region"], n, int(h["size"]), " (breaking up)" if bool(h["breaking"]) else ""])
	return out
