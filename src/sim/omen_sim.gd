class_name OmenSim
extends RefCounted
## Red Thaw atmospheric omens: occasional suppressed laughter near settlement
## buildings by day, brief human silhouettes at night. Pure functions of the
## shared world seed and clock — nothing is stored, sent or simulated — so all
## players in a region experience the same event at the same place and time
## (coherent, but each player's camera and hearing are their own). Never
## affects gameplay: no encounter, no noise, nothing to find.
## Tuning: content/tuning/omens.json; places: the region's "omens" block.

const PATH := "res://content/tuning/omens.json"
static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d = SafeFile.read_json(PATH)
		_cfg = d if d is Dictionary else {"_": 0}
	return _cfg


static func c(key: String, fallback: Variant) -> Variant:
	return cfg().get(key, fallback)


static func _rng(world: WorldState, region_id: String, kind: String, slot: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|%s|%s|%d" % [world.world_seed, region_id, kind, slot]).hash()
	return r


static func slot_ticks(kind: String) -> int:
	return maxi(1, int(float(c(kind + "_slot_seconds", 40)) * Simulation.TICK_RATE))


## The laughter event of a slot in a region, or {} if there is none.
## {slot, tick (when it sounds), spot: Vector2, sound, radius}
static func laugh(world: WorldState, region_id: String, slot: int) -> Dictionary:
	var om: Dictionary = world.region_def(region_id).get("omens", {})
	var spots: Array = om.get("laugh_spots", [])
	if spots.is_empty():
		return {}
	var r := _rng(world, region_id, "laugh", slot)
	if r.randf() >= float(c("laugh_chance", 0.3)):
		return {}
	var at := slot * slot_ticks("laugh") + r.randi_range(0, slot_ticks("laugh") - 1)
	if EnvSim.daylight_at(world, at) < float(c("laugh_min_daylight", 0.55)):
		return {}
	var sp: Array = spots[r.randi_range(0, spots.size() - 1)]
	var sounds: Array = c("laugh_sounds", ["sfx.giggle"])
	var jitter := Vector2(r.randf_range(-40, 40), r.randf_range(-30, 10))
	return {"slot": slot, "tick": at, "spot": Vector2(float(sp[0]), float(sp[1])) + jitter,
		"sound": str(sounds[r.randi_range(0, sounds.size() - 1)]), "radius": float(om.get("laugh_radius", 600))}


## The night silhouette of a slot in a region, or {}.
## {slot, tick (start), from: Vector2, to: Vector2, seconds}
static func shadow(world: WorldState, region_id: String, slot: int) -> Dictionary:
	var om: Dictionary = world.region_def(region_id).get("omens", {})
	var paths: Array = om.get("shadow_paths", [])
	if paths.is_empty():
		return {}
	var r := _rng(world, region_id, "shadow", slot)
	if r.randf() >= float(c("shadow_chance", 0.3)):
		return {}
	var at := slot * slot_ticks("shadow") + r.randi_range(0, slot_ticks("shadow") / 2)
	if EnvSim.daylight_at(world, at) > float(c("shadow_max_daylight", 0.25)):
		return {}
	var path: Array = paths[r.randi_range(0, paths.size() - 1)]
	var a := Vector2(float(path[0][0]), float(path[0][1]))
	var b := Vector2(float(path[1][0]), float(path[1][1]))
	if r.randf() < 0.5:
		var t := a
		a = b
		b = t
	var dur: Array = c("shadow_seconds", [3.5, 6.0])
	return {"slot": slot, "tick": at, "from": a, "to": b, "seconds": r.randf_range(float(dur[0]), float(dur[1]))}
