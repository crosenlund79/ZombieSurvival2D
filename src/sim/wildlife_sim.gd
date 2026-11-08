class_name WildlifeSim
extends RefCounted
## Wildlife (iteration 011 D): wolves and bears that roam their home area, idle,
## notice players, stop to watch, back away or bolt, and call out now and then
## (more at night). Host-only simulation; clients mirror compact rows.
##
## Iteration 015 E — dangerous wildlife:
##  * wolves hunt in packs: with at least `pack_min` of the pack nearby, at night
##    (or by day if the player is hurt, or on a `day_aggression` chance) they stalk —
##    circle at a distance, growling — then dart in to bite and back off again.
##    Escapable: they give up after `give_up_seconds`, when the player gets more
##    than `give_up_distance` from their home, gets into a vehicle or goes indoors;
##    then they keep away for `calm_seconds`. Hurt badly, a wolf runs.
##  * bears are territorial: a player entering their territory (home area +
##    `territory_margin`) is warned (the bear stands and huffs); stay, or come within
##    `charge_radius`, and it charges and swipes, then goes back home. Leave and it
##    lets you go. A badly hurt bear runs.
##  * animals can be hurt and killed (melee, firearms); killed animals stay gone
##    until the world is next started (wildlife is transient).
##  * "dev peaceful" (threat disabled) makes every animal harmless again.
##
## Content: res://content/tuning/wildlife.json ("species" tuning and per-region
## groups). Transient: animals are rebuilt from content when a world starts.
## Cheap by design: a handful of animals, static navigation-grid checks only,
## goals chosen rarely.

const PATH := "res://content/tuning/wildlife.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"species": {}, "regions": {}}
	return _data


static func spec(species: String) -> Dictionary:
	return data().get("species", {}).get(species, {})


static func _grid(world: WorldState, region_id: String) -> NavGrid:
	var r := world.region(region_id)
	return NavGrid.for_def(r.def_id) if r != null else null


static func _walkable(grid: NavGrid, p: Vector2) -> bool:
	return grid == null or not grid.is_blocked(grid.to_cell(p), {})


## Creates the animals content asks for that this world does not have yet.
static func ensure(world: WorldState) -> int:
	var added := 0
	var regions: Dictionary = data().get("regions", {})
	for rid in regions:
		if world.region(rid) == null:
			continue
		var grid := _grid(world, rid)
		var gi := 0
		for g in regions[rid]:
			var area: Array = g.get("area", [0, 0, 100, 100])
			var home := Rect2(float(area[0]), float(area[1]), float(area[2]), float(area[3]))
			for i in int(g.get("count", 1)):
				var id := "%s:%s:%d:%d" % [str(g.get("species", "wolf")), rid, gi, i]
				if world.animals.has(id):
					continue
				var rng := world.make_rng("wildlife:" + id)
				var a := AnimalState.new()
				a.animal_id = id
				a.species = str(g.get("species", "wolf"))
				a.region_id = rid
				a.group = "%s:%s:%d" % [a.species, rid, gi]
				a.health = float(spec(a.species).get("health", 60))
				a.home = home
				a.position = home.get_center()
				for attempt in 12:
					var p := home.position + Vector2(rng.randf(), rng.randf()) * home.size
					if _walkable(grid, p):
						a.position = p
						break
				a.goal = a.position
				a.timer = rng.randf_range(0.5, 4.0)
				a.call_timer = rng.randf_range(10.0, 60.0)
				a.facing = Vector2.RIGHT if rng.randf() < 0.5 else Vector2.LEFT
				world.animals[id] = a
				added += 1
			gi += 1
	return added


static func step(world: WorldState, ticks: int) -> Array:
	if world.animals.is_empty():
		return []
	var dt := float(ticks) / Simulation.TICK_RATE
	var events: Array = []
	var out: Array = []
	var night := EnvSim.is_night(world)
	for a in world.animals.values().duplicate():
		if a.health <= 0.0:
			a.health = float(spec(a.species).get("health", 60))
		a.attack_cd = maxf(0.0, a.attack_cd - dt)
		a.calm = maxf(0.0, a.calm - dt)
		if not _danger(world, a, dt, night, events, out):
			_think(world, a, dt, night, events)
	if events.is_empty() and out.is_empty():
		return []
	var r := WorldActions._ok()
	r["events"] = events
	out.append(r)
	return out


static func _nearest_player(world: WorldState, a: AnimalState) -> PlayerState:
	var best: PlayerState = null
	var bd := INF
	for p in world.online_players():
		if p.region_id != a.region_id or p.dead:
			continue
		var d: float = p.position.distance_to(a.position)
		if d < bd:
			bd = d
			best = p
	return best


static func _event(a: AnimalState, sound: String) -> Dictionary:
	return {"kind": "animal_call", "region_id": a.region_id, "animal_id": a.animal_id, "sound": sound,
		"x": snappedf(a.position.x, 0.1), "y": snappedf(a.position.y, 0.1)}


static func _think(world: WorldState, a: AnimalState, dt: float, night: bool, events: Array) -> void:
	var s := spec(a.species)
	var rng := world.sim_rng()
	var p := _nearest_player(world, a)
	var d: float = p.position.distance_to(a.position) if p != null else INF
	# --- awareness: players are watched, then avoided; never approached
	if d < float(s.get("flee_radius", 280)):
		if a.activity != "flee":
			a.activity = "flee"
			a.watching = p.player_id
			events.append(_event(a, str(s.get("alarm_sound", ""))))
	elif d < float(s.get("notice_radius", 500)) and (a.activity == "idle" or a.activity == "walk"):
		a.activity = "alert"
		a.watching = p.player_id
		a.timer = rng.randf_range(1.5, 3.0)
	match a.activity:
		"flee":
			if p == null or d > float(s.get("calm_radius", 680)):
				a.activity = "idle"
				a.watching = ""
				a.timer = rng.randf_range(1.0, 3.0)
			else:
				var away := (a.position - p.position).normalized()
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				_move(world, a, away, float(s.get("flee_speed", 200)), dt)
		"alert":
			if p != null:
				a.facing = (p.position - a.position).normalized()
			a.timer -= dt
			if a.timer <= 0.0:
				if p != null and d < float(s.get("notice_radius", 500)):
					# still too close for comfort: trot away from the player
					var away2 := (a.position - p.position).normalized()
					a.goal = a.position + away2 * float(s.get("wander_radius", 400)) * 0.6
					a.activity = "walk"
				else:
					a.activity = "idle"
					a.timer = rng.randf_range(1.0, 2.5)
		"walk":
			var to := a.goal - a.position
			if to.length() < 10.0:
				a.activity = "idle"
				var idle: Array = s.get("idle_seconds", [3.0, 6.0])
				a.timer = rng.randf_range(float(idle[0]), float(idle[1]))
			else:
				var speed := float(s.get("trot_speed" if a.watching != "" else "walk_speed", 70))
				if not _move(world, a, to.normalized(), speed, dt):
					a.activity = "idle"
					a.timer = rng.randf_range(0.5, 1.5)
		_:
			a.activity = "idle"
			a.timer -= dt
			if a.timer <= 0.0:
				a.watching = ""
				a.goal = _wander_goal(world, a, rng, float(s.get("wander_radius", 400)))
				a.activity = "walk"
	# --- calls (more often at night), heard by everyone in the region
	a.call_timer -= dt * (float(s.get("night_calls", 1.0)) if night else 1.0)
	if a.call_timer <= 0.0:
		var cs: Array = s.get("call_seconds", [60, 120])
		a.call_timer = rng.randf_range(float(cs[0]), float(cs[1]))
		if a.activity != "flee":
			events.append(_event(a, str(s.get("call_sound", ""))))


## Iteration 015 E: hunting, warning, charging, giving up. Returns true when it
## handled the animal this step (the calm behaviour in _think is skipped).
static func _danger(world: WorldState, a: AnimalState, dt: float, night: bool, events: Array, out: Array) -> bool:
	var s := spec(a.species)
	if not world.threat.enabled or not (bool(s.get("aggressive", false)) or bool(s.get("territorial", false))):
		return false
	var max_h := float(s.get("health", 60))
	if a.health < max_h * float(s.get("flee_health", 0.35)):
		return false  # badly hurt: the calm logic makes it run from players
	var p: PlayerState = world.players.get(a.watching) if a.activity in ["stalk", "attack", "warn"] else null
	if p != null and (p.dead or not p.online or p.region_id != a.region_id or p.vehicle_id != ""):
		p = null
	if a.activity == "retreat":
		var home := a.home.get_center()
		if a.position.distance_to(home) < 40.0 or not _move(world, a, (home - a.position).normalized(), float(s.get("walk_speed", 60)) * 1.4, dt):
			a.activity = "idle"
			a.timer = 2.0
		return true
	if a.activity in ["stalk", "attack", "warn"]:
		if p == null or _give_up(a, p, s):
			_calm_down(a, s)
			return true
		a.engaged += dt
		if bool(s.get("territorial", false)):
			_bear(world, a, p, s, dt, events, out)
		else:
			_wolf(world, a, p, s, dt, events, out)
		return true
	if a.calm > 0.0:
		return false
	# not engaged: should it start?
	var near := _nearest_player(world, a)
	if near == null or near.vehicle_id != "":
		return false
	var d := near.position.distance_to(a.position)
	if bool(s.get("territorial", false)):
		if a.home.grow(float(s.get("territory_margin", 160))).has_point(near.position) and d < float(s.get("notice_radius", 460)):
			a.activity = "warn"
			a.watching = near.player_id
			a.engaged = 0.0
			a.timer = float(s.get("warn_seconds", 3.0))
			a.warned = true
			events.append(_event(a, str(s.get("warn_sound", s.get("alarm_sound", "")))))
			return true
		return false
	if d < float(s.get("stalk_radius", 460)) and _pack_near(world, a) >= int(s.get("pack_min", 2)):
		var hurt := near.health < 50.0
		var rng := world.make_rng("wolfmood:%s:%d" % [a.group, world.tick / int(Simulation.TICK_RATE * 20)])
		if night or hurt or rng.randf() < float(s.get("day_aggression", 0.3)):
			for m in world.animals.values():  # the whole pack joins in
				if m.group == a.group and m.activity not in ["stalk", "attack"] and m.position.distance_to(a.position) < 700.0 and m.health >= float(s.get("health", 60)) * float(s.get("flee_health", 0.35)):
					m.activity = "stalk"
					m.watching = near.player_id
					m.engaged = 0.0
					m.timer = world.make_rng("stalk:" + m.animal_id + str(world.tick)).randf_range(3.0, 6.0)
			events.append(_event(a, str(s.get("alarm_sound", ""))))
			SessionLog.info("wildlife", "pack_hunts", {"group": a.group, "player": near.player_id.substr(0, 6)})
			return true
		a.calm = 20.0  # decided not to, for now
	return false


static func _pack_near(world: WorldState, a: AnimalState) -> int:
	var n := 0
	for m in world.animals.values():
		if m.group == a.group and m.position.distance_to(a.position) < 700.0:
			n += 1
	return n


static func _give_up(a: AnimalState, p: PlayerState, s: Dictionary) -> bool:
	if a.engaged > float(s.get("give_up_seconds", 25.0)):
		return true
	if p.position.distance_to(a.home.get_center()) > float(s.get("give_up_distance", 1200.0)):
		return true
	return p.position.distance_to(a.position) > float(s.get("lose_radius", 900.0))


static func _calm_down(a: AnimalState, s: Dictionary) -> void:
	a.activity = "retreat"
	a.watching = ""
	a.engaged = 0.0
	a.warned = false
	a.calm = float(s.get("calm_seconds", 45.0))


static func _wolf(world: WorldState, a: AnimalState, p: PlayerState, s: Dictionary, dt: float, events: Array, out: Array) -> void:
	var to := p.position - a.position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	a.facing = dir
	if a.activity == "stalk":
		# circle at a distance, edging closer, until it is time to dart in
		var ring := float(s.get("circle_radius", 240))
		var side := Vector2(-dir.y, dir.x) * (1.0 if a.animal_id.hash() % 2 == 0 else -1.0)
		var want := side * 0.9 + dir * clampf((d - ring) / 120.0, -1.0, 1.0)
		_move(world, a, want.normalized(), float(s.get("trot_speed", 150)), dt)
		a.timer -= dt
		if a.timer <= 0.0 and a.attack_cd <= 0.0:
			a.activity = "attack"
		return
	# attack: dart in, bite once, then fall back to circling
	if d > float(s.get("attack_range", 52)):
		if not _move(world, a, dir, float(s.get("chase_speed", 220)), dt):
			_move(world, a, Vector2(-dir.y, dir.x), float(s.get("chase_speed", 220)), dt)
		return
	if a.attack_cd <= 0.0:
		out.append(ZombieSim.damage_player(world, p, float(s.get("attack_damage", 8)), a.species))
		events.append(_event(a, str(s.get("bite_sound", s.get("alarm_sound", "")))))
		a.attack_cd = float(s.get("attack_cooldown", 1.8))
	a.activity = "stalk"
	a.timer = world.make_rng("regroup:" + a.animal_id + str(world.tick)).randf_range(1.5, 3.5)


static func _bear(world: WorldState, a: AnimalState, p: PlayerState, s: Dictionary, dt: float, events: Array, out: Array) -> void:
	var to := p.position - a.position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	a.facing = dir
	var territory := a.home.grow(float(s.get("territory_margin", 160)))
	if a.activity == "warn":
		a.timer -= dt
		if not territory.grow(80.0).has_point(p.position):
			_calm_down(a, s)  # the player backed off: it lets them go
			a.calm = 8.0
			return
		if d < float(s.get("charge_radius", 200)) or a.timer <= 0.0:
			a.activity = "attack"
			events.append(_event(a, str(s.get("charge_sound", s.get("call_sound", "")))))
		return
	# charge: run at the player, swipe, and after a hit or two go home
	if not territory.grow(float(s.get("chase_beyond", 300))).has_point(p.position):
		_calm_down(a, s)
		return
	if d > float(s.get("attack_range", 70)):
		_move(world, a, dir, float(s.get("chase_speed", 190)), dt)
		return
	if a.attack_cd <= 0.0:
		out.append(ZombieSim.damage_player(world, p, float(s.get("attack_damage", 22)), a.species))
		events.append(_event(a, str(s.get("alarm_sound", ""))))
		a.attack_cd = float(s.get("attack_cooldown", 2.4))
		if a.engaged > float(s.get("charge_seconds", 6.0)):
			_calm_down(a, s)


## A player hits an animal (host). Returns the result events.
static func damage(world: WorldState, a: AnimalState, amount: float, attacker: PlayerState) -> Array:
	var s := spec(a.species)
	if a.health <= 0.0:
		a.health = float(s.get("health", 60))
	a.health = maxf(0.0, a.health - amount)
	var ev := {"kind": "animal_hit", "region_id": a.region_id, "animal_id": a.animal_id, "x": a.position.x, "y": a.position.y,
		"amount": amount, "by": attacker.player_id if attacker != null else ""}
	if a.health <= 0.0:
		world.animals.erase(a.animal_id)
		ev["kind"] = "animal_killed"
		SessionLog.info("wildlife", "killed", {"animal": a.animal_id, "by": attacker.player_id.substr(0, 6) if attacker != null else ""})
		return [ev]
	# hurt: a bear or wolf turns on whoever hurt it (unless it is fleeing)
	if attacker != null and a.health >= float(s.get("health", 60)) * float(s.get("flee_health", 0.35)) and world.threat.enabled \
			and (bool(s.get("aggressive", false)) or bool(s.get("territorial", false))):
		a.activity = "attack"
		a.watching = attacker.player_id
		a.calm = 0.0
	elif attacker != null:
		a.activity = "flee"
		a.watching = attacker.player_id
	return [ev]


## The animal a melee swing or a shot from `p` toward `aim` would hit (host).
static func target_for(world: WorldState, p: PlayerState, aim: Vector2, reach: float, cone: float) -> AnimalState:
	var best: AnimalState = null
	var bd := INF
	for a in world.animals.values():
		if a.region_id != p.region_id:
			continue
		var to: Vector2 = a.position - p.position
		var d := to.length()
		if d > reach or (d > 30.0 and aim.dot(to / d) < cone):
			continue
		if d < bd:
			bd = d
			best = a
	return best


## Moves along dir if the next spot is walkable and inside the region. Returns false when blocked.
static func _move(world: WorldState, a: AnimalState, dir: Vector2, speed: float, dt: float) -> bool:
	var next := a.position + dir * speed * dt
	var b: Array = world.region_def(a.region_id).get("bounds", [])
	if b.size() == 4 and not Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3])).grow(-30.0).has_point(next):
		return false
	if not _walkable(_grid(world, a.region_id), next):
		return false
	a.position = next
	a.facing = dir
	return true


static func _wander_goal(world: WorldState, a: AnimalState, rng: RandomNumberGenerator, radius: float) -> Vector2:
	var grid := _grid(world, a.region_id)
	for attempt in 8:
		var g := a.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(radius * 0.3, radius)
		# stay near the home area (drift back toward it when outside)
		if not a.home.grow(radius * 0.5).has_point(g):
			g = a.home.get_center() + (g - a.home.get_center()) * 0.3
		if _walkable(grid, g) and (grid == null or grid.clear_line(a.position, g, {})):
			return g
	return a.position


static func rows(world: WorldState) -> Array:
	var out := []
	for a in world.animals.values():
		out.append(a.row())
	return out


## Client: mirror the host's animals (create, move, remove).
static func apply_rows(world: WorldState, rows_in: Array) -> void:
	var seen := {}
	for row in rows_in:
		var id := str(row[0])
		seen[id] = true
		var a: AnimalState = world.animals.get(id)
		if a == null:
			a = AnimalState.new()
			a.animal_id = id
			world.animals[id] = a
		a.species = str(row[1])
		a.region_id = str(row[2])
		a.position = Vector2(float(row[3]), float(row[4]))
		a.facing = Vector2(float(row[5]), float(row[6]))
		a.activity = str(row[7])
		if row.size() > 8:
			a.health = float(row[8])
	for id in world.animals.keys():
		if not seen.has(id):
			world.animals.erase(id)
