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
	var pk := prompt_key
	var pa := prompt_args
	if _locked_region() != "":
		pk = "PROMPT_LOCKED"
		pa = [LockSim.level(Session.world.region(_locked_region()).entity_def(entity_id))]
	var text := "[%s] %s" % [" / ".join(key_names), UITheme.fmt(pk, pa)]
	if on_repair.is_valid() and secondary_key != "":
		var rk := []
		for code in Settings.action_keys("repair"):
			rk.append(Settings.key_label(code))
		text += "    [%s] %s" % [" / ".join(rk), UITheme.fmt(secondary_key, secondary_args)]
	return text


func activate() -> void:
	# Iteration 015 D: anything locked (door, portal, container) opens the lock panel first.
	var rs := _locked_region()
	if rs != "":
		LockpickPanel.open(get_parent() as Node2D if get_parent() is Node2D else self, rs, entity_id)
		return
	if on_activate.is_valid():
		on_activate.call()
	else:
		Session.request_interact(entity_id)


## The local player's region id when this entity is locked there, else "".
func _locked_region() -> String:
	var me := Session.local_player()
	if me == null or Session.world == null or entity_id == "":
		return ""
	var r := Session.world.region(me.region_id)
	if r == null or not r.has_entity(entity_id) or not LockSim.is_locked(r, entity_id):
		return ""
	return me.region_id


func set_focused(value: bool) -> void:
	if focused != value:
		focused = value
		_highlight(value)
		focus_changed.emit(value)


const HIGHLIGHT_SHADER := preload("res://src/presentation/world/highlight.gdshader")
static var _highlight_material: ShaderMaterial
var _lit: Array[Sprite2D] = []


## Iteration 011 D: the focused target's own art gets a soft warm rim (sprites
## that already use another material, e.g. swaying plants, are left alone; the
## prompt still shows). Presentation only.
func _highlight(on: bool) -> void:
	for sp in _lit:
		if is_instance_valid(sp) and sp.material == _highlight_material:
			sp.material = null
	_lit.clear()
	if not on or not bool(Settings.get_value("display", "highlight_interactables", true)):
		return
	if _highlight_material == null:
		_highlight_material = ShaderMaterial.new()
		_highlight_material.shader = HIGHLIGHT_SHADER
	var owner_node := get_parent()
	if owner_node == null:
		return
	var nodes: Array = owner_node.get_children()
	var art := owner_node.get_node_or_null("Art")  # EntityView keeps its sprites under "Art"
	if art != null:
		nodes.append_array(art.get_children())
	for child in nodes:
		var sp := child as Sprite2D
		if sp != null and sp.visible and sp.texture != null and sp.material == null:
			sp.material = _highlight_material
			_lit.append(sp)


func _exit_tree() -> void:
	_highlight(false)
