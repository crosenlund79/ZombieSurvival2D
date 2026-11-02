class_name DevOverlay
extends Control
## Developer overlay (F3): live session/world/network/build information and a
## few commands. Commands that change the shared world go through the host
## (Session.request_dev_command); clients are refused unless the host allows it.

signal rebuild_view_requested
signal screenshot_requested

var _text: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -380
	offset_right = -10
	offset_top = 40
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(370, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.heading("DEV_TITLE", 16))
	_text = UITheme.small("", 12)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(340, 0)
	v.add_child(_text)
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	_btn(g, "DEV_SAVE", func() -> void: Session.request_dev_command("save"))
	_btn(g, "DEV_CLOCK", func() -> void: Session.request_dev_command("advance_clock", 3600.0))
	_btn(g, "DEV_SPAWN", func() -> void: Session.request_dev_command("spawn"))
	_btn(g, "DEV_RELOAD_ASSETS", func() -> void: Assets.reload())
	_btn(g, "DEV_REBUILD_VIEW", func() -> void: rebuild_view_requested.emit())
	_btn(g, "DEV_SCREENSHOT", func() -> void: screenshot_requested.emit())
	_btn(g, "DEV_CREATE_LEVEL", func() -> void: Session.request_dev_command("create_level"))
	_btn(g, "DEV_SPAWN_ZOMBIE", func() -> void: Session.request_dev_command("spawn_zombie"))
	_btn(g, "DEV_SPAWN_GROUP", func() -> void: Session.request_dev_command("spawn_group"))
	_btn(g, "DEV_NOISE", func() -> void: Session.request_dev_command("noise", 1.0))
	_btn(g, "DEV_HURT", func() -> void: Session.request_dev_command("hurt", 25.0))
	_btn(g, "DEV_HEAL", func() -> void: Session.request_dev_command("heal"))
	_btn(g, "DEV_PEACEFUL", func() -> void:
		Session.request_dev_command("peaceful", 1.0 if Session.world != null and Session.world.threat.enabled else 0.0))
	_btn(g, "DEV_GRANT_TIMBER", func() -> void: Session.request_dev_command("grant_stock", 12.0))
	_btn(g, "DEV_GRANT_SUPPLIES", func() -> void:
		Session.request_dev_command("grant", "fuel:2")
		Session.request_dev_command("grant", "water_dirty:3"))
	_btn(g, "DEV_THIRST", func() -> void: Session.request_dev_command("thirst", 20.0))
	_btn(g, "DEV_AI_LABELS", func() -> void: ZombieView.show_debug = not ZombieView.show_debug)


func _btn(parent: Control, key: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = key
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)


func _process(_delta: float) -> void:
	if not visible:
		return
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
			lines.append("zombies %d %s · attention here %.2f" % [w.zombies.size(), JSON.stringify(counts),
				w.threat.local_attention(me.region_id, me.position)])
			var hot := []
			for key in w.threat.zones:
				hot.append("%s=%.1f" % [key.substr(key.find("|") + 1), w.threat.zones[key]])
			if not hot.is_empty():
				lines.append("zones " + ", ".join(hot.slice(0, 6)))
	var s := Session.last_save
	lines.append("last save: %s" % ("—" if s.is_empty() else ("OK" if s["ok"] else "FAILED " + str(s["error"]))))
	lines.append("art/sound overrides active: %d · loops %s" % [Assets.override_count(), str(Audio.active_loops())])
	lines.append("log: " + ProjectSettings.globalize_path(SessionLog.log_path))
	_text.text = "\n".join(lines)
