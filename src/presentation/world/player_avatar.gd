class_name PlayerAvatar
extends CharacterBody2D
## Visual + local control for one player. The *local* avatar predicts its own
## movement (with collision) and reports positions to the host at 20 Hz; the
## host validates them. *Remote* avatars only interpolate toward the positions
## the host broadcasts. The avatar never owns the player's saved state.

const SPEED := 220.0           # walking; well below WorldActions.MAX_PLAYER_SPEED
const SPRINT_SPEED := 320.0    # running is faster but makes noise (host decides)
const SEND_INTERVAL := 0.05
const ASSET_ID := "char.player"
## Art per facing (0 down, 1 up, 2 left, 3 right). Side art faces right; left is flipped.
const FACING_ASSETS := ["char.player", "char.player_up", "char.player_side", "char.player_side"]
## Held weapon per facing (0 down, 1 up, 2 left, 3 right): hand offset, rotation,
## mirrored, drawn behind the body. Matches the hands of the figure art.
const WEAPON_POSE := [
	{"pos": Vector2(-16, -28), "rot": -0.35, "flip": false, "behind": false},
	{"pos": Vector2(16, -30), "rot": 0.35, "flip": true, "behind": true},
	{"pos": Vector2(-4, -28), "rot": -0.55, "flip": true, "behind": false},
	{"pos": Vector2(4, -28), "rot": 0.55, "flip": false, "behind": false},
]

## Set by UI while a menu/text field has focus (local input only — the shared
## world keeps running).
static var input_blocked := false

var player_id := ""
var is_local := false
var target_position := Vector2.ZERO
var facing := 0
var camera: Camera2D
var _sprite: Sprite2D
var _label: Label
var _send_accum := 0.0
var _last_sent := Vector2.INF
var _bob := 0.0
var _shown_facing := -1
var _frame := Rect2()        # region bounds the camera frames
var _weapon: Sprite2D
var _swing_tween: Tween
var _flash := 0.0
var _downed := false
var _aim := Vector2.DOWN
var _cam_snap := true
var _seated := false
var _cam_zoom_factor := 1.0
var _sensor: InteractionSensor
var _beam: PointLight2D
var _torch: Sprite2D
var _beam_dir := Vector2.DOWN
## Iteration 012 (experiment): set when this avatar is shown in a side-view
## bunker level. Its node position is then a side-view screen position; moves
## are reported in plan coordinates (SideSection.to_plan).
var side_region_id := ""
var _climbing := false
const CLIMB_SPEED := 150.0
const FALL_SPEED := 520.0


## bounds: camera limits (empty Rect2 = no limits). light: carry a small light.
static func create(state: PlayerState, local: bool, bounds: Rect2, light: bool = false) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.player_id = state.player_id
	a.is_local = local
	a.name = "Player_" + state.player_id.substr(0, 6)
	a.position = state.position
	a.target_position = state.position
	a._build(state.display_name, bounds)
	if light:
		a.add_child(LightFactory.lantern_light(Color(1.0, 0.86, 0.6), 1.5 if local else 1.0, 0.9 if local else 0.55))
	else:
		# Outdoors a small torch fades in at night so players stay readable.
		var torch := LightFactory.lantern_light(Color(1.0, 0.88, 0.66), 1.6 if local else 1.1, 0.0)
		torch.name = "NightTorch"
		a.add_child(torch)
	return a


func _build(display_name: String, bounds: Rect2) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_apply_art()
	_weapon = Sprite2D.new()
	_weapon.position = Vector2(14, -34)
	_weapon.rotation = 0.5
	add_child(_weapon)
	refresh_weapon()
	_torch = Sprite2D.new()
	_torch.visible = false
	add_child(_torch)
	_beam = LightFactory.cone_light(Color(1.0, 0.95, 0.82), 3.0, 0.0)
	_beam.name = "Flashlight"
	_beam.position = Vector2(0, -30)
	_beam.visible = false
	add_child(_beam)
	_label = Label.new()
	_label.text = display_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, -Assets.display_size(ASSET_ID).y - 24)
	_label.size = Vector2(120, 20)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.07))
	_label.add_theme_constant_override("outline_size", 4)
	_label.modulate = Color(1, 0.95, 0.82) if is_local else Color(0.85, 0.95, 1.0)
	add_child(_label)
	if is_local:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 13.0
		shape.shape = circle
		shape.position = Vector2(0, -8)
		add_child(shape)
		camera = Camera2D.new()
		camera.top_level = true  # positioned by _update_camera (framing), not by the avatar
		_frame = bounds
		var z := Settings.camera_zoom()
		camera.zoom = Vector2(z, z)
		add_child(camera)
		var sensor := InteractionSensor.new()
		sensor.name = "InteractionSensor"
		add_child(sensor)
		_sensor = sensor
	else:
		collision_layer = 0
		collision_mask = 0


func _ready() -> void:
	Assets.reloaded.connect(_apply_art)
	if is_local:
		add_to_group("local_avatar")
		camera.make_current()
		Session.local_position_corrected.connect(_on_corrected)


func _apply_art() -> void:
	_shown_facing = facing
	var id: String = FACING_ASSETS[clampi(facing, 0, 3)]
	if not AssetCatalog.has(id):
		id = ASSET_ID
	Assets.apply_to_sprite(_sprite, id)


func _physics_process(delta: float) -> void:
	_night_torch(delta)
	_update_flashlight(delta)
	var me: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
	_set_seated(me != null and me.vehicle_id != "")
	if is_local:
		if _seated:
			_ride(delta, me.vehicle_id)
		elif side_region_id != "":
			_local_move_side(delta)
		else:
			_local_move(delta)
		_update_camera(delta)
	else:
		var p: PlayerState = me
		if p != null:
			target_position = side_display(p.position) if side_region_id != "" else p.position
			facing = p.facing
		if position.distance_to(target_position) > 300.0:
			position = target_position
		var before := position
		position = position.lerp(target_position, 1.0 - exp(-12.0 * delta))
		_animate(delta, (position - before).length() > 0.3)


func _local_move(delta: float) -> void:
	var dir := Vector2.ZERO
	if not input_blocked:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("sprint") and not input_blocked
	velocity = dir * (SPRINT_SPEED if running else SPEED)
	if _downed:
		velocity = Vector2.ZERO
	move_and_slide()
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing = 2 if dir.x < 0 else 3
		else:
			facing = 1 if dir.y < 0 else 0
	_animate(delta, dir != Vector2.ZERO)
	_send_accum += delta
	if _send_accum >= SEND_INTERVAL:
		_send_accum = 0.0
		if global_position.distance_to(_last_sent) > 0.5:
			_last_sent = global_position
			Session.submit_local_move(global_position, facing)


func _side_region() -> RegionState:
	return Session.world.region(side_region_id) if Session.world != null else null


## Where a player at plan position `plan` is drawn in the side view: as reported
## when it is open air on a ladder or scaffold (climbing), else on the floor.
func side_display(plan: Vector2) -> Vector2:
	var r := _side_region()
	if r == null:
		return plan
	var at := plan
	var on_floor := absf(SideSection.floor_y(r, plan.x, plan.y - 4.0) - plan.y) < 6.0
	if not on_floor and not (SideSection.open_at(r, plan + Vector2(0, -6)) and SideSection.climbable(Session.world, r, plan)):
		at = SideSection.rest(r, plan)
	return SideSection.to_screen(r, at)


## Side-view control: A/D walk along the floor (one-row steps, no jumping),
## W/S climb a ladder or a timber scaffold, and you drop back to the floor
## when you step off. Reported to the host in plan coordinates.
func _local_move_side(delta: float) -> void:
	var r := _side_region()
	if r == null:
		return
	var input := Vector2.ZERO
	if not input_blocked and not _downed:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("sprint") and not input_blocked
	var plan := SideSection.to_plan(r, global_position)
	var floor_now := SideSection.floor_y(r, plan.x, plan.y - 4.0)
	var can_climb := SideSection.climbable(Session.world, r, plan)
	if can_climb and absf(input.y) > 0.4:
		_climbing = true
	if not can_climb:
		_climbing = false
	var moved := false
	if _climbing:
		var top := SideSection.ceiling_y(r, plan.x, plan.y - 4.0) + SideSection.row_h(r) * 0.9
		plan.y = clampf(plan.y + input.y * CLIMB_SPEED * delta, top, floor_now)
		moved = absf(input.y) > 0.1
		if plan.y >= floor_now - 0.5 and input.y >= 0.0:
			_climbing = false
	if absf(input.x) > 0.1:
		var dx := input.x * (SPRINT_SPEED if running else SPEED) * delta
		var next := SideSection.walk(Session.world, r, plan, dx)
		if next != plan:
			plan = next
			moved = true
			if not SideSection.climbable(Session.world, r, plan):
				_climbing = false
	if not _climbing:  # step off a scaffold or ledge: back down to the floor
		var f := SideSection.floor_y(r, plan.x, plan.y - 4.0)
		if plan.y < f:
			plan.y = move_toward(plan.y, f, FALL_SPEED * delta)
		elif plan.y > f + 0.5:
			plan.y = f
	velocity = Vector2.ZERO
	global_position = SideSection.to_screen(r, plan)
	if absf(input.x) > 0.1:
		facing = 2 if input.x < 0.0 else 3
	elif _climbing and absf(input.y) > 0.1:
		facing = 1
	_animate(delta, moved)
	_send_accum += delta
	if _send_accum >= SEND_INTERVAL:
		_send_accum = 0.0
		if plan.distance_to(_last_sent) > 0.5:
			_last_sent = plan
			Session.submit_local_move(plan, facing)


## In a vehicle the avatar is hidden, passes through everything and rides
## along with the car's view (the host keeps the saved position on the car).
func _set_seated(value: bool) -> void:
	if value == _seated:
		return
	_seated = value
	_sprite.visible = not value
	_label.visible = not value
	if value:
		_weapon.visible = false
	else:
		refresh_weapon()
	var torch := get_node_or_null("NightTorch")
	if torch != null:
		torch.visible = not value
	if is_local:
		collision_layer = 0 if value or side_region_id != "" else 1
		collision_mask = 0 if value or side_region_id != "" else 1
		if _sensor != null:
			_sensor.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
			if value and _sensor.focused != null and is_instance_valid(_sensor.focused):
				_sensor.focused.set_focused(false)
				_sensor.focused = null


func _ride(_delta: float, vehicle_id: String) -> void:
	velocity = Vector2.ZERO
	var rv := RegionView.find_for(self)
	var vv := rv.vehicle_view(vehicle_id) if rv != null else null
	if vv != null:
		global_position = vv.global_position


func vehicle_view() -> VehicleView:
	var p: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
	if p == null or p.vehicle_id == "":
		return null
	var rv := RegionView.find_for(self)
	return rv.vehicle_view(p.vehicle_id) if rv != null else null


## Presentation only: a small bob while walking, horizontal flip by facing.
func _animate(delta: float, moving: bool) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	var tint := Color(1, 1, 1).lerp(Color(1.9, 0.55, 0.5), _flash)
	tint.a = _sprite.modulate.a
	_sprite.modulate = tint
	if facing != _shown_facing:
		_apply_art()
		if _swing_tween == null or not _swing_tween.is_valid():
			_place_weapon()
	_sprite.flip_h = facing == 2
	_bob = _bob + delta * 12.0 if moving else 0.0
	_sprite.offset.y = -absf(sin(_bob)) * 6.0 / maxf(_sprite.scale.y, 0.01)


func _on_corrected(pos: Vector2) -> void:
	global_position = SideSection.to_screen(_side_region(), pos) if side_region_id != "" and _side_region() != null else pos
	_last_sent = pos
	_cam_snap = true


## Camera framing: a region smaller than the view stays centred (rooms, bunker
## levels); a larger one is followed but never shows beyond its bounds.
func _update_camera(delta: float) -> void:
	var target := global_position + Vector2(0, -24)
	# Driving: look ahead along the car's motion and pull the camera back a little.
	var vv := vehicle_view() if _seated else null
	if vv != null:
		target += Vector2.from_angle(vv.heading) * clampf(vv.speed, -150.0, 430.0) * 0.45
	var want_zoom := 0.82 if _seated else 1.0
	if absf(_cam_zoom_factor - want_zoom) > 0.001:
		var base := camera.zoom.x / _cam_zoom_factor
		_cam_zoom_factor = move_toward(_cam_zoom_factor, want_zoom, delta * 0.5)
		camera.zoom = Vector2.ONE * base * _cam_zoom_factor
	if _frame.has_area():
		var vis := get_viewport_rect().size / camera.zoom
		for axis in 2:
			if _frame.size[axis] <= vis[axis]:
				target[axis] = _frame.get_center()[axis]
			else:
				target[axis] = clampf(target[axis], _frame.position[axis] + vis[axis] * 0.5, _frame.end[axis] - vis[axis] * 0.5)
	if _cam_snap:
		camera.global_position = target
		_cam_snap = false
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-6.0 * delta))


func snap_camera() -> void:
	_cam_snap = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or input_blocked:
		return
	if _seated:
		var p: PlayerState = Session.local_player()
		if p != null and p.vehicle_id != "":
			if event.is_action_pressed("interact"):
				Session.request_vehicle(p.vehicle_id, "exit")
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("vehicle_engine"):
				Session.request_vehicle(p.vehicle_id, "engine")
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("attack"):
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("flashlight"):
		Session.request_inventory("flashlight", "")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack") and not _downed and BuildMode.placing == "":
		var aim := _facing_vector()
		if event is InputEventMouseButton:
			aim = (get_global_mouse_position() - (global_position + Vector2(0, -30))).normalized()
		play_swing(aim)
		Session.request_attack(aim)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("zoom_in"):
		_set_zoom(camera.zoom.x * 1.1)
	elif event.is_action_pressed("zoom_out"):
		_set_zoom(camera.zoom.x / 1.1)


func _facing_vector() -> Vector2:
	return [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][clampi(facing, 0, 3)]


## Visual swing (club or fists). Presentation only; the host decides hits.
func play_swing(aim: Vector2) -> void:
	_aim = aim
	if aim.x < -0.3:
		_sprite.flip_h = true
	elif aim.x > 0.3:
		_sprite.flip_h = false
	Audio.play("sfx.swing", global_position)
	var base := aim.angle() + PI / 2.0
	_weapon.visible = true
	_weapon.position = Vector2(0, -34) + aim * 10.0
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_weapon.rotation = base - 1.3
	_swing_tween = create_tween()
	_swing_tween.tween_property(_weapon, "rotation", base + 1.2, 0.14).set_trans(Tween.TRANS_QUAD)
	_swing_tween.tween_interval(0.12)
	_swing_tween.tween_callback(refresh_weapon)


func _night_torch(delta: float) -> void:
	var t := get_node_or_null("NightTorch") as PointLight2D
	if t == null or Session.world == null:
		return
	var want := (1.0 - EnvSim.daylight(Session.world)) * (0.85 if is_local else 0.5)
	t.energy = move_toward(t.energy, want, delta)
	t.visible = t.energy > 0.01


func refresh_weapon() -> void:
	var p: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
	var held := p.weapon if p != null else ""
	var art := "item." + held
	_weapon.visible = held != "" and AssetCatalog.has(art) and not _seated
	if _weapon.visible:
		Assets.apply_to_sprite(_weapon, art)
		# Keep the art's grip point (its pivot, near the handle end) on the node origin,
		# so the weapon sits in the hand and turns around the grip in every facing.
		_weapon.offset = _weapon.position / _weapon.scale
	_place_weapon()


func _place_weapon() -> void:
	var pose: Dictionary = WEAPON_POSE[clampi(facing, 0, 3)]
	_weapon.position = pose["pos"]
	_weapon.rotation = pose["rot"]
	_weapon.flip_h = pose["flip"]
	_weapon.z_index = -1 if pose["behind"] else 1


## Flashlight (iteration 011 D): the replicated on/off state lights a beam in the
## direction the player faces (the local player's beam follows movement smoothly).
func _update_flashlight(delta: float) -> void:
	var p: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
	var on := p != null and p.flashlight and not _seated and not _downed
	var want_dir := _facing_vector()
	if is_local and not input_blocked:
		var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if d != Vector2.ZERO:
			want_dir = d.normalized()
		else:
			want_dir = _beam_dir
	_beam_dir = Vector2.from_angle(lerp_angle(_beam_dir.angle(), want_dir.angle(), 1.0 - exp(-10.0 * delta)))
	var dark := 1.0 - EnvSim.daylight(Session.world) if Session.world != null else 0.0
	_beam.energy = move_toward(_beam.energy, (0.45 + 1.1 * dark) if on else 0.0, delta * 6.0)
	_beam.visible = _beam.energy > 0.01
	_beam.rotation = _beam_dir.angle()
	_beam.position = Vector2(0, -30) + _beam_dir * 10.0
	if on and not _torch.visible and AssetCatalog.has("item.flashlight"):
		Assets.apply_to_sprite(_torch, "item.flashlight")
	_torch.visible = on
	if on:
		_torch.position = Vector2(0, -30) + Vector2(_beam_dir.x * 12.0, _beam_dir.y * 6.0)
		_torch.rotation = _beam_dir.angle() if _beam_dir.x >= 0.0 else _beam_dir.angle() + PI
		_torch.flip_h = _beam_dir.x < 0.0
		_torch.z_index = -1 if _beam_dir.y < -0.5 else 1


func hurt_flash() -> void:
	_flash = 1.0


func set_downed(value: bool) -> void:
	if value == _downed:
		return
	_downed = value
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation", 1.45 if value else 0.0, 0.35)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.6 if value else 1.0, 0.35)


func _set_zoom(z: float) -> void:
	z = clampf(z / _cam_zoom_factor, SettingsService.ZOOM_MIN, SettingsService.ZOOM_MAX)
	camera.zoom = Vector2(z, z) * _cam_zoom_factor
	Settings.set_value("display", "camera_zoom", z)
