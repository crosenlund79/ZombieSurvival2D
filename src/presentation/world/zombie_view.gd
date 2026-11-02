class_name ZombieView
extends Node2D
## Presentation of one zombie. Position, facing, AI state and health come
## from Session.world.zombies (host: live simulation; clients: snapshots) and
## are interpolated here. Readable cues: "?" while investigating, "!" when it
## spots someone, a red wind-up pose before an attack, hit flash, fall on death.
## Sounds are local presentation of state changes — the noise that zombies
## *hear* is a separate host-side system.

const IDS_DOWN := "char.zombie"
static var show_debug := false

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
	_art(z)
	# Shamble: uneven bob and lean.
	_bob = _bob + delta * (7.0 if moving else 1.5)
	_sprite.rotation = sin(_bob * 0.5) * (0.07 if moving else 0.03)
	_sprite.offset.y = -absf(sin(_bob)) * 3.0 / maxf(_sprite.scale.y, 0.01)
	_flash = maxf(0.0, _flash - delta * 4.0)
	var tint := Color(1, 1, 1).lerp(Color(1.8, 0.6, 0.5), _flash)
	if z.ai == ZombieState.AI.WINDUP:
		tint = tint * Color(1.25, 0.85, 0.8)
	_sprite.modulate = tint
	if z.ai != _last_ai:
		_on_ai_changed(z)
		_last_ai = z.ai
	_cue.text = "?" if z.ai == ZombieState.AI.INVESTIGATE else ("!" if z.ai in [ZombieState.AI.CHASE, ZombieState.AI.WINDUP] else "")
	_cue.modulate = Color(1, 0.85, 0.4) if _cue.text == "?" else Color(1, 0.4, 0.3)
	_debug.visible = show_debug
	if show_debug:
		_debug.text = "%s %s %d" % [zombie_id, z.state_name(), roundi(z.health)]
	_bar.visible = z.health < 99.0 and not z.is_dead()
	_bar.queue_redraw()
	_groan_timer -= delta
	if _groan_timer <= 0.0 and not z.is_dead():
		_groan_timer = randf_range(6.0, 14.0)
		Audio.play("sfx.zombie_groan", global_position)


func _art(z: ZombieState) -> void:
	var id := IDS_DOWN
	var flip := false
	if z.is_dead():
		id = "char.zombie_dead"
	else:
		var f := z.facing
		var side := absf(f.x) > absf(f.y)
		if z.ai == ZombieState.AI.WINDUP:
			id = "char.zombie_side_lunge" if side else "char.zombie_lunge"
		elif side:
			id = "char.zombie_side"
		elif f.y < 0:
			id = "char.zombie_up"
		flip = side and f.x < 0
	if id != _shown:
		Assets.apply_to_sprite(_sprite, id)
		_shown = id
	_sprite.flip_h = flip


func _on_ai_changed(z: ZombieState) -> void:
	match z.ai:
		ZombieState.AI.CHASE:
			if _last_ai in [ZombieState.AI.WANDER, ZombieState.AI.INVESTIGATE, -1]:
				Audio.play("sfx.zombie_alert", global_position)
		ZombieState.AI.INVESTIGATE:
			if _last_ai == ZombieState.AI.WANDER and randf() < 0.5:
				Audio.play("sfx.zombie_groan", global_position)
		ZombieState.AI.WINDUP:
			Audio.play("sfx.zombie_attack", global_position)
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
