class_name Hud
extends Control
## In-game overlay: connection/session line, interaction prompt, notices.
## Reads state; never changes it.

var _status: Label
var _prompt: Label
var _notices: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UITheme.small("", 14)
	_status.position = Vector2(14, 10)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 4)
	add_child(_status)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -110
	_prompt.offset_bottom = -80
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	add_child(_prompt)
	_notices = VBoxContainer.new()
	_notices.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notices.offset_left = -320
	_notices.offset_right = 320
	_notices.offset_top = 44
	_notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)
	Session.notice.connect(show_notice)


func _process(_delta: float) -> void:
	if not Session.in_world():
		_status.text = ""
		_prompt.text = ""
		return
	var w := Session.world
	_status.text = "%s · %s · %s %d · %s %s" % [
		tr("MODE_" + Session.mode_name()), tr(Content.region_def(Session.local_player().region_id).get("display_key", "")),
		tr("HUD_PLAYERS"), w.online_players().size(), tr("HUD_TIME"), Simulation.format_time(w)]
	var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
	_prompt.text = sensor.focused.prompt_text() if sensor != null and sensor.focused != null and not PlayerAvatar.input_blocked else ""


func show_notice(key: String, args: Array) -> void:
	var l := Label.new()
	l.text = UITheme.fmt(key, args)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	if key.begins_with("ACTION_") or key.ends_with("FAILED") or key.begins_with("DEV_"):
		l.add_theme_color_override("font_color", UITheme.WARN)
	_notices.add_child(l)
	while _notices.get_child_count() > 5:
		var oldest := _notices.get_child(0)
		_notices.remove_child(oldest)  # queue_free alone would not shrink the count this frame
		oldest.queue_free()
	var tw := l.create_tween()  # dies with the label if it is trimmed early
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
