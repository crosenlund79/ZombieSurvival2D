class_name BloodSim
extends RefCounted
## Thawed blood (iteration 012). Host-authoritative, saved.
##
## Every Burnt One carries frozen blood in its clothing. Near real warmth — a
## region's authored heat sources (the cabin's lit stove radiating through its
## walls and chimney) and running car engines — its `thaw` rises; away from
## heat it refreezes. While thawed past a threshold it now and then drips
## (never more often than every few seconds), and the drop refreezes into one
## small crimson mark on the snow. So marks appear only where warmth plausibly
## thawed something, then a few more along the way while it refreezes — never a
## trail everywhere it walks.
##
## Marks are plain data in WorldState.blood: [id, region, x, y, birth_tick,
## size, cover, wash]. The weather erases them systemically: clear and fog let
## old blood slowly fade into the snow, falling snow and blizzards bury them
## (`cover`), rain and storms wash them out (`wash`). How readable a mark is
## (fog and blowing snow) is decided by `visibility()` for presentation; no
## HUD warning is ever shown. Content: res://content/tuning/blood.json.

const PATH := "res://content/tuning/blood.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {}
	return _data


static func c(key: String, fallback: Variant) -> Variant:
	return data().get(key, fallback)


static func wc(kind: String) -> Dictionary:
	var w: Dictionary = data().get("weather", {})
	return w.get(kind, w.get("clear", {}))


## Heat sources in a region right now: [[position, radius, strength], ...].
static func heat_sources(world: WorldState, region_id: String) -> Array:
	var out: Array = []
	for h in world.region_def(region_id).get("heat_sources", []):
		var p: Array = h.get("position", [0, 0])
		out.append([Vector2(float(p[0]), float(p[1])), float(h.get("radius", 200)), float(h.get("strength", 1.0))])
	var eng: Dictionary = c("vehicle_engine_heat", {"radius": 170, "strength": 1.2})
	for v in world.vehicles.values():
		if v.region_id == region_id and v.engine_on:
			out.append([v.position, float(eng.get("radius", 170)), float(eng.get("strength", 1.2))])
	for h2 in world.dev_heat:
		if str(h2[0]) == region_id:
			out.append([h2[1], float(h2[2]), 1.0])
	return out


## How warm it is for a Burnt One standing here (0 = no heat).
static func heat_at(sources: Array, pos: Vector2) -> float:
	var best := 0.0
	for s in sources:
		var d := pos.distance_to(s[0])
		if d < float(s[1]):
			best = maxf(best, float(s[2]) * (1.0 - d / float(s[1])))
	return best


## Snowy outdoor ground only (regions that Burnt Ones roam).
static func _snowy(world: WorldState, region_id: String) -> bool:
	return world.region_def(region_id).has("zombies")


static func step(world: WorldState, ticks: int) -> Array:
	var dt := float(ticks) / Simulation.TICK_RATE
	var changed := false
	var src_cache := {}
	for z in world.zombies.values():
		if z.is_dead():
			continue
		if not src_cache.has(z.region_id):
			src_cache[z.region_id] = heat_sources(world, z.region_id)
		var heat := heat_at(src_cache[z.region_id], z.position)
		if heat > 0.0:
			z.thaw = minf(1.0, z.thaw + dt * heat / float(c("thaw_seconds", 20.0)))
		else:
			z.thaw = maxf(0.0, z.thaw - dt / float(c("refreeze_seconds", 55.0)))
		z.drip_cd = maxf(0.0, z.drip_cd - dt)
		if z.thaw >= float(c("drip_threshold", 0.3)) and z.drip_cd <= 0.0 and _snowy(world, z.region_id):
			if world.sim_rng().randf() < float(c("drip_chance_per_second", 0.35)) * z.thaw * dt:
				drip(world, z.region_id, z.position)
				z.drip_cd = float(c("drip_min_interval", 5.0))
				changed = true
	if _weather_erase(world, dt):
		changed = true
	if not changed:
		return []
	var r := WorldActions._ok()
	r["blood"] = true
	return [r]


## Adds one small mark (host). Oldest marks go first beyond the cap.
static func drip(world: WorldState, region_id: String, pos: Vector2) -> void:
	var rng := world.sim_rng()
	var at := pos + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 3))
	world.blood.append([world.new_uid("b"), region_id, snappedf(at.x, 0.1), snappedf(at.y, 0.1), world.tick,
		snappedf(rng.randf_range(0.55, 1.0), 0.01), 0.0, 0.0])
	var cap := int(c("max_traces", 120))
	while world.blood.size() > cap:
		world.blood.pop_front()


## Weather wears marks away: fade (clear, fog), cover (snow, blizzard), wash
## (rain, thunderstorm). Returns true when a mark disappeared or changed a step
## large enough to be worth replicating.
static func _weather_erase(world: WorldState, dt: float) -> bool:
	if world.blood.is_empty():
		return false
	var kind := EnvSim.weather(world)
	var cfg := wc(kind)
	var rate := float(cfg.get("erase", 0.07)) / 60.0 * dt
	var how := str(cfg.get("kind", "fade"))
	var removed := false
	var stepped := false
	var keep: Array = []
	for b in world.blood:
		var before := floorf((float(b[6]) + float(b[7])) * 10.0)
		match how:
			"cover":
				b[6] = minf(1.0, float(b[6]) + rate)
			"wash":
				b[7] = minf(1.0, float(b[7]) + rate)
			_:
				b[7] = minf(1.0, float(b[7]) + rate * 0.5)
				b[6] = minf(1.0, float(b[6]) + rate * 0.5)
		if strength(b) <= 0.04:
			removed = true
			continue
		if floorf((float(b[6]) + float(b[7])) * 10.0) != before:
			stepped = true
		keep.append(b)
	world.blood = keep
	return removed or stepped


## How much of a mark is left (0..1).
static func strength(b: Array) -> float:
	return (1.0 - float(b[6])) * (1.0 - float(b[7]))


## How readable a mark is for someone looking from `viewer` right now (0..1):
## what is left of it, how far away it is and what the weather does to the view.
static func visibility(world: WorldState, b: Array, viewer: Vector2) -> float:
	var cfg := wc(EnvSim.weather(world))
	var rng := float(cfg.get("range", 1400))
	var d := viewer.distance_to(Vector2(float(b[2]), float(b[3])))
	var dist_k := clampf(1.0 - (d - rng * 0.5) / (rng * 0.5), 0.0, 1.0)
	return strength(b) * float(cfg.get("visibility", 1.0)) * dist_k


static func in_region(world: WorldState, region_id: String) -> Array:
	return world.blood.filter(func(b): return str(b[1]) == region_id)


static func encode(world: WorldState) -> Array:
	return world.blood.duplicate(true)


static func decode(world: WorldState, d) -> void:
	world.blood = []
	if not (d is Array):
		return
	for b in d:
		if b is Array and b.size() >= 8 and world.region(str(b[1])) != null:
			world.blood.append([str(b[0]), str(b[1]), float(b[2]), float(b[3]), int(b[4]), float(b[5]),
				clampf(float(b[6]), 0.0, 1.0), clampf(float(b[7]), 0.0, 1.0)])
