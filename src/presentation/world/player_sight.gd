class_name PlayerSight
extends Node2D
## Player-centred visibility (iteration 015 B), local to each game window.
##
## What you see is what your character could see, not what the camera frames:
##  * a view polygon cast from the local player against sight occluders
##    (buildings, cabins, rocks, wrecks — Props in group "sight_occluder"),
##    reaching far ahead, less to the sides and only a little behind you;
##  * the reach shrinks at night (the flashlight cone pushes it back out ahead),
##    in fog and in a blizzard;
##  * outside it the world is drawn as a dimmed, desaturated memory (static
##    scenery stays readable), with a soft vignette at the screen edges;
##  * Burnt Ones, animals and hostile people outside it are not drawn at all
##    (they fade); you still hear them.
## Rendering: the polygon is drawn into a small SubViewport mask that a
## full-screen shader samples (cheap, soft edges). Presentation only — nothing
## here changes the world; every player computes their own.
## Developer: F3 → World → Sight (on/off) and Vignette; Settings → Display → Vignette.

const RAYS := 120
const UPDATE := 0.06
const MASK_SCALE := 0.25
const OCCLUDER_DEPTH := 150.0  # how far a building's body reaches behind its base line

static var current: PlayerSight
static var enabled := true

var region_view: RegionView
var _poly := PackedVector2Array()
var _origin := Vector2.ZERO
var _facing := Vector2.DOWN
var _reach := 900.0
var _t := 0.0
var _occ: Array = []         # Rect2 occluders near the player (world space)
var _vp: SubViewport
var _mask_poly: Polygon2D
var _mask_soft: Polygon2D
var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial


static func create(rv: RegionView) -> PlayerSight:
	var s := PlayerSight.new()
	s.region_view = rv
	s.name = "PlayerSight"
	return s


func _ready() -> void:
	current = self
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(get_viewport().get_visible_rect().size * MASK_SCALE)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(_vp.size) * 4.0
	bg.position = -Vector2(_vp.size)
	_vp.add_child(bg)
	_mask_soft = Polygon2D.new()
	_mask_soft.color = Color(0.55, 0.55, 0.55)
	_vp.add_child(_mask_soft)
	_mask_poly = Polygon2D.new()
	_mask_poly.color = Color.WHITE
	_vp.add_child(_mask_poly)
	add_child(_vp)
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/presentation/world/player_sight.gdshader")
	_rect.material = _mat
	_layer.add_child(_rect)
	_mat.set_shader_parameter("mask", _vp.get_texture())
	get_viewport().size_changed.connect(func() -> void: _vp.size = Vector2i(get_viewport().get_visible_rect().size * MASK_SCALE))


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(delta: float) -> void:
	var on: bool = enabled and Settings.get_value("dev", "player_sight", true) != false
	_mat.set_shader_parameter("strength", 1.0 if on else 0.0)
	_mat.set_shader_parameter("vignette", float(Settings.get_value("display", "vignette", 0.55)))
	var a := region_view.local_avatar if region_view != null else null
	if a == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = UPDATE
		_origin = a.global_position + Vector2(0, -20)
		_facing = _facing_of(a)
		_reach = reach()
		_collect_occluders()
		_cast()
	# keep the mask aligned with the main camera every frame
	var ct := get_viewport().get_canvas_transform()
	_vp.canvas_transform = Transform2D(ct.x * MASK_SCALE, ct.y * MASK_SCALE, ct.origin * MASK_SCALE)


func _facing_of(a: PlayerAvatar) -> Vector2:
	var me := Session.local_player()
	if me != null and me.vehicle_id != "":
		var v: VehicleState = Session.world.vehicles.get(me.vehicle_id)
		if v != null:
			return Vector2.from_angle(v.rotation)
	return a._facing_vector()


## How far you can see now (px): daylight, weather, the flashlight.
func reach() -> float:
	var w := Session.world
	if w == null:
		return 900.0
	var r := lerpf(430.0, 980.0, EnvSim.daylight(w))
	match str(w.env.get("weather", "clear")):
		"fog": r *= 0.55
		"blizzard": r *= 0.45
		"snow", "rain": r *= 0.85
		"storm": r *= 0.7
	var me := Session.local_player()
	if me != null and me.flashlight:
		r = maxf(r, 760.0)
	return r


## Reach in a direction: full ahead, less to the sides, a little behind.
func reach_at(dir: Vector2) -> float:
	var c := _facing.normalized().dot(dir)
	var peripheral := 0.32
	var k := clampf((c + 0.35) / 1.0, 0.0, 1.0)  # 1 ahead (within ~110°), 0 behind
	return _reach * lerpf(peripheral, 1.0, k * k * (3.0 - 2.0 * k))


func _collect_occluders() -> void:
	_occ.clear()
	var lim := Rect2(_origin - Vector2.ONE * (_reach + 200.0), Vector2.ONE * (_reach + 200.0) * 2.0)
	for n in get_tree().get_nodes_in_group("sight_occluder"):
		var p := n as Prop
		if p == null or not p.is_inside_tree():
			continue
		var base := p.global_position + p.footprint_offset
		var depth := minf(OCCLUDER_DEPTH, p.footprint.x * 0.45)
		var r := Rect2(base.x - p.footprint.x * 0.5, base.y - p.footprint.y - depth, p.footprint.x, p.footprint.y + depth)
		if r.intersects(lim) and not r.has_point(_origin):
			_occ.append(r)


func _cast() -> void:
	_poly.resize(RAYS)
	for i in RAYS:
		var dir := Vector2.from_angle(TAU * float(i) / RAYS)
		var L := reach_at(dir)
		_poly[i] = _origin + dir * _ray(dir, L)
	_mask_poly.polygon = _poly
	var soft := PackedVector2Array()
	soft.resize(RAYS)
	for i in RAYS:
		soft[i] = _origin + (_poly[i] - _origin) * 1.12 + (_poly[i] - _origin).normalized() * 40.0
	_mask_soft.polygon = soft


func _ray(dir: Vector2, L: float) -> float:
	var best := L
	var inv := Vector2(1.0 / dir.x if absf(dir.x) > 1e-6 else 1e9, 1.0 / dir.y if absf(dir.y) > 1e-6 else 1e9)
	for r in _occ:
		var rr := r as Rect2
		var t1 := (rr.position.x - _origin.x) * inv.x
		var t2 := (rr.end.x - _origin.x) * inv.x
		var t3 := (rr.position.y - _origin.y) * inv.y
		var t4 := (rr.end.y - _origin.y) * inv.y
		var tmin := maxf(minf(t1, t2), minf(t3, t4))
		var tmax := minf(maxf(t1, t2), maxf(t3, t4))
		if tmax >= 0.0 and tmin <= tmax and tmin < best:
			best = maxf(0.0, tmin + 18.0)  # the near face itself stays visible
	return best


## 0..1: how visible a world point is to the local player right now.
func visibility(p: Vector2) -> float:
	if not enabled or Settings.get_value("dev", "player_sight", true) == false:
		return 1.0
	var d := p - _origin
	var dist := d.length()
	if dist < 70.0:
		return 1.0  # right beside you: always sensed
	var dir := d / dist
	var L := reach_at(dir)
	if dist > L:
		return 0.0
	if _ray(dir, dist) < dist - 20.0:
		return 0.0
	return clampf((L - dist) / 120.0, 0.0, 1.0)


func view_polygon() -> PackedVector2Array:
	return _poly
