@tool
class_name PlaceholderGround
extends Node2D
## Phase A placeholder ground: flat colour with a 100 px grid so movement and
## scale are easy to read.

@export var size := Vector2(1600, 1100):
	set(v):
		size = v
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.40, 0.25))
	var grid := Color(0, 0, 0, 0.12)
	for x in range(0, int(size.x) + 1, 100):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 2.0)
	for y in range(0, int(size.y) + 1, 100):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid, 2.0)
