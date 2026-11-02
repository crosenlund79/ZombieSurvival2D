class_name Hud
extends Control
## In-game overlay: connection/session line, interaction prompt, notices.
## Reads state; never changes it.

var _status: Label
var _prompt: Label
var _notices: VBoxContainer
var _resources: Label
var _vitals: Control
var _threat: Label
var _down: Label


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
	_resources = UITheme.small("", 15)
	_resources.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_resources.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_resources.offset_right = -14
	_resources.offset_top = 10
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resources.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_resources.add_theme_constant_override("outline_size", 4)
	add_child(_resources)
	_vitals = Control.new()
	_vitals.position = Vector2(14, 34)
	_vitals.size = Vector2(220, 40)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.draw.connect(_draw_vitals)
	add_child(_vitals)
	_threat = UITheme.small("", 15)
	_threat.position = Vector2(14, 76)
	_threat.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_threat.add_theme_constant_override("outline_size", 4)
	add_child(_threat)
	_down = Label.new()
	_down.add_theme_font_size_override("font_size", 30)
	_down.add_theme_color_override("font_color", Color("#E2B9A8"))
	_down.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_down.add_theme_constant_override("outline_size", 8)
	_down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_down.offset_left = -400
	_down.offset_right = 400
	_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_down)
	Session.notice.connect(show_notice)


func _process(_delta: float) -> void:
	if not Session.in_world():
		_status.text = ""
		_resources.text = ""
		_threat.text = ""
		_down.text = ""
		_prompt.text = ""
		return
	var w := Session.world
	var me := Session.local_player()
	_status.text = "%s · %s · %s %d · %s %s" % [
		tr("MODE_" + Session.mode_name()), region_label(me.region_id),
		tr("HUD_PLAYERS"), w.online_players().size(), tr("HUD_TIME"), Simulation.format_time(w)]
	_resources.text = _resource_line(me)
	_vitals.queue_redraw()
	_threat.text = threat_label(me)
	_down.text = tr("HUD_DOWNED") if me.dead else ""
	var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
	_prompt.text = sensor.focused.prompt_text() if sensor != null and sensor.focused != null and not PlayerAvatar.input_blocked else ""


## "The Homestead", "The Farmhouse", "Shelter · Level -2" …
static func region_label(region_id: String) -> String:
	var w := Session.world
	var name := TranslationServer.translate(str(w.region_def(region_id).get("display_key", "")))
	var parsed := BunkerState.parse_region_id(region_id)
	if not parsed.is_empty():
		name = UITheme.fmt("HUD_LEVEL", [name, parsed["depth"]])
	return name


## Attention around the player, as words (thresholds follow the escalation tuning).
static func threat_label(me: PlayerState) -> String:
	var w := Session.world
	if not w.region_def(me.region_id).has("zombies"):
		return TranslationServer.translate("HUD_THREAT_SHELTERED")
	var att := w.threat.local_attention(me.region_id, me.position)
	var levels: Array = ZombieSim.c("escalation", [])
	var key := "HUD_THREAT_CALM"
	if levels.size() >= 3 and att >= float(levels[2]["attention"]):
		key = "HUD_THREAT_HORDE"
	elif levels.size() >= 2 and att >= float(levels[1]["attention"]):
		key = "HUD_THREAT_GATHERING"
	elif levels.size() >= 1 and att >= float(levels[0]["attention"]):
		key = "HUD_THREAT_NOTICED"
	elif att >= 0.4:
		key = "HUD_THREAT_STIRRING"
	return TranslationServer.translate(key)


func _draw_vitals() -> void:
	var me := Session.local_player() if Session.in_world() else null
	if me == null:
		return
	_bar(Vector2(0, 0), me.health / 100.0, Color("#B5543A"), tr("HUD_HEALTH"))
	_bar(Vector2(0, 18), me.hydration / 100.0, Color("#4F8C9A"), tr("HUD_HYDRATION"))


func _bar(at: Vector2, frac: float, col: Color, label: String) -> void:
	var r := Rect2(at + Vector2(86, 2), Vector2(130, 11))
	_vitals.draw_rect(r.grow(2), Color(0.06, 0.05, 0.04, 0.8))
	_vitals.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), col)
	var font := _vitals.get_theme_default_font()
	_vitals.draw_string_outline(font, at + Vector2(0, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
	_vitals.draw_string(font, at + Vector2(0, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.PAPER)


func _resource_line(me: PlayerState) -> String:
	var parts: Array[String] = []
	parts.append(UITheme.fmt("HUD_CARRYING", [me.carrying("wood"), WorldActions.CARRY_LIMIT]))
	var b := Session.world.bunker_for_region(me.region_id)
	if b == null and Session.world.bunkers.size() == 1:
		b = Session.world.bunkers.values()[0]
	if b != null:
		parts.append(UITheme.fmt("HUD_STOCKPILE", [b.amount("wood")]))
	var r := Session.world.region(me.region_id)
	if r != null and not BunkerState.parse_region_id(me.region_id).is_empty():
		var total := 0
		var done := 0
		for eid in Content.entity_ids(r.def_id):
			if str(r.entity_def(eid).get("type", "")) == "support_site":
				total += 1
				if str(r.entity_state(eid).get("stage", "")) == "reinforced":
					done += 1
		for k in r.terrain.get("supports", {}):
			if str(r.terrain["supports"][k].get("stage", "")) == "reinforced":
				done += 1
		if total > 0 or done > 0:
			parts.append(UITheme.fmt("HUD_REINFORCED", [done]))
	return "\n".join(parts)


func show_notice(key: String, args: Array) -> void:
	var l := Label.new()
	l.text = UITheme.fmt(key, args)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	if key.begins_with("ACTION_") or key.ends_with("FAILED") or key == "DEV_HOST_ONLY":
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
