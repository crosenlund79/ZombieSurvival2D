class_name NpcView
extends Node2D
## Shows one survivor from replicated world data (host simulates; this view
## only interpolates position and shows activity). Talking opens the survivor
## panel (assign work); every choice is a host request.

var npc_id := ""
var _sprite: Sprite2D
var _label: Label
var _status: Label
var interact: Interactable
var _bob := 0.0


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
	Assets.apply_to_sprite(_sprite, str(NpcSim.defn(npc_id).get("art", "char.npc")))


func _process(delta: float) -> void:
	var n := state()
	if n == null:
		queue_free()
		return
	var moving := position.distance_to(n.position) > 1.0
	position = position.lerp(n.position, clampf(delta * 8.0, 0.0, 1.0))
	_bob = _bob + delta * 9.0 if moving else 0.0
	_sprite.position.y = -absf(sin(_bob)) * 3.0
	_sprite.flip_h = n.facing.x < -0.2
	_label.text = n.name
	_status.text = TranslationServer.translate("NPC_ACT_" + n.activity.to_upper()) if n.recruit == "home" else ""
	match n.recruit:
		"waiting":
			interact.prompt_key = "PROMPT_NPC_HAIL"
		"met":
			interact.prompt_key = "PROMPT_NPC_HELP"
		_:
			interact.prompt_key = "PROMPT_NPC_TALK"
	interact.prompt_args = [n.name]


func _talk() -> void:
	var n := state()
	if n == null:
		return
	if n.recruit == "home":
		MachinePanel.open(self, n.region_id, npc_id, SettlementPanel.npc_panel.bind(npc_id), func(action: String, arg: String) -> void:
			Session.request_npc(npc_id, action, arg))
	else:
		Session.request_npc(npc_id, "talk", "")
