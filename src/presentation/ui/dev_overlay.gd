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
		for rid in w.regions:
			var r: RegionState = w.regions[rid]
			for eid in Content.entity_ids(rid):
				lines.append("  %s rev %d %s" % [eid, r.rev(eid), JSON.stringify(r.entity_state(eid))])
	var s := Session.last_save
	lines.append("last save: %s" % ("—" if s.is_empty() else ("OK" if s["ok"] else "FAILED " + str(s["error"]))))
	lines.append("art/sound overrides active: %d · loops %s" % [Assets.override_count(), str(Audio.active_loops())])
	lines.append("log: " + ProjectSettings.globalize_path(SessionLog.log_path))
	_text.text = "\n".join(lines)
