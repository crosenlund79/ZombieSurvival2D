class_name WildTerrain
extends Node2D
## Presentation of a large wilderness travel region (iteration 015), built from
## the region's "wild" content block instead of hand-placed scene nodes:
##   ground   one tiling snow surface over the whole region
##   patches  roads, tracks, frozen lakes and clearings ([asset, [x, y, ...]])
##   scatter  thousands of trees, rocks, cabins and dressing
##            [asset, x, y, flip, foot_w, foot_h, sway]
## The scatter is streamed by chunk: only the chunks around the camera exist as
## nodes (Prop with art and collision), so a region many screens wide costs
## about as much as a small one. Navigation for the host comes from the
## region's "obstacles" (NavGrid), never from these nodes. Portal and container
## entities get their views here too. Presentation only; all state is in the world.

const CHUNK := 1024.0
const MARGIN := 700.0       # chunks this far beyond the screen are kept alive
const REFRESH := 0.2

var region_id := ""
var _chunks := {}            # Vector2i -> Array[items]
var _live := {}              # Vector2i -> Node2D holding that chunk's props
var _ysort: Node2D
var _t := 0.0


func _ready() -> void:
	var rv := RegionView.find_for(self)
	region_id = rv.region_id if rv != null else region_id
	var def := Content.region_def(rv.def_id if rv != null else region_id)
	var wild: Dictionary = def.get("wild", {})
	_ysort = rv.get_node_or_null("YSort") if rv != null else null
	if _ysort == null:
		_ysort = Node2D.new()
		_ysort.name = "YSort"
		_ysort.y_sort_enabled = true
		get_parent().add_child.call_deferred(_ysort)
	var b: Array = def.get("bounds", [0, 0, 1600, 1100])
	var ground := GroundPatch.new()
	ground.name = "Ground"
	ground.z_index = -10
	ground.polygon = PackedVector2Array([Vector2(-600, -600), Vector2(float(b[2]) + 600, -600),
		Vector2(float(b[2]) + 600, float(b[3]) + 600), Vector2(-600, float(b[3]) + 600)])
	ground.asset_id = str(wild.get("ground", "env.ground_snow"))
	add_child(ground)
	for pt in wild.get("patches", []):
		var gp := GroundPatch.new()
		gp.z_index = -9 if str(pt[0]) != "env.ground_road_snow" else -8
		var arr := PackedVector2Array()
		var flat: Array = pt[1]
		for i in range(0, flat.size() - 1, 2):
			arr.append(Vector2(float(flat[i]), float(flat[i + 1])))
		gp.polygon = arr
		gp.asset_id = str(pt[0])
		add_child(gp)
	for it in wild.get("scatter", []):
		var c := Vector2i(floori(float(it[1]) / CHUNK), floori(float(it[2]) / CHUNK))
		if not _chunks.has(c):
			_chunks[c] = []
		_chunks[c].append(it)
	_spawn_entity_views.call_deferred(def)


func _spawn_entity_views(def: Dictionary) -> void:
	for e in def.get("entities", []):
		var t := str(e.get("type", ""))
		var v: EntityView = null
		if t == "portal" and str(e.get("id", "")) != "":
			v = PortalView.new()
			(v as PortalView).art_asset = str(e.get("art", ""))
		elif t == "container":
			v = ContainerView.new()
		if v != null:
			v.entity_id = str(e["id"])
			_ysort.add_child(v)
		elif t == "door":
			# iteration 015 F: a gate in the open (Hearth Gate)
			var dv := DoorView.new()
			dv.entity_id = str(e["id"])
			dv.closed_asset = str(e.get("art_closed", dv.closed_asset))
			dv.open_asset = str(e.get("art_open", dv.open_asset))
			var bl: Array = e.get("blocker", [80, 16])
			dv.blocker_size = Vector2(float(bl[0]), float(bl[1]))
			dv.prompt_open_key = str(e.get("prompt_open_key", dv.prompt_open_key))
			dv.prompt_close_key = str(e.get("prompt_close_key", dv.prompt_close_key))
			_ysort.add_child(dv)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	var view := _view_rect()
	if view.size == Vector2.ZERO:
		return
	var want := {}
	var c0 := Vector2i(floori((view.position.x - MARGIN) / CHUNK), floori((view.position.y - MARGIN) / CHUNK))
	var c1 := Vector2i(floori((view.end.x + MARGIN) / CHUNK), floori((view.end.y + MARGIN) / CHUNK))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var c := Vector2i(cx, cy)
			if _chunks.has(c):
				want[c] = true
				if not _live.has(c):
					_live[c] = _build_chunk(c)
	for c2 in _live.keys():
		if not want.has(c2):
			(_live[c2] as Node).queue_free()
			_live.erase(c2)


## The world rectangle the camera currently shows.
func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	var r := vp.get_visible_rect()
	return Rect2(inv * r.position, Vector2.ZERO).expand(inv * r.end)


func _build_chunk(c: Vector2i) -> Node2D:
	var holder := Node2D.new()
	holder.name = "Chunk_%d_%d" % [c.x, c.y]
	holder.y_sort_enabled = true
	for it in _chunks[c]:
		var p := Prop.new()
		p.asset_id = str(it[0])
		p.position = Vector2(float(it[1]), float(it[2]))
		p.flip_h = int(it[3]) == 1
		if float(it[4]) > 0.0:
			p.footprint = Vector2(float(it[4]), float(it[5]))
		p.sway = it.size() > 6 and int(it[6]) == 1
		p.occlude = float(it[4]) > 60.0
		holder.add_child(p)
	_ysort.add_child(holder)
	return holder


func live_chunks() -> int:
	return _live.size()


func live_props() -> int:
	var n := 0
	for c in _live:
		n += (_live[c] as Node).get_child_count()
	return n
