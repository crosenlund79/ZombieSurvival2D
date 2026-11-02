class_name RegionState
extends RefCounted
## Player-made changes to one region, kept apart from the authored initial
## content. Only fields that differ from the content definition are stored,
## plus a revision counter per changed entity.

var region_id := ""
var overrides := {}  # entity_id -> {field: value}
var revs := {}       # entity_id -> int (increments on every authoritative change)


func has_entity(entity_id: String) -> bool:
	return not Content.entity_def(region_id, entity_id).is_empty()


## Current state = authored initial state merged with saved changes.
func entity_state(entity_id: String) -> Dictionary:
	var def := Content.entity_def(region_id, entity_id)
	var state: Dictionary = def.get("initial", {}).duplicate(true)
	state.merge(overrides.get(entity_id, {}), true)
	return state


func rev(entity_id: String) -> int:
	return int(revs.get(entity_id, 0))


## Authority only. Stores only fields that differ from the initial content.
func set_fields(entity_id: String, fields: Dictionary) -> void:
	var initial: Dictionary = Content.entity_def(region_id, entity_id).get("initial", {})
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
	var initial: Dictionary = Content.entity_def(region_id, entity_id).get("initial", {})
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
	return {"entities": ents}


## Unknown entities (content removed since the save) are dropped with a warning.
static func from_dict(id: String, d: Dictionary, warnings: Array) -> RegionState:
	var r := RegionState.new()
	r.region_id = id
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
