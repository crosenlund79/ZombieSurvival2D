class_name MachinePanel
extends PanelContainer
## Small local panel for a machine or container (storage locker, generator,
## purifier). Shows status lines and action buttons; every button only sends
## a request to the host (Session.request_entity_action). Closes when the
## player walks away, presses Esc/E again, or the view is rebuilt. Never pauses.

static var current: MachinePanel

var region_id := ""
var entity_id := ""
var _title: Label
var _lines: Label
var _buttons: VBoxContainer
var _builder: Callable   # func() -> {"title", "lines": [..], "buttons": [[label, action, arg, enabled], ..]}
## func(action, arg) sending the request; default: Session.request_entity_action(entity_id, ...).
var _request: Callable
var _anchor: Node2D
var _sig := ""


static func open(anchor: Node2D, rid: String, eid: String, builder: Callable, request: Callable = Callable()) -> void:
	close_current()
	var p := MachinePanel.new()
	p._request = request
	p.region_id = rid
	p.entity_id = eid
	p._builder = builder
	p._anchor = anchor
	var ui := anchor.get_tree().root.get_node_or_null("Main/CanvasLayer/UIRoot")
	if ui == null:
		for n in anchor.get_tree().get_nodes_in_group("ui_root"):
			ui = n
	if ui == null:
		return
	ui.add_child(p)
	current = p


static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -230
	offset_right = 230
	offset_top = -470
	offset_bottom = -130
	var v := VBoxContainer.new()
	add_child(v)
	_title = UITheme.heading("", 20)
	v.add_child(_title)
	_lines = UITheme.small("", 14)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lines)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_buttons)
	var close := Button.new()
	close.text = "MENU_CLOSE"
	close.pressed.connect(close_current)
	v.add_child(close)
	_refresh()


func _process(_delta: float) -> void:
	var me := Session.local_player()
	if me == null or me.region_id != region_id or not is_instance_valid(_anchor) or me.dead:
		close_current()
		return
	# Measured where the player is drawn (also correct in the side-view bunker, iteration 012).
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var at: Vector2 = avatar.global_position if avatar != null else me.position
	if at.distance_to(_anchor.global_position) > 170.0:
		close_current()
		return
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact"):
		close_current()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var d: Dictionary = _builder.call()
	_title.text = str(d.get("title", ""))
	_lines.text = "\n".join(d.get("lines", []))
	var sig := JSON.stringify(d.get("buttons", []))
	if sig == _sig:
		return
	_sig = sig
	for c in _buttons.get_children():
		c.queue_free()
	for b in d.get("buttons", []):
		var btn := Button.new()
		btn.text = str(b[0])
		btn.disabled = not bool(b[3])
		var action: String = b[1]
		var arg: Variant = b[2]
		btn.pressed.connect(func() -> void:
			Audio.play("ui.click")
			if _request.is_valid():
				_request.call(action, str(arg))
			else:
				Session.request_entity_action(entity_id, action, arg))
		_buttons.add_child(btn)
