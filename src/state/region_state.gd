class_name RegionState
extends RefCounted
## Player-made changes to one region, kept apart from the authored initial
## content. Only fields that differ from the content definition are stored,
## plus a revision counter per changed entity.
##
## region_id identifies this region in the world (e.g. "homestead" or
## "bunker:homestead.farmhouse.shelter:-2"); def_id names the content
## definition it was built from (the same id for static regions, or
## "level:<template>" for bunker levels).

var region_id := ""
var def_id := ""
var overrides := {}  # entity_id -> {field: value}
var revs := {}       # entity_id -> int (increments on every authoritative change)
## Excavation state for regions with an "excavation" grid (see Terrain):
## {"dug": {"c,r": true}, "digging": {"c,r": {...}}, "supports": {"c,r": {...}}}
var terrain := {}
## Player-built structures and ground piles: object id -> plain data
## {"def", "tier", "x", "y", "hp", "stage", ...type state}. See Build.
var objects := {}


static func make(id: String, definition_id: String = "") -> RegionState:
	var r := RegionState.new()
	r.region_id = id
	r.def_id = definition_id if definition_id != "" else id
	return r


func definition() -> Dictionary:
	return Content.region_def(def_id)


func entity_def(entity_id: String) -> Dictionary:
	return Content.entity_def(def_id, entity_id)


func has_entity(entity_id: String) -> bool:
	return not entity_def(entity_id).is_empty()


## Current state = authored initial state merged with saved changes.
func entity_state(entity_id: String) -> Dictionary:
	var state: Dictionary = entity_def(entity_id).get("initial", {}).duplicate(true)
	state.merge(overrides.get(entity_id, {}), true)
	return state


func rev(entity_id: String) -> int:
	return int(revs.get(entity_id, 0))


## Authority only. Stores only fields that differ from the initial content.
func set_fields(entity_id: String, fields: Dictionary) -> void:
	var initial: Dictionary = entity_def(entity_id).get("initial", {})
	var o: Dictionary = overrides.get(entity_id, {})
	for k in fields:
		if initial.has(k) and initial[k] == fields[k]:
			o.erase(k)
		else:
			o[k] = fields[k]
	if o.is_empty():
		overrides.erase(entity_id)
	else:
		overrides[entity_id] = o
	revs[entity_id] = rev(entity_id) + 1


## Replica side: accept the host's full state for an entity.
func apply_remote(entity_id: String, state: Dictionary, new_rev: int) -> void:
	var initial: Dictionary = entity_def(entity_id).get("initial", {})
	var o := {}
	for k in state:
		if not (initial.has(k) and initial[k] == state[k]):
			o[k] = state[k]
	if o.is_empty():
		overrides.erase(entity_id)
	else:
		overrides[entity_id] = o
	revs[entity_id] = new_rev


func to_dict() -> Dictionary:
	var ents := {}
	var ids := overrides.keys() + revs.keys()
	for id in ids:
		if not ents.has(id):
			ents[id] = {"state": overrides.get(id, {}), "rev": rev(id)}
	var d := {"entities": ents}
	if def_id != region_id:
		d["def_id"] = def_id
	if not terrain.is_empty():
		d["terrain"] = terrain.duplicate(true)
	if not objects.is_empty():
		d["objects"] = objects.duplicate(true)
	return d


## Unknown entities (content removed since the save) are dropped with a warning.
static func from_dict(id: String, d: Dictionary, warnings: Array) -> RegionState:
	var r := RegionState.make(id, str(d.get("def_id", id)))
	var t = d.get("terrain", {})
	if t is Dictionary:
		for part in ["dug", "digging", "supports"]:
			if t.get(part) is Dictionary and not (t[part] as Dictionary).is_empty():
				r.terrain[part] = (t[part] as Dictionary).duplicate(true)
	var objs = d.get("objects", {})
	if objs is Dictionary:
		for oid in objs:
			var o = objs[oid]
			var problem := Build.validate_object(o)
			if problem != "":
				warnings.append("region %s: object %s dropped (%s)" % [id, oid, problem])
				continue
			r.objects[str(oid)] = (o as Dictionary).duplicate(true)
	var ents: Dictionary = d.get("entities", {})
	for eid in ents:
		if not r.has_entity(eid):
			warnings.append("region %s: entity %s no longer exists in content; change dropped" % [id, eid])
			continue
		var e: Dictionary = ents[eid]
		var st: Dictionary = e.get("state", {})
		if not st.is_empty():
			r.overrides[eid] = st.duplicate(true)
		r.revs[eid] = int(e.get("rev", 0))
	return r
