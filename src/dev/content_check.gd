class_name ContentCheck
extends RefCounted
## Lightweight content integrity inspection. Reports PASS / WARN / FAIL lines.
## Checks only content that exists today: regions, region scenes, asset
## manifests, asset IDs referenced by code/scenes, and translation keys.
## Never modifies or deletes anything.

var lines: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	lines.clear()
	Content.reload()
	AssetCatalog.reload()
	_check_regions()
	_check_manifests()
	_check_code_references()
	_check_locale()
	return lines


func count(level: String) -> int:
	var n := 0
	for l in lines:
		if l["level"] == level:
			n += 1
	return n


func report_text() -> String:
	var out: Array[String] = []
	for l in lines:
		out.append("%-4s %s" % [l["level"], l["msg"]])
	out.append("Summary: %d PASS, %d WARN, %d FAIL" % [count("PASS"), count("WARN"), count("FAIL")])
	return "\n".join(out)


func _add(level: String, msg: String) -> void:
	lines.append({"level": level, "msg": msg})


func _check_regions() -> void:
	for p in Content.problems:
		_add("FAIL", "region file: " + p)
	var all_ids := {}
	var locale := Localization.keys()
	for rid in Content.region_ids():
		var def := Content.region_def(rid)
		var scene := str(def.get("scene", ""))
		if not ResourceLoader.exists(scene):
			_add("FAIL", "region %s: scene missing (%s)" % [rid, scene])
		else:
			_add("PASS", "region %s: scene exists" % rid)
			_check_region_scene(rid, scene)
		if not str(def.get("display_key", "")) in locale:
			_add("WARN", "region %s: display_key %s not in locale" % [rid, def.get("display_key", "")])
		var b: Array = def.get("bounds", [])
		if b.size() != 4:
			_add("FAIL", "region %s: bounds must be [x, y, w, h]" % rid)
			continue
		var rect := Rect2(b[0], b[1], b[2], b[3])
		for sp in def.get("spawn_points", []):
			if not rect.has_point(Vector2(sp[0], sp[1])):
				_add("FAIL", "region %s: spawn point %s outside bounds" % [rid, str(sp)])
		if def.get("spawn_points", []).is_empty():
			_add("FAIL", "region %s: no spawn points" % rid)
		for e in def.get("entities", []):
			var eid := str(e.get("id", ""))
			if eid == "":
				_add("FAIL", "region %s: entity without id" % rid)
				continue
			if all_ids.has(eid):
				_add("FAIL", "duplicate entity id %s" % eid)
			all_ids[eid] = true
			if not str(e.get("type", "")) in Content.ENTITY_TYPES:
				_add("FAIL", "entity %s: unknown type %s" % [eid, e.get("type", "")])
			if not (e.get("initial") is Dictionary):
				_add("FAIL", "entity %s: missing initial state" % eid)
			if not rect.has_point(Content.entity_position(e)):
				_add("FAIL", "entity %s: position outside region bounds" % eid)
		_add("PASS", "region %s: %d entities checked" % [rid, def.get("entities", []).size()])


func _check_region_scene(rid: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_add("FAIL", "region %s: scene cannot be loaded" % rid)
		return
	var root := packed.instantiate()  # not added to the tree: no _ready side effects
	var views := {}
	for n in root.find_children("*", "", true, false):
		if n is DoorView:
			var dv: DoorView = n
			if Content.entity_def(rid, dv.entity_id).is_empty():
				_add("FAIL", "region %s scene: DoorView %s points to unknown entity '%s'" % [rid, dv.name, dv.entity_id])
			views[dv.entity_id] = true
	for eid in Content.entity_ids(rid):
		if str(Content.entity_def(rid, eid).get("type")) == "door" and not views.has(eid):
			_add("WARN", "region %s: door entity %s has no DoorView in the scene" % [rid, eid])
	if not (root is RegionView) or (root as RegionView).region_id != rid:
		_add("FAIL", "region %s: scene root must be a RegionView with region_id '%s'" % [rid, rid])
	root.free()


func _check_manifests() -> void:
	for p in AssetCatalog.problems:
		_add("FAIL", "manifest: " + p)
	var ok := 0
	for id in AssetCatalog.ids():
		var e := AssetCatalog.entry(id)
		var tpl := str(e.get("template", ""))
		if AssetCatalog.override_stem(tpl) == "":
			_add("FAIL", "asset %s: template path breaks the convention (%s)" % [id, tpl])
			continue
		if not ResourceLoader.exists(tpl) and not FileAccess.file_exists(tpl):
			_add("FAIL", "asset %s: template file missing (%s)" % [id, tpl])
			continue
		if not str(e.get("status", "")) in AssetCatalog.STATUSES:
			_add("FAIL", "asset %s: status must be READY / ADAPTER_REQUIRED / REFERENCE_ONLY" % id)
		if e["kind"] == "visual":
			for k in ["display_size", "source_size", "pivot", "transparency"]:
				if not e.has(k):
					_add("WARN", "asset %s: missing %s" % [id, k])
		else:
			if not str(e.get("bus", "")) in SettingsService.BUSES:
				_add("FAIL", "sound %s: unknown bus %s" % [id, e.get("bus", "")])
		ok += 1
	_add("PASS", "%d manifest entries have valid templates" % ok)


## Asset IDs written in code or scenes must exist in a manifest.
func _check_code_references() -> void:
	var rx := RegEx.new()
	rx.compile("\"((?:char|world|env|prop|sfx|ui|amb|fx)\\.[a-z0-9_.]+)\"")
	var missing := 0
	for path in _files("res://src", ["gd"]) + _files("res://scenes", ["tscn", "gd"]):
		var text := FileAccess.get_file_as_string(path)
		for m in rx.search_all(text):
			var id := m.get_string(1)
			if id.get_extension() in ["json", "png", "wav", "ogg", "gd", "tscn", "cfg"]:
				continue  # a file name, not an asset id
			if not AssetCatalog.has(id):
				missing += 1
				_add("FAIL", "%s references unknown asset id %s" % [path, id])
	if missing == 0:
		_add("PASS", "all asset ids referenced in code/scenes exist")


func _check_locale() -> void:
	var data = SafeFile.read_json(Localization.PATH)
	if data is String:
		_add("FAIL", "locale: " + data)
		return
	for key in data:
		for loc in SettingsService.LANGUAGES:
			if not data[key].has(loc):
				_add("WARN", "locale: %s missing '%s'" % [key, loc])
	var rx := RegEx.new()
	rx.compile("\"([A-Z][A-Z0-9]+_[A-Z0-9_]+)\"")
	var unknown := {}
	for path in _files("res://src", ["gd"]):
		for m in rx.search_all(FileAccess.get_file_as_string(path)):
			var k := m.get_string(1)
			if not data.has(k) and not k.ends_with("_") and not k in AssetCatalog.STATUSES:
				unknown[k] = path
	for k in unknown:
		_add("WARN", "possible translation key %s (in %s) not in locale" % [k, unknown[k]])
	_add("PASS", "locale: %d keys" % data.size())


func _files(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), exts))
	return out
