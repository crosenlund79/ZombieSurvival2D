class_name ZombieView
extends Node2D
## Presentation of one Burnt One (the simulation still calls them zombies). Position, facing, AI state and health come
## from Session.world.zombies (host: live simulation; clients: snapshots) and
## are interpolated here. Readable cues: "?" while investigating, "!" when it
## spots someone, a red wind-up pose before an attack, hit flash, fall on death.
## Sounds are local presentation of state changes — the noise that zombies
## *hear* is a separate host-side system.

const IDS_DOWN := "char.burnt"
const CRAWL_IDS := {"down": ["char.burnt_crawl_down_0", "char.burnt_crawl_down_1"],
	"up": ["char.burnt_crawl_up_0", "char.burnt_crawl_up_1"], "side": ["char.burnt_crawl_side_0", "char.burnt_crawl_side_1"]}
const CROUCH_IDS := {"down": "char.burnt_crouch_down", "up": "char.burnt_crouch_up", "side": "char.burnt_crouch_side"}
static var show_debug := false
const SILHOUETTE_SHADER := preload("res://src/presentation/world/silhouette.gdshader")
## Iteration 012: four body archetypes so Burnt Ones read as different people in
## silhouette (height, build, posture, gait). Picked from the creature's id;
## modest ranges keep them human, never cartoonish.
##   scale: width/height of the shape · skew: forward hunch · lean: held tilt
##   bob: gait bounce · limp: uneven step · crawl: crawl tempo · flat: crawl height
const ARCHETYPES := [
	{"name": "gaunt", "scale": Vector2(0.88, 1.09), "skew": 0.0, "lean": -0.03, "bob": 1.2, "limp": 0.0, "crawl": 1.15, "flat": 1.0},
	{"name": "hunched", "scale": Vector2(1.0, 0.92), "skew": 0.14, "lean": 0.08, "bob": 0.8, "limp": 0.0, "crawl": 0.9, "flat": 0.9},
	{"name": "heavy", "scale": Vector2(1.12, 0.97), "skew": 0.04, "lean": 0.02, "bob": 0.6, "limp": 0.0, "crawl": 0.8, "flat": 1.05},
	{"name": "limping", "scale": Vector2(0.95, 1.02), "skew": 0.06, "lean": -0.06, "bob": 1.0, "limp": 0.7, "crawl": 1.0, "flat": 0.95},
]

var zombie_id := ""
var _sprite: Sprite2D
var _cue: Label
var _debug: Label
var _bar: Node2D
var _target := Vector2.ZERO
var _last_ai := -1
var _shown := ""
var _bob := 0.0
var _flash := 0.0
var _groan_timer := 0.0
var _base_scale_y := 0.0
var _twitch := 0.0
var _twitch_timer := 2.0
var _lean := 0.0
var _frame := 0
var _frame_t := 0.0
var _track_dist := 0.0
var _last_pos := Vector2.INF
var _screech_t := 0.0
var _outdoor := false
var _mat: ShaderMaterial
var _arch: Dictionary = {}
var _jitter := Vector2.ONE
static var _tracks: Array = []   # recent track decals (shared cap across all views)
const MAX_TRACKS := 60


func setup(z: ZombieState) -> void:
	zombie_id = z.zombie_id
	position = z.position
	_target = z.position
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_cue = Label.new()
	_cue.add_theme_font_size_override("font_size", 22)
	_cue.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.05))
	_cue.add_theme_constant_override("outline_size", 6)
	_cue.position = Vector2(-8, -122)
	add_child(_cue)
	_debug = Label.new()
	_debug.add_theme_font_size_override("font_size", 11)
	_debug.position = Vector2(-40, -140)
	add_child(_debug)
	_bar = Node2D.new()
	_bar.position = Vector2(0, -96)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_groan_timer = randf_range(3.0, 9.0)
	var h := absi(z.zombie_id.hash())
	_arch = ARCHETYPES[h % ARCHETYPES.size()]
	_jitter = Vector2(0.97 + float(h / 7 % 7) / 100.0, 0.96 + float(h / 49 % 9) / 100.0)
	_lean = float(_arch["lean"]) + randf_range(-0.03, 0.03)
	_sprite.skew = float(_arch["skew"])
	_mat = ShaderMaterial.new()
	_mat.shader = SILHOUETTE_SHADER
	_sprite.material = _mat
	_outdoor = Session.world != null and Session.world.region_def(z.region_id).has("zombies")
	Assets.reloaded.connect(func() -> void: _shown = "")


func _state() -> ZombieState:
	return Session.world.zombies.get(zombie_id) if Session.world != null else null


func _process(delta: float) -> void:
	var z := _state()
	if z == null:
		return
	_target = z.position
	if position.distance_to(_target) > 200.0:
		position = _target
	var before := position
	position = position.lerp(_target, 1.0 - exp(-10.0 * delta))
	var moving := before.distance_to(position) > 0.2
	_frame_t += delta * (1.0 if moving else 0.25) * float(_arch.get("crawl", 1.0))
	if _frame_t >= (0.09 if z.burst > 0.0 else 0.17):
		_frame_t = 0.0
		_frame = 1 - _frame
	_art(z)
	_signs(z, delta)
	_screech_t = maxf(0.0, _screech_t - delta)
	# Body language: a held, slightly wrong lean, an uneven gait and now and then a
	# sudden jerk of the whole body (unsettling, but physically plausible).
	_bob = _bob + delta * (7.0 if moving else 1.5) * (0.85 + 0.3 * float(_arch.get("bob", 1.0)) * 0.5)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0 and not z.is_dead():
		_twitch_timer = randf_range(1.5, 6.0)
		_twitch = randf_range(-0.16, 0.16)
	_twitch = move_toward(_twitch, 0.0, delta * 0.9)
	_sprite.rotation = _lean + sin(_bob * 0.5) * (0.06 if moving else 0.02) + _twitch
	if z.posture == ZombieState.Posture.CRAWL:
		_sprite.rotation *= 0.4  # low to the ground: the jerks read in the limbs, not a tilt
	if _screech_t > 0.0:  # head thrown back, body shuddering
		_sprite.rotation += sin(_screech_t * 60.0) * 0.05 - 0.12 * _screech_t
		_sprite.scale.y = _base_scale_y * (1.0 + 0.06 * _screech_t)
	elif _base_scale_y > 0.0:
		_sprite.scale.y = _base_scale_y
	var step := absf(sin(_bob)) * float(_arch.get("bob", 1.0))
	if float(_arch.get("limp", 0.0)) > 0.0 and moving:  # an uneven, dragging step
		step = maxf(step, 0.0) * (1.0 + float(_arch["limp"]) * (1.0 if sin(_bob * 0.5) > 0.0 else -0.6))
		_sprite.rotation += sin(_bob * 0.5) * 0.05 * float(_arch["limp"])
	_sprite.offset.y = -step * 3.0 / maxf(_sprite.scale.y, 0.01)
	_flash = maxf(0.0, _flash - delta * 4.0)
	var tint := Color(1, 1, 1).lerp(Color(1.8, 0.6, 0.5), _flash)
	if z.ai == ZombieState.AI.WINDUP:
		tint = tint * Color(1.25, 0.85, 0.8)
	# Silhouette (iteration 012): the tint goes to the shader so a hit or a wind-up
	# warms the dark shape without revealing anything. Developer debug view only
	# (F3 "zombie debug") shows the full figure.
	_sprite.material = null if show_debug else _mat
	if show_debug:
		_sprite.modulate = tint
	else:
		_sprite.modulate = Color(1, 1, 1, 1)
		_mat.set_shader_parameter("tint", tint)
	if z.ai != _last_ai:
		_on_ai_changed(z)
		_last_ai = z.ai
	_cue.text = "?" if z.ai in [ZombieState.AI.INVESTIGATE, ZombieState.AI.LISTEN] else ("!" if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.WINDUP] else "")
	_cue.modulate = Color(1, 0.85, 0.4) if _cue.text == "?" else Color(1, 0.4, 0.3)
	# Iteration 012: no enemy indicators in ordinary play (the "?"/"!" cues and the
	# health bar are technical detail, shown only with the developer AI labels).
	_cue.visible = show_debug
	_debug.visible = show_debug
	if show_debug:
		_debug.text = "%s %s %d" % [zombie_id, z.state_name(), roundi(z.health)]
	_bar.visible = show_debug and z.health < 99.0 and not z.is_dead()
	_bar.queue_redraw()
	_groan_timer -= delta
	if _groan_timer <= 0.0 and not z.is_dead():
		_groan_timer = randf_range(6.0, 14.0)
		Audio.play("sfx.burnt_breath", global_position, EnvSim.sound_mask_db(Session.world))


func _art(z: ZombieState) -> void:
	var id := IDS_DOWN
	var flip := false
	if z.is_dead():
		id = "char.burnt_dead"
	else:
		var f := z.facing
		var side := absf(f.x) > absf(f.y)
		var view := "side" if side else ("up" if f.y < 0 else "down")
		if z.ai == ZombieState.AI.WINDUP:
			id = "char.burnt_side_lunge" if side else "char.burnt_lunge"
		elif z.posture == ZombieState.Posture.CRAWL:
			id = CRAWL_IDS[view][_frame]
		elif z.posture == ZombieState.Posture.CROUCH:
			id = CROUCH_IDS[view]
		elif side:
			id = "char.burnt_side"
		elif f.y < 0:
			id = "char.burnt_up"
		flip = side and f.x < 0
	if id != _shown:
		Assets.apply_to_sprite(_sprite, id)
		var shape: Vector2 = _arch.get("scale", Vector2.ONE) * _jitter
		if z.posture == ZombieState.Posture.CRAWL and not z.is_dead():
			shape.y *= float(_arch.get("flat", 1.0))
		_sprite.position *= shape  # keep the feet on the ground point
		_sprite.scale *= shape
		_base_scale_y = _sprite.scale.y
		_shown = id
	_sprite.flip_h = flip


## Restrained signs of their presence (local, cosmetic): fading tracks in the
## snow — boot prints when upright, hand and knee prints when crawling — a rare
## fleck of dried blood, and kicked-up snow during a crawling burst.
func _signs(z: ZombieState, _delta: float) -> void:
	if not _outdoor or z.is_dead():
		_last_pos = position
		return
	if _last_pos != Vector2.INF:
		_track_dist += _last_pos.distance_to(position)
	_last_pos = position
	if _track_dist < (26.0 if z.posture == ZombieState.Posture.CRAWL else 38.0):
		return
	_track_dist = 0.0
	var host := get_parent().get_parent() as Node2D if get_parent() != null else null
	if host == null:
		return
	# Blood marks are no longer random flecks on tracks: they come only from blood
	# thawed by warmth (BloodSim, iteration 012).
	var kind := "fx.track_hand" if z.posture == ZombieState.Posture.CRAWL else "fx.track_boot"
	var d := Sprite2D.new()
	Assets.apply_to_sprite(d, kind)
	var holder := Node2D.new()
	holder.z_index = -2
	holder.position = position + Vector2(randf_range(-4, 4), -2)
	holder.rotation = z.facing.angle() + PI * 0.5 if kind != "fx.track_blood" else randf() * TAU
	holder.add_child(d)
	host.add_child(holder)
	_tracks.append(holder)
	var tw := holder.create_tween()
	tw.tween_interval(40.0)
	tw.tween_property(holder, "modulate:a", 0.0, 8.0)
	tw.tween_callback(holder.queue_free)
	while _tracks.size() > MAX_TRACKS:
		var old = _tracks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	if z.burst > 0.0:
		_snow_puff()


func _snow_puff() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.9, 0.92, 0.94, 0.8)
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## The screech: head thrown back, the whole body shudders for a moment.
func screech() -> void:
	_screech_t = 1.0
	_twitch = -0.2


func _on_ai_changed(z: ZombieState) -> void:
	match z.ai:
		ZombieState.AI.CHASE:
			if _last_ai in [ZombieState.AI.WANDER, ZombieState.AI.INVESTIGATE, -1]:
				Audio.play("sfx.burnt_notice", global_position, EnvSim.sound_mask_db(Session.world))
		ZombieState.AI.INVESTIGATE:
			if _last_ai == ZombieState.AI.WANDER and randf() < 0.5:
				Audio.play("sfx.burnt_breath", global_position, EnvSim.sound_mask_db(Session.world))
		ZombieState.AI.LISTEN:
			_twitch = 0.12  # a sharp turn of the head toward the sound
		ZombieState.AI.WINDUP:
			Audio.play("sfx.burnt_attack", global_position)
		ZombieState.AI.DEAD:
			var tw := create_tween()
			tw.tween_interval(4.5)
			tw.tween_property(self, "modulate:a", 0.0, 1.2)


func hit_flash() -> void:
	_flash = 1.0


func _draw_bar() -> void:
	var z := _state()
	if z == null:
		return
	var r := Rect2(-22, 0, 44, 5)
	_bar.draw_rect(r.grow(1.5), Color(0.08, 0.07, 0.05, 0.85))
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * z.health / 100.0, r.size.y)), Color("#B5543A"))
