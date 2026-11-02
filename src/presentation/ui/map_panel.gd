class_name MapPanel
extends Control
## World map (M). Local to each player; never pauses the shared world.
## Everything drawn comes from data: the surface region's "map" block in its
## content file (roads, areas, landmarks), live bunker records, and player
## positions. Players indoors or underground are shown at the surface point
## of the building/shelter they are in, with their depth.

const INK := Color(0.16, 0.13, 0.09)
const INK_SOFT := Color(0.16, 0.13, 0.09, 0.45)
const ROAD := Color(0.36, 0.33, 0.29)
const TRACK := Color(0.55, 0.42, 0.28)
const WOODS := Color(0.35, 0.40, 0.20, 0.35)
const YARD := Color(0.55, 0.43, 0.28, 0.35)
const ME := Color("#954C33")
const OTHER := Color("#346773")
const BUNKER := Color("#7A5A20")

var _paper: TextureRect
var _legend: Label
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.show_behind_parent = true  # children normally draw over _draw(); these two go underneath
	add_child(dim)
	_paper = TextureRect.new()
	_paper.stretch_mode = TextureRect.STRETCH_TILE
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.show_behind_parent = true
	add_child(_paper)
	_title = UITheme.heading("MAP_TITLE", 24)
	_title.add_theme_color_override("font_color", INK)
	add_child(_title)
	_legend = Label.new()
	_legend.add_theme_color_override("font_color", INK)
	_legend.add_theme_font_size_override("font_size", 14)
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_legend)
	visibility_changed.connect(func() -> void:
		if visible:
			_paper.texture = Assets.texture("ui.map_paper")
			queue_redraw())
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("world_map"):
		hide()
		get_viewport().set_input_as_handled()


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


func _map_rect(bounds: Rect2) -> Rect2:
	var area := Rect2(Vector2(60, 70), size - Vector2(120, 170))
	var s := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var draw_size := bounds.size * s
	return Rect2(area.position + (area.size - draw_size) * 0.5, draw_size)


func _draw() -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var here := surface_point(w, me.region_id, me.position)
	var surface_id: String = here.get("region_id", Content.DEFAULT_REGION)
	var def := w.region_def(surface_id)
	var b: Array = def.get("bounds", [0, 0, 1600, 1100])
	var bounds := Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	var rect := _map_rect(bounds)
	var sc := rect.size.x / bounds.size.x
	var to_map := func(p: Vector2) -> Vector2: return rect.position + (p - bounds.position) * sc
	_paper.position = rect.position - Vector2(30, 50)
	_paper.size = rect.size + Vector2(60, 130)
	_title.position = rect.position + Vector2(0, -44)
	_title.text = UITheme.fmt("MAP_TITLE", [tr(str(def.get("display_key", "")))])
	var map: Dictionary = def.get("map", {})
	for area in map.get("areas", []):
		var pts := PackedVector2Array()
		for p in area.get("polygon", []):
			pts.append(to_map.call(Vector2(p[0], p[1])))
		if pts.size() >= 3:
			draw_colored_polygon(pts, WOODS if area.get("kind") == "woods" else YARD)
			pts.append(pts[0])
			draw_polyline(pts, INK_SOFT, 1.5)
	for road in map.get("roads", []):
		var line := PackedVector2Array()
		for p in road.get("points", []):
			line.append(to_map.call(Vector2(p[0], p[1])))
		var wpx := float(road.get("width", 40)) * sc
		var col := ROAD if road.get("kind", "road") == "road" else TRACK
		draw_polyline(line, INK, wpx + 3.0)
		draw_polyline(line, col, wpx)
	for lm in map.get("landmarks", []):
		var c: Vector2 = to_map.call(Vector2(lm["position"][0], lm["position"][1]))
		var sz: Array = lm.get("size", [40, 40])
		var r := Rect2(c - Vector2(sz[0], sz[1]) * sc * 0.5, Vector2(sz[0], sz[1]) * sc)
		match str(lm.get("kind", "")):
			"building":
				draw_rect(r, Color(0.78, 0.70, 0.55))
				draw_rect(r, INK, false, 2.0)
			"tree":
				draw_circle(c, 5.0, Color(0.30, 0.36, 0.18))
				draw_arc(c, 5.0, 0, TAU, 12, INK, 1.0)
			_:
				draw_circle(c, 4.0, INK)
		if lm.has("label_key"):
			_label(c + Vector2(0, r.size.y * 0.5 + 14), tr(str(lm["label_key"])), 13)
	# Harvestable trees from live world state (felled ones as stumps).
	var surf := w.region(surface_id)
	if surf != null:
		for eid in Content.entity_ids(surf.def_id):
			var ed := surf.entity_def(eid)
			if str(ed.get("type", "")) == "tree":
				var tp: Vector2 = to_map.call(Content.entity_position(ed))
				if bool(surf.entity_state(eid).get("felled", false)):
					draw_circle(tp, 2.5, TRACK)
				else:
					draw_circle(tp, 6.0, Color(0.30, 0.38, 0.18))
					draw_arc(tp, 6.0, 0, TAU, 12, INK, 1.2)
	# Shelters.
	for bid in w.bunkers:
		var bk: BunkerState = w.bunkers[bid]
		var entrance := w.region(bk.entrance_region)
		if entrance == null:
			continue
		var sp := surface_point(w, bk.entrance_region, Content.entity_position(entrance.entity_def(bk.entrance_entity)))
		if sp.is_empty() or sp["region_id"] != surface_id:
			continue
		var bp: Vector2 = to_map.call(sp["position"]) + Vector2(46, 10)
		var tri := PackedVector2Array([bp + Vector2(0, -12), bp + Vector2(11, 8), bp + Vector2(-11, 8)])
		draw_colored_polygon(tri, BUNKER)
		tri.append(tri[0])
		draw_polyline(tri, INK, 2.0)
		_label(bp + Vector2(70, 5), UITheme.fmt("MAP_SHELTER", [bk.levels.size()]), 13)
	# Players.
	for p in w.online_players():
		var pp := surface_point(w, p.region_id, p.position)
		if pp.is_empty() or pp["region_id"] != surface_id:
			continue
		var mp: Vector2 = to_map.call(pp["position"])
		var mine: bool = p.player_id == me.player_id
		draw_circle(mp, 9.0 if mine else 7.0, ME if mine else OTHER)
		draw_arc(mp, 9.0 if mine else 7.0, 0, TAU, 16, INK, 2.0)
		var tag: String = p.display_name
		if int(pp["depth"]) < 0:
			tag += " (%d)" % int(pp["depth"])
		elif pp["inside_key"] != "":
			tag += " ⌂"
		_label(mp + Vector2(0, -16), tag, 12)
	# Legend / where am I.
	var where := Hud.region_label(me.region_id)
	if int(here.get("depth", 0)) < 0:
		_legend.text = UITheme.fmt("MAP_YOU_UNDERGROUND", [where, int(here["depth"])])
	elif str(here.get("inside_key", "")) != "":
		_legend.text = UITheme.fmt("MAP_YOU_INSIDE", [where])
	else:
		_legend.text = UITheme.fmt("MAP_YOU_SURFACE", [where])
	_legend.text += "\n" + tr("MAP_LEGEND")
	_legend.position = Vector2(rect.position.x, rect.end.y + 12)
	_legend.size = Vector2(rect.size.x, 60)
	draw_rect(rect.grow(4), INK, false, 3.0)


func _label(at: Vector2, text: String, size: int) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.93, 0.88, 0.76, 0.9))
	draw_string(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
