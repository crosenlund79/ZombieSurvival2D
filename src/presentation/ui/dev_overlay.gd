class_name DevOverlay
extends Control
## Developer overlay (F3): live session/world/network/build information and a
## few commands. Commands that change the shared world go through the host
## (Session.request_dev_command); clients are refused unless the host allows it.

signal rebuild_view_requested
signal screenshot_requested

var _text: Label
var _tabs: TabContainer


func select_tab(i: int) -> void:
	if _tabs != null:
		_tabs.current_tab = clampi(i, 0, _tabs.get_tab_count() - 1)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -400
	offset_right = -10
	offset_top = 40
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.heading("DEV_TITLE", 16))
	_text = UITheme.small("", 12)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(360, 0)
	var info := ScrollContainer.new()
	info.custom_minimum_size = Vector2(0, 230)
	info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(_text)
	v.add_child(info)
	# Iteration 013: commands grouped in categories. Every command that changes the
	# shared world is a host request (Session.request_dev_command).
	var tabs := TabContainer.new()
	_tabs = tabs
	tabs.custom_minimum_size = Vector2(0, 300)
	v.add_child(tabs)
	var world_tab := _tab(tabs, "DEV_TAB_WORLD")
	var player_tab := _tab(tabs, "DEV_TAB_PLAYER")
	var prog := VBoxContainer.new()
	prog.name = "DEV_TAB_PROGRESSION"
	tabs.add_child(prog)
	tabs.set_tab_title(2, tr("DEV_TAB_PROGRESSION"))
	# --- World
	_btn(world_tab, "DEV_SAVE", func() -> void: Session.request_dev_command("save"))
	_btn(world_tab, "DEV_CLOCK", func() -> void: Session.request_dev_command("advance_clock", 3600.0))
	_btn(world_tab, "DEV_NIGHT", func() -> void: Session.request_dev_command("time", 22.0))
	_btn(world_tab, "DEV_DAY", func() -> void: Session.request_dev_command("time", 9.0))
	# Iteration 014: world-time speed (single player only)
	for ts in [0.0, 1.0, 2.0, 5.0, 10.0]:
		var tv: float = ts
		_btn(world_tab, tr("DEV_TIME_PAUSE") if tv == 0.0 else (tr("DEV_TIME_X") % int(tv)), func() -> void: Session.request_dev_command("time_scale", tv))
	_btn(world_tab, "DEV_RAIN", func() -> void:
		# cycle through every weather kind
		var ks := EnvSim.KINDS
		var cur := ks.find(EnvSim.weather(Session.world)) if Session.world != null else 0
		Session.request_dev_command("weather", ks[(cur + 1) % ks.size()]))
	_btn(world_tab, "DEV_PEACEFUL", func() -> void:
		Session.request_dev_command("peaceful", 1.0 if Session.world != null and Session.world.threat.enabled else 0.0))
	# iteration 015: player visibility (local presentation only)
	_btn(world_tab, "DEV_SIGHT", func() -> void:
		Settings.set_value("dev", "player_sight", Settings.get_value("dev", "player_sight", true) == false))
	_btn(world_tab, "DEV_VIGNETTE", func() -> void:
		var vg := float(Settings.get_value("display", "vignette", 0.55))
		Settings.set_value("display", "vignette", 0.0 if vg >= 0.9 else (0.55 if vg < 0.5 else 1.0)))
	_btn(world_tab, "DEV_SPAWN_ZOMBIE", func() -> void: Session.request_dev_command("spawn_zombie"))
	_btn(world_tab, "DEV_SPAWN_GROUP", func() -> void: Session.request_dev_command("spawn_group"))
	_btn(world_tab, "DEV_NOISE", func() -> void: Session.request_dev_command("noise", 1.0))
	_btn(world_tab, "DEV_HUNT", func() -> void: Session.request_dev_command("hunt"))
	# iteration 015 E: hordes, hideouts, the test rifle
	_btn(world_tab, "DEV_HORDE", func() -> void: Session.request_dev_command("horde"))
	_btn(world_tab, "DEV_HORDES_TOGGLE", func() -> void:
		Session.request_dev_command("hordes", 0.0 if Session.world != null and HordeSim.enabled(Session.world) else 1.0))
	_btn(world_tab, "DEV_HIDEOUT_RESET", func() -> void: Session.request_dev_command("hideout_reset"))
	for hn in [1, 2, 3]:
		var hv: int = hn
		_btn(world_tab, tr("DEV_HIDEOUT_GOTO") % hv, func() -> void: Session.request_dev_command("hideout_goto", float(hv)))
	_btn(world_tab, "DEV_TEST_RIFLE", func() -> void:
		Session.request_dev_command("test_rifle", 0.0 if Session.world != null and bool(Session.world.meta.get("test_rifle", false)) else 1.0))
	_btn(world_tab, "DEV_AMBIENT", func() -> void:
		Session.request_dev_command("ambient", 0.0 if Session.world != null and Session.world.threat.ambient else 1.0))
	_btn(world_tab, "DEV_SIEGE", func() -> void: Session.request_dev_command("siege", 15.0))
	_btn(world_tab, "DEV_HEAT", func() -> void: Session.request_dev_command("heat", 60.0))
	_btn(world_tab, "DEV_CREATE_LEVEL", func() -> void: Session.request_dev_command("create_level"))
	_btn(world_tab, "DEV_BUNKER_VIEW", func() -> void:
		var m := get_tree().root.get_node_or_null("Main")
		if m != null:
			m.toggle_bunker_view())
	_btn(world_tab, "DEV_DAMAGE", func() -> void: Session.request_dev_command("damage_structures", 60.0))
	_btn(world_tab, "DEV_REPAIR_ALL", func() -> void: Session.request_dev_command("repair_structures"))
	_btn(world_tab, "DEV_RECRUIT", func() -> void: Session.request_dev_command("recruit", "mara"))
	_btn(world_tab, "DEV_JOB_WATER", func() -> void: Session.request_dev_command("npc_job", "water"))
	_btn(world_tab, "DEV_JOB_FARM", func() -> void: Session.request_dev_command("npc_job", "farm"))
	_btn(world_tab, "DEV_AI_LABELS", func() -> void: ZombieView.show_debug = not ZombieView.show_debug)
	_btn(world_tab, "DEV_RELOAD_ASSETS", func() -> void: Assets.reload())
	_btn(world_tab, "DEV_REBUILD_VIEW", func() -> void: rebuild_view_requested.emit())
	_btn(world_tab, "DEV_SCREENSHOT", func() -> void: screenshot_requested.emit())
	_btn(world_tab, "DEV_REPORT", func() -> void: Session.request_dev_command("report"))
	# --- Player
	_btn(player_tab, "DEV_SPAWN", func() -> void: Session.request_dev_command("spawn"))
	_btn(player_tab, "DEV_HURT", func() -> void: Session.request_dev_command("hurt", 25.0))
	_btn(player_tab, "DEV_HEAL", func() -> void: Session.request_dev_command("heal"))
	_btn(player_tab, "DEV_THIRST", func() -> void: Session.request_dev_command("thirst", 20.0))
	_btn(player_tab, "DEV_HUNGER", func() -> void: Session.request_dev_command("hunger", 20.0))
	_btn(player_tab, "DEV_COLD", func() -> void: Session.request_dev_command("warmth", 25.0))
	_btn(player_tab, "DEV_GRANT_TIMBER", func() -> void: Session.request_dev_command("grant_stock", 12.0))
	_btn(player_tab, "DEV_GRANT_SUPPLIES", func() -> void:
		Session.request_dev_command("grant", "fuel:2")
		Session.request_dev_command("grant", "water_dirty:3"))
	_btn(player_tab, "DEV_GRANT_KIT", func() -> void:
		for it in ["scrap_metal:8", "cement:4", "spike_kit:2", "timber_frame:1", "grow_light:1", "cloth:4", "electrical_parts:2"]:
			Session.request_dev_command("grant", it))
	# --- Progression (host only)
	_build_progression(prog)


## Progression tab: the XP multiplier (shared by every present and future skill,
## applies to XP earned from now on, never retroactive) and Scavenging cheats.
## Host only — on a client the controls are shown disabled.
var _mult_label: Label
var _mult_slider: HSlider
var _prog_label: Label
var _prog_controls: Array[Control] = []
var _target_all: CheckBox
var _syncing := false


func _build_progression(v: VBoxContainer) -> void:
	_prog_label = UITheme.small("", 12)
	_prog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_prog_label)
	_mult_label = UITheme.small("", 13)
	v.add_child(_mult_label)
	var m: Dictionary = SkillSim.data().get("xp_multiplier", {})
	_mult_slider = HSlider.new()
	_mult_slider.min_value = float(m.get("min", 0.0))
	_mult_slider.max_value = float(m.get("max", 25.0))
	_mult_slider.step = 0.5
	_mult_slider.value = 1.0
	_mult_slider.custom_minimum_size = Vector2(340, 20)
	_mult_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mult_slider.value_changed.connect(func(val: float) -> void:
		if not _syncing:
			Session.request_dev_command("xp_multiplier", val))
	v.add_child(_mult_slider)
	_prog_controls.append(_mult_slider)
	var quick := HBoxContainer.new()
	v.add_child(quick)
	for q in m.get("quick", [1, 5, 10, 25]):
		var qv := float(q)
		_prog_controls.append(_btn(quick, "%d×" % int(qv), func() -> void: Session.request_dev_command("xp_multiplier", qv)))
	_prog_controls.append(_btn(quick, "DEV_XP_RESET_MULT", func() -> void: Session.request_dev_command("xp_multiplier", 1.0)))
	_target_all = CheckBox.new()
	_target_all.text = "DEV_XP_ALL_PLAYERS"
	_target_all.add_theme_font_size_override("font_size", 12)
	v.add_child(_target_all)
	_prog_controls.append(_target_all)
	var g := GridContainer.new()
	g.columns = 3
	v.add_child(g)
	for amount in [25, 100, 500]:
		var a: int = amount
		_prog_controls.append(_btn(g, "+%d XP" % a, func() -> void: Session.request_dev_command("grant_xp", _target_arg(str(a)))))
	for lvl in [1, 5, 10]:
		var l: int = lvl
		_prog_controls.append(_btn(g, tr("DEV_SET_LEVEL") % l, func() -> void: Session.request_dev_command("set_skill_level", _target_arg(str(l)))))
	_prog_controls.append(_btn(g, "DEV_RESET_SCAV", func() -> void: Session.request_dev_command("reset_skill", _target_arg("0"))))


func _target_arg(base: String) -> String:
	return base + ("|all" if _target_all != null and _target_all.button_pressed else "")


func _tab(tabs: TabContainer, key: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = key
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr(key))
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(g)
	return g


func _btn(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_progression() -> void:
	if _mult_label == null:
		return
	var w := Session.world
	var mult := SkillSim.multiplier(w)
	_mult_label.text = UITheme.fmt("DEV_XP_MULT", ["%.1f" % mult])
	_syncing = true
	_mult_slider.set_value_no_signal(mult)
	_syncing = false
	var host := Session.is_authority()
	for c in _prog_controls:
		if c is BaseButton:
			(c as BaseButton).disabled = not host
		elif c is Range:
			(c as Range).editable = host
	var me := Session.local_player()
	var line := ""
	if me != null:
		var pr := SkillSim.progress(me, "scavenging")
		line = UITheme.fmt("DEV_SCAV_LINE", [pr["level"], pr["xp"], "%.1f" % SkillSim.search_seconds_at("shelf", int(pr["level"]))])
	if not host:
		line += "\n" + tr("DEV_PROGRESSION_HOST_ONLY")
	_prog_label.text = line


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_progression()
	var lines: Array[String] = []
	lines.append(BuildInfo.label())
	lines.append("engine %s · renderer %s · instance '%s' · %d fps · %d nodes" % [Engine.get_version_info().get("string", "?"),
		RenderingServer.get_current_rendering_method(), Paths.instance_name(), Engine.get_frames_per_second(),
		get_tree().get_node_count()])
	lines.append("mode %s · peer %d · authority %s · net %s %s" % [Session.mode_name(),
		multiplayer.get_unique_id(), str(Session.is_authority()), Net.status_name(), Net.detail])
	var w := Session.world
	if w != null:
		var me := Session.local_player()
		lines.append("world %s · seed %d · tick %d (%s)" % [w.world_id, w.world_seed, w.tick, Simulation.format_time(w)])
		if me != null:
			lines.append("region %s · me %s @ (%d, %d)" % [me.region_id, me.player_id.substr(0, 6), me.position.x, me.position.y])
		for p in w.online_players():
			lines.append("  · %s [%s] (%d, %d)" % [p.display_name, p.player_id.substr(0, 6), p.position.x, p.position.y])
		if me != null and w.region(me.region_id) != null:
			var r: RegionState = w.region(me.region_id)
			for eid in Content.entity_ids(r.def_id):
				if r.rev(eid) > 0:
					lines.append("  %s rev %d %s" % [eid, r.rev(eid), JSON.stringify(r.entity_state(eid))])
		for bid in w.bunkers:
			var b: BunkerState = w.bunkers[bid]
			var depths := b.levels.keys()
			depths.sort()
			lines.append("bunker %s · levels %s · wood %d" % [bid, str(depths), b.amount("wood")])
		if me != null:
			lines.append("carrying %s · jobs %d" % [JSON.stringify(me.carried), w.jobs.size()])
			lines.append("health %d · hydration %d · weapon '%s' · dead %s" % [me.health, me.hydration, me.weapon, str(me.dead)])
			var counts := {}
			for z in w.zombies.values():
				counts[z.state_name()] = int(counts.get(z.state_name(), 0)) + 1
			lines.append("burnt ones %d %s · ambient %s · attention here %.2f" % [w.zombies.size(), JSON.stringify(counts),
				str(w.threat.ambient), w.threat.local_attention(me.region_id, me.position)])
			lines.append_array(ZombieSim.hunt_lines(w))
			lines.append("hordes %s · %s · ai lod %s" % ["on" if HordeSim.enabled(w) else "off", ", ".join(HordeSim.lines(w)) if not w.threat.hordes.is_empty() else "none", JSON.stringify(ZombieSim.lod_counts)])
			var hot := []
			for key in w.threat.zones:
				hot.append("%s=%.1f" % [key.substr(key.find("|") + 1), w.threat.zones[key]])
			if not hot.is_empty():
				lines.append("zones " + ", ".join(hot.slice(0, 6)))
			lines.append("hunger %d · gear %s · equipped %s" % [me.hunger, JSON.stringify(me.gear.map(func(g): return "%s:%d" % [g["item"], g["cond"]])), JSON.stringify(me.equipped)])
			lines.append("heat %s · home %.1f · event %s" % [JSON.stringify(w.meta.get("heat", {})), EventSim.home_heat(w), JSON.stringify(EventSim.siege(w))])
			lines.append("day %d %s · %s until %d · sim %.2f ms" % [EnvSim.day_number(w), EnvSim.clock_text(w), EnvSim.weather(w), int(w.env.get("until", 0)), Session.sim_ms])
			for bid2 in w.bunkers:
				var lv := (w.bunkers[bid2] as BunkerState).level_region(-1)
				var lr := w.region(lv)
				if lr != null:
					lines.append("storage %s" % JSON.stringify((w.bunkers[bid2] as BunkerState).resources))
					lines.append("generator %s · purifier %s · power %s" % [JSON.stringify(lr.entity_state("generator")), JSON.stringify(lr.entity_state("purifier")), str(InfraSim.is_powered(w, lv))])
			var rr := w.region(me.region_id)
			if rr != null and not rr.objects.is_empty():
				var objs := []
				for oid in rr.objects:
					var o: Dictionary = rr.objects[oid]
					objs.append("%s:%s hp%s%s" % [oid, o.get("def"), str(o.get("hp", "-")), (" job" if o.has("job") else "") + (" " + str(o.get("crop", "")) if o.has("crop") else "")])
				lines.append("objects " + ", ".join(objs.slice(0, 10)))
			for n in w.npcs.values():
				lines.append("survivor %s %s %s job '%s' %s %s" % [n.name, n.recruit, n.region_id, n.job, n.activity, n.status])
			for e in SessionLog.recent(6):
				if str(e.get("cat", "")) in ["inventory", "world", "settlement", "threat"]:
					lines.append("· %s %s %s" % [e.get("cat"), e.get("ev"), JSON.stringify(e.get("data", {})).substr(0, 90)])
	var s := Session.last_save
	lines.append("last save: %s" % ("—" if s.is_empty() else ("OK" if s["ok"] else "FAILED " + str(s["error"]))))
	lines.append("art/sound overrides active: %d · loops %s" % [Assets.override_count(), str(Audio.active_loops())])
	lines.append("log: " + ProjectSettings.globalize_path(SessionLog.log_path))
	_text.text = "\n".join(lines)
