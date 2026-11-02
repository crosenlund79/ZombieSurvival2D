@tool
class_name PlaceholderBlock
extends StaticBody2D
## Phase A geometric placeholder: a solid rectangle with matching collision.
## Origin = top-left corner.

@export var size := Vector2(100, 100):
	set(v):
		size = v
		_rebuild()
@export var color := Color(0.32, 0.31, 0.28):
	set(v):
		color = v
		queue_redraw()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = get_node_or_null("Shape")
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "Shape"
		add_child(shape_node)
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.09), false, 3.0)
