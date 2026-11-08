class_name MapPanel
extends Control
## World map (M, or "Read" on the field map). Local to each player; never pauses
## the shared world. Iteration 015: one geographic map of the whole world drawn
## from the same world coordinates the regions are played in (WorldGeo), so the
## distances on paper are the distances you travel.
##
##  * World view: every settlement, the wilderness between them, roads and tracks;
##    Local view: the area around you in detail (cabins, buildings, labels).
##    Tab switches; the mouse wheel / +/- zoom; drag or the arrow keys pan;
##    C re-centres on you.
##  * Fog of war: only explored cells (WorldGeo.explored, recorded by the host
##    as players travel) show what is there; the rest stays blank paper.
##    Cabins, towers and other wilderness finds appear once their cell is explored.
##  * Drawn as a weathered field map: stamped pine forests, frozen lakes and the
##    sea, cased roads and dashed tracks, hatched buildings, cabin marks, a
##    compass and a scale bar; labels are placed so they never overlap.
##  * Markers: you (red), other players, vehicles, shelters. At night the paper
##    darkens; labels and markers are drawn above the shade.

const INK := Color(0.12, 0.13, 0.14)
const INK_SOFT := Color(0.12, 0.13, 0.14, 0.4)
const ROAD := Color(0.74, 0.73, 0.69)
const TRACK := Color(0.32, 0.28, 0.24)
const PINE := Color(0.14, 0.2, 0.18, 0.85)
const WOODS := Color(0.22, 0.29, 0.26, 0.16)
const YARD := Color(0.45, 0.40, 0.34, 0.18)
const ICE := Color(0.70, 0.79, 0.84, 0.55)
const WATER := Color(0.18, 0.26, 0.32, 0.6)
const FOG := Color(0.87, 0.84, 0.76, 1.0)
const ME := Color("#8E1F1A")
const OTHER := Color("#2E4A5C")
const BUNKER := Color("#5A4632")
const WORLD_ZOOM := 0.022
const LOCAL_ZOOM := 0.16

## The map panel of this game window (opened from the inventory's field map).
static var instance: MapPanel

var _paper: TextureRect
var _title: Label
var _legend: Label
var _mode := "world"
var _zoom := WORLD_ZOOM
var _center := Vector2.ZERO        # world point at the middle of the map area
var _dragging := false
var _labels: Array = []            # placed label rects (no overlaps)
var _pending: Array = []           # [pos, text, size, rect] drawn after the night shade
var _redraw_t := 0.0


func _ready() -> void:
	instance = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.show_behind_parent = true
	add_child(dim)
	_paper = TextureRect.new()
	_paper.stretch_mode = TextureRect.STRETCH_TILE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.show_behind_parent = true
	add_child(_paper)
	_title = UITheme.heading("MAP_TITLE", 24)
	_title.add_theme_color_override("font_color", INK)
	add_child(_title)
	_legend = Label.new()
	_legend.add_theme_color_override("font_color", INK)
	_legend.add_theme_font_size_override("font_size", 13)
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_legend)
	visibility_changed.connect(func() -> void:
		if visible:
			_paper.texture = Assets.texture("ui.map_paper")
			_recentre()
			queue_redraw())
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not visible:
		return
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.25
		queue_redraw()


func _area() -> Rect2:
	return Rect2(Vector2(50, 64), size - Vector2(100, 150))


func _recentre() -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var sp := WorldGeo.surface_world(w, me.region_id, me.position)
	if _mode == "world":
		var all := _world_bounds(w)
		_zoom = minf(_area().size.x / maxf(1.0, all.size.x), _area().size.y / maxf(1.0, all.size.y)) * 0.96
		_center = all.get_center()
	else:
		_zoom = LOCAL_ZOOM
		_center = sp if sp != Vector2.INF else _center


func set_mode(m: String) -> void:
	_mode = m
	_recentre()
	queue_redraw()


func mode() -> String:
	return _mode


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("world_map") or event.is_action_pressed("pause_menu"):
		hide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		var pan := 220.0 / _zoom
		match k:
			KEY_TAB: set_mode("local" if _mode == "world" else "world")
			KEY_C: _recentre()
			KEY_EQUAL, KEY_KP_ADD: _zoom_at(1.25, size * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT: _zoom_at(0.8, size * 0.5)
			KEY_LEFT: _center.x -= pan
			KEY_RIGHT: _center.x += pan
			KEY_UP: _center.y -= pan
			KEY_DOWN: _center.y += pan
			_: return
		queue_redraw()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_center -= (event as InputEventMouseMotion).relative / _zoom
		queue_redraw()
		accept_event()


func _zoom_at(f: float, at: Vector2) -> void:
	var before := _to_world(at)
	_zoom = clampf(_zoom * f, WORLD_ZOOM * 0.6, 0.6)
	_center += before - _to_world(at)
	queue_redraw()


func _to_map(wp: Vector2) -> Vector2:
	return _area().get_center() + (wp - _center) * _zoom


func _to_world(mp: Vector2) -> Vector2:
	return _center + (mp - _area().get_center()) / _zoom


static func _world_bounds(_w: WorldState) -> Rect2:
	var b := Rect2()
	for rid in WorldGeo.outdoor_ids():
		var r := WorldGeo.world_rect(rid)
		b = r if b.size == Vector2.ZERO else b.merge(r)
	return b


## Where on the surface a region position is: {region_id, position, depth, inside_key}.
static func surface_point(world: WorldState, region_id: String, pos: Vector2, guard: int = 0) -> Dictionary:
	var r := world.region(region_id)
	if r == null or guard > 8:
		return {}
	var def := r.definition()
	if def.has("map"):
		return {"region_id": region_id, "position": pos, "depth": 0, "inside_key": ""}
	var parsed := BunkerState.parse_region_id(region_id)
	if not parsed.is_empty():
		var b := world.bunker(parsed["bunker_id"])
		if b == null:
			return {}
		var entrance := world.region(b.entrance_region)
		if entrance == null:
			return {}
		var up := surface_point(world, b.entrance_region, Content.entity_position(entrance.entity_def(b.entrance_entity)), guard + 1)
		if not up.is_empty():
			up["depth"] = parsed["depth"]
		return up
	if def.has("surface"):
		var sp: Dictionary = def["surface"]
		var p: Array = sp.get("position", [0, 0])
		var res := surface_point(world, str(sp.get("region", "")), Vector2(float(p[0]), float(p[1])), guard + 1)
		if not res.is_empty() and res["inside_key"] == "":
			res["inside_key"] = str(def.get("display_key", ""))
		return res
	return {}


## Surface regions the player has found (the start region and every discovered one).
static func shown_regions(w: WorldState) -> Array:
	var out := []
	for rid in Content.region_ids():
		var def := w.region_def(rid)
		if not def.has("map") or w.region(rid) == null:
			continue
		var key := str(def.get("discovery", ""))
		if key == "" or w.meta.get("discoveries", {}).has(key):
			out.append(rid)
	return out


static func region_offset(_w: WorldState, rid: String) -> Vector2:
	return WorldGeo.offset(rid)


func _world_point(w: WorldState, region_id: String, pos: Vector2) -> Vector2:
	var sp := surface_point(w, region_id, pos)
	if sp.is_empty():
		return Vector2.INF
	return WorldGeo.to_world(str(sp["region_id"]), sp["position"])


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var area := _area()
	_paper.position = area.position - Vector2(24, 40)
	_paper.size = area.size + Vector2(48, 110)
	_labels.clear()
	_pending.clear()
	var here := surface_point(w, me.region_id, me.position)
	_title.position = area.position + Vector2(0, -46)
	_title.text = UITheme.fmt("MAP_TITLE", [tr(str(w.region_def(str(here.get("region_id", Content.DEFAULT_REGION))).get("display_key", "")))]) \
		+ "  ·  " + tr("MAP_MODE_WORLD" if _mode == "world" else "MAP_MODE_LOCAL")
	var view := Rect2(_to_world(area.position), area.size / _zoom)
	var explored := WorldGeo.explored(w)
	for rid in WorldGeo.outdoor_ids():
		var wr := WorldGeo.world_rect(rid)
		if not wr.intersects(view) or w.region(rid) == null:
			continue
		_draw_region(w, rid, view)
	_draw_fog(w, view, explored, area)
	# Ways on into places not yet found.
	for ex in unexplored_exits(w, _known_regions(w)):
		var at := _to_map(WorldGeo.to_world(ex["region_id"], ex["position"]))
		if not area.has_point(at):
			continue
		var dir: Vector2 = ex["dir"]
		draw_line(at - dir * 14.0, at + dir * 12.0, INK, 2.5)
		draw_colored_polygon(PackedVector2Array([at + dir * 24.0, at + dir * 12.0 + dir.orthogonal() * 6.0, at + dir * 12.0 - dir.orthogonal() * 6.0]), INK)
		_place_label(at + dir * 30.0 + Vector2(0, -10), tr("MAP_UNEXPLORED"), 11, 1)
	var night := 1.0 - EnvSim.daylight(w)
	if night > 0.02:
		draw_rect(area.grow(8.0), Color(0.05, 0.07, 0.15, 0.42 * night))
	for lb in _pending:
		_label(lb[0], lb[1], lb[2])
	_draw_markers(w, me, area)
	_draw_frame(area)
	var where := Hud.region_label(me.region_id)
	if int(here.get("depth", 0)) < 0:
		_legend.text = UITheme.fmt("MAP_YOU_UNDERGROUND", [where, int(here["depth"])])
	elif str(here.get("inside_key", "")) != "":
		_legend.text = UITheme.fmt("MAP_YOU_INSIDE", [where])
	else:
		_legend.text = UITheme.fmt("MAP_YOU_SURFACE", [where])
	_legend.text += "   " + tr("MAP_CONTROLS") + "\n" + tr("MAP_LEGEND")
	_legend.position = Vector2(area.position.x, area.end.y + 10)
	_legend.size = Vector2(area.size.x, 60)


func _known_regions(w: WorldState) -> Array:
	var out := []
	for rid in WorldGeo.outdoor_ids():
		var key := str(w.region_def(rid).get("discovery", ""))
		if key == "" or w.meta.get("discoveries", {}).has(key):
			out.append(rid)
	return out


func _draw_region(w: WorldState, rid: String, view: Rect2) -> void:
	var def := w.region_def(rid)
	var map: Dictionary = def.get("map", {})
	var off := WorldGeo.offset(rid)
	var to := func(p: Vector2) -> Vector2: return _to_map(p + off)
	var wr := WorldGeo.world_rect(rid)
	# forests: polygons (settlements) or the coarse forest grid (wilderness), stamped with pines
	var fg: Dictionary = map.get("forest", {})
	if not fg.is_empty():
		var cell := float(fg.get("cell", 400))
		var gw := int(fg.get("w", 0))
		var data := str(fg.get("data", ""))
		var stamp := clampi(int(18.0 / maxf(0.001, cell * _zoom)), 1, 6)
		for i in data.length():
			if data[i] != "1":
				continue
			var cx := i % gw
			var cy := i / gw
			var wp := off + Vector2((cx + 0.5) * cell, (cy + 0.5) * cell)
			if not view.grow(cell).has_point(wp):
				continue
			var mp := _to_map(wp)
			draw_rect(Rect2(mp - Vector2(cell, cell) * _zoom * 0.5, Vector2(cell, cell) * _zoom), WOODS)
			if (cx + cy * 3) % stamp == 0:
				_pine(mp + Vector2(_j(wp.x, wp.y, 1), _j(wp.x, wp.y, 2)) * cell * _zoom * 0.3, clampf(cell * _zoom / 9.0, 0.5, 1.6), PINE)
	for area in map.get("areas", []):
		var pts := PackedVector2Array()
		for p in area.get("polygon", []):
			pts.append(to.call(Vector2(float(p[0]), float(p[1]))))
		if pts.size() < 3:
			continue
		match str(area.get("kind", "")):
			"woods":
				draw_colored_polygon(pts, WOODS)
				_stamp_pines(pts)
			"water":
				draw_colored_polygon(pts, WATER)
			"ice":
				draw_colored_polygon(pts, ICE)
				var ring := pts.duplicate()
				ring.append(pts[0])
				draw_polyline(ring, INK_SOFT, 1.0)
			_:
				draw_colored_polygon(pts, YARD)
	for road in map.get("roads", []):
		var line := PackedVector2Array()
		for p in road.get("points", []):
			line.append(to.call(Vector2(float(p[0]), float(p[1]))))
		if line.size() < 2:
			continue
		var wpx := maxf(2.0, float(road.get("width", 40)) * _zoom * 0.7)
		if str(road.get("kind", "road")) == "road":
			draw_polyline(line, INK, wpx + 2.5)
			draw_polyline(line, ROAD, wpx)
		else:
			for i in line.size() - 1:
				var a := line[i]
				var d := line[i + 1] - a
				var n := maxi(1, int(d.length() / 7.0))
				for k in n:
					if k % 2 == 0:
						draw_line(a + d * float(k) / n, a + d * float(k + 1) / n, TRACK, 1.8)
	var detail := _zoom > 0.05
	var explored := WorldGeo.explored(w)
	for lm in map.get("landmarks", []):
		var wp: Vector2 = off + Vector2(float(lm["position"][0]), float(lm["position"][1]))
		if bool(lm.get("hidden", false)) and not explored.has(WorldGeo.cell_key(wp)):
			continue
		var c := _to_map(wp)
		var sz: Array = lm.get("size", [40, 40])
		var r := Rect2(c - Vector2(float(sz[0]), float(sz[1])) * _zoom * 0.5, Vector2(float(sz[0]), float(sz[1])) * _zoom)
		r = Rect2(r.get_center() - r.size.max(Vector2(3, 3)) * 0.5, r.size.max(Vector2(3, 3)))
		match str(lm.get("kind", "")):
			"building":
				draw_rect(r, Color(0.6, 0.58, 0.54))
				draw_rect(r, INK, false, 1.5)
			"ruin":
				draw_rect(r, Color(0.7, 0.7, 0.67))
				draw_line(r.position, r.end, INK, 1.2)
			"burned":
				draw_circle(c, maxf(3.0, r.size.x * 0.35), Color(0.08, 0.08, 0.08, 0.85))
			"cabin":
				_cabin_mark(c)
			"tower", "mast":
				draw_line(c + Vector2(-4, 4), c + Vector2(0, -8), INK, 1.6)
				draw_line(c + Vector2(4, 4), c + Vector2(0, -8), INK, 1.6)
			_:
				draw_circle(c, 2.5, INK)
		if lm.has("label_key") and (detail or str(lm.get("kind", "")) == "cabin" and _zoom > 0.035):
			_place_label(c + Vector2(0, 14), tr(str(lm["label_key"])), 11, 2)
	if def.has("display_key"):
		var big := not bool(def.get("wilderness", false))
		var key := str(def.get("discovery", ""))
		var known: bool = key == "" or w.meta.get("discoveries", {}).has(key)
		if known:
			var at := _to_map(wr.get_center()) if big else _to_map(wr.get_center() + Vector2(0, -wr.size.y * 0.3))
			_place_label(at, tr(str(def["display_key"])).to_upper() if big else tr(str(def["display_key"])), 16 if big else 12, 5 if big else 3)


func _draw_fog(_w: WorldState, view: Rect2, explored: Dictionary, area: Rect2) -> void:
	# Unexplored land is blank paper: drawn with the paper texture itself, aligned with
	# the background, so it hides what is there without showing a box. A softer second
	# pass around each cell feathers the edge of what you have seen.
	var tex := _paper.texture
	var cell := WorldGeo.EXPLORE_CELL
	var c0 := Vector2i(floori(view.position.x / cell), floori(view.position.y / cell))
	var c1 := Vector2i(floori(view.end.x / cell), floori(view.end.y / cell))
	var sz := Vector2(cell, cell) * _zoom + Vector2(1, 1)
	var feather := clampf(cell * _zoom * 0.35, 2.0, 18.0)
	var cells: Array = []
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if explored.has("%d:%d" % [cx, cy]):
				continue
			var wp := Vector2(cx * cell, cy * cell)
			if WorldGeo.region_at(wp + Vector2(cell, cell) * 0.5) == "":
				continue
			cells.append(Rect2(_to_map(wp), sz))
	for pass_i in 2:
		for r0 in cells:
			var r: Rect2 = (r0 as Rect2).grow(feather if pass_i == 0 else 0.0).intersection(area)
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			var col := Color(1, 1, 1, 0.55 if pass_i == 0 else 1.0)
			if tex != null:
				draw_texture_rect_region(tex, r, Rect2(r.position - _paper.position, r.size), col)
			else:
				draw_rect(r, Color(FOG, col.a))


func _draw_markers(w: WorldState, me: PlayerState, area: Rect2) -> void:
	for v in w.vehicles.values():
		var vp := _world_point(w, v.region_id, v.position)
		if vp == Vector2.INF or not WorldGeo.is_explored(w, vp):
			continue
		var cp := _to_map(vp)
		if not area.has_point(cp):
			continue
		var fwd := Vector2.from_angle(v.rotation)
		var body := PackedVector2Array([cp + fwd * 8 + fwd.orthogonal() * 4, cp + fwd * 8 - fwd.orthogonal() * 4,
			cp - fwd * 8 - fwd.orthogonal() * 4, cp - fwd * 8 + fwd.orthogonal() * 4])
		draw_colored_polygon(body, Color("#4C5E62"))
		body.append(body[0])
		draw_polyline(body, INK, 1.4)
	for bid in w.bunkers:
		var bk: BunkerState = w.bunkers[bid]
		var entrance := w.region(bk.entrance_region)
		if entrance == null:
			continue
		var bp := _world_point(w, bk.entrance_region, Content.entity_position(entrance.entity_def(bk.entrance_entity)))
		if bp == Vector2.INF:
			continue
		var m := _to_map(bp) + Vector2(14, 10)
		if not area.has_point(m):
			continue
		draw_rect(Rect2(m - Vector2(7, 7), Vector2(14, 14)), BUNKER)
		draw_rect(Rect2(m - Vector2(7, 7), Vector2(14, 14)), INK, false, 1.6)
		for k in 3:
			draw_line(m + Vector2(-3, -3 + k * 3), m + Vector2(3, -3 + k * 3), INK, 1.0)
		_label(m + Vector2(0, 22), UITheme.fmt("MAP_SHELTER", [bk.levels.size()]), 11)
	for p in w.online_players():
		var pp := _world_point(w, p.region_id, p.position)
		if pp == Vector2.INF:
			continue
		var mp := _to_map(pp)
		if not area.has_point(mp):
			continue
		var mine: bool = p.player_id == me.player_id
		var col := ME if mine else OTHER
		draw_arc(mp, 9.0 if mine else 7.0, 0, TAU, 20, col, 3.0)
		draw_circle(mp, 3.0, col)
		_label(mp + Vector2(0, -15), p.display_name, 12)


func _cabin_mark(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(6, 0), c + Vector2(6, 6), c + Vector2(-6, 6)]), Color(0.45, 0.36, 0.28))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(0, -7), c + Vector2(8, 0)]), INK)
	draw_rect(Rect2(c + Vector2(-6, 0), Vector2(12, 6)), INK, false, 1.2)


func _stamp_pines(poly: PackedVector2Array) -> void:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		bb = bb.expand(q)
	var step := 14.0
	var y := bb.position.y + 5.0
	var row := 0
	while y < bb.end.y and y < size.y:
		var x := bb.position.x + (7.0 if row % 2 else 0.0)
		while x < bb.end.x and x < size.x:
			if x > 0 and y > 0:
				var at := Vector2(x + _j(x, y, 1) * 3.0, y + _j(x, y, 2) * 2.0)
				if Geometry2D.is_point_in_polygon(at, poly) and _j(x, y, 3) > -0.4:
					_pine(at, 0.8, PINE)
			x += step
		y += step * 0.8
		row += 1


func _draw_frame(area: Rect2) -> void:
	draw_rect(area.grow(4), INK, false, 2.5)
	draw_rect(area.grow(9), INK_SOFT, false, 1.0)
	var c := area.end - Vector2(44, 52)
	draw_circle(c, 19.0, Color(0.9, 0.9, 0.87, 0.75))
	draw_arc(c, 19.0, 0, TAU, 32, INK, 1.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -25), c + Vector2(6, 0), c + Vector2(-6, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 21), c + Vector2(5, 0), c + Vector2(-5, 0)]), INK_SOFT)
	_label(c + Vector2(0, -29), "N", 13)
	# scale bar: a round distance that fits ~160 px
	var steps := [500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0]
	var dist := 500.0
	for s in steps:
		if s * _zoom <= 160.0:
			dist = s
	var bar := dist * _zoom
	var b0 := Vector2(area.position.x + 20, area.end.y - 22)
	draw_rect(Rect2(b0, Vector2(bar, 6)), Color(0.9, 0.9, 0.87))
	draw_rect(Rect2(b0, Vector2(bar * 0.5, 6)), INK)
	draw_rect(Rect2(b0, Vector2(bar, 6)), INK, false, 1.2)
	var minutes := dist / PlayerAvatar.SPEED / 60.0
	_label(b0 + Vector2(bar * 0.5, -6), UITheme.fmt("MAP_SCALE_WALK", ["%.0f" % maxf(1.0, minutes)]), 11)


## Deterministic jitter in [-1, 1] for map stamps (same picture every time).
static func _j(a: float, b: float, k: int) -> float:
	var h := sin(a * 12.9898 + b * 78.233 + float(k) * 37.719) * 43758.5453
	return (h - floorf(h)) * 2.0 - 1.0


func _pine(at: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7) * s, at + Vector2(4.5, 1) * s, at + Vector2(-4.5, 1) * s]), col)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3) * s, at + Vector2(5.5, 4) * s, at + Vector2(-5.5, 4) * s]), col)


## Queues a label unless it would overlap one already placed (higher priority wins).
func _place_label(at: Vector2, text: String, fsize: int, priority: int) -> void:
	var font := get_theme_default_font()
	var wd := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var r := Rect2(at - Vector2(wd * 0.5 + 3, fsize + 2), Vector2(wd + 6, fsize + 6))
	if not _area().encloses(r):
		return
	for i in _labels.size():
		var other: Array = _labels[i]
		if (other[0] as Rect2).intersects(r):
			if int(other[1]) >= priority:
				return
			_labels.remove_at(i)
			for j in _pending.size():
				if _pending[j][3] == other[0]:
					_pending.remove_at(j)
					break
			break
	_labels.append([r, priority])
	_pending.append([at, text, fsize, r])


## Edges of known outdoor regions that continue into a region not yet discovered:
## [{region_id, position (local), dir, to}] — the marker sits where a road crosses.
static func unexplored_exits(w: WorldState, shown: Array) -> Array:
	var out := []
	for rid in shown:
		if not WorldGeo.is_outdoor(w.region_def(rid)):
			continue
		var b := WorldGeo.local_bounds(rid)
		var open := WorldGeo.open_edges(rid)
		var seen := {}
		for side in open:
			var dir: Vector2 = {"west": Vector2.LEFT, "east": Vector2.RIGHT, "north": Vector2.UP, "south": Vector2.DOWN}[side]
			for span in open[side]:
				var mid := (float(span[0]) + float(span[1])) * 0.5
				var at := Vector2.ZERO
				match side:
					"west": at = Vector2(b.position.x, mid)
					"east": at = Vector2(b.end.x, mid)
					"north": at = Vector2(mid, b.position.y)
					"south": at = Vector2(mid, b.end.y)
				var to := WorldGeo.region_at(WorldGeo.to_world(rid, at + dir * 40.0), rid)
				if to == "" or to in shown or seen.has(to):
					continue
				seen[to] = true
				at = _road_crossing(w.region_def(rid), side, at)
				out.append({"region_id": rid, "position": at, "dir": dir, "to": to})
	return out


## Where a mapped road meets an edge near `at` (falls back to `at`).
static func _road_crossing(def: Dictionary, side: String, at: Vector2) -> Vector2:
	var best := at
	var best_d := INF
	for road in def.get("map", {}).get("roads", []):
		for pt in road.get("points", []):
			var p := Vector2(float(pt[0]), float(pt[1]))
			var d := absf(p.x - at.x) if side in ["west", "east"] else absf(p.y - at.y)
			if d < 60.0 and p.distance_to(at) < best_d:
				best_d = p.distance_to(at)
				best = Vector2(at.x, p.y) if side in ["west", "east"] else Vector2(p.x, at.y)
	return best


func _label(at: Vector2, text: String, fsize: int) -> void:
	var font := get_theme_default_font()
	var wd := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string_outline(font, at - Vector2(wd / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, Color(0.93, 0.88, 0.76, 0.9))
	draw_string(font, at - Vector2(wd / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, INK)
