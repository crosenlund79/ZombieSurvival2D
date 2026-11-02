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
	_weapon = Sprite2D.new()
	_weapon.position = Vector2(14, -34)
	_weapon.rotation = 0.5
	add_child(_weapon)
	refresh_weapon()
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


## Presentation only: a small bob while walking, horizontal flip by facing.
func _animate(delta: float, moving: bool) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	var tint := Color(1, 1, 1).lerp(Color(1.9, 0.55, 0.5), _flash)
	tint.a = _sprite.modulate.a
	_sprite.modulate = tint
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


func refresh_weapon() -> void:
	var p: PlayerState = Session.world.players.get(player_id) if Session.world != null else null
	var held := p.weapon if p != null else ""
	var art := "item." + held
	_weapon.visible = held != "" and AssetCatalog.has(art)
	if _weapon.visible:
		Assets.apply_to_sprite(_weapon, art)
	_weapon.position = Vector2(14, -34)
	_weapon.rotation = 0.5


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
	z = clampf(z, SettingsService.ZOOM_MIN, SettingsService.ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	Settings.set_value("display", "camera_zoom", z)
