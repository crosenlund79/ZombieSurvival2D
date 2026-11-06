class_name EnvSim
extends RefCounted
## Shared world conditions on the authoritative clock (host simulates; every
## peer derives the time of day from the replicated tick and receives weather
## changes). State: world.env = {"weather": kind, "until": tick, "seq": n}.
## Iteration 011 kinds: clear, snow, fog, heavy_rain, blizzard, thunderstorm.
## Calm (clear) spells alternate with a seeded, weighted choice of weather, so
## the same world always has the same weather history. Saves from before 011
## stored "rain" for what was shown as snowfall: it reads as "snow".
##
## Gameplay effects: darkness and weather shorten Burnt One sight; precipitation
## masks noise (smaller hearing radius) and fills meltwater collectors; cold
## (region climate x night x weather) drives player exposure (SurvivalSim).
## Lightning is a pure function of the seed and clock (lightning()), so every
## peer flashes at the same moment without any replication.

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
	return _daylight_for_hour(hour(world))


## Daylight at an arbitrary world tick (used by deterministic schedules).
static func daylight_at(world: WorldState, tick: int) -> float:
	var secs := float(tick) / Simulation.TICK_RATE
	return _daylight_for_hour(fmod(float(c("start_hour", 8.0)) + secs / float(c("day_seconds", 1440)) * 24.0, 24.0))


static func _daylight_for_hour(h: float) -> float:
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


const KINDS: Array[String] = ["clear", "snow", "fog", "heavy_rain", "blizzard", "thunderstorm"]
const PRECIPITATION: Array[String] = ["snow", "heavy_rain", "blizzard", "thunderstorm"]


static func weather(world: WorldState) -> String:
	if world == null:
		return "clear"
	var w := str(world.env.get("weather", "clear"))
	return "snow" if w == "rain" else w   # pre-011 saves


static func wcfg(kind: String) -> Dictionary:
	return c("weather", {}).get(kind, {})


## True while anything falls from the sky (masks noise, fills collectors).
static func is_raining(world: WorldState) -> bool:
	return weather(world) in PRECIPITATION


## Region climate from its content: {"exposure": 1.0, "fog": 1.0} (outdoor only).
static func climate(world: WorldState, region_id: String) -> Dictionary:
	return world.region_def(region_id).get("climate", {}) if world != null else {}


static func sight_scale(world: WorldState, region_id: String = "") -> float:
	var s := 1.0
	var dl := daylight(world)
	s *= lerpf(float(c("night", {}).get("sight_scale", 0.6)), 1.0, dl)
	var wsight := float(wcfg(weather(world)).get("sight_scale", 1.0))
	if region_id != "" and weather(world) == "fog":
		wsight = pow(wsight, float(climate(world, region_id).get("fog", 1.0)))
	return s * wsight


## Iteration 012: how much the weather masks distant sounds for players (dB, <= 0):
## wind, rain and blowing snow make Burnt One sounds useful but imperfect clues.
static func sound_mask_db(world: WorldState) -> float:
	if world == null:
		return 0.0
	return float(wcfg(weather(world)).get("sound_mask_db", 0.0))


static func hearing_scale(world: WorldState) -> float:
	return float(wcfg(weather(world)).get("hearing_scale", 1.0))


## Ambient cold on the surface of a region (0 = mild, ~1 = cold day, >1.5 =
## dangerous). Shelters (regions without a climate block) return 0.
static func cold(world: WorldState, region_id: String) -> float:
	var cl := climate(world, region_id)
	if cl.is_empty():
		return 0.0
	var k := float(c("cold", {}).get("base", 0.8)) * float(cl.get("exposure", 1.0))
	k += float(c("cold", {}).get("night", 0.35)) * (1.0 - daylight(world))
	k += float(wcfg(weather(world)).get("cold", 0.0))
	# Unheated buildings (iteration 013 interiors) keep out most of the wind and weather.
	k *= float(cl.get("shelter", 1.0))
	return maxf(0.0, k)


static func extra_population(world: WorldState) -> int:
	return int(c("night", {}).get("extra_population", 2)) if is_night(world) else 0


static func _spell_ticks(world: WorldState, kind: String, seq: int) -> int:
	var rng := world.make_rng("weather:%d" % seq)
	var r: Array = wcfg(kind).get("minutes", c("clear_minutes", [10, 18]) if kind == "clear" else [3, 6])
	return int(rng.randf_range(float(r[0]), float(r[1])) * 60.0 * Simulation.TICK_RATE)


## Seeded, weighted choice of the next weather after a calm spell.
static func _next_kind(world: WorldState, seq: int) -> String:
	var rng := world.make_rng("weather_kind:%d" % seq)
	var total := 0.0
	for k in KINDS:
		total += float(wcfg(k).get("weight", 0.0)) if k != "clear" else 0.0
	var roll := rng.randf() * total
	for k in KINDS:
		if k == "clear":
			continue
		roll -= float(wcfg(k).get("weight", 0.0))
		if roll <= 0.0:
			return k
	return "snow"


## Host: advance the weather. Returns a result when it changed (published as "env").
static func step(world: WorldState, _ticks: int) -> Array:
	if world.env.is_empty():
		world.env = {"weather": "clear", "seq": 0, "until": world.tick + _spell_ticks(world, "clear", 0)}
	if world.tick < int(world.env.get("until", 0)):
		return []
	var seq := int(world.env.get("seq", 0)) + 1
	var next := _next_kind(world, seq) if weather(world) == "clear" else "clear"
	set_weather(world, next, seq)
	var res := WorldActions._ok()
	res["env"] = true
	res["events"] = [{"kind": "weather", "weather": next}]
	return [res]


static func set_weather(world: WorldState, kind: String, seq: int = -1) -> void:
	if kind == "rain":
		kind = "snow"
	if not (kind in KINDS):
		kind = "clear"
	if seq < 0:
		seq = int(world.env.get("seq", 0)) + 1
	world.env = {"weather": kind, "seq": seq, "until": world.tick + _spell_ticks(world, kind, seq)}
	SessionLog.info("world", "weather", {"weather": kind, "until": world.env["until"]})


## Lightning during a thunderstorm: one possible strike per slot, decided by the
## seed. Returns {} or {tick, strength 0.5-1, thunder_delay seconds, near}.
static func lightning(world: WorldState, slot: int) -> Dictionary:
	if weather(world) != "thunderstorm":
		return {}
	var slot_ticks := int(float(c("lightning", {}).get("slot_seconds", 9)) * Simulation.TICK_RATE)
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|lightning|%d" % [world.world_seed, slot]).hash()
	if r.randf() >= float(c("lightning", {}).get("chance", 0.4)):
		return {}
	var near := r.randf() < 0.35
	return {"tick": slot * slot_ticks + r.randi_range(0, slot_ticks - 1), "strength": r.randf_range(0.55, 1.0) if near else r.randf_range(0.3, 0.6),
		"thunder_delay": r.randf_range(0.4, 1.2) if near else r.randf_range(1.8, 4.5), "near": near}


static func lightning_slot_ticks() -> int:
	return int(float(c("lightning", {}).get("slot_seconds", 9)) * Simulation.TICK_RATE)


## "Day 2 · 21:30" for the HUD.
static func clock_text(world: WorldState) -> String:
	var h := hour(world)
	return "%d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
