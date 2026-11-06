class_name SideTerrain
extends Node2D
## The cross-section of one bunker level (iteration 012, experimental side view).
## Draws the earth strata, bedrock, the dug rooms with their back wall, timber
## floorboards and ceiling beams (concrete slabs in concrete levels), the shaft
## up to the hatch, digging in progress, and the timber supports as
## scaffolding. Offers the side-view dig / support prompt for the cell you face
## (left/right at your feet or head, the ceiling with W, the floor with S).
## Same grid data, same host requests as the top-down TerrainView.

var region_id := ""
var _interact: Interactable
var _target := Vector2i(-1, -1)
var _mode := ""
var _marker := Node2D.new()
var _marker_color := Color.WHITE
var _posts := {}
var _tex := {}


func _ready() -> void:
	var view := RegionView.find_for(self)
	region_id = view.region_id if view != null else ""
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -9
	_marker.z_index = 12
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	_interact = Interactable.new()
	_interact.priority = 1
	_interact.reach = 150.0
	_interact.entity_id = "terrain"
	_interact.on_activate = _activate
	add_child(_interact)
	Session.terrain_changed.connect(func(rid: String) -> void:
		if rid == region_id:
			_rebuild())
	Assets.reloaded.connect(_rebuild)
	_rebuild()


func _region() -> RegionState:
	return Session.world.region(region_id) if Session.world != null else null


func _rebuild() -> void:
	_tex.clear()
	_sync_posts()
	queue_redraw()


func _s(p: Vector2) -> Vector2:
	return SideSection.to_screen(_region(), p)


func _srect(r: Rect2) -> Rect2:
	return SideSection.screen_rect(_region(), r)


func _tex_of(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = Assets.texture(id) if AssetCatalog.has(id) else null
	return _tex[id]


func _tile(id: String, rect: Rect2) -> void:
	var tex: Texture2D = _tex_of(id)
	if tex == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_texture_rect_region(tex, rect, Rect2(rect.position, rect.size))


func _strip(id: String, x0: float, x1: float, y: float, h: float) -> void:
	var tex: Texture2D = _tex_of(id)
	if tex == null:
		return
	draw_texture_rect_region(tex, Rect2(x0, y, x1 - x0, h), Rect2(x0, 0, x1 - x0, tex.get_size().y))


func _draw() -> void:
	var r := _region()
	if r == null:
		return
	if str(r.definition().get("style", "")) == "building":
		_draw_building(r)
		return
	var b := _srect(SideSection.bounds(r)).grow(400.0)
	_tile("side.earth", b)
	var ink := Color(0.1, 0.07, 0.05, 0.92)
	var mine := str(r.definition().get("style", "")) == "mine"
	if not SideSection.has_grid(r):
		_draw_room(r, ink)
		_draw_shaft(r)
		_draw_signs(r)
		return
	var g := Terrain.grid_size(r)
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			var rect := _srect(Terrain.cell_rect(r, c))
			if Terrain.is_open(r, c):
				_tile("side.wall_mine" if mine else "side.backwall", rect)
			elif Terrain.is_permanent(r, c) and x > 0 and y > 0 and x < g.x - 1 and y < g.y - 1:
				_tile("side.rock", rect)
	_draw_shaft(r)
	# floors (boards on the earth below open air), ceilings (beams under earth above), side walls
	for c in Terrain.open_cells(r):
		var rect := _srect(Terrain.cell_rect(r, c))
		if not Terrain.is_open(r, c + Vector2i(0, 1)):
			_strip("side.rail" if mine else "side.floorboards", rect.position.x, rect.end.x, rect.end.y - (14.0 if mine else 4.0), 16.0)
		if not Terrain.is_open(r, c + Vector2i(0, -1)):
			_strip("side.beam", rect.position.x, rect.end.x, rect.position.y, 12.0)
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), ink, 2.5)
		for side in [-1, 1]:
			if not Terrain.is_open(r, c + Vector2i(side, 0)):
				var x := rect.position.x if side < 0 else rect.end.x
				draw_rect(Rect2(x - (10.0 if side > 0 else 0.0), rect.position.y, 10.0, rect.size.y), Color(0, 0, 0, 0.28))
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ink, 3.0)
	_draw_signs(r)
	# digging in progress: cracks and a progress bar
	var dig: Dictionary = r.terrain.get("digging", {})
	for k in dig:
		var rect2 := _srect(Terrain.cell_rect(r, Terrain.parse_key(k)))
		draw_line(rect2.position + Vector2(10, 6), rect2.get_center(), ink, 2.0)
		draw_line(rect2.get_center(), rect2.end - Vector2(12, 6), ink, 2.0)
		var t := clampf(float(Session.world.tick - int(dig[k]["started"])) / maxf(1.0, float(dig[k]["ticks"])), 0, 1)
		var bar := Rect2(rect2.position + Vector2(6, rect2.size.y * 0.5 - 4), Vector2(rect2.size.x - 12, 8))
		draw_rect(bar.grow(2), Color(0.08, 0.07, 0.05, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("#CFB88D"))


## A level without a grid: one concrete room with slab floor and ceiling.
func _draw_room(r: RegionState, ink: Color) -> void:
	var room := _srect(SideSection.room_rect(r))
	_tile("side.concrete_wall", room)
	_strip("side.concrete_slab", room.position.x - 30.0, room.end.x + 30.0, room.end.y - 4.0, 26.0)
	_strip("side.concrete_slab", room.position.x - 30.0, room.end.x + 30.0, room.position.y - 22.0, 22.0)
	for x in [room.position.x, room.end.x]:
		draw_rect(Rect2(x - 14.0, room.position.y - 22.0, 28.0, room.size.y + 48.0), Color(0.42, 0.41, 0.38))
		draw_line(Vector2(x - 14.0, room.position.y - 22.0), Vector2(x - 14.0, room.end.y + 22.0), ink, 2.0)
		draw_line(Vector2(x + 14.0, room.position.y - 22.0), Vector2(x + 14.0, room.end.y + 22.0), ink, 2.0)
	draw_rect(room, ink, false, 3.0)


## The shaft above the way up: a dark slot through the earth with daylight at its top.
func _draw_shaft(r: RegionState) -> void:
	for eid in Content.entity_ids(r.def_id):
		if not eid.ends_with("ladder_up"):
			continue
		var p := Content.entity_position(r.entity_def(eid))
		var ceil_y := _s(SideSection.hang(r, p)).y
		var top := _srect(SideSection.bounds(r)).position.y - 300.0
		var w := 70.0
		var shaft := Rect2(p.x - w * 0.5, top, w, ceil_y - top + 4.0)
		draw_rect(shaft, Color(0.07, 0.06, 0.05))
		draw_rect(Rect2(shaft.position.x - 6.0, top, 6.0, shaft.size.y), Color(0.24, 0.22, 0.2))
		draw_rect(Rect2(shaft.end.x, top, 6.0, shaft.size.y), Color(0.24, 0.22, 0.2))
		for k in 6:  # faint daylight falling down the shaft
			var a := 0.10 * (1.0 - float(k) / 6.0)
			draw_rect(Rect2(shaft.position.x + 4.0, ceil_y - 40.0 - k * 40.0, w - 8.0, 40.0), Color(0.9, 0.9, 0.85, a))


## Quiet chalk-and-paint signage on the earth: where the shaft and the floor
## hatch lead, so the stack of levels reads at a glance (no HUD).
func _draw_signs(r: RegionState) -> void:
	var font := ThemeDB.fallback_font
	var parsed := BunkerState.parse_region_id(region_id)
	if parsed.is_empty():
		return
	var depth: int = parsed["depth"]
	var b := Session.world.bunker(parsed["bunker_id"])
	for eid in Content.entity_ids(r.def_id):
		var d := r.entity_def(eid)
		var p := Content.entity_position(d)
		var text := ""
		var at := Vector2.ZERO
		if eid.ends_with("ladder_up"):
			var up_name := ""
			if depth == -1 and b != null:
				var ent := Session.world.region(b.entrance_region)
				up_name = TranslationServer.translate(str(ent.definition().get("display_key", ""))) if ent != null else ""
			text = "↑ " + (up_name if up_name != "" else UITheme.fmt("SIDE_LEVEL", [depth + 1]))
			at = _s(SideSection.hang(r, p)) + Vector2(44, -26)
		elif eid.ends_with("ladder_down") and bool(r.entity_state(eid).get("enabled", true)) and b != null and b.has_level(depth - 1):
			text = "↓ " + UITheme.fmt("SIDE_LEVEL", [depth - 1])
			at = _s(SideSection.rest(r, p)) + Vector2(70, 40)
		if text != "":
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.08, 0.06, 0.04, 0.85))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.86, 0.8, 0.66, 0.85))


## Timber supports placed by players: scaffolding from floor to ceiling.
func _sync_posts() -> void:
	var r := _region()
	if r == null or not SideSection.has_grid(r):
		return
	var sup: Dictionary = r.terrain.get("supports", {})
	for k in _posts.keys():
		if not sup.has(k):
			(_posts[k] as Node).queue_free()
			_posts.erase(k)
	for k in sup:
		var c := Terrain.parse_key(k)
		var center := Terrain.cell_center(r, c)
		if not _posts.has(k):
			var spr := Sprite2D.new()
			spr.z_index = 3
			add_child(spr)
			_posts[k] = spr
		var done := str(sup[k].get("stage", "")) == "reinforced"
		var sp: Sprite2D = _posts[k]
		Assets.apply_to_sprite(sp, "side.scaffold_done" if done else "side.scaffold_building")
		var h := SideArt.open_height(r, center)
		var kk := h / maxf(1.0, sp.texture.get_size().y * sp.scale.y)
		sp.scale.y *= kk
		sp.position = Vector2(sp.position.x, sp.position.y * kk) + SideArt.rest_screen(r, center)


func _process(_delta: float) -> void:
	var r := _region()
	if r == null:
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
	if a == null or PlayerAvatar.input_blocked or not SideSection.has_grid(r) or bool(Terrain.cfg(r).get("fixed", false)):
		return
	var plan := SideSection.to_plan(r, a.global_position)
	var feet := Terrain.cell_of(r, plan + Vector2(0, -4))
	var head := feet + Vector2i(0, -1)
	var cands: Array = []
	if Input.is_action_pressed("move_up") and not SideSection.climbable(Session.world, r, plan):
		var run := SideSection.run_of(r, feet.x, feet.y)
		cands = [Vector2i(feet.x, run.x - 1)]
	elif Input.is_action_pressed("move_down") and not SideSection.climbable(Session.world, r, plan):
		cands = [feet + Vector2i(0, 1)]
	else:
		var dx := -1 if a.facing == 2 else 1
		cands = [feet + Vector2i(dx, 0), head + Vector2i(dx, 0)]
	var t := Vector2i(-1, -1)
	for cc in cands:
		if Terrain.in_grid(r, cc) and not Terrain.is_open(r, cc):
			t = cc
			break
	if t.x < 0 or _object_at_hand(a):
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
		if Terrain.support_problem(r, feet) == "":
			_mode = "support"
			_interact.prompt_key = "PROMPT_PLACE_SUPPORT"
			_interact.prompt_args = [cost, b.amount("wood") if b != null else 0]
		else:
			_mode = "dig"
			_interact.prompt_key = "PROMPT_DIG_UNSTABLE"
			_interact.prompt_args = []
		_interact.enabled = true
	else:
		_marker_color = Color(0.9, 0.35, 0.3)
	_interact.global_position = a.global_position + Vector2(0, -20)


func _object_at_hand(a: PlayerAvatar) -> bool:
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or it == _interact or not it.enabled or not it.is_visible_in_tree():
			continue
		if absf(a.global_position.x - it.global_position.x) <= minf(it.reach, 60.0) and absf(a.global_position.y - it.global_position.y) < 160.0:
			return true
	return false


func _activate() -> void:
	var r := _region()
	if r == null or _mode == "":
		return
	var view := RegionView.find_for(self)
	var plan := SideSection.to_plan(r, view.local_avatar.global_position)
	if _mode == "support":
		Session.request_terrain("support", Terrain.cell_of(r, plan + Vector2(0, -4)))
	else:
		Session.request_terrain("dig", _target)


func _draw_marker() -> void:
	var r := _region()
	if r == null or _target.x < 0:
		return
	var rect := _srect(Terrain.cell_rect(r, _target)).grow(-3)
	_marker.draw_rect(rect, Color(_marker_color, 0.2))
	_marker.draw_rect(rect, _marker_color, false, 3.0)



# ------------------------------------------------------------------ iteration 014: buildings in section

## A building interior (region "style": "building"): sky and snow outside, the
## earth below the ground line, the walls and slabs of the building in section,
## each room's wall covering, floors and ceilings, windows and room dividers.
func _draw_building(r: RegionState) -> void:
	var sec: Dictionary = r.definition().get("section", {})
	var ink := Color(0.1, 0.07, 0.05, 0.92)
	var b := _srect(SideSection.bounds(r)).grow(500.0)
	var ground_y := _s(Terrain.cell_rect(r, Vector2i(0, int(sec.get("ground_row", 0)))).position).y
	var dl := EnvSim.daylight(Session.world) if Session.world != null else 1.0
	var sky := Color(0.07, 0.08, 0.11).lerp(Color(0.42, 0.46, 0.52), dl)
	draw_rect(Rect2(b.position, Vector2(b.size.x, ground_y - b.position.y)), sky)
	_tile("side.earth", Rect2(b.position.x, ground_y, b.size.x, b.end.y - ground_y))
	draw_rect(Rect2(b.position.x, ground_y - 10.0, b.size.x, 14.0), Color(0.86, 0.88, 0.9))  # snow on the ground
	var env: Array = sec.get("envelope", [])
	var ext := str(sec.get("exterior", "side.ext_siding"))
	var g := Terrain.grid_size(r)
	for y in g.y:
		for x in g.x:
			var c := Vector2i(x, y)
			var rect := _srect(Terrain.cell_rect(r, c))
			if Terrain.is_open(r, c):
				_tile(_room_of(sec, c, "wall", "side.wall_house"), rect)
			elif env.size() == 4 and x >= int(env[0]) and y >= int(env[1]) and x < int(env[0]) + int(env[2]) and y < int(env[1]) + int(env[3]):
				_tile(ext if y < int(sec.get("ground_row", 0)) or str(sec.get("basement", "")) == "" else str(sec.get("basement")), rect)
	for c in Terrain.open_cells(r):
		var rect := _srect(Terrain.cell_rect(r, c))
		var below: Vector2i = c + Vector2i(0, 1)
		if not Terrain.is_open(r, below) or Terrain.is_platform(r, c):
			_strip(_room_of(sec, c, "floor", "side.floorboards"), rect.position.x, rect.end.x, rect.end.y - 4.0, 16.0)
		if not Terrain.is_open(r, c + Vector2i(0, -1)):
			_strip("side.ceiling", rect.position.x, rect.end.x, rect.position.y, 10.0)
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), ink, 2.5)
		for side in [-1, 1]:
			if not Terrain.is_open(r, c + Vector2i(side, 0)):
				var x := rect.position.x if side < 0 else rect.end.x
				draw_rect(Rect2(x - (10.0 if side > 0 else 0.0), rect.position.y, 10.0, rect.size.y), Color(0, 0, 0, 0.3))
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ink, 3.0)
	# interior dividers: a wall from the ceiling down to the top of a doorway
	for dv in sec.get("dividers", []):
		var top := _s(Vector2(float(dv[0]), float(dv[1])))
		var door_top := _s(Vector2(float(dv[0]), float(dv[2]))).y
		var wall := Rect2(top.x - 7.0, top.y, 14.0, door_top - top.y)
		draw_rect(wall, Color(0.32, 0.27, 0.22))
		draw_rect(wall, ink, false, 2.0)
		var floor_y := _s(Vector2(float(dv[0]), float(dv[3]))).y if dv.size() > 3 else door_top + 100.0
		for xo in [-7.0, 7.0]:
			draw_line(Vector2(top.x + xo, door_top), Vector2(top.x + xo, floor_y), Color(0.25, 0.2, 0.15, 0.9), 3.0)
	# signs for the storeys
	var font := ThemeDB.fallback_font
	for lb in sec.get("labels", []):
		var at := _s(Vector2(float(lb[0]), float(lb[1])))
		var text := TranslationServer.translate(str(lb[2]))
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.08, 0.06, 0.04, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.86, 0.8, 0.66, 0.85))


## The room covering a cell: its wall or floor picture (`key`), else `fallback`.
func _room_of(sec: Dictionary, c: Vector2i, key: String, fallback: String) -> String:
	for room in sec.get("rooms", []):
		var rr: Array = room.get("rect", [])
		if rr.size() == 4 and c.x >= int(rr[0]) and c.y >= int(rr[1]) and c.x < int(rr[0]) + int(rr[2]) and c.y < int(rr[1]) + int(rr[3]):
			return str(room.get(key, fallback))
	return fallback
