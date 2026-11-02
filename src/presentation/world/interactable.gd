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
## False while the object cannot be used (e.g. a hatch under construction).
var enabled := true
var prompt_args: Array = []
## Optional custom action (e.g. terrain digging); default requests the entity interaction.
var on_activate: Callable


## def_id: the content definition of the region (see RegionView.def_id).
func setup(def_id: String, id: String) -> void:
	entity_id = id
	var def := Content.entity_def(def_id, id)
	if not def.is_empty():
		reach = float(def.get("interact_range", reach))
		priority = int(def.get("priority", priority))


func _ready() -> void:
	add_to_group("interactable")


func prompt_text() -> String:
	var key_names := []
	for code in Settings.action_keys("interact"):
		key_names.append(Settings.key_label(code))
	return "[%s] %s" % [" / ".join(key_names), UITheme.fmt(prompt_key, prompt_args)]


func activate() -> void:
	if on_activate.is_valid():
		on_activate.call()
	else:
		Session.request_interact(entity_id)


func set_focused(value: bool) -> void:
	if focused != value:
		focused = value
		focus_changed.emit(value)
