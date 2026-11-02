class_name PortalView
extends EntityView
## A way between regions: doorway, hatch ladder, ladder up/down between bunker
## levels. Optional art; hidden and unusable while the portal is disabled
## (e.g. "ladder_down" before a deeper level exists) or while the entity named
## in `requires_open` is closed. The host resolves where it actually leads.

@export var art_asset := ""
## Hide the art when the portal is unusable (a ladder down that does not exist yet).
@export var hide_when_unavailable := true


func _watched_entities() -> Array:
	var req := str(def.get("requires_open", ""))
	return [req] if req != "" else []


func _refresh(_cause: String) -> void:
	var st := state()
	var available := bool(st.get("enabled", true))
	var req := str(def.get("requires_open", ""))
	if available and req != "" and region_state() != null:
		available = bool(region_state().entity_state(req).get("open", false))
	if interact != null:
		interact.enabled = available
	if art_asset != "":
		show_art("Main", art_asset)
		_art_root.visible = available or not hide_when_unavailable
