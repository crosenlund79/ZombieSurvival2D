class_name Content
extends RefCounted
## Authored content definitions (res://content/regions/*.json). Read-only.
## Region files describe the *initial* world: entity IDs, types, positions and
## initial state. Player changes are stored separately in RegionState.

const REGION_DIR := "res://content/regions/"
const DEFAULT_REGION := "homestead"
## Entity types the rules in WorldActions understand.
const ENTITY_TYPES: Array[String] = ["door"]

static var _regions: Dictionary = {}
static var _loaded := false
static var problems: Array[String] = []


static func reload() -> void:
	_regions.clear()
	problems.clear()
	_loaded = true
	for file in DirAccess.get_files_at(REGION_DIR):
		if not file.ends_with(".json"):
			continue
		var data = SafeFile.read_json(REGION_DIR + file)
		if data is String:
			problems.append("%s: %s" % [file, data])
			continue
		var id := str(data.get("region_id", ""))
		if id == "":
			problems.append("%s: missing region_id" % file)
			continue
		var by_id := {}
		for e in data.get("entities", []):
			by_id[str(e.get("id", ""))] = e
		data["_entities_by_id"] = by_id
		_regions[id] = data


static func ensure_loaded() -> void:
	if not _loaded:
		reload()


static func region_ids() -> Array:
	ensure_loaded()
	return _regions.keys()


static func region_def(region_id: String) -> Dictionary:
	ensure_loaded()
	return _regions.get(region_id, {})


static func entity_def(region_id: String, entity_id: String) -> Dictionary:
	return region_def(region_id).get("_entities_by_id", {}).get(entity_id, {})


static func entity_ids(region_id: String) -> Array:
	return region_def(region_id).get("_entities_by_id", {}).keys()


static func entity_position(def: Dictionary) -> Vector2:
	var p: Array = def.get("position", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func spawn_point(region_id: String, index: int) -> Vector2:
	var pts: Array = region_def(region_id).get("spawn_points", [[0, 0]])
	var p: Array = pts[index % pts.size()]
	return Vector2(float(p[0]), float(p[1]))


## Short fingerprint of all region content; host and client must match.
static func fingerprint() -> String:
	ensure_loaded()
	var parts: Array[String] = []
	var ids := _regions.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = _regions[id].duplicate()
		d.erase("_entities_by_id")
		parts.append(JSON.stringify(d, "", true))
	return "|".join(parts).md5_text().substr(0, 12)
