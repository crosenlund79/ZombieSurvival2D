class_name AssetCatalog
extends RefCounted
## Reads the asset manifests (res://assets/manifest/*.json) and maps stable
## logical asset IDs to template / override paths. Pure data, no loading.
## Usable from editor tool scripts (no autoload needed).
##
## Convention:
##   template  res://assets/templates/<rel>/template_<name>.<ext>
##   bundled   res://assets/overrides/<rel>/<name>.<ext>
##   external  user://overrides/<rel>/<name>.<ext>

const MANIFEST_DIR := "res://assets/manifest/"
const TEMPLATE_ROOT := "res://assets/templates/"
const OVERRIDE_ROOT := "res://assets/overrides/"
const EXTERNAL_ROOT := "user://overrides/"
const STATUSES: Array[String] = ["READY", "ADAPTER_REQUIRED", "REFERENCE_ONLY"]
const IMAGE_EXTS: Array[String] = ["png"]
const AUDIO_EXTS: Array[String] = ["ogg", "wav"]

static var _entries: Dictionary = {}
static var _loaded := false
static var problems: Array[String] = []


static func reload() -> void:
	_entries.clear()
	problems.clear()
	_loaded = true
	for file in DirAccess.get_files_at(MANIFEST_DIR):
		if not file.ends_with(".json"):
			continue
		var data = SafeFile.read_json(MANIFEST_DIR + file)
		if data is String:
			problems.append("%s: %s" % [file, data])
			continue
		var kind := "audio" if str(data.get("kind", "visual")) == "audio" else "visual"
		for raw in data.get("assets", []):
			var e: Dictionary = raw
			var id := str(e.get("id", ""))
			if id == "":
				problems.append("%s: entry without id" % file)
				continue
			if _entries.has(id):
				problems.append("%s: duplicate asset id %s" % [file, id])
				continue
			e["kind"] = kind
			e["manifest"] = file
			_entries[id] = e


static func ensure_loaded() -> void:
	if not _loaded:
		reload()


static func has(id: String) -> bool:
	ensure_loaded()
	return _entries.has(id)


static func entry(id: String) -> Dictionary:
	ensure_loaded()
	return _entries.get(id, {})


static func ids() -> Array:
	ensure_loaded()
	return _entries.keys()


static func template_path(id: String) -> String:
	return str(entry(id).get("template", ""))


## Relative path below the template root with the `template_` prefix removed,
## without extension. "" if the template path breaks the convention.
static func override_stem(template: String) -> String:
	if not is_safe_template_path(template):
		return ""
	var rel := template.substr(TEMPLATE_ROOT.length())
	var dir := rel.get_base_dir()
	var file := rel.get_file()
	if not file.begins_with("template_"):
		return ""
	var stem := file.substr("template_".length()).get_basename()
	return stem if dir == "" else dir.path_join(stem)


static func is_safe_template_path(path: String) -> bool:
	return path.begins_with(TEMPLATE_ROOT) and not ".." in path and not "\\" in path


static func extensions_for(id: String) -> Array[String]:
	return AUDIO_EXTS if str(entry(id).get("kind", "visual")) == "audio" else IMAGE_EXTS


static func bundled_candidates(id: String) -> Array[String]:
	var stem := override_stem(template_path(id))
	var out: Array[String] = []
	if stem != "":
		for ext in extensions_for(id):
			out.append(OVERRIDE_ROOT + stem + "." + ext)
	return out


static func external_candidates(id: String) -> Array[String]:
	var stem := override_stem(template_path(id))
	var out: Array[String] = []
	if stem != "":
		for ext in extensions_for(id):
			out.append(EXTERNAL_ROOT + stem + "." + ext)
	return out


static func display_size(id: String) -> Vector2:
	var a: Array = entry(id).get("display_size", [64, 64])
	return Vector2(float(a[0]), float(a[1]))


## Pivot as a fraction of the display box (0..1). [0.5, 1.0] = bottom centre.
static func pivot(id: String) -> Vector2:
	var a: Array = entry(id).get("pivot", [0.5, 0.5])
	return Vector2(float(a[0]), float(a[1]))
