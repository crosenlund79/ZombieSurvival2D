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
	_btn(g, "DEV_BUNKER_VIEW", func() -> void:
		var m := get_tree().root.get_node_or_null("Main")
		if m != null:
			m.toggle_bunker_view())
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
	_btn(g, "DEV_NIGHT", func() -> void: Session.request_dev_command("time", 22.0))
	_btn(g, "DEV_DAY", func() -> void: Session.request_dev_command("time", 9.0))
	_btn(g, "DEV_RAIN", func() -> void:
		# cycle through every weather kind
		var ks := EnvSim.KINDS
		var cur := ks.find(EnvSim.weather(Session.world)) if Session.world != null else 0
		Session.request_dev_command("weather", ks[(cur + 1) % ks.size()]))
	_btn(g, "DEV_COLD", func() -> void: Session.request_dev_command("warmth", 25.0))
	_btn(g, "DEV_HEAT", func() -> void: Session.request_dev_command("heat", 60.0))
	_btn(g, "DEV_SIEGE", func() -> void: Session.request_dev_command("siege", 15.0))
	_btn(g, "DEV_HUNGER", func() -> void: Session.request_dev_command("hunger", 20.0))
	_btn(g, "DEV_GRANT_KIT", func() -> void:
		for it in ["scrap_metal:8", "cement:4", "spike_kit:2", "timber_frame:1", "grow_light:1", "cloth:4", "electrical_parts:2"]:
			Session.request_dev_command("grant", it))
	_btn(g, "DEV_DAMAGE", func() -> void: Session.request_dev_command("damage_structures", 60.0))
	_btn(g, "DEV_REPAIR_ALL", func() -> void: Session.request_dev_command("repair_structures"))
	_btn(g, "DEV_RECRUIT", func() -> void: Session.request_dev_command("recruit", "mara"))
	_btn(g, "DEV_JOB_WATER", func() -> void: Session.request_dev_command("npc_job", "water"))
	_btn(g, "DEV_JOB_FARM", func() -> void: Session.request_dev_command("npc_job", "farm"))
	_btn(g, "DEV_REPORT", func() -> void: Session.request_dev_command("report"))
	_btn(g, "DEV_AI_LABELS", func() -> void: ZombieView.show_debug = not ZombieView.show_debug)
	_btn(g, "DEV_HUNT", func() -> void: Session.request_dev_command("hunt"))
	_btn(g, "DEV_AMBIENT", func() -> void:
		Session.request_dev_command("ambient", 0.0 if Session.world != null and Session.world.threat.ambient else 1.0))


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
			lines.append("burnt ones %d %s · ambient %s · attention here %.2f" % [w.zombies.size(), JSON.stringify(counts),
				str(w.threat.ambient), w.threat.local_attention(me.region_id, me.position)])
			lines.append_array(ZombieSim.hunt_lines(w))
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
