class_name SettingsPanel
extends Control
## Client-local settings: audio buses, display, UI scale, language, controls,
## and the art/sound override folder. Changes apply and save immediately.
## Opening it never pauses the shared world.

signal closed

var _capture_action := ""
var _capture_button: Button
var _control_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	v.add_child(UITheme.heading("SETTINGS_TITLE", 24))

	v.add_child(UITheme.heading("SETTINGS_AUDIO", 18))
	for bus in SettingsService.BUSES:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.bus_volume(bus)
		s.custom_minimum_size = Vector2(260, 24)
		s.value_changed.connect(func(val: float) -> void: Settings.set_bus_volume(bus, val))
		_row(v, "BUS_" + bus.to_upper(), s)

	v.add_child(UITheme.heading("SETTINGS_DISPLAY", 18))
	var fs := CheckBox.new()
	fs.button_pressed = Settings.fullscreen()
	fs.toggled.connect(func(on: bool) -> void:
		Settings.set_value("display", "fullscreen", on)
		Settings.apply_display())
	_row(v, "SETTINGS_FULLSCREEN", fs)
	var res := OptionButton.new()
	var current := Settings.window_size()
	for i in SettingsService.RESOLUTIONS.size():
		var r: Vector2i = SettingsService.RESOLUTIONS[i]
		res.add_item("%d × %d" % [r.x, r.y], i)
		if r == current:
			res.select(i)
	res.item_selected.connect(func(i: int) -> void:
		Settings.set_value("display", "window_size", SettingsService.RESOLUTIONS[i])
		Settings.apply_display())
	_row(v, "SETTINGS_WINDOW_SIZE", res)
	var ui := HSlider.new()
	ui.min_value = SettingsService.UI_SCALE_MIN
	ui.max_value = SettingsService.UI_SCALE_MAX
	ui.step = 0.05
	ui.value = Settings.ui_scale()
	ui.custom_minimum_size = Vector2(260, 24)
	# Apply on release so the panel does not resize under the cursor while dragging.
	ui.drag_ended.connect(func(_changed: bool) -> void: Settings.set_value("display", "ui_scale", ui.value))
	_row(v, "SETTINGS_UI_SCALE", ui)
	var lang := OptionButton.new()
	for i in SettingsService.LANGUAGES.size():
		lang.add_item("LANG_" + SettingsService.LANGUAGES[i].to_upper(), i)
		if SettingsService.LANGUAGES[i] == Settings.language():
			lang.select(i)
	lang.item_selected.connect(func(i: int) -> void:
		Settings.set_value("general", "language", SettingsService.LANGUAGES[i])
		Settings.apply_language())
	_row(v, "SETTINGS_LANGUAGE", lang)

	v.add_child(UITheme.heading("SETTINGS_CONTROLS", 18))
	for action in SettingsService.REMAPPABLE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 30)
		b.pressed.connect(func() -> void: _begin_capture(action, b))
		_control_buttons[action] = b
		_row(v, "ACTION_" + action.to_upper(), b)
	var reset := Button.new()
	reset.text = "SETTINGS_RESET_CONTROLS"
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh_controls())
	v.add_child(reset)

	v.add_child(UITheme.heading("SETTINGS_ASSETS", 18))
	var info := UITheme.small(UITheme.fmt("SETTINGS_ASSETS_HINT", [ProjectSettings.globalize_path("user://overrides/")]), 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	v.add_child(info)
	var h := HBoxContainer.new()
	var open_dir := Button.new()
	open_dir.text = "SETTINGS_OPEN_OVERRIDES"
	open_dir.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(Paths.overrides_dir())))
	h.add_child(open_dir)
	var reload := Button.new()
	reload.text = "SETTINGS_RELOAD_ASSETS"
	reload.pressed.connect(func() -> void: Assets.reload())
	h.add_child(reload)
	v.add_child(h)

	var close := Button.new()
	close.text = "MENU_CLOSE"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_panel)
	v.add_child(close)
	_refresh_controls()


func _row(parent: Control, key: String, field: Control) -> void:
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = key
	l.custom_minimum_size = Vector2(260, 0)
	r.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(field)
	parent.add_child(r)


func _refresh_controls() -> void:
	for action in _control_buttons:
		var names := []
		for code in Settings.action_keys(action):
			names.append(Settings.key_label(code))
		(_control_buttons[action] as Button).text = " / ".join(names) if not names.is_empty() else "—"


func _begin_capture(action: String, button: Button) -> void:
	_capture_action = action
	_capture_button = button
	button.text = tr("SETTINGS_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _capture_action != "" and event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code != KEY_NONE:
			Settings.rebind(_capture_action, code)
		_capture_action = ""
		_refresh_controls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_menu"):
		close_panel()
		get_viewport().set_input_as_handled()


func close_panel() -> void:
	_capture_action = ""
	closed.emit()
	queue_free()
