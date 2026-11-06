class_name Content
extends RefCounted
## Authored content definitions. Read-only.
##
## Two kinds of definition ("defs"):
##  * Static regions — res://content/regions/*.json, keyed by region_id (e.g. "homestead").
##    These exist in every world.
##  * Level templates — res://content/bunker_levels/*.json, keyed "level:<template_id>".
##    Bunker levels are created at runtime from a template; each created level is a
##    region whose RegionState.def_id points at its template.
## A def describes the *initial* state: entity IDs, types, positions, reach and
## initial state. Player changes are stored separately in RegionState.

const REGION_DIR := "res://content/regions/"
const LEVEL_DIR := "res://content/bunker_levels/"
const LEVEL_PREFIX := "level:"
const DEFAULT_REGION := "homestead"
## Entity types the rules in WorldActions understand.
const ENTITY_TYPES: Array[String] = ["door", "portal", "shelter_site", "tree", "stockpile", "support_site", "weapon_rack", "starter_bag", "bed",
	"storage", "generator", "purifier", "lamp", "loot", "container"]

static var _defs: Dictionary = {}       # def_id -> def
static var _region_ids: Array = []      # static regions only
static var _loaded := false
static var problems: Array[String] = []


static func reload() -> void:
	_defs.clear()
	_region_ids.clear()
	problems.clear()
	_loaded = true
	_load_dir(REGION_DIR, "region_id", "")
	_load_dir(LEVEL_DIR, "template_id", LEVEL_PREFIX)


static func _load_dir(dir: String, id_key: String, prefix: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var data = SafeFile.read_json(dir + file)
		if data is String:
			problems.append("%s: %s" % [file, data])
			continue
		var id := str(data.get(id_key, ""))
		if id == "":
			problems.append("%s: missing %s" % [file, id_key])
			continue
		var by_id := {}
		for e in data.get("entities", []):
			by_id[str(e.get("id", ""))] = e
		data["_entities_by_id"] = by_id
		_defs[prefix + id] = data
		if prefix == "":
			_region_ids.append(id)


static func ensure_loaded() -> void:
	if not _loaded:
		reload()


## Static regions present in every world.
static func region_ids() -> Array:
	ensure_loaded()
	return _region_ids.duplicate()


static func level_template_ids() -> Array:
	ensure_loaded()
	var out := []
	for k in _defs:
		if str(k).begins_with(LEVEL_PREFIX):
			out.append(str(k).substr(LEVEL_PREFIX.length()))
	return out


## Any def by id: a static region id or "level:<template_id>".
static func region_def(def_id: String) -> Dictionary:
	ensure_loaded()
	return _defs.get(def_id, {})


static func level_def_id(template_id: String) -> String:
	return LEVEL_PREFIX + template_id


static func entity_def(def_id: String, entity_id: String) -> Dictionary:
	return region_def(def_id).get("_entities_by_id", {}).get(entity_id, {})


static func entity_ids(def_id: String) -> Array:
	return region_def(def_id).get("_entities_by_id", {}).keys()


static func entity_position(def: Dictionary) -> Vector2:
	var p: Array = def.get("position", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func spawn_point(def_id: String, index: int) -> Vector2:
	var pts: Array = region_def(def_id).get("spawn_points", [[0, 0]])
	var p: Array = pts[index % pts.size()]
	return Vector2(float(p[0]), float(p[1]))


## Short fingerprint of all content; host and client must match.
static func fingerprint() -> String:
	ensure_loaded()
	var parts: Array[String] = []
	var ids := _defs.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = _defs[id].duplicate()
		d.erase("_entities_by_id")
		parts.append(str(id) + "=" + JSON.stringify(d, "", true))
	return "|".join(parts).md5_text().substr(0, 12)
