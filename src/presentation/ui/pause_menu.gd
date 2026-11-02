class_name PauseMenu
extends Control
## Local in-game menu. It does NOT pause the shared world — other players and
## the world clock keep running while it is open.

signal open_settings
signal leave_requested

var _save_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(320, 0)
	panel.add_child(v)
	v.add_child(UITheme.heading("PAUSE_TITLE", 22))
	var hint := UITheme.small("PAUSE_HINT", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_btn(v, "PAUSE_RESUME", func() -> void: hide())
	_save_btn = _btn(v, "PAUSE_SAVE", func() -> void: Session.save_world())
	_btn(v, "MENU_SETTINGS", func() -> void: open_settings.emit())
	_btn(v, "PAUSE_LEAVE", func() -> void:
		hide()
		leave_requested.emit())
	visibility_changed.connect(func() -> void:
		if visible:
			_save_btn.disabled = not Session.is_authority())


func _btn(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(func() -> void:
		Audio.play("ui.click")
		cb.call())
	parent.add_child(b)
	return b
