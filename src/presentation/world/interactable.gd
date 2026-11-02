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
## Optional second action on the repair key (repair a damaged structure, upgrade a hatch).
var on_repair: Callable
## Translation key describing on_repair in the prompt ("" = not offered right now).
var secondary_key := ""
var secondary_args: Array = []


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
	var text := "[%s] %s" % [" / ".join(key_names), UITheme.fmt(prompt_key, prompt_args)]
	if on_repair.is_valid() and secondary_key != "":
		var rk := []
		for code in Settings.action_keys("repair"):
			rk.append(Settings.key_label(code))
		text += "    [%s] %s" % [" / ".join(rk), UITheme.fmt(secondary_key, secondary_args)]
	return text


func activate() -> void:
	if on_activate.is_valid():
		on_activate.call()
	else:
		Session.request_interact(entity_id)


func set_focused(value: bool) -> void:
	if focused != value:
		focused = value
		focus_changed.emit(value)
