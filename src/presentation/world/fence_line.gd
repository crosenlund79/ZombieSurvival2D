@tool
class_name FenceLine
extends Node2D
## A straight fence from this node's origin to `end_point` (local), either
## horizontal (east-west) or vertical (north-south). Places repeating fence
## art and one collision strip. Segment art is replaceable via its asset ID.

@export var end_point := Vector2(512, 0):
	set(v):
		end_point = v
		_rebuild()
@export var asset_ids: Array[String] = ["world.fence_h_a", "world.fence_h_a", "world.fence_h_b"]:
	set(v):
		asset_ids = v
		_rebuild()
@export var vertical := false:
	set(v):
		vertical = v
		_rebuild()
@export var thickness := 14.0


func _ready() -> void:
	y_sort_enabled = true
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.has_meta("fence_generated"):
			c.free()
	if asset_ids.is_empty():
		return
	var length := absf(end_point.y if vertical else end_point.x)
	var seg := AssetCatalog.display_size(asset_ids[0])
	var nominal := seg.y * 0.82 if vertical else seg.x
	# Whole number of segments, spread to end exactly at end_point.
	var count := maxi(1, roundi(length / nominal))
	var step := length / count
	var dir := signf(end_point.y if vertical else end_point.x)
	for i in count:
		var p := Prop.new()
		p.set_meta("fence_generated", true)
		p.asset_id = asset_ids[i % asset_ids.size()]
		if vertical:
			p.position = Vector2(0, dir * (i + 1) * step)
		else:
			p.position = Vector2(dir * (i + 0.5) * step, 0)
		add_child(p, false, Node.INTERNAL_MODE_BACK)
	var body := StaticBody2D.new()
	body.set_meta("fence_generated", true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(thickness, length) if vertical else Vector2(length, thickness)
	shape.shape = rect
	shape.position = Vector2(0, end_point.y * 0.5) if vertical else Vector2(end_point.x * 0.5, -thickness * 0.5)
	body.add_child(shape)
	add_child(body, false, Node.INTERNAL_MODE_BACK)
