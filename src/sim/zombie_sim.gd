class_name ZombieSim
extends RefCounted
## Host-only zombie simulation, stepped by Simulation.advance on the shared
## clock. Handles hearing (noise events), attention escalation and decay,
## the AI state machine, movement on the NavGrid, zombie attacks, corpses,
## reinforcement spawning and base-population replenishment.
##
## Results are WorldActions-style dictionaries ("events", "vitals") that
## GameSession publishes. Clients never run this.

const DT := 1.0 / Simulation.TICK_RATE
const TUNING_PATH := "res://content/tuning/zombies.json"

static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d = SafeFile.read_json(TUNING_PATH)
		_cfg = d if d is Dictionary else {}
	return _cfg


static func c(key: String, fallback: Variant) -> Variant:
	return cfg().get(key, fallback)


## Queues a noise event of a configured category at a world position.
static func make_noise(world: WorldState, region_id: String, pos: Vector2, category: String, scale: float = 1.0) -> void:
	var n: Dictionary = c("noise", {}).get(category, {"radius": 200, "attention": 0.2})
	if region_cfg(region_id, world).is_empty():
		# Nobody hears it in here, but part of the sound reaches the surface
		# (through the hatch for bunker levels; a steel hatch keeps most in).
		var leak := EventSim.leak_target(world, region_id)
		if leak.is_empty() or float(leak[2]) < 0.05 or region_cfg(str(leak[0]), world).is_empty():
			return
		world.threat.add_noise(str(leak[0]), leak[1], float(n["radius"]) * scale * float(leak[2]),
			float(n["attention"]) * scale * float(leak[2]), category + "_leak")
		return
	world.threat.add_noise(region_id, pos, float(n["radius"]) * scale, float(n["attention"]) * scale, category)


static func region_cfg(region_id: String, world: WorldState) -> Dictionary:
	return world.region_def(region_id).get("zombies", {})


# ======================================================================
# Population
# ======================================================================

static func spawn(world: WorldState, region_id: String, pos: Vector2, persistent: bool) -> ZombieState:
	var z := ZombieState.new()
	world.next_zombie += 1
	z.zombie_id = "z%d" % world.next_zombie
	z.region_id = region_id
	z.position = pos
	z.goal = pos
	z.health = float(c("health", 100))
	z.persistent = persistent
	world.zombies[z.zombie_id] = z
	return z


static func _far_from_players(world: WorldState, region_id: String, pos: Vector2, min_dist: float) -> bool:
	for p in world.online_players():
		if p.region_id == region_id and not p.dead and p.position.distance_to(pos) < min_dist:
			return false
	return true


## Tops up the persistent base population of every region that defines one.
## Called when a session starts and periodically; never spawns near players.
static func ensure_population(world: WorldState) -> int:
	var added := 0
	if not world.threat.enabled or not world.threat.ambient:
		return 0
	for rid in world.regions:
		var zc := region_cfg(rid, world)
		if zc.is_empty():
			continue
		var want := int(zc.get("base_population", 0))
		var have := 0
		for z in world.zombies.values():
			if z.region_id == rid and z.persistent and not z.is_dead():
				have += 1
		var spots: Array = zc.get("spawns", [])
		for i in spots.size():
			if have >= want:
				break
			var sp: Array = spots[(i + world.next_zombie) % spots.size()]
			var pos := Vector2(float(sp[0]), float(sp[1]))
			if _far_from_players(world, rid, pos, float(c("min_spawn_distance_from_players", 720))):
				spawn(world, rid, pos, true)
				have += 1
				added += 1
	return added


# ======================================================================
# Main step
# ======================================================================

static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	if not world.threat.enabled:
		world.zombies.clear()
		world.threat.queue.clear()
		world.threat.zones.clear()
		return results
	var ai_ticks := mini(ticks, int(c("ai_catchup_ticks", 10)))
	for t in ai_ticks:
		results.append_array(_tick(world))
	# Long jumps (dev clock advance): decay attention for the skipped time only.
	if ticks > ai_ticks:
		_decay(world, (ticks - ai_ticks) * DT)
	return results


static func _tick(world: WorldState) -> Array:
	var results: Array = []
	_process_noise(world)
	_decay(world, DT)
	_escalate(world, results)
	var budget := [int(c("path_budget_per_tick", 3))]
	_traps(world, results)
	_hunts(world, results)
	var dyn_cache := {}
	for z in world.zombies.values().duplicate():
		if not dyn_cache.has(z.region_id):
			var grid := NavGrid.for_def(world.region(z.region_id).def_id) if world.region(z.region_id) != null else null
			dyn_cache[z.region_id] = [grid, NavGrid.dynamic_blocked(world, z.region_id, grid) if grid != null else {}]
		var nav: Array = dyn_cache[z.region_id]
		if nav[0] == null:
			continue
		_update(world, z, nav[0], nav[1], budget, results)
	if world.tick % int(float(c("replenish_every", 60)) * Simulation.TICK_RATE) == 0:
		ensure_population(world)
	return results


# ======================================================================
# Burnt One hunts (Red Thaw). What starts a hunt is undecided: only the
# developer command "dev hunt" does. A hunter is told where its target is at the
# start and catches the scent again every scent_seconds while it has lost them;
# otherwise it uses the normal sight / chase / attack / lose-target AI. It never
# follows anyone into a building or the bunker (other regions) and gives up after
# hunt_seconds, walking off the map. Hunters are transient: never saved.
# ======================================================================

## Starts a hunt for player_id. Returns {ok, zombie_id} or {ok: false, reason}.
static func start_hunt(world: WorldState, player_id: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online or p.dead:
		return {"ok": false, "reason": "HUNT_NO_TARGET"}
	var zc := region_cfg(p.region_id, world)
	if zc.is_empty():
		return {"ok": false, "reason": "HUNT_TARGET_SHELTERED"}
	var want := float(c("hunt_spawn_distance", 760))
	var best := Vector2.INF
	for sp in (zc.get("entries", []) as Array) + (zc.get("spawns", []) as Array):
		var pos := Vector2(float(sp[0]), float(sp[1]))
		if not _far_from_players(world, p.region_id, pos, float(c("hunt_min_distance", 480))):
			continue
		if best == Vector2.INF or absf(pos.distance_to(p.position) - want) < absf(best.distance_to(p.position) - want):
			best = pos
	if best == Vector2.INF:
		return {"ok": false, "reason": "HUNT_NO_SPOT"}
	var z := spawn(world, p.region_id, best, false)
	z.hunter = true
	z.hunt_target = player_id
	z.hunt_until = world.tick + int(float(c("hunt_seconds", 240)) * Simulation.TICK_RATE)
	_investigate(world, z, p.position)
	SessionLog.info("threat", "hunt_started", {"zombie": z.zombie_id, "target": player_id.substr(0, 6),
		"region": p.region_id, "from": [roundi(best.x), roundi(best.y)], "distance": roundi(best.distance_to(p.position))})
	return {"ok": true, "zombie_id": z.zombie_id}


static func _hunts(world: WorldState, results: Array) -> void:
	for z in world.zombies.values():
		if not z.hunter or z.is_dead() or z.leaving:
			continue
		if world.tick >= z.hunt_until:
			z.hunter = false
			z.target_player = ""
			_after_search(world, z)
			z.leaving = true
			SessionLog.info("threat", "hunt_ended", {"zombie": z.zombie_id, "reason": "gave_up"})
			results.append(_event_result({"kind": "hunt_ended", "zombie_id": z.zombie_id}))
			continue
		if z.ai == ZombieState.AI.WANDER or z.ai == ZombieState.AI.INVESTIGATE:
			var every := int(float(c("hunt_scent_seconds", 12)) * Simulation.TICK_RATE)
			if every > 0 and world.tick % every == 0:
				var p: PlayerState = world.players.get(z.hunt_target, null)
				if p != null and p.online and not p.dead and p.region_id == z.region_id:
					_investigate(world, z, p.position)
					SessionLog.info("threat", "hunt_scent", {"zombie": z.zombie_id, "at": [roundi(p.position.x), roundi(p.position.y)]})


## Diagnostics: one line per hunter.
static func hunt_lines(world: WorldState) -> Array[String]:
	var out: Array[String] = []
	for z in world.zombies.values():
		if not z.hunter:
			continue
		var p: PlayerState = world.players.get(z.hunt_target, null)
		var d := "-"
		if p != null and p.region_id == z.region_id:
			d = str(roundi(p.position.distance_to(z.position)))
		out.append("hunt %s %s target=%s dist=%s hp=%d left=%ds" % [z.zombie_id, z.state_name(), z.hunt_target.substr(0, 6), d,
			roundi(z.health), maxi(0, (z.hunt_until - world.tick) / Simulation.TICK_RATE)])
	return out


static func _process_noise(world: WorldState) -> void:
	var th := world.threat
	if th.queue.is_empty():
		return
	var mult := float(c("hearing_multiplier", 1.0)) * EnvSim.hearing_scale(world)
	for ev in th.queue:
		var key := ThreatState.zone_key(ev["region_id"], ev["position"])
		th.zones[key] = float(th.zones.get(key, 0.0)) + float(ev["attention"])
		EventSim.on_noise(world, ev["region_id"], ev["position"], float(ev["attention"]))
		th.recent.append({"tick": world.tick, "category": ev["category"], "zone": key})
		if th.recent.size() > 12:
			th.recent.pop_front()
		var is_screech: bool = str(ev["category"]) == "screech"
		var hearers: Array = []
		for z in world.zombies.values():
			if z.region_id != ev["region_id"] or z.is_dead():
				continue
			if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.WINDUP, ZombieState.AI.RECOVER]:
				continue
			if is_screech and str(ev.get("source", "")) == z.zombie_id:
				continue
			if z.position.distance_to(ev["position"]) <= float(ev["radius"]) * mult:
				hearers.append(z)
		if is_screech:
			# A screech calls only the nearest few, and they never screech back (no chains).
			hearers.sort_custom(func(a, b): return a.position.distance_to(ev["position"]) < b.position.distance_to(ev["position"]))
			hearers = hearers.slice(0, int(c("screech_max_responders", 3)))
		for z in hearers:
			if is_screech:
				_investigate(world, z, ev["position"])
				z.heard_screech = true
				z.posture = ZombieState.Posture.CROUCH
				z.posture_timer = 1.0
			elif float(ev["attention"]) >= float(c("listen_threshold", 0.4)) and z.ai != ZombieState.AI.LISTEN:
				# A real disturbance: stop, turn toward it and listen before going.
				z.ai = ZombieState.AI.LISTEN
				z.goal = ev["position"]
				z.last_known = ev["position"]
				z.listen_level = float(ev["attention"])
				z.timer = world.sim_rng().randf_range(float(c("listen_seconds", [0.9, 1.6])[0]), float(c("listen_seconds", [0.9, 1.6])[1]))
				z.path.clear()
			elif z.ai != ZombieState.AI.LISTEN:
				# Heard it: go and look where the sound came from (not at who made it).
				_investigate(world, z, ev["position"])
	th.queue.clear()


## Host: a Burnt One screeches. The screech is itself a world noise (category
## "screech") that draws the nearest few others; cooldowns per individual and
## per region keep silence the norm. Returns the event result or {}.
static func screech(world: WorldState, z: ZombieState) -> Dictionary:
	var rk := "screech:" + z.region_id
	if z.screech_cd > 0.0 or world.tick - int(world.cooldowns.get(rk, -100000)) < int(float(c("screech_region_cooldown", 14)) * Simulation.TICK_RATE):
		return {}
	world.cooldowns[rk] = world.tick
	z.screech_cd = float(c("screech_cooldown", 50))
	var n: Dictionary = c("noise", {}).get("screech", {"radius": 680, "attention": 0.6})
	world.threat.queue.append({"region_id": z.region_id, "position": z.position, "radius": float(n["radius"]),
		"attention": float(n["attention"]), "category": "screech", "source": z.zombie_id})
	world.meta["last_screech"] = {"tick": world.tick, "region": z.region_id, "x": roundi(z.position.x), "y": roundi(z.position.y)}
	SessionLog.info("threat", "screech", {"zombie": z.zombie_id, "region": z.region_id, "at": [roundi(z.position.x), roundi(z.position.y)]})
	return _event_result({"kind": "screech", "zombie_id": z.zombie_id, "region_id": z.region_id, "x": z.position.x, "y": z.position.y})


static func _decay(world: WorldState, seconds: float) -> void:
	var k := pow(0.5, seconds / float(c("attention_half_life", 18)))
	for key in world.threat.zones.keys():
		var v: float = world.threat.zones[key] * k
		if v < 0.05:
			world.threat.zones.erase(key)
		else:
			world.threat.zones[key] = v


static func _investigate(world: WorldState, z: ZombieState, pos: Vector2) -> void:
	var jitter := Vector2(world.sim_rng().randf_range(-50, 50), world.sim_rng().randf_range(-50, 50))
	z.ai = ZombieState.AI.INVESTIGATE
	z.goal = pos + jitter
	z.last_known = pos
	z.timer = 0.0
	z.leaving = false


## Attention thresholds draw zombies to a disturbed zone: idle ones nearby
## first, then (from a higher level) reinforcements from off-screen entries.
static func _escalate(world: WorldState, results: Array) -> void:
	var levels: Array = c("escalation", [])
	for key in world.threat.zones:
		var att: float = world.threat.zones[key]
		var want := 0
		var level := -1
		for i in levels.size():
			if att >= float(levels[i]["attention"]):
				want = int(levels[i]["want"])
				level = i
		if want == 0:
			continue
		var region_id: String = key.split("|")[0]
		var center := ThreatState.zone_center(key)
		var engaged := 0
		var idle: Array = []
		for z in world.zombies.values():
			if z.region_id != region_id or z.is_dead():
				continue
			if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.WINDUP, ZombieState.AI.RECOVER, ZombieState.AI.STAGGER, ZombieState.AI.LISTEN] \
					or (z.ai == ZombieState.AI.INVESTIGATE and z.last_known.distance_to(center) < ThreatState.ZONE_SIZE * 1.5):
				if z.position.distance_to(center) < float(c("recruit_radius", 1100)) * 1.2:
					engaged += 1
			elif z.position.distance_to(center) < float(c("recruit_radius", 1100)):
				idle.append(z)
		idle.sort_custom(func(a, b): return a.position.distance_to(center) < b.position.distance_to(center))
		while engaged < want and not idle.is_empty():
			_investigate(world, idle.pop_front(), center)
			engaged += 1
		if engaged >= want or level < int(c("reinforce_from_level", 1)) or not world.threat.ambient:
			continue
		var last := int(world.threat.last_spawn.get(key, -100000))
		if world.tick - last < int(float(c("reinforcement_cooldown", 5)) * Simulation.TICK_RATE):
			continue
		var active := 0
		var transient := 0
		for z in world.zombies.values():
			if not z.is_dead():
				active += 1
				if not z.persistent:
					transient += 1
		var entries: Array = region_cfg(region_id, world).get("entries", [])
		var cands: Array = []
		for e in entries:
			var ep := Vector2(float(e[0]), float(e[1]))
			if _far_from_players(world, region_id, ep, float(c("min_spawn_distance_from_players", 720))):
				cands.append(ep)
		cands.sort_custom(func(a, b): return a.distance_to(center) < b.distance_to(center))
		var spawned := 0
		while spawned < int(c("reinforcements_per_wave", 2)) and engaged < want and not cands.is_empty() \
				and active < int(c("max_active", 16)) and transient < int(c("max_reinforcements", 8)):
			var ep: Vector2 = cands[spawned % cands.size()]
			var z := spawn(world, region_id, ep, false)
			_investigate(world, z, center)
			spawned += 1
			engaged += 1
			active += 1
			transient += 1
		if spawned > 0:
			world.threat.last_spawn[key] = world.tick
			results.append(_event_result({"kind": "horde_reinforced", "zone": key, "count": spawned}))


# ======================================================================
# Individual zombie
# ======================================================================

static func _update(world: WorldState, z: ZombieState, grid: NavGrid, dyn: Dictionary, budget: Array, results: Array) -> void:
	if z.is_dead():
		z.dead_time += DT
		if z.dead_time >= float(c("corpse_time", 6)):
			world.zombies.erase(z.zombie_id)
		return
	z.attack_cooldown = maxf(0.0, z.attack_cooldown - DT)
	z.screech_cd = maxf(0.0, z.screech_cd - DT)
	z.burst = maxf(0.0, z.burst - DT)
	z.burst_cd = maxf(0.0, z.burst_cd - DT)
	z.posture_timer = maxf(0.0, z.posture_timer - DT)
	match z.ai:
		ZombieState.AI.STAGGER:
			z.timer -= DT
			if z.timer <= 0.0:
				z.ai = ZombieState.AI.CHASE if z.target_player != "" else ZombieState.AI.INVESTIGATE
			return
		ZombieState.AI.WINDUP:
			if z.target_struct != "":
				z.timer -= DT
				if z.timer <= 0.0:
					var rect := Build.target_rect(world, z.region_id, z.target_struct)
					if rect.has_area() and Build.edge_distance(rect, z.position) <= Build.ATTACK_GAP + 12.0:
						results.append(Build.damage_target(world, z.region_id, z.target_struct, float(c("structure_damage", 14))))
					z.attack_cooldown = float(c("attack_cooldown", 1.3))
					z.ai = ZombieState.AI.RECOVER
					z.timer = 0.35
				return
			var tp := _target(world, z)
			if tp != null:
				z.facing = (tp.position - z.position).normalized()
			z.timer -= DT
			if z.timer <= 0.0:
				if tp != null and tp.position.distance_to(z.position) <= float(c("attack_reach", 66)) \
						and grid.clear_line(z.position, tp.position, dyn):
					results.append(damage_player(world, tp, float(c("attack_damage", 18)), z.zombie_id))
				z.attack_cooldown = float(c("attack_cooldown", 1.3))
				z.ai = ZombieState.AI.RECOVER
				z.timer = 0.35
			return
		ZombieState.AI.RECOVER:
			z.timer -= DT
			if z.timer <= 0.0:
				z.ai = ZombieState.AI.CHASE
			return
	# Senses: sight (cone + short all-round range, needs line of sight).
	var seen := _look(world, z, grid, dyn)
	if seen != null and z.ai == ZombieState.AI.CHASE and z.target_player == seen.player_id:
		var mv: Vector2 = seen.position - z.last_known
		if mv.length() > 1.0:
			z.last_dir = z.last_dir.lerp(mv.normalized(), 0.3)
	if seen != null:
		if z.target_player != seen.player_id or z.ai != ZombieState.AI.CHASE:
			z.path.clear()
		z.target_player = seen.player_id
		z.last_known = seen.position
		z.lost_sight = 0.0
		z.ai = ZombieState.AI.CHASE
		z.leaving = false
	if seen != null:
		z.target_struct = ""
	if z.target_struct != "":
		_breach(world, z, grid, dyn, budget)
		return
	_posture(world, z)
	match z.ai:
		ZombieState.AI.LISTEN:
			# Frozen, head turned toward the sound. Then perhaps a screech, then go.
			var to := z.goal - z.position
			if to.length() > 1.0:  # turn by angle (a vector lerp stalls on a sound directly behind)
				z.facing = Vector2.from_angle(lerp_angle(z.facing.angle(), to.angle(), 0.3))
			z.timer -= DT
			if z.timer <= 0.0:
				var at := z.goal
				if z.listen_level >= float(c("screech_threshold", 0.9)):
					var sr := screech(world, z)
					if not sr.is_empty():
						results.append(sr)
				_investigate(world, z, at)
		ZombieState.AI.CHASE:
			var tp := _target(world, z)
			if tp == null:
				# Target went indoors, underground, died or left: search where it was last seen.
				z.target_player = ""
				_investigate(world, z, z.last_known)
				z.goal = z.last_known
			else:
				if seen == null:
					z.lost_sight += DT
					if z.lost_sight >= float(c("lose_target_after", 3.5)):
						# Lost them: search where they were heading, then a couple of spots around.
						z.target_player = ""
						var guess := z.last_known + z.last_dir * float(c("search_lead", 90))
						_investigate(world, z, guess)
						z.goal = guess
						z.search_left = int(c("search_points", 2))
						return
				z.goal = tp.position if seen != null else z.last_known
				var d := z.position.distance_to(tp.position)
				if seen != null and d <= float(c("attack_start_range", 44)) and z.attack_cooldown <= 0.0:
					z.ai = ZombieState.AI.WINDUP
					z.timer = float(c("attack_windup", 0.6))
					z.facing = (tp.position - z.position).normalized()
					z.posture = ZombieState.Posture.UPRIGHT  # rears up to strike (lunge pose)
					z.burst = 0.0
					z.posture_timer = 1.0
					return
				if d > 30.0:
					_move(world, z, grid, dyn, float(c("speed_chase", 92)) * _pace(z), budget)
		ZombieState.AI.INVESTIGATE:
			if z.position.distance_to(z.goal) > 22.0 and z.timer <= 0.0:
				_move(world, z, grid, dyn, float(c("speed_investigate", 62)) * _pace(z), budget)
				if z.position.distance_to(z.goal) <= 22.0:
					z.timer = float(c("search_time", 3.5))
			else:
				if z.timer <= 0.0:
					z.timer = float(c("search_time", 3.5))
				z.timer -= DT
				if z.timer <= 0.0:
					if z.search_left > 0:
						z.search_left -= 1
						var rng2 := world.sim_rng()
						z.goal = z.last_known + Vector2(rng2.randf_range(-160, 160), rng2.randf_range(-160, 160))
						z.timer = 0.0
						z.path.clear()
					else:
						z.heard_screech = false
						_after_search(world, z)
		ZombieState.AI.WANDER:
			if z.leaving:
				_move(world, z, grid, dyn, float(c("speed_investigate", 62)), budget)
				if z.position.distance_to(z.goal) < 30.0:
					world.zombies.erase(z.zombie_id)  # walked back off the map
				return
			if z.timer > 0.0:
				z.timer -= DT
				return
			if z.position.distance_to(z.goal) <= 16.0 or z.goal == Vector2.ZERO:
				var rng := world.sim_rng()
				z.goal = z.position + Vector2(rng.randf_range(-220, 220), rng.randf_range(-220, 220))
				z.path.clear()
				z.timer = rng.randf_range(1.5, 4.5)
				return
			var before := z.position
			_move(world, z, grid, dyn, float(c("speed_wander", 32)) * _pace(z), budget)
			if before.distance_to(z.position) < 0.5:
				z.goal = z.position  # stuck: pick another spot next time


## Speed factor from temperament and posture (crawling bursts are the fastest).
static func _pace(z: ZombieState) -> float:
	var k := z.temperament().x
	match z.posture:
		ZombieState.Posture.CROUCH:
			k *= float(c("crouch_speed", 0.7))
		ZombieState.Posture.CRAWL:
			k *= float(c("burst_speed", 1.55)) if z.burst > 0.0 else float(c("crawl_speed", 0.8))
	return k


## Chooses a body posture for the moment. Wandering: mostly upright, sometimes
## lowered. Investigating: lowered, creeping; crawl-prone individuals drop to all
## fours near the spot. Chasing: upright, with occasional crawling bursts (a fast
## animal scramble) at mid range. Changes are rate-limited so they read as
## deliberate transitions, and every individual differs (temperament).
static func _posture(world: WorldState, z: ZombieState) -> void:
	if z.burst > 0.0:
		return
	if z.posture == ZombieState.Posture.CRAWL and z.burst_cd > float(c("burst_cooldown", 6.0)) - 1.0:
		return  # keep scrambling low for a moment after a burst
	if z.posture_timer > 0.0:
		return
	var crawly := z.temperament().y
	var rng := world.sim_rng()
	var want := z.posture
	match z.ai:
		ZombieState.AI.WANDER:
			want = ZombieState.Posture.CROUCH if rng.randf() < 0.18 + crawly * 0.2 else ZombieState.Posture.UPRIGHT
			if crawly > 0.8 and rng.randf() < 0.15:
				want = ZombieState.Posture.CRAWL
		ZombieState.AI.LISTEN:
			want = ZombieState.Posture.CROUCH if crawly > 0.4 else ZombieState.Posture.UPRIGHT
		ZombieState.AI.INVESTIGATE:
			var near := z.position.distance_to(z.goal) < 140.0
			want = ZombieState.Posture.CRAWL if near and crawly > 0.45 else ZombieState.Posture.CROUCH
		ZombieState.AI.CHASE:
			want = ZombieState.Posture.CRAWL if crawly > 0.85 else ZombieState.Posture.UPRIGHT
			var tp := _target(world, z)
			if tp != null and z.burst_cd <= 0.0:
				var d := tp.position.distance_to(z.position)
				if d > 90.0 and d < 340.0 and rng.randf() < float(c("burst_chance", 0.35)) * (0.5 + crawly):
					want = ZombieState.Posture.CRAWL
					z.burst = float(c("burst_seconds", 1.4))
					z.burst_cd = float(c("burst_cooldown", 6.0))
	if want != z.posture:
		z.posture = want
	z.posture_timer = rng.randf_range(1.2, 3.0)


static func _after_search(world: WorldState, z: ZombieState) -> void:
	z.ai = ZombieState.AI.WANDER
	z.goal = z.position
	z.timer = world.sim_rng().randf_range(1.0, 3.0)
	if z.siege:
		# Horde zombies stay on task until the defence event ends (EventSim sends them off).
		var t := EventSim.exposed_target(world, z.region_id, z.position)
		if t != "":
			z.target_struct = t
			z.stuck = 0.0
		return
	if not z.persistent and world.threat.local_attention(z.region_id, z.position) < 0.8:
		# Reinforcements drift back off-map once things calm down.
		var entries: Array = region_cfg(z.region_id, world).get("entries", [])
		var best := Vector2.INF
		for e in entries:
			var ep := Vector2(float(e[0]), float(e[1]))
			if best == Vector2.INF or ep.distance_to(z.position) < best.distance_to(z.position):
				best = ep
		if best != Vector2.INF:
			z.leaving = true
			z.goal = best
			z.timer = 0.0
			z.path.clear()


static func _target(world: WorldState, z: ZombieState) -> PlayerState:
	if z.target_player == "":
		return null
	var p: PlayerState = world.players.get(z.target_player, null)
	if p == null or not p.online or p.dead or p.region_id != z.region_id:
		return null
	return p


static func _look(world: WorldState, z: ZombieState, grid: NavGrid, dyn: Dictionary) -> PlayerState:
	var best: PlayerState = null
	var best_d := INF
	var sight := float(c("sight_range", 300)) * EnvSim.sight_scale(world, z.region_id)
	var omni := float(c("omni_sense_range", 110))
	var cos_half := cos(deg_to_rad(float(c("sight_cone_degrees", 140)) * 0.5))
	for p in world.online_players():
		if p.region_id != z.region_id or p.dead:
			continue
		var to: Vector2 = p.position - z.position
		var d: float = to.length()
		if d > sight:
			continue
		if d > omni and z.facing.dot(to / maxf(d, 0.001)) < cos_half:
			continue
		if not grid.clear_line(z.position, p.position, dyn):
			continue
		# Prefer the current target unless another player is much closer.
		var score: float = d * (0.6 if p.player_id == z.target_player else 1.0)
		if score < best_d:
			best_d = score
			best = p
	return best


static func _move(world: WorldState, z: ZombieState, grid: NavGrid, dyn: Dictionary, speed: float, budget: Array) -> void:
	var dest := z.goal
	if grid.clear_line(z.position, z.goal, dyn):
		z.path.clear()
		z.path_goal = Vector2.INF
	else:
		if z.path.is_empty() or z.path_goal.distance_to(z.goal) > 48.0:
			if budget[0] <= 0:
				return  # wait for path budget next tick
			budget[0] -= 1
			z.path = grid.find_path(z.position, z.goal, dyn)
			z.path_goal = z.goal
			if z.path.is_empty():
				# No way through: something built is in the way. Hunting or
				# investigating zombies break through it; wanderers give up.
				if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.INVESTIGATE]:
					z.target_struct = Build.breach_target(world, z.region_id, z.position, z.goal)
					z.stuck = 0.0
				if z.target_struct == "":
					z.goal = z.position
				return
		while not z.path.is_empty() and z.position.distance_to(z.path[0]) < 10.0:
			z.path.pop_front()
		if z.path.is_empty():
			return
		dest = z.path[0]
	var dir := dest - z.position
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# Keep a little apart from other zombies.
	var sep := Vector2.ZERO
	var spacing := float(c("separation", 26))
	for o in world.zombies.values():
		if o == z or o.region_id != z.region_id or o.is_dead():
			continue
		var away: Vector2 = z.position - o.position
		var dd: float = away.length()
		if dd < spacing and dd > 0.01:
			sep += away / dd * (spacing - dd) / spacing
	if z.trap_time > 0.0:
		speed *= _trap_slow()
	var v := (dir + sep * 1.2).normalized() * speed * DT
	z.facing = z.facing.lerp(dir, 0.35).normalized()
	var np := z.position + v
	if not grid.is_blocked(grid.to_cell(np), dyn):
		z.position = np
	elif not grid.is_blocked(grid.to_cell(z.position + Vector2(v.x, 0)), dyn):
		z.position += Vector2(v.x, 0)
	elif not grid.is_blocked(grid.to_cell(z.position + Vector2(0, v.y)), dyn):
		z.position += Vector2(0, v.y)


## Walks up to the structure in the way and hits it until it breaks (or the
## zombie notices a player, or the structure stops blocking).
static func _breach(world: WorldState, z: ZombieState, grid: NavGrid, dyn: Dictionary, budget: Array) -> void:
	var rect := Build.target_rect(world, z.region_id, z.target_struct)
	if not rect.has_area():
		z.target_struct = ""
		z.path.clear()
		return
	var d := Build.edge_distance(rect, z.position)
	if d <= Build.ATTACK_GAP:
		z.stuck = 0.0
		if z.attack_cooldown <= 0.0:
			z.ai = ZombieState.AI.WINDUP
			z.timer = float(c("attack_windup", 0.6))
			z.facing = (rect.get_center() - z.position).normalized()
		return
	# Walk (with pathfinding, so around buildings) to a spot just outside the structure.
	var target := Vector2(clampf(z.position.x, rect.position.x, rect.end.x), clampf(z.position.y, rect.position.y, rect.end.y))
	var approach := target + (z.position - target).normalized() * (Build.ATTACK_GAP - 14.0)
	if grid.is_blocked(grid.to_cell(approach), dyn):
		approach = _open_side(grid, dyn, rect, z.position)
	var before := z.position
	var keep := z.target_struct
	z.goal = approach
	_move(world, z, grid, dyn, float(c("speed_investigate", 62)), budget)
	z.target_struct = keep
	if before.distance_to(z.position) < 0.2:
		z.stuck += DT
		if z.stuck > 4.0:
			# Cannot get at it from here: forget it and look around.
			z.target_struct = ""
			z.stuck = 0.0
			z.ai = ZombieState.AI.WANDER
			z.goal = z.position


## A walkable point next to a structure's footprint, nearest to `from`.
static func _open_side(grid: NavGrid, dyn: Dictionary, rect: Rect2, from: Vector2) -> Vector2:
	var best := rect.get_center()
	var best_d := INF
	var gap := Build.ATTACK_GAP - 14.0
	for p in [Vector2(rect.get_center().x, rect.position.y - gap), Vector2(rect.get_center().x, rect.end.y + gap),
			Vector2(rect.position.x - gap, rect.get_center().y), Vector2(rect.end.x + gap, rect.get_center().y)]:
		if not grid.is_blocked(grid.to_cell(p), dyn) and p.distance_to(from) < best_d:
			best_d = p.distance_to(from)
			best = p
	return best


## Spike traps hurt and slow zombies standing on them, and wear out doing so.
static func _traps(world: WorldState, results: Array) -> void:
	var by_region := {}
	for rid in world.regions:
		var r: RegionState = world.regions[rid]
		for oid in r.objects:
			var o: Dictionary = r.objects[oid]
			if Build.def(str(o.get("def", ""))).has("trap") and Build.is_built(o) and float(o.get("hp", 0)) > 0.0:
				if not by_region.has(rid):
					by_region[rid] = []
				by_region[rid].append(oid)
	for z in world.zombies.values():
		if z.is_dead():
			continue
		var on := ""
		if by_region.has(z.region_id):
			var r2: RegionState = world.regions[z.region_id]
			for oid2 in by_region[z.region_id]:
				if Build.footprint(r2, r2.objects[oid2]).has_point(z.position):
					on = oid2
					break
		if on == "":
			z.trap_time = 0.0
			continue
		z.trap_time += DT
		if z.trap_time < 0.5:
			continue
		z.trap_time = 0.01
		var reg: RegionState = world.regions[z.region_id]
		var o2: Dictionary = reg.objects[on]
		var trap: Dictionary = Build.def(str(o2["def"]))["trap"]
		var hit := damage_zombie(world, z, float(trap.get("damage_per_second", 16)) * 0.5, null, Vector2.ZERO)
		o2["hp"] = maxf(0.0, float(o2.get("hp", 0)) - float(trap.get("wear_per_second", 3)) * 0.5)
		hit["objects"] = [[z.region_id, on]]
		hit["events"].append({"kind": "trap_hit", "region_id": z.region_id, "oid": on, "x": z.position.x, "y": z.position.y})
		results.append(hit)


static func _trap_slow() -> float:
	return float(Build.def("spike_trap").get("trap", {}).get("slow", 0.45))


# ======================================================================
# Damage
# ======================================================================

static func damage_player(world: WorldState, p: PlayerState, amount: float, source: String) -> Dictionary:
	# Worn protective gear takes a share off hits from zombies, and wears.
	var armour := p.equipped_gear("body")
	var worn := false
	if source != "dev" and not armour.is_empty() and float(armour.get("cond", 0)) > 0.0:
		amount *= 1.0 - float(Items.info(str(armour["item"])).get("armor", 0.0))
		armour["cond"] = maxf(0.0, float(armour["cond"]) - 1.0)
		worn = true
	p.health = maxf(0.0, p.health - amount)
	p.last_hurt_tick = world.tick
	var events := [{"kind": "player_hit", "player_id": p.player_id, "amount": amount, "source": source}]
	if p.health <= 0.0 and not p.dead:
		p.dead = true
		p.respawn_tick = world.tick + int(float(SurvivalSim.RESPAWN_SECONDS) * Simulation.TICK_RATE)
		events.append({"kind": "player_died", "player_id": p.player_id})
		for z in world.zombies.values():
			if z.target_player == p.player_id:
				z.target_player = ""
				_investigate(world, z, p.position)
	var res := _event_result(events[0])
	res["events"] = events
	res["vitals"] = [p.player_id]
	if worn:
		res["players"] = [p.player_id]
	return res


static func damage_zombie(world: WorldState, z: ZombieState, amount: float, attacker: PlayerState, knock: Vector2) -> Dictionary:
	z.health = maxf(0.0, z.health - amount)
	var killed := z.health <= 0.0
	if killed:
		z.ai = ZombieState.AI.DEAD
		z.dead_time = 0.0
		EventSim.on_kill(world, z.region_id)
	else:
		z.ai = ZombieState.AI.STAGGER
		z.timer = float(c("stagger_time", 0.35))
		if attacker != null:
			z.target_player = attacker.player_id
			z.last_known = attacker.position
			z.target_struct = ""
		var grid := NavGrid.for_def(world.region(z.region_id).def_id)
		var np := z.position + knock
		if not grid.is_blocked(grid.to_cell(np), {}):
			z.position = np
	return _event_result({"kind": "zombie_hit", "zombie_id": z.zombie_id, "amount": amount,
		"player_id": attacker.player_id if attacker != null else "", "killed": killed})


static func _event_result(ev: Dictionary) -> Dictionary:
	var r := WorldActions._ok()
	r["events"] = [ev]
	r["vitals"] = []
	return r
