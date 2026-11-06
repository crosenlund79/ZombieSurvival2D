class_name SkillSim
extends RefCounted
## Per-player skills (iteration 013). Only Scavenging is active; the framework is
## data-driven (content/tuning/skills.json) so later skills add a table entry.
##
## A player's skills live in PlayerState.skills ({"scavenging": {"xp": n}}), saved
## with the player and replicated with their inventory. Levels are derived from XP,
## never stored, so a curve change re-levels everyone consistently.
## XP is only ever awarded by the host (award), times the developer XP multiplier
## (world meta "xp_multiplier", runtime: back to 1× on load). Every calculation that
## depends on a skill goes through this class.

const PATH := "res://content/tuning/skills.json"
const ACTIVE: Array[String] = ["scavenging"]
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {}
	return _data


static func cfg(skill: String) -> Dictionary:
	return data().get(skill, {})


static func xp(p: PlayerState, skill: String) -> int:
	if p == null:
		return 0
	return int((p.skills.get(skill, {}) as Dictionary).get("xp", 0))


static func max_level(skill: String) -> int:
	return int(cfg(skill).get("max_level", 10))


## Cumulative XP needed to reach `level` (1-based).
static func xp_for_level(skill: String, level: int) -> int:
	var t: Array = cfg(skill).get("level_xp", [0])
	var i := clampi(level - 1, 0, t.size() - 1)
	return int(t[i])


static func level_of_xp(skill: String, amount: int) -> int:
	var t: Array = cfg(skill).get("level_xp", [0])
	var lvl := 1
	for i in range(1, mini(t.size(), max_level(skill))):
		if amount >= int(t[i]):
			lvl = i + 1
	return lvl


static func level(p: PlayerState, skill: String) -> int:
	return level_of_xp(skill, xp(p, skill))


## {level, xp, into, needed (0 at max), max} for the Skills screen.
static func progress(p: PlayerState, skill: String) -> Dictionary:
	var x := xp(p, skill)
	var lvl := level_of_xp(skill, x)
	var at_max := lvl >= max_level(skill)
	var base := xp_for_level(skill, lvl)
	var nxt := xp_for_level(skill, lvl + 1) if not at_max else base
	return {"level": lvl, "xp": x, "into": x - base, "needed": nxt - base, "next_total": nxt, "max": at_max}


# ------------------------------------------------------------------ scavenging effect

static func search_factor(level_value: int) -> float:
	var t: Array = cfg("scavenging").get("search_factor", [1.0])
	return float(t[clampi(level_value - 1, 0, t.size() - 1)])


static func base_seconds(kind: String) -> float:
	return float((cfg("scavenging").get("base_seconds", {}) as Dictionary).get(kind, 5.0))


## Seconds a search of a container of `kind` takes at a scavenging level. Never instant.
static func search_seconds_at(kind: String, level_value: int) -> float:
	return maxf(float(cfg("scavenging").get("min_seconds", 1.2)), base_seconds(kind) * search_factor(level_value))


static func search_seconds(p: PlayerState, kind: String) -> float:
	return search_seconds_at(kind, level(p, "scavenging"))


## XP for one completed search (before the multiplier). `finds` = item units found.
static func search_xp(finds: int) -> int:
	var x: Dictionary = cfg("scavenging").get("xp", {})
	if finds <= 0:
		return int(x.get("empty_search", 6))
	return int(x.get("search", 12)) + int(x.get("per_find", 2)) * mini(finds, 5)


# ------------------------------------------------------------------ awarding (host)

static func multiplier(world: WorldState) -> float:
	if world == null:
		return 1.0
	return float(world.meta.get("xp_multiplier", float((data().get("xp_multiplier", {}) as Dictionary).get("default", 1.0))))


static func clamp_multiplier(v: float) -> float:
	var m: Dictionary = data().get("xp_multiplier", {})
	return clampf(v, float(m.get("min", 0.0)), float(m.get("max", 25.0)))


## Adds XP (scaled by the multiplier unless raw). Returns {gained, level_before, level_after}.
static func award(world: WorldState, p: PlayerState, skill: String, amount: int, raw := false) -> Dictionary:
	var before := level(p, skill)
	var gained := amount if raw else roundi(float(amount) * multiplier(world))
	gained = maxi(0, gained)
	var cap := xp_for_level(skill, max_level(skill))
	var now := mini(cap, xp(p, skill) + gained)
	gained = now - xp(p, skill)
	_set_xp(p, skill, now)
	return {"gained": gained, "level_before": before, "level_after": level(p, skill)}


static func set_level(p: PlayerState, skill: String, lvl: int) -> void:
	_set_xp(p, skill, xp_for_level(skill, clampi(lvl, 1, max_level(skill))))


static func reset(p: PlayerState, skill: String) -> void:
	_set_xp(p, skill, 0)


static func _set_xp(p: PlayerState, skill: String, value: int) -> void:
	var s: Dictionary = (p.skills.get(skill, {}) as Dictionary).duplicate()
	s["xp"] = maxi(0, value)
	p.skills[skill] = s


## Sanitised copy of saved skills (unknown skills dropped, XP clamped).
static func sanitize(d: Variant) -> Dictionary:
	var out := {}
	if not (d is Dictionary):
		return out
	for k in d:
		if not (str(k) in ACTIVE) or not (d[k] is Dictionary):
			continue
		var cap := xp_for_level(str(k), max_level(str(k)))
		out[str(k)] = {"xp": clampi(int((d[k] as Dictionary).get("xp", 0)), 0, cap)}
	return out
