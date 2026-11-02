class_name ProgressMarker
extends Node2D
## Small inked progress bar shown above something being built.
## Reads progress from a callable each frame; presentation only.

var source: Callable
var width := 90.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not source.is_valid():
		return
	var p: float = source.call()
	var r := Rect2(-width / 2, -7, width, 14)
	draw_rect(r.grow(3), Color(0.08, 0.07, 0.05, 0.85))
	draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color("#CFB88D"))
	draw_rect(r, Color(0.15, 0.12, 0.09), false, 2.0)
