class_name MainMenu
extends Control
## Startup menu: Single Player, Host Game, Join Game, Settings, Quit.
## Only *requests* sessions from Session; shows errors in plain words.

signal open_settings

var _status: Label
var _buttons: VBoxContainer
var _world_panel: PanelContainer
var _join_panel: PanelContainer
var _world_hosting := false
var _name_world: LineEdit
var _port_world: SpinBox
var _port_row: HBoxContainer
var _seed: LineEdit
var _continue_btn: Button
var _world_title: Label
var _name_join: LineEdit
var _addr: LineEdit
var _port_join: SpinBox
var _connect_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.08, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	center.add_child(col)
	var title := UITheme.heading(BuildInfo.GAME_TITLE, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UITheme.small("MENU_SUBTITLE", 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	col.add_child(sub)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	_add_button(_buttons, "MENU_SINGLE", func() -> void: _show_world_panel(false))
	_add_button(_buttons, "MENU_HOST", func() -> void: _show_world_panel(true))
	_add_button(_buttons, "MENU_JOIN", _show_join_panel)
	_add_button(_buttons, "MENU_SETTINGS", func() -> void: open_settings.emit())
	_add_button(_buttons, "MENU_QUIT", func() -> void: get_tree().quit())
	_build_world_panel(col)
	_build_join_panel(col)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(420, 0)
	col.add_child(_status)
	Session.join_progress.connect(func(key: String) -> void: show_status(key, false))
	_back_to_main()


func _add_button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func() -> void:
		Audio.play("ui.click")
		cb.call())
	parent.add_child(b)
	return b


func _row(parent: Control, label_key: String, field: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = label_key
	l.custom_minimum_size = Vector2(140, 0)
	r.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(field)
	parent.add_child(r)
	return r


func _port_box() -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 1024
	s.max_value = 65535
	s.value = int(Settings.get_value("general", "last_port", NetService.DEFAULT_PORT))
	return s


func _build_world_panel(parent: Control) -> void:
	_world_panel = PanelContainer.new()
	parent.add_child(_world_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_world_panel.add_child(v)
	_world_title = UITheme.heading("MENU_SINGLE", 20)
	v.add_child(_world_title)
	_name_world = LineEdit.new()
	_name_world.max_length = 20
	_row(v, "FIELD_PLAYER_NAME", _name_world)
	_port_world = _port_box()
	_port_row = _row(v, "FIELD_PORT", _port_world)
	_continue_btn = _add_button(v, "MENU_CONTINUE", func() -> void: _start(Saves.most_recent_world_id()))
	_seed = LineEdit.new()
	_seed.placeholder_text = "FIELD_SEED_HINT"
	_row(v, "FIELD_SEED", _seed)
	_add_button(v, "MENU_NEW_WORLD", func() -> void: _start(""))
	_add_button(v, "MENU_BACK", _back_to_main)


func _build_join_panel(parent: Control) -> void:
	_join_panel = PanelContainer.new()
	parent.add_child(_join_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_join_panel.add_child(v)
	v.add_child(UITheme.heading("MENU_JOIN", 20))
	_name_join = LineEdit.new()
	_name_join.max_length = 20
	_row(v, "FIELD_PLAYER_NAME", _name_join)
	_addr = LineEdit.new()
	_addr.text = str(Settings.get_value("general", "last_address", "127.0.0.1"))
	_row(v, "FIELD_ADDRESS", _addr)
	_port_join = _port_box()
	_row(v, "FIELD_PORT", _port_join)
	_connect_btn = _add_button(v, "MENU_CONNECT", _join)
	_add_button(v, "MENU_BACK", func() -> void:
		if Session.mode == GameSession.Mode.CLIENT:
			Session.leave("JOIN_CANCELLED")
		_back_to_main())


func _back_to_main() -> void:
	_world_panel.hide()
	_join_panel.hide()
	_buttons.show()


func _show_world_panel(hosting: bool) -> void:
	_world_hosting = hosting
	_world_title.text = "MENU_HOST" if hosting else "MENU_SINGLE"
	_port_row.visible = hosting
	_name_world.text = Settings.player_name()
	var recent := Saves.most_recent_world_id()
	_continue_btn.disabled = recent == ""
	_continue_btn.text = UITheme.fmt("MENU_CONTINUE_WORLD", [recent]) if recent != "" else tr("MENU_CONTINUE_NONE")
	_buttons.hide()
	_join_panel.hide()
	_world_panel.show()
	show_status("", false)


func _show_join_panel() -> void:
	_name_join.text = Settings.player_name()
	_connect_btn.disabled = false
	_buttons.hide()
	_world_panel.hide()
	_join_panel.show()
	show_status("", false)


func _start(world_id: String) -> void:
	var name := SettingsService.sanitize_name(_name_world.text)
	Settings.set_value("general", "player_name", name)
	var s := -1
	if world_id == "" and _seed.text.strip_edges().is_valid_int():
		s = absi(_seed.text.strip_edges().to_int())
	var res: Dictionary
	if _world_hosting:
		var port := int(_port_world.value)
		Settings.set_value("general", "last_port", port)
		res = Session.start_host(port, world_id, s, name)
	else:
		res = Session.start_single(world_id, s, name)
	if not res["ok"]:
		show_status(UITheme.fmt(res["error"]) + ("\n" + str(res.get("detail", "")) if res.has("detail") else ""), true)


func _join() -> void:
	var name := SettingsService.sanitize_name(_name_join.text)
	var addr := _addr.text.strip_edges()
	if addr == "":
		show_status("JOIN_NEED_ADDRESS", true)
		return
	Settings.set_value("general", "player_name", name)
	Settings.set_value("general", "last_address", addr)
	Settings.set_value("general", "last_port", int(_port_join.value))
	var res := Session.start_join(addr, int(_port_join.value), name)
	if not res["ok"]:
		show_status(res["error"], true)
	else:
		_connect_btn.disabled = true


func show_status(key_or_text: String, is_error: bool) -> void:
	_status.text = tr(key_or_text) if key_or_text != "" else ""
	_status.add_theme_color_override("font_color", UITheme.ERROR if is_error else UITheme.STRAW)


func on_session_ended(reason_key: String) -> void:
	_connect_btn.disabled = false
	var neutral := reason_key in ["SESSION_LEFT", "JOIN_CANCELLED"]
	show_status("" if neutral else reason_key, not neutral)
