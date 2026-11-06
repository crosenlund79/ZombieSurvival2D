class_name ContentCheck
extends RefCounted
## Lightweight content integrity inspection. Reports PASS / WARN / FAIL lines.
## Checks only content that exists today: regions, region scenes, asset
## manifests, asset IDs referenced by code/scenes, and translation keys.
## Never modifies or deletes anything.

var lines: Array[Dictionary] = []
## Entity types whose state is stored (they need an "initial" block).
const STATEFUL: Array[String] = ["door", "shelter_site", "tree", "support_site", "generator", "purifier", "loot", "starter_bag", "container"]


func run() -> Array[Dictionary]:
	lines.clear()
	Content.reload()
	AssetCatalog.reload()
	_check_regions()
	_check_level_templates()
	_check_manifests()
	_check_code_references()
	_check_data()
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
			if str(e.get("type", "")) in STATEFUL and not (e.get("initial") is Dictionary):
				_add("FAIL", "entity %s: missing initial state" % eid)
			_check_portal(rid, e)
			if not rect.has_point(Content.entity_position(e)):
				_add("FAIL", "entity %s: position outside region bounds" % eid)
		_add("PASS", "region %s: %d entities checked" % [rid, def.get("entities", []).size()])


func _check_portal(def_id: String, e: Dictionary) -> void:
	var eid := str(e.get("id", ""))
	var req := str(e.get("requires_open", ""))
	if req != "" and Content.entity_def(def_id, req).is_empty():
		_add("FAIL", "%s: requires_open points to unknown entity %s" % [eid, req])
	if str(e.get("type", "")) == "portal":
		var t: Dictionary = e.get("target", {})
		if t.has("region") and Content.region_def(str(t["region"])).is_empty():
			_add("FAIL", "%s: target region %s does not exist" % [eid, t["region"]])
		if t.has("bunker_of") and Content.entity_def(def_id, str(t["bunker_of"])).get("type", "") != "shelter_site":
			_add("FAIL", "%s: bunker_of must name a shelter_site in the same region" % eid)
		if t.is_empty():
			_add("FAIL", "%s: portal without target" % eid)
	if str(e.get("type", "")) == "shelter_site":
		var tpl := str(e.get("level_template", ""))
		if Content.region_def(Content.level_def_id(tpl)).is_empty():
			_add("FAIL", "%s: unknown level_template %s" % [eid, tpl])


func _check_level_templates() -> void:
	for tid in Content.level_template_ids():
		var def_id := Content.level_def_id(tid)
		var def := Content.region_def(def_id)
		for need in ["ladder_up", "ladder_down"]:
			if Content.entity_def(def_id, need).is_empty():
				_add("FAIL", "level template %s: missing %s (levels must connect)" % [tid, need])
		for e in def.get("entities", []):
			if str(e.get("type", "")) in STATEFUL and not (e.get("initial") is Dictionary):
				_add("FAIL", "level template %s: %s missing initial state" % [tid, e.get("id", "")])
			_check_portal(def_id, e)
		var scene := str(def.get("scene", ""))
		if not ResourceLoader.exists(scene):
			_add("FAIL", "level template %s: scene missing (%s)" % [tid, scene])
			continue
		_check_scene_entities(def_id, scene)
		_add("PASS", "level template %s checked" % tid)


## Every EntityView/DoorView in a scene must point at an entity of its definition.
func _check_scene_entities(def_id: String, scene_path: String) -> void:
	var root := (load(scene_path) as PackedScene).instantiate()
	for n in root.find_children("*", "", true, false):
		var eid := ""
		if n is DoorView:
			eid = (n as DoorView).entity_id
		elif n is EntityView:
			eid = (n as EntityView).entity_id
		else:
			continue
		if Content.entity_def(def_id, eid).is_empty():
			_add("FAIL", "%s: node %s points to unknown entity '%s'" % [scene_path, n.name, eid])
	root.free()


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
	_check_scene_entities(rid, scene_path)


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
	rx.compile("\"((?:char|world|env|prop|sfx|ui|amb|fx|build|item)\\.[a-z0-9_.]+)\"")
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


## Construction, item, recipe and loot data: every referenced item, asset and
## translation key must exist.
func _check_data() -> void:
	var problems := 0
	var keys := {}
	var data = SafeFile.read_json(Localization.PATH)
	for id in Items.ids():
		for k in ["name_key", "desc_key"]:
			keys[str(Items.info(id).get(k, ""))] = "items.json:" + id
	for id in Build.defs():
		var d := Build.def(id)
		keys[str(d.get("name_key", ""))] = "buildables.json:" + id
		keys[str(d.get("desc_key", ""))] = "buildables.json:" + id
		for t in d.get("tiers", []):
			keys[str(t.get("name_key", ""))] = "buildables.json:" + id
			for item in t.get("cost", {}):
				if not Items.exists(item):
					problems += 1
					_add("FAIL", "buildable %s costs unknown item %s" % [id, item])
			if not Items.exists(str(t.get("repair_item", "wood"))):
				problems += 1
				_add("FAIL", "buildable %s repairs with unknown item" % id)
			for ak in ["art", "art_open", "art_worn", "art_growing", "art_ripe", "art_full", "bunker_art"]:
				if t.has(ak) and not AssetCatalog.has(str(t[ak])):
					problems += 1
					_add("FAIL", "buildable %s uses unknown asset %s" % [id, t[ak]])
	for rid in Craft.recipes():
		var r := Craft.recipe(rid)
		for part in ["in", "out"]:
			for item in r.get(part, {}):
				if not Items.exists(item):
					problems += 1
					_add("FAIL", "recipe %s uses unknown item %s" % [rid, item])
	for id in Build.menu():
		if id != "support" and Build.def(id).is_empty():
			problems += 1
			_add("FAIL", "build menu lists unknown definition " + str(id))
	for def_id in Content.region_ids() + Content.level_template_ids().map(func(t): return Content.level_def_id(t)):
		for eid in Content.entity_ids(def_id):
			var e := Content.entity_def(def_id, eid)
			for item in (e.get("loot", {}) as Dictionary).keys() + (e.get("kit", {}) as Dictionary).keys():
				if not Items.exists(item):
					problems += 1
					_add("FAIL", "%s loot has unknown item %s" % [eid, item])
			for g in e.get("gear", []):
				if not Items.exists(str(g)):
					problems += 1
					_add("FAIL", "%s gear has unknown item %s" % [eid, g])
			if ScavengeSim.is_container(e):
				for ak in ["art", "art_searched"]:
					if not AssetCatalog.has(str(e.get(ak, ""))):
						problems += 1
						_add("FAIL", "%s %s asset %s not in any manifest" % [eid, ak, e.get(ak, "")])
				if not (SkillSim.cfg("scavenging").get("base_seconds", {}) as Dictionary).has(str(e.get("kind", ""))):
					problems += 1
					_add("FAIL", "%s has unknown container kind %s" % [eid, e.get("kind", "")])
			for k2 in ["prompt_key"]:
				if e.has(k2):
					keys[str(e[k2])] = def_id + ":" + eid
	if data is Dictionary:
		for k in keys:
			if k != "" and not data.has(k):
				problems += 1
				_add("FAIL", "translation key %s (%s) missing from locale" % [k, keys[k]])
	if problems == 0:
		_add("PASS", "items, buildables and loot reference valid items, assets and text")


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
