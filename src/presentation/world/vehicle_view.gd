class_name VehicleView
extends CharacterBody2D
## Presentation and local driving of one vehicle (iteration 011).
##
## Everyone sees the car from VehicleState (Session.world.vehicles). When the
## local player is the driver this view *predicts* the car: it reads input,
## runs simple top-down car physics with collision and reports poses to the
## host at 20 Hz (Session.submit_vehicle_pose); the host validates and may
## snap it back (Session.vehicle_corrected). Everyone else interpolates.
## The car is solid for players walking around it. Art: 16 headings
## (vehicle.wagon_00 = facing east, counter-clockwise... see HEADING_ASSETS),
## each replaceable by the creator.

const SEND_INTERVAL := 0.05
## Ground-plane foreshortening of the oblique view (matches the art generator).
const OBLIQUE := 0.6
## One illustration per screen heading, index i = heading of i * 22.5 degrees
## clockwise from east (screen y points down).
const HEADING_ASSETS := ["vehicle.wagon_00", "vehicle.wagon_01", "vehicle.wagon_02", "vehicle.wagon_03",
	"vehicle.wagon_04", "vehicle.wagon_05", "vehicle.wagon_06", "vehicle.wagon_07",
	"vehicle.wagon_08", "vehicle.wagon_09", "vehicle.wagon_10", "vehicle.wagon_11",
	"vehicle.wagon_12", "vehicle.wagon_13", "vehicle.wagon_14", "vehicle.wagon_15"]

var vehicle_id := ""
var heading := 0.0             # screen angle (radians) the car points at
var speed := 0.0               # signed px/s
var steer := 0.0
var _sprite: Sprite2D
var _shape: CollisionPolygon2D
var _shown_index := -1
var _shape_heading := INF
var _send_accum := 0.0
var _last_sent := {}
var _lights: Array[PointLight2D] = []
var _tail: PointLight2D
var _engine: AudioStreamPlayer2D
var _interact: Interactable
var _bump_cd := 0.0
var _exhaust: CPUParticles2D
var _driving := false


static func create(v: VehicleState) -> VehicleView:
	var view := VehicleView.new()
	view.vehicle_id = v.vehicle_id
	view.name = "Vehicle_" + v.vehicle_id
	view.position = v.position
	view.heading = v.rotation
	view.speed = v.speed
	return view


func state() -> VehicleState:
	return Session.world.vehicles.get(vehicle_id) if Session.world != null else null


func vdef() -> Dictionary:
	var v := state()
	return VehicleSim.vdef(v) if v != null else {}


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_shape = CollisionPolygon2D.new()
	add_child(_shape)
	for side in [-1.0, 1.0]:
		var l := LightFactory.cone_light(Color(1.0, 0.93, 0.78), 2.6, 0.0)
		l.visible = false
		add_child(l)
		_lights.append(l)
		l.set_meta("side", side)
	_tail = LightFactory.lantern_light(Color(1.0, 0.25, 0.18), 0.35, 0.0)
	_tail.visible = false
	add_child(_tail)
	_engine = AudioStreamPlayer2D.new()
	_engine.bus = "SFX"
	_engine.max_distance = 1400.0
	add_child(_engine)
	_exhaust = CPUParticles2D.new()
	_exhaust.amount = 14
	_exhaust.lifetime = 1.6
	_exhaust.emitting = false
	_exhaust.gravity = Vector2(0, -14)
	_exhaust.initial_velocity_min = 8.0
	_exhaust.initial_velocity_max = 20.0
	_exhaust.texture = LightFactory.radial_texture()
	_exhaust.scale_amount_min = 0.06
	_exhaust.scale_amount_max = 0.14
	_exhaust.color = Color(0.86, 0.86, 0.84, 0.35)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_exhaust.color_ramp = fade
	_exhaust.z_index = 1
	add_child(_exhaust)
	_interact = Interactable.new()
	_interact.entity_id = "vehicle:" + vehicle_id
	_interact.prompt_key = "PROMPT_ENTER_VEHICLE"
	_interact.reach = float(vdef().get("enter_range", 120))
	_interact.priority = 3
	_interact.on_activate = func() -> void: Session.request_vehicle(vehicle_id, "enter")
	_interact.on_repair = _open_trunk
	_interact.secondary_key = "PROMPT_VEHICLE_TRUNK"
	add_child(_interact)
	Assets.reloaded.connect(_apply_art)
	Session.vehicle_corrected.connect(_on_corrected)
	_apply_art()
	_update_shape()


func _apply_art() -> void:
	_shown_index = -1
	_update_art()


func heading_index() -> int:
	return posmod(roundi(heading / (TAU / 16.0)), 16)


func _update_art() -> void:
	var i := heading_index()
	if i == _shown_index:
		return
	_shown_index = i
	var id: String = HEADING_ASSETS[i]
	if AssetCatalog.has(id):
		Assets.apply_to_sprite(_sprite, id)


## Ground footprint for the current heading, projected like the art.
func _update_shape() -> void:
	if absf(angle_difference(_shape_heading, heading)) < 0.05:
		return
	_shape_heading = heading
	var d := vdef()
	var hl := float(d.get("length", 170)) * 0.5
	var hw := float(d.get("width", 74)) * 0.5
	# screen heading -> ground heading of the oblique projection
	var g := atan2(sin(heading) / OBLIQUE, cos(heading))
	var pts := PackedVector2Array()
	for c in [Vector2(hl, hw), Vector2(hl, -hw), Vector2(-hl, -hw), Vector2(-hl, hw)]:
		var r: Vector2 = (c as Vector2).rotated(g)
		pts.append(Vector2(r.x, r.y * OBLIQUE))
	_shape.polygon = pts


## Half extent of the car along its screen heading (front bumper distance).
func front_offset() -> float:
	var d := vdef()
	var g := atan2(sin(heading) / OBLIQUE, cos(heading))
	var f := Vector2(float(d.get("length", 170)) * 0.5, 0).rotated(g)
	return Vector2(f.x, f.y * OBLIQUE).length()


func _physics_process(delta: float) -> void:
	var v := state()
	if v == null:
		queue_free()
		return
	_driving = v.driver() == Session.local_player_id and Session.local_player_id != ""
	if _driving:
		_drive(delta, v)
	else:
		if position.distance_to(v.position) > 400.0:
			position = v.position
		position = position.lerp(v.position, 1.0 - exp(-12.0 * delta))
		heading = lerp_angle(heading, v.rotation, 1.0 - exp(-12.0 * delta))
		speed = v.speed
		steer = v.steer
	# Seated players pass through their own car; outsiders bump into it.
	var me := Session.local_player()
	collision_layer = 0 if (me != null and me.vehicle_id == vehicle_id) else 1
	_interact.enabled = me != null and me.vehicle_id == ""
	_update_art()
	_update_shape()
	_update_effects(delta, v)


func _drive(delta: float, v: VehicleState) -> void:
	var d := vdef()
	var throttle := 0.0
	var turn := 0.0
	if not PlayerAvatar.input_blocked:
		throttle = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
		turn = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var max_f := float(d.get("max_speed", 430))
	var max_r := float(d.get("reverse_speed", 150))
	if not v.engine_on:
		throttle = 0.0
	if throttle > 0.0:
		speed += (float(d.get("accel", 230)) if speed >= 0.0 else float(d.get("brake", 560))) * throttle * delta
	elif throttle < 0.0:
		speed -= (float(d.get("brake", 560)) if speed > 0.0 else float(d.get("accel", 230)) * 0.6) * -throttle * delta
	else:
		speed = move_toward(speed, 0.0, float(d.get("coast", 120)) * delta)
	speed = clampf(speed, -max_r, max_f)
	steer = move_toward(steer, turn, delta * 5.0)
	var grip := clampf(absf(speed) / 140.0, 0.0, 1.0) * signf(speed)
	heading = wrapf(heading + steer * float(d.get("turn_rate", 2.1)) * grip * delta, -PI, PI)
	velocity = Vector2.from_angle(heading) * speed
	move_and_slide()
	_bump_cd = maxf(0.0, _bump_cd - delta)
	if get_slide_collision_count() > 0:
		var hit := get_slide_collision(0)
		var into := -Vector2.from_angle(heading).dot(hit.get_normal()) * signf(speed)
		if into > 0.4:
			if absf(speed) > 160.0 and _bump_cd <= 0.0:
				Audio.play("sfx.hit_metal", global_position)
				_bump_cd = 0.6
			speed *= -0.25
	_send_accum += delta
	if _send_accum >= SEND_INTERVAL:
		_send_accum = 0.0
		var pose := {"p": global_position.snapped(Vector2(0.5, 0.5)), "r": snappedf(heading, 0.002), "s": snappedf(speed, 1.0)}
		if pose != _last_sent:
			_last_sent = pose
			Session.submit_vehicle_pose(vehicle_id, global_position, heading, speed, steer)


func _on_corrected(id: String) -> void:
	if id != vehicle_id:
		return
	var v := state()
	if v != null:
		position = v.position
		heading = v.rotation
		speed = 0.0


func _update_effects(delta: float, v: VehicleState) -> void:
	var dark := 1.0 - EnvSim.daylight(Session.world) if Session.world != null else 0.0
	var dir := Vector2.from_angle(heading)
	var front := front_offset()
	for l in _lights:
		var side := float(l.get_meta("side"))
		var want := (0.35 + dark * 1.1) if v.engine_on else 0.0
		l.energy = move_toward(l.energy, want, delta * 3.0)
		l.visible = l.energy > 0.01
		l.rotation = heading
		l.position = dir * (front - 6.0) + dir.orthogonal() * side * 18.0 + Vector2(0, -26)
	_tail.energy = move_toward(_tail.energy, (0.25 + dark * 0.6) if v.engine_on else 0.0, delta * 3.0)
	_tail.visible = _tail.energy > 0.01
	_tail.position = -dir * front + Vector2(0, -22)
	_exhaust.emitting = v.engine_on
	_exhaust.position = -dir * (front + 4.0) + Vector2(0, -10)
	if v.engine_on:
		if not _engine.playing:
			_engine.stream = Assets.audio_stream("sfx.engine_loop")
			_engine.volume_db = float(Assets.info("sfx.engine_loop").get("volume_db", -8.0))
			if _engine.stream != null:
				_engine.play()
		var load := clampf(absf(speed) / float(vdef().get("max_speed", 430)), 0.0, 1.0)
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.85 + load * 0.95, 1.0 - exp(-4.0 * delta))
	elif _engine.playing:
		_engine.stop()


func _open_trunk() -> void:
	MachinePanel.open(self, state().region_id if state() != null else "", "vehicle:" + vehicle_id, trunk_panel,
		func(action: String, arg: String) -> void: Session.request_vehicle(vehicle_id, action, arg))


## Trunk panel: contents and store / take buttons (requests only).
func trunk_panel() -> Dictionary:
	var v := state()
	var me := Session.local_player()
	if v == null or me == null:
		return {"title": "", "lines": [], "buttons": []}
	var items: Dictionary = v.cargo.get("items", {})
	var gear: Array = v.cargo.get("gear", [])
	var lines: Array = [UITheme.fmt("STRUCT_CONTAINS", [Hud.bag_text(items) + Hud.gear_text(gear),
		Items.slots(items) + gear.size(), int(vdef().get("cargo_slots", 12))])]
	var buttons: Array = []
	var cap := int(vdef().get("cargo_slots", 12))
	var used := Items.slots(items) + gear.size()
	var loose := me.gear.filter(func(g): return not (str(g["uid"]) in me.equipped.values()))
	buttons.append([TranslationServer.translate("TRUNK_STORE_ALL"), "store_all", "", used < cap and (not me.carried.is_empty() or not loose.is_empty())])
	buttons.append([TranslationServer.translate("TRUNK_TAKE_ALL"), "take_all", "", used > 0 and Inv.free_slots(me) > 0])
	if used >= cap:
		lines.append(TranslationServer.translate("TRUNK_FULL"))
	for item in me.carried:
		buttons.append([UITheme.fmt("STRUCT_STORE", [me.carrying(item), TranslationServer.translate(Items.name_key(item))]), "store", item, used < cap])
	for g in me.gear:
		buttons.append([UITheme.fmt("STRUCT_STORE", [1, TranslationServer.translate(Items.name_key(str(g["item"])))]), "store", str(g["uid"]), used < cap])
	for item2 in items:
		buttons.append([UITheme.fmt("STRUCT_TAKE", [int(items[item2]), TranslationServer.translate(Items.name_key(item2))]), "take", item2, Inv.free_slots(me) > 0])
	for g2 in gear:
		buttons.append([UITheme.fmt("STRUCT_TAKE", [1, TranslationServer.translate(Items.name_key(str(g2["item"])))]), "take", str(g2["uid"]), Inv.free_slots(me) > 0])
	return {"title": TranslationServer.translate("VEHICLE_TRUNK"), "lines": lines, "buttons": buttons}
