class_name Interactable
extends Node2D
## A focusable interaction point. Its position and range come from the
## entity's content definition, so the authority and the view agree.
## Activating only *requests* the action; the host decides the outcome.

signal focus_changed(focused: bool)

@export var entity_id := ""
@export var prompt_key := "PROMPT_USE"
@export var priority := 0
var reach := 90.0
var focused := false


func setup(region_id: String, id: String) -> void:
	entity_id = id
	var def := Content.entity_def(region_id, id)
	if not def.is_empty():
		reach = float(def.get("interact_range", reach))


func _ready() -> void:
	add_to_group("interactable")


func prompt_text() -> String:
	var key_names := []
	for code in Settings.action_keys("interact"):
		key_names.append(Settings.key_label(code))
	return "[%s] %s" % [" / ".join(key_names), tr(prompt_key)]


func activate() -> void:
	Session.request_interact(entity_id)


func set_focused(value: bool) -> void:
	if focused != value:
		focused = value
		focus_changed.emit(value)
