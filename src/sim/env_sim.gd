class_name EnvSim
extends RefCounted
## Shared world conditions on the authoritative clock (host simulates; every
## peer derives the time of day from the replicated tick and receives weather
## changes). State: world.env = {"weather": "clear"|"rain", "until": tick,
## "seq": n}. Weather spells have seeded, reproducible lengths, so the same
## world always has the same weather history.
##
## Gameplay effects (read by ZombieSim): darkness shortens zombie sight and
## brings extra night wanderers; rain shortens sight and masks noise (smaller
## hearing radius) and fills rain collectors faster.

const TUNING_PATH := "res://content/tuning/environment.json"
static var _cfg: Dictionary = {}


static func c(key: String, fallback: Variant) -> Variant:
	if _cfg.is_empty():
		var d = SafeFile.read_json(TUNING_PATH)
		_cfg = d if d is Dictionary else {}
	return _cfg.get(key, fallback)


static func hour(world: WorldState) -> float:
	if world == null:
		return 12.0
	return fmod(float(c("start_hour", 8.0)) + world.sim_seconds() / float(c("day_seconds", 1440)) * 24.0, 24.0)


static func day_number(world: WorldState) -> int:
	return 1 + int((float(c("start_hour", 8.0)) + world.sim_seconds() / float(c("day_seconds", 1440)) * 24.0) / 24.0)


## 1 = full daylight, 0 = deep night (smooth dawn and dusk).
static func daylight(world: WorldState) -> float:
	var h := hour(world)
	var dawn: Array = c("dawn", [5.0, 7.0])
	var dusk: Array = c("dusk", [19.0, 21.0])
	if h >= float(dawn[1]) and h <= float(dusk[0]):
		return 1.0
	if h > float(dawn[0]) and h < float(dawn[1]):
		return smoothstep(float(dawn[0]), float(dawn[1]), h)
	if h > float(dusk[0]) and h < float(dusk[1]):
		return 1.0 - smoothstep(float(dusk[0]), float(dusk[1]), h)
	return 0.0


static func is_night(world: WorldState) -> bool:
	return daylight(world) < 0.35


static func weather(world: WorldState) -> String:
	return str(world.env.get("weather", "clear")) if world != null else "clear"


static func is_raining(world: WorldState) -> bool:
	return weather(world) == "rain"


static func sight_scale(world: WorldState) -> float:
	var s := 1.0
	var dl := daylight(world)
	s *= lerpf(float(c("night", {}).get("sight_scale", 0.6)), 1.0, dl)
	if is_raining(world):
		s *= float(c("rain", {}).get("sight_scale", 0.8))
	return s


static func hearing_scale(world: WorldState) -> float:
	return float(c("rain", {}).get("hearing_scale", 0.75)) if is_raining(world) else 1.0


static func extra_population(world: WorldState) -> int:
	return int(c("night", {}).get("extra_population", 2)) if is_night(world) else 0


static func _spell_ticks(world: WorldState, kind: String, seq: int) -> int:
	var rng := world.make_rng("weather:%d" % seq)
	var r: Array = c("rain_minutes" if kind == "rain" else "clear_minutes", [5, 10])
	return int(rng.randf_range(float(r[0]), float(r[1])) * 60.0 * Simulation.TICK_RATE)


## Host: advance the weather. Returns a result when it changed (published as "env").
static func step(world: WorldState, _ticks: int) -> Array:
	if world.env.is_empty():
		world.env = {"weather": "clear", "seq": 0, "until": world.tick + _spell_ticks(world, "clear", 0)}
	if world.tick < int(world.env.get("until", 0)):
		return []
	var seq := int(world.env.get("seq", 0)) + 1
	var next := "rain" if weather(world) == "clear" else "clear"
	set_weather(world, next, seq)
	var res := WorldActions._ok()
	res["env"] = true
	res["events"] = [{"kind": "weather", "weather": next}]
	return [res]


static func set_weather(world: WorldState, kind: String, seq: int = -1) -> void:
	if seq < 0:
		seq = int(world.env.get("seq", 0)) + 1
	world.env = {"weather": kind, "seq": seq, "until": world.tick + _spell_ticks(world, kind, seq)}
	SessionLog.info("world", "weather", {"weather": kind, "until": world.env["until"]})


## "Day 2 · 21:30" for the HUD.
static func clock_text(world: WorldState) -> String:
	var h := hour(world)
	return "%d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
