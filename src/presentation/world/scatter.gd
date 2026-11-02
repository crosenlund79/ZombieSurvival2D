@tool
class_name Scatter
extends Node2D
## Decorative dressing (grass tufts, flowers, small shrubs) scattered inside
## `area` with a fixed seed, so every player and every run sees the same
## layout. Skips `avoid` rectangles (roads, yard, buildings). No collision.
## Change `seed` or `count` in the inspector to re-roll.

@export var area := Rect2(0, 0, 512, 512):
	set(v):
		area = v
		_rebuild()
@export var avoid: Array[Rect2] = []:
	set(v):
		avoid = v
		_rebuild()
@export var asset_ids: Array[String] = ["env.grass_a", "env.grass_b"]:
	set(v):
		asset_ids = v
		_rebuild()
@export var count := 40:
	set(v):
		count = v
		_rebuild()
@export var layout_seed := 1:
	set(v):
		layout_seed = v
		_rebuild()
@export var sway := true
@export var min_spacing := 40.0


func _ready() -> void:
	y_sort_enabled = true
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or asset_ids.is_empty():
		return
	for c in get_children(true):
		if c.has_meta("scatter_generated"):
			c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < count and tries < count * 20:
		tries += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var blocked := false
		for r in avoid:
			if r.has_point(p):
				blocked = true
				break
		if not blocked:
			for q in placed:
				if q.distance_to(p) < min_spacing:
					blocked = true
					break
		if blocked:
			continue
		placed.append(p)
		var prop := Prop.new()
		prop.set_meta("scatter_generated", true)
		prop.asset_id = asset_ids[rng.randi() % asset_ids.size()]
		prop.flip_h = rng.randf() < 0.5
		prop.sway = sway
		prop.position = p
		add_child(prop, false, Node.INTERNAL_MODE_BACK)
