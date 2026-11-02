class_name TerrainView
extends Node2D
## Presentation of an excavation grid (see Terrain). Draws dug floor, solid
## earth, the visible wall face of solid cells (3/4 view) and inked edges;
## rebuilds collision whenever the host reports a terrain change; places timber
## support posts; and offers the contextual prompt for the cell you face:
## "Dig" when allowed, "Place a timber support here" when the earth is too
## unstable, with a coloured outline (green / amber / red).
## Collision and rules come from the grid data, never from the art.

const FACE_H := 72.0

var region_id := ""
var _body: StaticBody2D
var _posts := {}           # cell key -> Node2D
var _interact: Interactable
var _marker: Node2D
var _target := Vector2i(-1, -1)
var _mode := ""            # "dig" | "support" | ""
var _marker_color := Color.WHITE
var _tex_floor: Texture2D
var _tex_mass: Texture2D
var _tex_face: Texture2D


func _ready() -> void:
	var view := RegionView.find_for(self)
	region_id = view.region_id if view != null else ""
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -9
	_marker = Node2D.new()
	_marker.z_index = 1
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	_interact = Interactable.new()
	_interact.priority = 1  # facing earth wins, unless an object is right at hand (see _object_at_hand)
	_interact.reach = 140.0
	_interact.entity_id = "terrain"
	_interact.on_activate = _activate
	add_child(_interact)
	Session.terrain_changed.connect(func(rid: String) -> void:
		if rid == region_id:
			_rebuild())
	Session.combat_event.connect(_on_event)
	Assets.reloaded.connect(_rebuild)
	_rebuild()


func _region() -> RegionState:
	return Session.world.region(region_id) if Session.world != null else null


func _rebuild() -> void:
	var r := _region()
	if not Terrain.has_terrain(r):
		return
	_tex_floor = Assets.texture("bunker.earth_floor")
	_tex_mass = Assets.texture("bunker.earth_mass")
	_tex_face = Assets.texture("bunker.earth_face")
	_rebuild_collision(r)
	_sync_posts(r)
	queue_redraw()


func _rebuild_collision(r: RegionState) -> void:
	if _body != null:
		_body.queue_free()
	_body = StaticBody2D.new()
	add_child(_body)
	var g := Terrain.grid_size(r)
	var s := Terrain.cell_size(r)
	for y in g.y:
		var run_start := -1
		for x in g.x + 1:
			var c := Vector2i(x, y)
			var edge := x < g.x and not Terrain.is_open(r, c) and _near_open(r, c)
			if edge and run_start < 0:
				run_start = x
			elif not edge and run_start >= 0:
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2((x - run_start) * s, s)
				shape.shape = rect
				shape.position = Terrain.origin(r) + Vector2(run_start * s + rect.size.x * 0.5, y * s + s * 0.5)
				_body.add_child(shape)
				run_start = -1


func _near_open(r: RegionState, c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if Terrain.is_open(r, c + Vector2i(dx, dy)):
				return true
	return false


func _sync_posts(r: RegionState) -> void:
	var view := RegionView.find_for(self)
	var ysort: Node = view.get_node_or_null("YSort") if view != null else null
	if ysort == null:
		return
	var sup: Dictionary = r.terrain.get("supports", {})
	for k in _posts.keys():
		if not sup.has(k):
			(_posts[k] as Node).queue_free()
			_posts.erase(k)
	for k in sup:
		var c := Terrain.parse_key(k)
		if not _posts.has(k):
			var n := Node2D.new()
			n.name = "Support_" + k.replace(",", "_")
			var spr := Sprite2D.new()
			spr.name = "Art"
			n.add_child(spr)
			var rect := Terrain.cell_rect(r, c)
			n.position = Vector2(rect.get_center().x, rect.end.y - 6)
			ysort.add_child(n)
			_posts[k] = n
		var done := str(sup[k].get("stage", "")) == "reinforced"
		Assets.apply_to_sprite((_posts[k] as Node).get_node("Art"), "bunker.support_post" if done else "bunker.support_post_building")


func _draw() -> void:
	var r := _region()
	if not Terrain.has_terrain(r) or _tex_floor == null:
		return
	var g := Terrain.grid_size(r)
	var s := Terrain.cell_size(r)
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			var rect := Terrain.cell_rect(r, c)
			if Terrain.is_open(r, c):
				_tile(_tex_floor, rect, Vector2(256, 256))
			else:
				_tile(_tex_mass, rect, Vector2(256, 256))
	# Visible faces of solid cells that have dug space to the south (3/4 view),
	# drawn upward from the boundary so walls read as having height.
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			if not Terrain.is_open(r, c) and Terrain.is_open(r, c + Vector2i(0, 1)):
				var rect := Terrain.cell_rect(r, c)
				var face := Rect2(Vector2(rect.position.x, rect.end.y - FACE_H), Vector2(s, FACE_H))
				_tile(_tex_face, face, Vector2(256, 96))
				draw_rect(Rect2(face.position, Vector2(s, 8)), Color(0.1, 0.07, 0.05, 0.55))
	# Inked boundary between dug and solid ground.
	var ink := Color(0.12, 0.09, 0.06, 0.9)
	for c in Terrain.open_cells(r):
		var rect := Terrain.cell_rect(r, c)
		var jitter := float((c.x * 73 + c.y * 37) % 7) - 3.0
		if not Terrain.is_open(r, c + Vector2i(0, -1)):
			draw_line(rect.position + Vector2(0, jitter * 0.3), Vector2(rect.end.x, rect.position.y - jitter * 0.3), ink, 3.0)
		if not Terrain.is_open(r, c + Vector2i(0, 1)):
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end + Vector2(0, jitter * 0.3), ink, 3.5)
		if not Terrain.is_open(r, c + Vector2i(-1, 0)):
			draw_line(rect.position, Vector2(rect.position.x + jitter * 0.3, rect.end.y), ink, 3.0)
		if not Terrain.is_open(r, c + Vector2i(1, 0)):
			draw_line(Vector2(rect.end.x, rect.position.y), rect.end + Vector2(jitter * 0.3, 0), ink, 3.0)
	# Cells being dug: cracks + progress bar.
	var dig: Dictionary = r.terrain.get("digging", {})
	for k in dig:
		var rect2 := Terrain.cell_rect(r, Terrain.parse_key(k))
		draw_line(rect2.position + Vector2(12, 14), rect2.get_center(), ink, 2.0)
		draw_line(rect2.get_center(), rect2.end - Vector2(14, 10), ink, 2.0)
		var t := clampf(float(Session.world.tick - int(dig[k]["started"])) / maxf(1.0, float(dig[k]["ticks"])), 0, 1)
		var bar := Rect2(rect2.position + Vector2(6, s * 0.5 - 5), Vector2(s - 12, 10))
		draw_rect(bar.grow(2), Color(0.08, 0.07, 0.05, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("#CFB88D"))


func _tile(tex: Texture2D, rect: Rect2, display: Vector2) -> void:
	# World-anchored texture coordinates so neighbouring cells line up seamlessly.
	var scale := tex.get_size() / display
	draw_texture_rect_region(tex, rect, Rect2(rect.position * scale, rect.size * scale))


func _process(_delta: float) -> void:
	var r := _region()
	if not Terrain.has_terrain(r):
		return
	if not (r.terrain.get("digging", {}) as Dictionary).is_empty():
		queue_redraw()
	_update_target(r)
	_marker.queue_redraw()


func _update_target(r: RegionState) -> void:
	var view := RegionView.find_for(self)
	var a: PlayerAvatar = view.local_avatar if view != null else null
	_mode = ""
	_target = Vector2i(-1, -1)
	_interact.enabled = false
	if a == null or PlayerAvatar.input_blocked:
		return
	var dir: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][clampi(a.facing, 0, 3)]
	var here := Terrain.cell_of(r, a.global_position + Vector2(0, -8))
	var t := Terrain.cell_of(r, a.global_position + Vector2(0, -8) + dir * 48.0)
	if t == here:
		t = here + Vector2i(roundi(dir.x), roundi(dir.y))
	if Terrain.is_open(r, t) or not Terrain.in_grid(r, t):
		return
	if _object_at_hand(a):
		return
	_target = t
	var problem := Terrain.dig_problem(r, t)
	var b := Session.world.bunker_for_region(region_id)
	var cost := int(Terrain.cfg(r).get("support_wood", 4))
	if problem == "":
		_mode = "dig"
		_marker_color = Color(0.55, 0.9, 0.45)
		_interact.prompt_key = "PROMPT_DIG"
		_interact.prompt_args = [Terrain.cfg(r).get("dig_seconds", 2.0)]
		_interact.enabled = true
	elif problem == "ACTION_DIG_UNSUPPORTED":
		_marker_color = Color(1.0, 0.7, 0.25)
		if Terrain.support_problem(r, here) == "":
			_mode = "support"
			_interact.prompt_key = "PROMPT_PLACE_SUPPORT"
			_interact.prompt_args = [cost, b.amount("wood") if b != null else 0]
		else:
			_mode = "dig"  # host explains why
			_interact.prompt_key = "PROMPT_DIG_UNSTABLE"
			_interact.prompt_args = []
		_interact.enabled = true
	else:
		_marker_color = Color(0.9, 0.35, 0.3)
	_interact.global_position = Terrain.cell_center(r, t)


## Another usable object (ladder, pile, support spot…) close by takes precedence.
func _object_at_hand(a: PlayerAvatar) -> bool:
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or it == _interact or not it.enabled or not it.is_visible_in_tree():
			continue
		if a.global_position.distance_to(it.global_position) <= minf(it.reach, 70.0):
			return true
	return false


func _activate() -> void:
	var r := _region()
	if r == null or _mode == "":
		return
	var view := RegionView.find_for(self)
	if _mode == "support":
		Session.request_terrain("support", Terrain.cell_of(r, view.local_avatar.global_position + Vector2(0, -8)))
	else:
		Session.request_terrain("dig", _target)


func _draw_marker() -> void:
	var r := _region()
	if r == null or _target.x < 0:
		return
	var rect := Terrain.cell_rect(r, _target).grow(-3)
	_marker.draw_rect(rect, Color(_marker_color, 0.18))
	_marker.draw_rect(rect, _marker_color, false, 3.0)
	if _mode == "support":
		var view := RegionView.find_for(self)
		var here := Terrain.cell_of(r, view.local_avatar.global_position + Vector2(0, -8))
		var reach := float(Terrain.cfg(r).get("support_radius_cells", 3.2)) * Terrain.cell_size(r)
		_marker.draw_arc(Terrain.cell_center(r, here), reach, 0, TAU, 48, Color(1.0, 0.8, 0.4, 0.5), 2.0)


func _on_event(ev: Dictionary) -> void:
	if str(ev.get("region_id", "")) != region_id:
		return
	var r := _region()
	if r == null:
		return
	var pos := Terrain.cell_center(r, Terrain.parse_key(str(ev.get("cell", "0,0"))))
	match str(ev.get("kind", "")):
		"dig_started":
			Audio.play("sfx.dig_earth", pos)
		"dug":
			Audio.play("sfx.wood_drop", pos)
		"support_started":
			Audio.play("sfx.build_hammer", pos)
		"support_done":
			Audio.play("sfx.build_done", pos)
