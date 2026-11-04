class_name NpcView
extends Node2D
## Shows one survivor from replicated world data (host simulates; this view
## only interpolates position and shows activity). Talking opens the survivor
## panel (assign work); every choice is a host request.
## Red Thaw: before they trust you (recruit "waiting"/"met") the survivor is
## huddled in a sheltered corner — trembling, now and then muttering a broken
## line, flinching and answering with a fragment when spoken to. These are local
## presentation only (each player hears their own mutters); recruitment itself
## stays host-validated in NpcSim.

var npc_id := ""
var _sprite: Sprite2D
var _label: Label
var _status: Label
var interact: Interactable
var _bob := 0.0
var _say: Label
var _say_time := 0.0
var _mutter_timer := 6.0
var _flinch := 0.0
var _t := 0.0
var _huddled := false
var _pivot := Vector2.ZERO  # sprite position that puts the art's ground point on the node


static func create(id: String) -> NpcView:
	var v := NpcView.new()
	v.npc_id = id
	v.name = "Npc_" + id
	return v


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_label = UITheme.small("", 12)
	_label.position = Vector2(-60, -112)
	_label.size = Vector2(120, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_status = UITheme.small("", 11)
	_status.position = Vector2(-90, -98)
	_status.size = Vector2(180, 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 3)
	add_child(_status)
	_say = UITheme.small("", 13)
	_say.position = Vector2(-130, -150)
	_say.size = Vector2(260, 40)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86))
	_say.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_say.add_theme_constant_override("outline_size", 4)
	_say.modulate.a = 0.0
	add_child(_say)
	_mutter_timer = randf_range(4.0, 10.0)
	interact = Interactable.new()
	interact.entity_id = npc_id
	interact.reach = 90.0
	interact.priority = 1
	interact.position = Vector2(0, -30)
	interact.on_activate = _talk
	add_child(interact)
	var n := state()
	if n != null:
		position = n.position
	Assets.reloaded.connect(_art)
	_art()


func state() -> NpcState:
	return Session.world.npcs.get(npc_id) if Session.world != null else null


func _art() -> void:
	var d := NpcSim.defn(npc_id)
	if _huddled and d.has("huddle_art"):
		Assets.apply_to_sprite(_sprite, str(d["huddle_art"]))
	else:
		Assets.apply_to_sprite(_sprite, str(d.get("art", "char.npc")))
	_pivot = _sprite.position


## Shows a short line above the survivor for a few seconds (local only).
func say(text: String, seconds: float = 4.5) -> void:
	_say.text = text
	_say_time = seconds


func _random_line(key: String) -> String:
	var lines: Array = NpcSim.defn(npc_id).get(key, [])
	return TranslationServer.translate(str(lines[randi() % lines.size()])) if not lines.is_empty() else ""


func _process(delta: float) -> void:
	var n := state()
	if n == null:
		queue_free()
		return
	var huddled: bool = n.recruit in ["waiting", "met"] and NpcSim.defn(npc_id).has("huddle_art")
	if huddled != _huddled:
		_huddled = huddled
		interact.position = Vector2(0, -8) if huddled else Vector2(0, -30)  # sitting vs standing
		_art()
	_t += delta
	var moving := position.distance_to(n.position) > 1.0
	position = position.lerp(n.position, clampf(delta * 8.0, 0.0, 1.0))
	_bob = _bob + delta * 9.0 if moving else 0.0
	var base := Vector2.ZERO
	if _huddled:
		var o: Array = NpcSim.defn(npc_id).get("huddle_offset", [0, 0])
		base = Vector2(float(o[0]), float(o[1]))
		# trembling: a fine, uneven shiver; much stronger for a moment after a flinch
		_flinch = maxf(0.0, _flinch - delta * 1.5)
		var amp := 0.6 + _flinch * 2.5
		_sprite.position = _pivot + base + Vector2(sin(_t * 37.0) * amp + sin(_t * 23.0) * amp * 0.5, absf(sin(_t * 29.0)) * amp * 0.4)
		_sprite.rotation = sin(_t * 3.1) * 0.012 + sin(_t * 41.0) * 0.006 * (1.0 + _flinch * 3.0)
		_mutter_timer -= delta
		var me := Session.local_player()
		if _mutter_timer <= 0.0:
			_mutter_timer = randf_range(12.0, 26.0)
			var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
			var here: Vector2 = avatar.global_position if avatar != null else (me.position if me != null else Vector2.INF)
			if me != null and me.region_id == n.region_id and here.distance_to(n.position) < 520.0:
				var snd := _random_line("mutters")
				if snd != "":
					Audio.play(snd, global_position)
				say(_random_line("lines"), 3.5)
	else:
		_sprite.position = _pivot + Vector2(0, -absf(sin(_bob)) * 3.0)
		_sprite.rotation = 0.0
		_sprite.flip_h = n.facing.x < -0.2
	_say_time = maxf(0.0, _say_time - delta)
	_say.modulate.a = clampf(_say_time, 0.0, 1.0)
	_label.text = n.name if n.recruit != "waiting" else TranslationServer.translate("NPC_UNKNOWN")
	_status.text = TranslationServer.translate("NPC_ACT_" + n.activity.to_upper()) if n.recruit == "home" else ""
	match n.recruit:
		"waiting":
			interact.prompt_key = "PROMPT_NPC_HAIL"
		"met":
			interact.prompt_key = "PROMPT_NPC_HELP"
		_:
			interact.prompt_key = "PROMPT_NPC_TALK"
	interact.prompt_args = [n.name if n.recruit != "waiting" else TranslationServer.translate("NPC_UNKNOWN_PROMPT")]


func _talk() -> void:
	var n := state()
	if n == null:
		return
	if n.recruit == "home":
		MachinePanel.open(self, n.region_id, npc_id, SettlementPanel.npc_panel.bind(npc_id), func(action: String, arg: String) -> void:
			Session.request_npc(npc_id, action, arg))
	else:
		if _huddled:
			_flinch = 1.0
			say(_random_line("lines"))
		Session.request_npc(npc_id, "talk", "")
