@tool
class_name Prop
extends Node2D
## A standing world object (building, tree, vehicle, fence piece, clutter).
## Art comes from an asset ID (replaceable by the creator); collision comes
## from `footprint`, so swapping art never changes where you can walk.
## Origin = where the object touches the ground (used for depth sorting).
##
## occlude: fade when the local player walks behind it.
## sway:    gentle wind motion for vegetation (shader, presentation only).

const SWAY_SHADER := preload("res://src/presentation/world/sway.gdshader")
const OCCLUDED_ALPHA := 0.42

@export var asset_id := "":
	set(v):
		asset_id = v
		_refresh_art()
@export var flip_h := false:
	set(v):
		flip_h = v
		_refresh_art()
## Collision rectangle size at the base (zero = no collision).
@export var footprint := Vector2.ZERO:
	set(v):
		footprint = v
		_rebuild_body()
@export var footprint_offset := Vector2.ZERO:
	set(v):
		footprint_offset = v
		_rebuild_body()
@export var occlude := false
## false = the footprint blocks players but not the Burnt Ones' navigation grid
## (decorative dressing such as the seeded forest pines, so it never walls off
## authored entry points or routes).
@export var nav_block := true
@export var sway := false:
	set(v):
		sway = v
		_refresh_art()

var _sprite: Sprite2D
var _body: StaticBody2D
var _fade := 1.0
static var _sway_material: ShaderMaterial


func _ready() -> void:
	_refresh_art()
	_rebuild_body()
	# iteration 015: buildings, cabins, rocks and wrecks block the player's line of sight (PlayerSight)
	if nav_block and footprint.x >= 60.0 and not Engine.is_editor_hint():
		add_to_group("sight_occluder")
	if not Engine.is_editor_hint():
		Assets.reloaded.connect(_refresh_art)
	set_process(occlude and not Engine.is_editor_hint())


func _refresh_art() -> void:
	if not is_inside_tree() or asset_id == "":
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Art"
		add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		_apply_editor_preview()
	else:
		Assets.apply_to_sprite(_sprite, asset_id)
	_sprite.flip_h = flip_h
	if sway:
		if _sway_material == null:
			_sway_material = ShaderMaterial.new()
			_sway_material.shader = SWAY_SHADER
		_sprite.material = _sway_material
	else:
		_sprite.material = null


## Editor preview without autoloads: template art at its display size.
func _apply_editor_preview() -> void:
	var path := AssetCatalog.template_path(asset_id)
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	_sprite.texture = tex
	_sprite.centered = false
	var box := AssetCatalog.display_size(asset_id)
	var s := minf(box.x / tex.get_size().x, box.y / tex.get_size().y)
	_sprite.scale = Vector2(s, s)
	var piv := AssetCatalog.pivot(asset_id)
	var drawn := tex.get_size() * s
	_sprite.position = -Vector2(box.x * piv.x, box.y * piv.y) + Vector2((box.x - drawn.x) * 0.5, box.y - drawn.y)


func _rebuild_body() -> void:
	if not is_inside_tree():
		return
	if _body != null:
		_body.queue_free()
		_body = null
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		return
	_body = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = footprint
	shape.shape = rect
	shape.position = footprint_offset + Vector2(0, -footprint.y * 0.5)
	_body.add_child(shape)
	add_child(_body, false, Node.INTERNAL_MODE_BACK)


## Visible rectangle of the art in local coordinates.
func art_rect() -> Rect2:
	var box := AssetCatalog.display_size(asset_id)
	var piv := AssetCatalog.pivot(asset_id)
	return Rect2(-Vector2(box.x * piv.x, box.y * piv.y), box)


## Current occlusion alpha (1 = fully visible). Other views can follow it.
func current_alpha() -> float:
	return _fade


func _process(delta: float) -> void:
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var target := 1.0
	if avatar != null and _sprite != null:
		var local := to_local(avatar.global_position)
		# Behind = player stands above (smaller y than) our base and overlaps the art.
		var r := art_rect().grow_individual(-8, 0, -8, 0)
		if local.y < -4.0 and r.has_point(local + Vector2(0, -30)):
			target = OCCLUDED_ALPHA
	_fade = move_toward(_fade, target, delta * 3.0)
	_sprite.modulate.a = _fade
