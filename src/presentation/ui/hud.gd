class_name Hud
extends Control
## In-game overlay (iteration 015 redesign): reads state, never changes it.
##   top-left      where you are, the day and time, the weather (icons, one line)
##   bottom-left   vitals as icon gauges (health, water, food, warmth) and the
##                 threat around you
##   bottom-right  status chips: what you carry (slots), what is in your hand
##                 and its condition, rounds, the light; inside a shelter its power
##   bottom-centre the interaction prompt on a key cap
##   right         notices as small toasts with an icon, fading on their own
## Long lists (what you carry, the shelter's stock) live in the inventory and
## storage panels, not over the world.

var _region: Label
var _info: Label
var _info_icon: TextureRect
var _weather_icon: TextureRect
var _prompt: Label
var _prompt_panel: PanelContainer
var _notices: VBoxContainer
var _vitals: Control
var _vitals_panel: PanelContainer
var _threat: Label
var _threat_icon: TextureRect
var _chips: HBoxContainer
var _hint: Label
var _down: Label
var _banner: Label
var _vote: PanelContainer
var _vote_label: Label
var _vote_id := -1
var _vote_answered := -1
var _chip_sig := ""
var _status: Label  # kept for compatibility (the full status line, used in screenshots/tests)


func _outline(l: Label, size: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", size)
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top-left: place and time
	var top := VBoxContainer.new()
	top.position = Vector2(18, 12)
	top.add_theme_constant_override("separation", 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_region = _outline(UITheme.heading("", 18), 5)
	top.add_child(_region)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	top.add_child(row)
	_info_icon = UITheme.icon_rect("clock", 18)
	row.add_child(_info_icon)
	_info = _outline(UITheme.small("", 14))
	row.add_child(_info)
	_weather_icon = UITheme.icon_rect("snow", 18)
	row.add_child(_weather_icon)
	_status = Label.new()
	_status.visible = false
	add_child(_status)
	# bottom-centre prompt on a key cap panel
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.offset_top = -132
	_prompt_panel.offset_bottom = -92
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", UITheme.panel_box(0.92))
	add_child(_prompt_panel)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt)
	# right: notices as toasts
	_notices = VBoxContainer.new()
	_notices.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notices.offset_left = -420
	_notices.offset_right = -18
	_notices.offset_top = 70
	_notices.add_theme_constant_override("separation", 6)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)
	# bottom-left: vitals and threat
	_vitals_panel = PanelContainer.new()
	_vitals_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vitals_panel.offset_left = 16
	_vitals_panel.offset_top = -150
	_vitals_panel.offset_bottom = -16
	_vitals_panel.offset_right = 236
	_vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_panel.add_theme_stylebox_override("panel", UITheme.panel_box(0.88))
	add_child(_vitals_panel)
	var vbox := VBoxContainer.new()
	_vitals_panel.add_child(vbox)
	_vitals = Control.new()
	_vitals.custom_minimum_size = Vector2(196, 92)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.draw.connect(_draw_vitals)
	vbox.add_child(_vitals)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	vbox.add_child(trow)
	_threat_icon = UITheme.icon_rect("quiet", 18)
	trow.add_child(_threat_icon)
	_threat = UITheme.small("", 13)
	trow.add_child(_threat)
	# bottom-right: status chips and a hint line
	_chips = HBoxContainer.new()
	_chips.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_chips.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chips.offset_right = -16
	_chips.offset_bottom = -34
	_chips.add_theme_constant_override("separation", 8)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chips)
	_hint = _outline(UITheme.small("", 14))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -18
	_hint.offset_bottom = -70
	_hint.offset_top = -92
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)
	_down = Label.new()
	_down.add_theme_font_size_override("font_size", 30)
	_down.add_theme_color_override("font_color", Color("#E2B9A8"))
	_outline(_down, 8)
	_down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_down.offset_left = -400
	_down.offset_right = 400
	_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_down)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 19)
	_banner.add_theme_color_override("font_color", Color("#E2B9A8"))
	_outline(_banner, 6)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.offset_top = 64
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	Session.notice.connect(show_notice)
	Session.combat_event.connect(_on_world_event)


func _process(_delta: float) -> void:
	var on := Session.in_world()
	for n in [_vitals_panel, _chips, _region, _info_icon, _weather_icon]:
		(n as CanvasItem).visible = on
	if not on:
		_info.text = ""
		_threat.text = ""
		_down.text = ""
		_prompt_panel.visible = false
		_hint.text = ""
		return
	var w := Session.world
	var me := Session.local_player()
	_region.text = region_label(me.region_id)
	var info := "%s   " % UITheme.fmt("HUD_CLOCK", [EnvSim.day_number(w), EnvSim.clock_text(w)])
	if w.online_players().size() > 1 or Session.mode != Session.Mode.SINGLE:
		info += "%s %d   " % [tr("HUD_PLAYERS"), w.online_players().size()]
	info += weather_label(w)
	if not is_equal_approx(Session.time_scale, 1.0) and Session.mode == Session.Mode.SINGLE:
		info += "   " + (tr("HUD_TIME_PAUSED") if Session.time_scale <= 0.0 else UITheme.fmt("HUD_TIME_SCALE", ["%.0f" % Session.time_scale]))
	_info.text = info
	var wk := EnvSim.weather(w)
	_weather_icon.texture = UITheme.icon("fog" if wk == "fog" else ("snow" if wk in ["snow", "blizzard"] else ("moon" if EnvSim.is_night(w) else "sun")))
	_status.text = "%s · %s · %s" % [tr("MODE_" + Session.mode_name()), region_label(me.region_id), info]
	_vitals.queue_redraw()
	_threat.text = threat_label(me)
	if w.region_def(me.region_id).has("zombies"):
		_threat.text += " · " + tr("HUD_HEAT_%d" % EventSim.heat_level(w, me.region_id))
	_threat_icon.texture = UITheme.icon("quiet" if _threat.text.begins_with(tr("HUD_THREAT_CALM")) or _threat.text.begins_with(tr("HUD_THREAT_SHELTERED")) else "noise")
	_update_chips(me)
	_hint.text = _hint_line(me)
	_banner.text = siege_text(w)
	if bool(w.meta.get("dev_world", false)) and _banner.text == "":
		_banner.text = tr("HUD_DEV_WORLD")
	_down.text = tr("HUD_DOWNED") if me.dead else ""
	_update_vote(w, me)
	var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
	var ptxt := sensor.focused.prompt_text() if sensor != null and sensor.focused != null and not PlayerAvatar.input_blocked else ""
	var main := get_tree().root.get_node_or_null("Main")
	if BuildMode.placing != "" and main != null and main.get("build_mode") != null:
		ptxt = main.build_mode.hint_text()
	if me.vehicle_id != "" and not PlayerAvatar.input_blocked:
		ptxt = vehicle_hint(w, me)
	_prompt.text = ptxt
	_prompt_panel.visible = ptxt != ""


## A status chip: icon + short text, on a small panel.
func _chip(icon_name: String, text: String, tint: Color = Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.panel_box(0.88))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var ic := UITheme.icon_rect(icon_name, 22)
	ic.modulate = tint
	h.add_child(ic)
	var l := UITheme.small(text, 14)
	h.add_child(l)
	return p


func _update_chips(me: PlayerState) -> void:
	var chips: Array = []
	chips.append(["bag", "%d/%d" % [Inv.slots_used(me), Inv.capacity(me)], Color.WHITE])
	var hand := me.equipped_gear("hand")
	if not hand.is_empty():
		var info := Items.info(str(hand["item"]))
		var pct := roundi(float(hand.get("cond", 0)) / maxf(1.0, float(info.get("durability", 1))) * 100.0)
		chips.append(["wrench", "%s %d%%" % [tr(Items.name_key(str(hand["item"]))), pct], Color.WHITE if pct > 25 else UITheme.WARN])
		if Firearms.is_firearm(str(hand["item"])):
			chips.append(["rounds", UITheme.fmt("HUD_AMMO_SHORT", [Firearms.loaded(hand), int(Firearms.spec(str(hand["item"])).get("capacity", 0)), Firearms.spare(me, hand)]), Color.WHITE])
	if me.flashlight:
		chips.append(["light", tr("HUD_LIGHT_ON"), Color.WHITE])
	if not BunkerState.parse_region_id(me.region_id).is_empty():
		chips.append(["shelter", tr("HUD_POWER_ON") if InfraSim.is_powered(Session.world, me.region_id) else tr("HUD_POWER_OFF"), Color.WHITE])
	var sig := JSON.stringify(chips)
	if sig == _chip_sig:
		return
	_chip_sig = sig
	for c in _chips.get_children():
		c.queue_free()
	for c in chips:
		_chips.add_child(_chip(c[0], c[1], c[2]))


## One short line only when something needs doing (thirst, hunger) — with the key.
func _hint_line(me: PlayerState) -> String:
	var parts: Array[String] = []
	if InfraSim.is_thirsty(me):
		var water := me.carrying("water_clean") + me.carrying("water_bottle")
		parts.append(UITheme.fmt("HUD_DRINK_HINT", [water]) if water > 0 else tr("HUD_THIRSTY"))
	if InfraSim.is_hungry(me):
		var food := Inv.best_food(me)
		parts.append(UITheme.fmt("HUD_EAT_HINT", [tr(Items.name_key(food))]) if food != "" else tr("HUD_HUNGRY"))
	return "   ".join(parts)


static func _k(action: String) -> String:
	var codes: Array = Settings.action_keys(action)
	return Settings.key_label(codes[0]) if not codes.is_empty() else "?"


## Control hint while seated in a vehicle (driver / passenger, engine state).
static func vehicle_hint(w: WorldState, me: PlayerState) -> String:
	var v: VehicleState = w.vehicles.get(me.vehicle_id)
	if v == null:
		return ""
	if v.driver() != me.player_id:
		return UITheme.fmt("HUD_VEHICLE_PASSENGER", [_k("interact")])
	if not v.engine_on:
		return UITheme.fmt("HUD_VEHICLE_DRIVER_OFF", [_k("vehicle_engine"), _k("interact")])
	return UITheme.fmt("HUD_VEHICLE_DRIVER", [_k("move_up"), _k("move_down"), _k("move_left"), _k("move_right"),
		_k("vehicle_engine"), _k("interact")])


## Horde warning / attack banner from the replicated event record ("" = none).
static func siege_text(w: WorldState) -> String:
	var s := EventSim.siege(w)
	match str(s.get("phase", "idle")):
		"warning":
			return UITheme.fmt("SIEGE_WARNING_HUD", [maxi(0, ceili(float(int(s.get("ends", 0)) - w.tick) / Simulation.TICK_RATE))])
		"active":
			return UITheme.fmt("SIEGE_ACTIVE_HUD", [int(s.get("remaining", 0))])
	return ""


func _on_world_event(ev: Dictionary) -> void:
	match str(ev.get("kind", "")):
		"weather":
			show_notice("WEATHER_STARTS_" + str(ev.get("weather", "clear")).to_upper(), [])
		"siege_warning":
			show_notice("SIEGE_WARNING", [])
			Audio.play("sfx.horde_warning")
		"siege_started":
			show_notice("SIEGE_STARTED", [])
		"siege_repelled":
			show_notice("SIEGE_REPELLED", [])
		"siege_dispersed":
			show_notice("SIEGE_DISPERSED", [])
		"npc_arrived":
			show_notice("NPC_ARRIVED", [str(ev.get("name", ""))])
		"search_done":
			# Iteration 013: restrained XP feedback, only for the searcher.
			if str(ev.get("player_id", "")) != Session.local_player_id:
				return
			if int(ev.get("xp", 0)) > 0:
				show_xp(UITheme.fmt("XP_GAINED", [int(ev["xp"]), TranslationServer.translate("SKILL_SCAVENGING")]))
			if bool(ev.get("level_up", false)):
				var lvl := int(ev.get("level", 1))
				show_notice("SKILL_LEVEL_UP", [TranslationServer.translate("SKILL_SCAVENGING"), lvl, "%.1f" % SkillSim.search_seconds_at("shelf", lvl)])
				Audio.play("ui.click")


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


## "Snow", "Fog", "Blizzard"… (night is shown when the sky is clear).
static func weather_label(w: WorldState) -> String:
	var k := EnvSim.weather(w)
	if k == "clear":
		return TranslationServer.translate("HUD_NIGHT") if EnvSim.is_night(w) else TranslationServer.translate("HUD_WEATHER_CLEAR")
	return TranslationServer.translate("HUD_WEATHER_" + k.to_upper())


## The communal sleep vote: a small panel with readiness and Yes / No.
func _update_vote(w: WorldState, me: PlayerState) -> void:
	var v := SleepSim.vote(w)
	if _vote == null:
		_vote = PanelContainer.new()
		_vote.set_anchors_preset(Control.PRESET_CENTER)
		_vote.offset_left = -220
		_vote.offset_right = 220
		_vote.offset_top = 120
		var box := VBoxContainer.new()
		_vote.add_child(box)
		_vote_label = UITheme.small("", 15)
		_vote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_vote_label)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		for pair in [["SLEEP_YES", true], ["SLEEP_NO", false]]:
			var b := Button.new()
			b.text = tr(pair[0])
			var yes: bool = pair[1]
			b.pressed.connect(func() -> void:
				Audio.play("ui.click")
				_vote_answered = _vote_id
				Session.request_sleep_vote(yes))
			row.add_child(b)
		add_child(_vote)
	if v.is_empty():
		_vote.hide()
		return
	_vote_id = int(v["id"])
	var ready: Array = v.get("yes", [])
	var total := w.online_players().size()
	var mine := ready.has(me.player_id) or _vote_answered == _vote_id
	_vote_label.text = UITheme.fmt("SLEEP_VOTE_PANEL", [str(v.get("by_name", "")), ready.size(), total]) + ("\n" + tr("SLEEP_WAITING") if mine else "")
	(_vote.get_child(0).get_child(1) as HBoxContainer).visible = not mine
	_vote.mouse_filter = Control.MOUSE_FILTER_STOP
	_vote.show()


func _draw_vitals() -> void:
	var me := Session.local_player() if Session.in_world() else null
	if me == null:
		return
	var wcol := Color("#9FC3D6") if not SurvivalSim.is_chilled(me) else (Color("#D9E8F2") if not SurvivalSim.is_freezing(me) else Color("#F2F6FA"))
	_gauge(0, "health", me.health / 100.0, Color("#B5543A"))
	_gauge(1, "water", me.hydration / 100.0, Color("#4F8C9A"))
	_gauge(2, "food", me.hunger / 100.0, Color("#C9A23A"))
	_gauge(3, "warmth", me.warmth / 100.0, wcol)


## One vital: its icon and a worn bar (pulses red when low).
func _gauge(row: int, icon_name: String, frac: float, col: Color) -> void:
	var y := row * 23.0
	var tex := UITheme.icon(icon_name)
	if tex != null:
		_vitals.draw_texture_rect(tex, Rect2(Vector2(0, y), Vector2(20, 20)), false)
	var r := Rect2(Vector2(28, y + 6), Vector2(164, 9))
	_vitals.draw_rect(r.grow(2), Color(0.05, 0.045, 0.04, 0.85))
	var low := frac < 0.25
	var c := col
	if low:
		c = col.lerp(Color("#E04A3A"), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0))
	_vitals.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), c)
	for k in range(1, 4):  # notches
		var x := r.position.x + r.size.x * k / 4.0
		_vitals.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.35), 1.0)


static func bag_text(bag: Dictionary) -> String:
	var bits: Array[String] = []
	for item in Items.ids():
		if Items.amount(bag, item) > 0:
			bits.append("%s %d" % [TranslationServer.translate(Items.name_key(item)), Items.amount(bag, item)])
	return " · ".join(bits) if not bits.is_empty() else "—"


static func gear_text(gear: Array) -> String:
	var bits: Array[String] = []
	for g in gear:
		bits.append(TranslationServer.translate(Items.name_key(str(g.get("item", "")))))
	return (" · " + " · ".join(bits)) if not bits.is_empty() else ""


func _resource_line(me: PlayerState) -> String:
	var parts: Array[String] = []
	parts.append(UITheme.fmt("HUD_CARRYING", [Inv.slots_used(me), Inv.capacity(me)]) + "  " + bag_text(me.carried))
	if me.carrying("water_clean") + me.carrying("water_bottle") > 0:
		parts.append(UITheme.fmt("HUD_DRINK_HINT", [me.carrying("water_clean") + me.carrying("water_bottle")]))
	if InfraSim.is_thirsty(me):
		parts.append(tr("HUD_THIRSTY"))
	var food := Inv.best_food(me)
	if food != "" and me.hunger < 85.0:
		parts.append(UITheme.fmt("HUD_EAT_HINT", [tr(Items.name_key(food))]))
	if InfraSim.is_hungry(me):
		parts.append(tr("HUD_HUNGRY"))
	var hand := me.equipped_gear("hand")
	if not hand.is_empty():
		var info := Items.info(str(hand["item"]))
		parts.append(UITheme.fmt("HUD_HOLDING", [UITheme.fmt("INV_GEAR_COND", [tr(Items.name_key(str(hand["item"]))),
			roundi(float(hand.get("cond", 0)) / maxf(1.0, float(info.get("durability", 1))) * 100.0)])]))
		if Firearms.is_firearm(str(hand["item"])):  # iteration 014: rounds in the weapon / spare
			parts.append(UITheme.fmt("HUD_AMMO", [Firearms.loaded(hand), int(Firearms.spec(str(hand["item"])).get("capacity", 0)), Firearms.spare(me, hand)]))
	var b := Session.world.bunker_for_region(me.region_id)
	if b == null and Session.world.bunkers.size() == 1:
		b = Session.world.bunkers.values()[0]
	if b != null:
		parts.append(UITheme.fmt("HUD_STOCKPILE", [bag_text(b.resources)]))
		if not BunkerState.parse_region_id(me.region_id).is_empty():
			parts.append(tr("HUD_POWER_ON") if InfraSim.is_powered(Session.world, me.region_id) else tr("HUD_POWER_OFF"))
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


## A small, quiet "+12 Scavenging XP" that drifts up and fades (iteration 013).
func show_xp(text: String) -> void:
	var l := UITheme.small(text, 14)
	l.modulate = Color(0.92, 0.86, 0.66, 0.0)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -160
	l.offset_right = 160
	l.offset_top = -190
	l.offset_bottom = -170
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.9, 0.25)
	tw.parallel().tween_property(l, "offset_top", -220.0, 1.8)
	tw.parallel().tween_property(l, "offset_bottom", -200.0, 1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func show_notice(key: String, args: Array) -> void:
	var refused := key.begins_with("ACTION_") or key.ends_with("FAILED") or key == "DEV_HOST_ONLY"
	if key.begins_with("ACTION_") or (key.begins_with("VEHICLE_") and key != "VEHICLE_STATION_WAGON") or key in ["FLASHLIGHT_NONE", "SLEEP_DECLINED", "SLEEP_NOT_HERE"]:
		Audio.play("ui.error")  # refused action (audio inbox clip)
	var icon_name := "warning" if refused else ("discovery" if key.begins_with("DISCOVER") else ("xp" if key.begins_with("SKILL") or key.begins_with("XP") else "info"))
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.panel_box(0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UITheme.icon_rect(icon_name, 22))
	var l := Label.new()
	l.text = UITheme.fmt(key, args)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 14)
	if refused:
		l.add_theme_color_override("font_color", UITheme.WARN)
	h.add_child(l)
	_notices.add_child(p)
	while _notices.get_child_count() > 4:
		var oldest := _notices.get_child(0)
		_notices.remove_child(oldest)  # queue_free alone would not shrink the count this frame
		oldest.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()  # dies with the toast if it is trimmed early
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
