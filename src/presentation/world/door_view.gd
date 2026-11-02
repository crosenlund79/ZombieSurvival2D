class_name DoorView
extends Node2D
## Presentation of a "door" entity (also used for gates). Position, open state
## and reach all come from world data; this node only displays them, blocks
## movement while closed, and requests toggles through its Interactable.
## Art swaps never change the blocker: its size is set here, not by the image.

@export var entity_id := ""
@export var closed_asset := "world.door_closed"
@export var open_asset := "world.door_open"
@export var blocker_size := Vector2(80, 16)
@export var prompt_open_key := "PROMPT_OPEN_GATE"
@export var prompt_close_key := "PROMPT_CLOSE_GATE"

var region_id := ""
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _interact: Interactable
var _open := false


func _ready() -> void:
	var view := _region_view()
	region_id = view.region_id if view != null else Content.DEFAULT_REGION
	var def := Content.entity_def(region_id, entity_id)
	if def.is_empty():
		SessionLog.error("world", "door_view_without_entity", {"entity": entity_id, "region": region_id})
		return
	position = Content.entity_position(def)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var body := StaticBody2D.new()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = blocker_size
	_shape.shape = rect
	_shape.position = Vector2(0, -blocker_size.y * 0.5)
	body.add_child(_shape)
	add_child(body)
	_interact = Interactable.new()
	_interact.setup(region_id, entity_id)
	_interact.focus_changed.connect(func(f: bool) -> void:
		_sprite.modulate = Color(1.3, 1.22, 1.0) if f else Color.WHITE)
	add_child(_interact)
	Session.entity_changed.connect(_on_entity_changed)
	Assets.reloaded.connect(_refresh)
	_refresh()


func _region_view() -> RegionView:
	var n := get_parent()
	while n != null and not (n is RegionView):
		n = n.get_parent()
	return n as RegionView


func _refresh() -> void:
	if Session.world == null:
		return
	var region := Session.world.region(region_id)
	if region == null:
		return
	_open = bool(region.entity_state(entity_id).get("open", false))
	Assets.apply_to_sprite(_sprite, open_asset if _open else closed_asset)
	_shape.set_deferred("disabled", _open)
	_interact.prompt_key = prompt_close_key if _open else prompt_open_key


func _on_entity_changed(rid: String, eid: String, _state: Dictionary, cause: String) -> void:
	if rid != region_id or eid != entity_id:
		return
	_refresh()
	if cause == "action":
		Audio.play("sfx.door_open" if _open else "sfx.door_close", global_position)


func is_open() -> bool:
	return _open
