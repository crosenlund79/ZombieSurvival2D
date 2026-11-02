class_name PlayerAvatar
extends CharacterBody2D
## Visual + local control for one player. The *local* avatar predicts its own
## movement (with collision) and reports positions to the host at 20 Hz; the
## host validates them. *Remote* avatars only interpolate toward the positions
## the host broadcasts. The avatar never owns the player's saved state.

const SPEED := 220.0           # below WorldActions.MAX_PLAYER_SPEED
const SEND_INTERVAL := 0.05
const ASSET_ID := "char.player"
## Art per facing (0 down, 1 up, 2 left, 3 right). Side art faces right; left is flipped.
const FACING_ASSETS := ["char.player", "char.player_up", "char.player_side", "char.player_side"]

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
var _cam_snap := true


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
	return a


func _build(display_name: String, bounds: Rect2) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_apply_art()
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
	if is_local:
		_local_move(delta)
		_update_camera(delta)
	else:
		var p: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
		if p != null:
			target_position = p.position
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
	velocity = dir * SPEED
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


## Presentation only: a small bob while walking, horizontal flip by facing.
func _animate(delta: float, moving: bool) -> void:
	if facing != _shown_facing:
		_apply_art()
	_sprite.flip_h = facing == 2
	_bob = _bob + delta * 12.0 if moving else 0.0
	_sprite.offset.y = -absf(sin(_bob)) * 6.0 / maxf(_sprite.scale.y, 0.01)


func _on_corrected(pos: Vector2) -> void:
	global_position = pos
	_last_sent = pos
	_cam_snap = true


## Camera framing: a region smaller than the view stays centred (rooms, bunker
## levels); a larger one is followed but never shows beyond its bounds.
func _update_camera(delta: float) -> void:
	var target := global_position + Vector2(0, -24)
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
	if event.is_action_pressed("zoom_in"):
		_set_zoom(camera.zoom.x * 1.1)
	elif event.is_action_pressed("zoom_out"):
		_set_zoom(camera.zoom.x / 1.1)


func _set_zoom(z: float) -> void:
	z = clampf(z, SettingsService.ZOOM_MIN, SettingsService.ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	Settings.set_value("display", "camera_zoom", z)
