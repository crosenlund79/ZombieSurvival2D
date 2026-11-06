class_name MapPanel
extends Control
## World map (M, or "Read" on the field map from the starter bag). Local to each
## player; never pauses the shared world. Red Thaw: drawn as a weathered,
## hand-inked field map — pine-forest masses stamped with tree symbols, pale
## snowy clearings, faint contour hints, cased roads, dashed woodland tracks,
## hatched buildings, ruin and burn marks, a compass and a scale bar.
## Everything drawn comes from data: the surface region's "map" block in its
## content file (roads, areas, landmarks), live bunker records, and player
## positions. Players indoors or underground are shown at the surface point
## of the building/shelter they are in, with their depth.
## Iteration 011: the region you are in is outlined in red ink, road exits that
## lead somewhere not yet discovered get an "unexplored" arrow where they leave
## a discovered region, vehicles are marked, and at night the paper darkens
## (labels and markers are drawn after the shade so they stay readable).

const INK := Color(0.12, 0.13, 0.14)
const INK_SOFT := Color(0.12, 0.13, 0.14, 0.4)
const ROAD := Color(0.72, 0.72, 0.68)
const TRACK := Color(0.30, 0.27, 0.24)
const WOODS := Color(0.20, 0.27, 0.24, 0.32)
const PINE := Color(0.13, 0.19, 0.17, 0.85)
const CLEARING := Color(0.93, 0.94, 0.92, 0.35)
const YARD := Color(0.45, 0.40, 0.34, 0.22)
const CONTOUR := Color(0.32, 0.40, 0.46, 0.22)
const ME := Color("#8E1F1A")
const OTHER := Color("#2E4A5C")
const BUNKER := Color("#5A4632")

## The map panel of this game window (opened from the inventory's field map).
static var instance: MapPanel

var _paper: TextureRect
var _later: Array = []   # labels drawn after the night shade
var _legend: Label
var _title: Label


func _ready() -> void:
	instance = self
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


## Surface regions shown on the map: the start region and every discovered one.
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


static func region_offset(w: WorldState, rid: String) -> Vector2:
	var o: Array = w.region_def(rid).get("map", {}).get("offset", [0, 0])
	return Vector2(float(o[0]), float(o[1]))


func _draw() -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var here := surface_point(w, me.region_id, me.position)
	var shown := shown_regions(w)
	var bounds := Rect2()
	for rid in shown:
		var b: Array = w.region_def(rid).get("bounds", [0, 0, 1600, 1100])
		var rb := Rect2(region_offset(w, rid) + Vector2(float(b[0]), float(b[1])), Vector2(float(b[2]), float(b[3])))
		bounds = rb if bounds.size == Vector2.ZERO else bounds.merge(rb)
	var rect := _map_rect(bounds)
	var sc := rect.size.x / bounds.size.x
	_paper.position = rect.position - Vector2(30, 50)
	_paper.size = rect.size + Vector2(60, 130)
	_title.position = rect.position + Vector2(0, -44)
	_title.text = UITheme.fmt("MAP_TITLE", [tr(str(w.region_def(str(here.get("region_id", Content.DEFAULT_REGION))).get("display_key", "")))])
	_later.clear()
	for rid in shown:
		var off := region_offset(w, rid)
		var to_map := func(p: Vector2) -> Vector2: return rect.position + (p + off - bounds.position) * sc
		_draw_region(w, rid, to_map, sc)
	# The region you are in: outlined in red ink.
	var hr := str(here.get("region_id", ""))
	if hr in shown:
		var hb2: Array = w.region_def(hr).get("bounds", [0, 0, 1600, 1100])
		var h0: Vector2 = rect.position + (region_offset(w, hr) + Vector2(float(hb2[0]), float(hb2[1])) - bounds.position) * sc
		draw_rect(Rect2(h0, Vector2(float(hb2[2]), float(hb2[3])) * sc).grow(-2.0), Color(ME, 0.85), false, 3.0)
	# Road exits from discovered regions to places not discovered yet.
	for ex in unexplored_exits(w, shown):
		var at: Vector2 = rect.position + (region_offset(w, ex["region_id"]) + ex["position"] - bounds.position) * sc
		var dir: Vector2 = ex["dir"]
		draw_line(at - dir * 18.0, at + dir * 16.0, INK, 3.0)
		draw_colored_polygon(PackedVector2Array([at + dir * 30.0, at + dir * 16.0 + dir.orthogonal() * 7.0, at + dir * 16.0 - dir.orthogonal() * 7.0]), INK)
		_later.append([at + Vector2(0, -16), tr("MAP_UNEXPLORED"), 13])
	# Night: the paper darkens; labels and markers below are drawn on top of it.
	var night := 1.0 - EnvSim.daylight(w)
	if night > 0.02:
		draw_rect(rect.grow(10.0), Color(0.05, 0.07, 0.15, 0.5 * night))
	for lb in _later:
		_label(lb[0], lb[1], lb[2])
	_later.clear()
	# Vehicles: a small car mark (with a dot for each occupant).
	for v in w.vehicles.values():
		var vp := surface_point(w, v.region_id, v.position)
		if vp.is_empty() or not (vp["region_id"] in shown):
			continue
		var cp: Vector2 = rect.position + (vp["position"] + region_offset(w, vp["region_id"]) - bounds.position) * sc
		var fwd := Vector2.from_angle(v.rotation)
		var body := PackedVector2Array([cp + fwd * 9 + fwd.orthogonal() * 4.5, cp + fwd * 9 - fwd.orthogonal() * 4.5,
			cp - fwd * 9 - fwd.orthogonal() * 4.5, cp - fwd * 9 + fwd.orthogonal() * 4.5])
		draw_colored_polygon(body, Color("#4C5E62"))
		body.append(body[0])
		draw_polyline(body, INK, 1.5)
		_label(cp + Vector2(0, 18), tr("MAP_VEHICLE"), 11)
	# Shelters.
	for bid in w.bunkers:
		var bk: BunkerState = w.bunkers[bid]
		var entrance := w.region(bk.entrance_region)
		if entrance == null:
			continue
		var sp := surface_point(w, bk.entrance_region, Content.entity_position(entrance.entity_def(bk.entrance_entity)))
		if sp.is_empty() or not (sp["region_id"] in shown):
			continue
		var bp: Vector2 = rect.position + (sp["position"] + region_offset(w, sp["region_id"]) - bounds.position) * sc + Vector2(46, 10)
		# shelter: a hatch square with a downward ladder mark
		draw_rect(Rect2(bp - Vector2(9, 9), Vector2(18, 18)), BUNKER)
		draw_rect(Rect2(bp - Vector2(9, 9), Vector2(18, 18)), INK, false, 2.0)
		draw_line(bp + Vector2(-4, -5), bp + Vector2(-4, 6), INK, 1.5)
		draw_line(bp + Vector2(4, -5), bp + Vector2(4, 6), INK, 1.5)
		for k in 3:
			draw_line(bp + Vector2(-4, -3 + k * 4), bp + Vector2(4, -3 + k * 4), INK, 1.2)
		_label(bp + Vector2(70, 5), UITheme.fmt("MAP_SHELTER", [bk.levels.size()]), 13)
	# Players.
	for p in w.online_players():
		var pp := surface_point(w, p.region_id, p.position)
		if pp.is_empty() or not (pp["region_id"] in shown):
			continue
		var mp: Vector2 = rect.position + (pp["position"] + region_offset(w, pp["region_id"]) - bounds.position) * sc
		var mine: bool = p.player_id == me.player_id
		# a pencilled ring with a centre dot; the local player in red ink
		draw_arc(mp, 9.0 if mine else 7.0, 0, TAU, 20, ME if mine else OTHER, 3.0)
		draw_circle(mp, 3.0, ME if mine else OTHER)
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
	_draw_frame(rect, sc)


func _draw_frame(rect: Rect2, sc: float) -> void:
	draw_rect(rect.grow(4), INK, false, 2.5)
	draw_rect(rect.grow(9), INK_SOFT, false, 1.0)
	for i in 9:  # graticule ticks along the border
		var t := float(i) / 8.0
		var x := rect.position.x + rect.size.x * t
		var y := rect.position.y + rect.size.y * t
		draw_line(Vector2(x, rect.position.y - 4), Vector2(x, rect.position.y - 10), INK, 1.5)
		draw_line(Vector2(x, rect.end.y + 4), Vector2(x, rect.end.y + 10), INK, 1.5)
		draw_line(Vector2(rect.position.x - 4, y), Vector2(rect.position.x - 10, y), INK, 1.5)
		draw_line(Vector2(rect.end.x + 4, y), Vector2(rect.end.x + 10, y), INK, 1.5)
	# compass
	var c := rect.end - Vector2(46, 56)
	draw_circle(c, 20.0, Color(0.9, 0.9, 0.87, 0.75))
	draw_arc(c, 20.0, 0, TAU, 32, INK, 1.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(6, 0), c + Vector2(-6, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 22), c + Vector2(5, 0), c + Vector2(-5, 0)]), INK_SOFT)
	_label(c + Vector2(0, -30), "N", 14)
	# scale bar: 500 world px (a few minutes on foot)
	var bar := 500.0 * sc
	var b0 := Vector2(rect.position.x + 20, rect.end.y - 24)
	draw_rect(Rect2(b0, Vector2(bar, 6)), Color(0.9, 0.9, 0.87))
	draw_rect(Rect2(b0, Vector2(bar * 0.5, 6)), INK)
	draw_rect(Rect2(b0, Vector2(bar, 6)), INK, false, 1.2)
	_label(b0 + Vector2(bar * 0.5, -6), tr("MAP_SCALE"), 11)


## Deterministic jitter in [-1, 1] for map stamps (same picture every time).
static func _j(a: float, b: float, k: int) -> float:
	var h := sin(a * 12.9898 + b * 78.233 + float(k) * 37.719) * 43758.5453
	return (h - floorf(h)) * 2.0 - 1.0


func _pine(at: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7) * s, at + Vector2(4.5, 1) * s, at + Vector2(-4.5, 1) * s]), col)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3) * s, at + Vector2(5.5, 4) * s, at + Vector2(-5.5, 4) * s]), col)
	draw_line(at + Vector2(0, 4) * s, at + Vector2(0, 6.5) * s, col, maxf(1.0, s))


func _draw_region(w: WorldState, rid: String, to_map: Callable, sc: float) -> void:
	var def := w.region_def(rid)
	var map: Dictionary = def.get("map", {})
	var b: Array = def.get("bounds", [0, 0, 1600, 1100])
	var r0: Vector2 = to_map.call(Vector2(float(b[0]), float(b[1])))
	var r1: Vector2 = to_map.call(Vector2(float(b[0]) + float(b[2]), float(b[1]) + float(b[3])))
	var rr := Rect2(r0, r1 - r0)
	draw_rect(rr, CLEARING)  # snowy open ground
	# faint contour hints (muted elevation cues)
	for k in 5:
		var line := PackedVector2Array()
		var y0 := rr.position.y + rr.size.y * (0.12 + 0.2 * float(k)) + _j(r0.x, r0.y, k) * 12.0
		for i in 25:
			var x := rr.position.x + rr.size.x * float(i) / 24.0
			line.append(Vector2(x, y0 + sin(float(i) * 0.7 + float(k)) * 9.0 + _j(x, y0, k) * 2.0))
		draw_polyline(line, CONTOUR, 1.2)
	var woods_polys: Array = []
	for area in map.get("areas", []):
		var pts := PackedVector2Array()
		for p in area.get("polygon", []):
			pts.append(to_map.call(Vector2(p[0], p[1])))
		if pts.size() < 3:
			continue
		if area.get("kind") == "woods":
			draw_colored_polygon(pts, WOODS)
			woods_polys.append(pts)
		elif area.get("kind") == "water":
			draw_colored_polygon(pts, Color(0.16, 0.24, 0.3, 0.55))
		elif area.get("kind") == "ice":
			draw_colored_polygon(pts, Color(0.72, 0.8, 0.85, 0.45))
		else:
			draw_colored_polygon(pts, YARD)
			pts.append(pts[0])
			draw_polyline(pts, INK_SOFT, 1.2)
	# pine symbols stamped across the forest masses
	var step := 15.0
	for poly in woods_polys:
		var bb := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bb = bb.expand(q)
		var y := bb.position.y + 6.0
		var row := 0
		while y < bb.end.y:
			var x := bb.position.x + (7.0 if row % 2 else 0.0)
			while x < bb.end.x:
				var at := Vector2(x + _j(x, y, 1) * 4.0, y + _j(x, y, 2) * 3.0)
				if Geometry2D.is_point_in_polygon(at, poly) and _j(x, y, 3) > -0.55:
					_pine(at, 0.9 + 0.25 * _j(x, y, 4), PINE)
				x += step
			y += step * 0.8
			row += 1
	for road in map.get("roads", []):
		var line := PackedVector2Array()
		for p in road.get("points", []):
			line.append(to_map.call(Vector2(p[0], p[1])))
		var wpx := maxf(3.0, float(road.get("width", 40)) * sc * 0.6)
		if road.get("kind", "road") == "road":
			draw_polyline(line, INK, wpx + 3.0)   # cased road
			draw_polyline(line, ROAD, wpx)
		else:
			for i in line.size() - 1:  # dashed woodland track
				var a := line[i]
				var d := line[i + 1] - a
				var n := int(d.length() / 9.0)
				for k in n:
					if k % 2 == 0:
						draw_line(a + d * float(k) / n, a + d * float(k + 1) / n, TRACK, 2.2)
	for lm in map.get("landmarks", []):
		var c: Vector2 = to_map.call(Vector2(lm["position"][0], lm["position"][1]))
		var sz: Array = lm.get("size", [40, 40])
		var r := Rect2(c - Vector2(sz[0], sz[1]) * sc * 0.5, Vector2(sz[0], sz[1]) * sc)
		match str(lm.get("kind", "")):
			"building":
				draw_rect(r, Color(0.62, 0.60, 0.56))
				for k in int(r.size.x / 4.0):  # hatching
					var hx := r.position.x + 4.0 * float(k)
					draw_line(Vector2(hx, r.end.y), Vector2(minf(hx + r.size.y, r.end.x), r.position.y + maxf(0.0, hx + r.size.y - r.end.x)), INK_SOFT, 1.0)
				draw_rect(r, INK, false, 2.0)
			"ruin":
				draw_rect(r, Color(0.7, 0.7, 0.67))
				draw_line(r.position, r.end, INK, 1.5)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), INK, 1.5)
				draw_polyline(PackedVector2Array([r.position + Vector2(0, r.size.y), r.position, r.position + Vector2(r.size.x * 0.6, 0)]), INK, 2.0)
			"burned":
				draw_circle(c, maxf(5.0, r.size.x * 0.35), Color(0.08, 0.08, 0.08, 0.85))
				for k in 6:
					var a := TAU * float(k) / 6.0
					draw_line(c, c + Vector2(cos(a), sin(a)) * (r.size.x * 0.6 + 3.0), INK, 1.5)
			_:
				draw_circle(c, 3.5, INK)
		if lm.has("label_key"):
			_label_later(c + Vector2(0, r.size.y * 0.5 + 14), tr(str(lm["label_key"])).to_upper(), 11)
	if def.has("display_key"):
		_label_later(rr.position + Vector2(rr.size.x * 0.5, 22), tr(str(def["display_key"])).to_upper(), 15)
	var surf := w.region(rid)
	for eid in Content.entity_ids(surf.def_id):
		var ed := surf.entity_def(eid)
		if str(ed.get("type", "")) == "tree":
			var tp: Vector2 = to_map.call(Content.entity_position(ed))
			if bool(surf.entity_state(eid).get("felled", false)):
				draw_circle(tp, 2.0, TRACK)
			else:
				_pine(tp, 1.3, INK)
	# Player-built structures as small marks (defences, machines).
	for oid in surf.objects:
		var o: Dictionary = surf.objects[oid]
		if not Build.is_pile(o):
			draw_rect(Rect2(to_map.call(Build.pos_of(o)) - Vector2(3, 3), Vector2(6, 6)), INK)


func _label_later(at: Vector2, text: String, size: int) -> void:
	_later.append([at, text, size])


## Road exits (vehicle exits and road portals) of discovered regions whose
## destination has not been discovered: [{region_id, position, dir}].
static func unexplored_exits(w: WorldState, shown: Array) -> Array:
	var out := []
	for rid in shown:
		var def := w.region_def(rid)
		var b: Array = def.get("bounds", [0, 0, 1600, 1100])
		var centre := Vector2(float(b[0]) + float(b[2]) * 0.5, float(b[1]) + float(b[3]) * 0.5)
		var seen := {}
		var exits := []
		for ex in def.get("vehicle_exits", []):
			var rr: Array = ex.get("rect", [0, 0, 0, 0])
			exits.append([str(ex.get("target", {}).get("region", "")), Vector2(float(rr[0]) + float(rr[2]) * 0.5, float(rr[1]) + float(rr[3]) * 0.5)])
		var reg := w.region(rid)
		for eid in Content.entity_ids(reg.def_id):
			var ed := reg.entity_def(eid)
			if str(ed.get("type", "")) == "portal" and ed.get("target", {}).has("region"):
				exits.append([str(ed["target"]["region"]), Content.entity_position(ed)])
		for e in exits:
			var to: String = e[0]
			if to == "" or to in shown or seen.has(to) or not w.region_def(to).has("map"):
				continue
			seen[to] = true
			var d: Vector2 = (e[1] as Vector2) - centre
			var dir := Vector2(signf(d.x), 0) if absf(d.x) / maxf(1.0, float(b[2])) >= absf(d.y) / maxf(1.0, float(b[3])) else Vector2(0, signf(d.y))
			out.append({"region_id": rid, "position": e[1], "dir": dir})
	return out


func _label(at: Vector2, text: String, size: int) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.93, 0.88, 0.76, 0.9))
	draw_string(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
