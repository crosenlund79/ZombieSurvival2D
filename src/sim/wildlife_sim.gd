class_name WildlifeSim
extends RefCounted
## Non-aggressive wildlife (iteration 011 D): wolves and bears that roam their
## home area, idle, notice players, stop to watch, back away or bolt, and call
## out now and then (more at night). They never attack and never block the
## Burnt One systems. Host-only simulation; clients mirror compact rows.
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
	var night := EnvSim.is_night(world)
	for a in world.animals.values():
		_think(world, a, dt, night, events)
	if events.is_empty():
		return []
	var r := WorldActions._ok()
	r["events"] = events
	return [r]


static func _nearest_player(world: WorldState, a: AnimalState) -> PlayerState:
	var best: PlayerState = null
	var bd := INF
	for p in world.online_players():
		if p.region_id != a.region_id or p.dead:
			continue
		var d := p.position.distance_to(a.position)
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
	var d := p.position.distance_to(a.position) if p != null else INF
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
	for id in world.animals.keys():
		if not seen.has(id):
			world.animals.erase(id)
