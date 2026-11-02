class_name AutotestDriver
extends Node
## Test-only remote control, active only with the `--autotest` command-line
## flag. Reads one command per line from <user_root>/autotest_inbox.txt and
## writes the result plus a state report to <user_root>/autotest_outbox.json.
## Used by tools/mp_test.py to drive real, separate game processes.
## Commands go through the same public Session/Input paths a player uses.

var main: Node
var _inbox := ""
var _outbox := ""
var _done := 0
var _busy := false
var _notices: Array = []


func _ready() -> void:
	_inbox = Paths.user_root() + "autotest_inbox.txt"
	_outbox = Paths.user_root() + "autotest_outbox.json"
	if FileAccess.file_exists(_inbox):
		DirAccess.remove_absolute(_inbox)
	Session.notice.connect(func(k: String, a: Array) -> void: _note(k + " " + str(a)))
	Session.world_ended.connect(func(r: String) -> void: _note("ENDED " + r))
	_write({"seq": 0, "cmd": "ready", "ok": true, "error": "", "state": _state()})
	SessionLog.info("autotest", "driver_ready", {"inbox": ProjectSettings.globalize_path(_inbox)})


func _note(s: String) -> void:
	_notices.append(s)
	if _notices.size() > 20:
		_notices.pop_front()


func _process(_delta: float) -> void:
	if _busy or not FileAccess.file_exists(_inbox):
		return
	var lines := FileAccess.get_file_as_string(_inbox).split("\n", false)
	if lines.size() <= _done:
		return
	var line := lines[_done].strip_edges()
	_done += 1
	_busy = true
	_run(line)


func _run(line: String) -> void:
	var parts := line.split(" ", false)
	var cmd := parts[0] if parts.size() > 0 else ""
	var a := parts.slice(1)
	var ok := true
	var err := ""
	match cmd:
		"single", "host":
			var port := 0
			if cmd == "host":
				port = int(a[0])
				a = a.slice(1)
			var world_id := "" if a[0] == "new" else Saves.most_recent_world_id()
			var s := int(a[1]) if a[0] == "new" else -1
			var name: String = a[a.size() - 1]
			var res := Session.start_single(world_id, s, name) if cmd == "single" else Session.start_host(port, world_id, s, name)
			ok = res["ok"]
			err = str(res.get("error", "")) + " " + str(res.get("detail", ""))
			await get_tree().process_frame
		"join":
			var res2 := Session.start_join(a[0], int(a[1]), a[2])
			ok = res2["ok"]
			err = str(res2.get("error", ""))
			var t := 0.0
			while ok and not Session.in_world() and Session.mode == GameSession.Mode.CLIENT and t < 12.0:
				await get_tree().create_timer(0.1).timeout
				t += 0.1
			ok = Session.in_world()
			if not ok:
				err = "not in world; notices: " + str(_notices)
		"walk_to":
			var target := Vector2(float(a[0]), float(a[1]))
			var limit := float(a[2]) if a.size() > 2 else 8.0
			ok = await _walk_to(target, limit)
			if not ok:
				err = "could not reach target"
		"hold":
			Input.action_press(a[0])
			await get_tree().create_timer(float(a[1])).timeout
			Input.action_release(a[0])
		"press_interact":
			var ev := InputEventAction.new()
			ev.action = "interact"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.05).timeout
			var ev2 := InputEventAction.new()
			ev2.action = "interact"
			ev2.pressed = false
			Input.parse_input_event(ev2)
			await get_tree().create_timer(0.5).timeout
		"interact":
			Session.request_interact(a[0], int(a[1]) if a.size() > 1 else -1)
			await get_tree().create_timer(0.5).timeout
		"attack_nearest":
			# Swing at the nearest zombie n times (aim recomputed each swing).
			for i in int(a[0]):
				var me := Session.local_player()
				var best: ZombieState = null
				for z in Session.world.zombies.values():
					if z.region_id == me.region_id and not z.is_dead():
						if best == null or z.position.distance_to(me.position) < best.position.distance_to(me.position):
							best = z
				var aim := Vector2.DOWN if best == null else (best.position - me.position).normalized()
				if main.region_view != null and main.region_view.local_avatar != null:
					main.region_view.local_avatar.play_swing(aim)
				Session.request_attack(aim)
				await get_tree().create_timer(float(a[1]) if a.size() > 1 else 0.7).timeout
		"entity_action":
			Session.request_entity_action(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
		"press_key":
			# Tap an input action (e.g. drink) the way a player would.
			var kd := InputEventAction.new()
			kd.action = a[0]
			kd.pressed = true
			Input.parse_input_event(kd)
			await get_tree().create_timer(0.05).timeout
			var ku := InputEventAction.new()
			ku.action = a[0]
			ku.pressed = false
			Input.parse_input_event(ku)
			await get_tree().create_timer(0.5).timeout
		"build":
			Session.request_build(a[0], Vector2(float(a[1]), float(a[2])))
			await get_tree().create_timer(0.5).timeout
		"obj":
			Session.request_object(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
		"inv":
			Session.request_inventory(a[0], a[1] if a.size() > 1 else "")
			await get_tree().create_timer(0.4).timeout
		"eat":
			Session.request_eat()
			await get_tree().create_timer(0.4).timeout
		"npc":
			Session.request_npc(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
		"panel":
			# Open a UI panel: inventory / guide / settlement (screenshots).
			var pnl: Control = {"inventory": main.inventory_panel, "guide": main.guide, "settlement": main.settlement_panel}.get(a[0])
			if pnl != null:
				pnl.visible = a.size() < 2 or a[1] == "on"
			await get_tree().create_timer(0.4).timeout
		"build_ghost":
			BuildMode.forced_pos = Vector2(float(a[1]), float(a[2]))
			main.build_mode.start(a[0])
			await get_tree().create_timer(0.3).timeout
		"build_cancel":
			main.build_mode.cancel()
			BuildMode.forced_pos = Vector2.INF
			await get_tree().create_timer(0.2).timeout
		"build_menu":
			if a.size() > 0 and a[0] == "off":
				main.build_mode.close_menu()
			else:
				main.build_mode.open_menu()
			await get_tree().create_timer(0.3).timeout
		"panel_close":
			MachinePanel.close_current()
			await get_tree().create_timer(0.2).timeout
		"terrain":
			Session.request_terrain(a[0], Vector2i(int(a[1]), int(a[2])))
			await get_tree().create_timer(0.4).timeout
		"face":
			# Turn toward a direction by tapping the movement key briefly.
			var act := "move_" + a[0]
			Input.action_press(act)
			await get_tree().create_timer(0.08).timeout
			Input.action_release(act)
			await get_tree().create_timer(0.2).timeout
		"press_repeat":
			# Press the interact key n times, interval seconds apart (e.g. chopping).
			for i in int(a[0]):
				var down := InputEventAction.new()
				down.action = "interact"
				down.pressed = true
				Input.parse_input_event(down)
				await get_tree().create_timer(0.05).timeout
				var up := InputEventAction.new()
				up.action = "interact"
				up.pressed = false
				Input.parse_input_event(up)
				await get_tree().create_timer(float(a[1])).timeout
			await get_tree().create_timer(0.5).timeout
		"save":
			var r := Session.save_world()
			ok = r["ok"]
			err = str(r["error"])
		"leave":
			Session.leave()
			await get_tree().create_timer(0.6).timeout
		"wait":
			await get_tree().create_timer(float(a[0])).timeout
		"rebuild_view":
			main.rebuild_view()
			await get_tree().process_frame
		"reload_assets":
			Assets.reload()
			await get_tree().process_frame
		"dev":
			var arg: Variant = null
			if a.size() >= 3:
				arg = Vector2(float(a[1]), float(a[2]))
			elif a.size() == 2:
				arg = float(a[1]) if a[1].is_valid_float() else a[1]
			Session.request_dev_command(a[0], arg)
			await get_tree().create_timer(0.3).timeout
		"zoom":
			var view: RegionView = main.region_view
			if view != null and view.local_avatar != null:
				view.local_avatar.camera.zoom = Vector2(float(a[0]), float(a[0]))
				view.local_avatar.snap_camera()
			await get_tree().create_timer(0.3).timeout
		"screenshot":
			await RenderingServer.frame_post_draw
			var p: String = main.take_screenshot(a[0], false)
			ok = p != ""
		"ui":
			var on: bool = a.size() < 2 or a[1] == "on"
			match a[0]:
				"dev":
					main.dev_overlay.visible = on
				"pause":
					main.pause_menu.visible = on
				"map":
					main.map_panel.visible = on
				"settings":
					if on:
						main.open_settings()
					elif main.settings_panel != null:
						main.settings_panel.close_panel()
			await get_tree().create_timer(0.3).timeout
		"window":
			DisplayServer.window_set_size(Vector2i(int(a[0]), int(a[1])))
			await get_tree().create_timer(0.5).timeout
		"set":
			var v: Variant = a[2]
			if a[2].is_valid_float():
				v = float(a[2])
			Settings.set_value(a[0], a[1], v)
		"report":
			pass
		"quit":
			_write({"seq": _done, "cmd": line, "ok": true, "error": "", "state": _state()})
			get_tree().quit()
			return
		_:
			ok = false
			err = "unknown command"
	_write({"seq": _done, "cmd": line, "ok": ok, "error": err.strip_edges(), "state": _state()})
	_busy = false


func _walk_to(target: Vector2, limit: float) -> bool:
	var t := 0.0
	var actions := ["move_left", "move_right", "move_up", "move_down"]
	var result := false
	while t < 15.0:
		var view: RegionView = main.region_view
		if view == null or view.local_avatar == null:
			break
		var d := target - view.local_avatar.global_position
		if d.length() <= limit:
			result = true
			break
		for act in actions:
			Input.action_release(act)
		if absf(d.x) > 4.0:
			Input.action_press("move_right" if d.x > 0 else "move_left")
		if absf(d.y) > 4.0:
			Input.action_press("move_down" if d.y > 0 else "move_up")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for act in actions:
		Input.action_release(act)
	await get_tree().create_timer(0.3).timeout
	return result


func _state() -> Dictionary:
	var s := {"mode": Session.mode_name(), "net": Net.status_name(), "in_world": Session.in_world(),
		"local_player_id": Session.local_player_id, "notices": _notices.duplicate(),
		"last_save": Session.last_save, "loops": Audio.active_loops(),
		"fps": Engine.get_frames_per_second(), "nodes": get_tree().get_node_count(),
		"settings": {"language": Settings.language(), "ui_scale": Settings.ui_scale(),
			"camera_zoom": Settings.camera_zoom(), "master": Settings.bus_volume("Master"),
			"master_bus_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")),
			"interact_keys": Settings.action_keys("interact")}}
	var w := Session.world
	if w != null:
		s["world_id"] = w.world_id
		s["seed"] = w.world_seed
		s["tick"] = w.tick
		var players := []
		for pid in w.players:
			var p: PlayerState = w.players[pid]
			players.append({"gear": p.gear.map(func(g): return g["item"]), "hunger": p.hunger, "id": pid, "name": p.display_name, "online": p.online,
				"x": p.position.x, "y": p.position.y, "region": p.region_id, "carried": p.carried,
				"health": p.health, "dead": p.dead, "hydration": p.hydration})
		s["players"] = players
		var ents := {}
		var levels := {}
		for rid in w.regions:
			var r: RegionState = w.regions[rid]
			var target := ents
			if r.def_id != rid:
				levels[rid] = {}
				target = levels[rid]
			for eid in Content.entity_ids(r.def_id):
				target[eid] = {"state": r.entity_state(eid), "rev": r.rev(eid)}
		s["entities"] = ents
		s["level_entities"] = levels
		var bunkers := {}
		for bid in w.bunkers:
			var b: BunkerState = w.bunkers[bid]
			var depths := b.levels.keys()
			depths.sort()
			bunkers[bid] = {"levels": depths, "wood": b.amount("wood"), "entrance": b.entrance_region,
				"resources": b.resources.duplicate(),
				"powered": InfraSim.is_powered(w, b.level_region(depths[0])) if not depths.is_empty() else false}
		s["bunkers"] = bunkers
		var terrains := {}
		for rid in w.regions:
			var rr: RegionState = w.regions[rid]
			if not rr.terrain.is_empty():
				terrains[rid] = (rr.terrain.get("dug", {}) as Dictionary).keys()
		s["terrains"] = terrains
		var objs := {}
		for rid2 in w.regions:
			var r2: RegionState = w.regions[rid2]
			if r2.objects.is_empty():
				continue
			var row := {}
			for oid in r2.objects:
				var o: Dictionary = r2.objects[oid]
				row[oid] = {"def": o.get("def"), "tier": o.get("tier", 0), "hp": o.get("hp", 0), "stage": o.get("stage", "built"),
					"x": o.get("x"), "y": o.get("y"), "open": o.get("open", false), "items": o.get("items", {}),
					"stored": o.get("stored", 0), "crop": o.get("crop", ""), "water": o.get("water", 0)}
			objs[rid2] = row
		s["objects"] = objs
		s["env"] = w.env
		s["meta"] = w.meta
		s["jobs"] = w.jobs.size()
		var zs := []
		for z in w.zombies.values():
			zs.append({"id": z.zombie_id, "ai": z.state_name(), "x": z.position.x, "y": z.position.y,
				"region": z.region_id, "hp": z.health, "persistent": z.persistent})
		s["zombies"] = zs
		var me := Session.local_player()
		if me != null and w.region(me.region_id) != null and Terrain.has_terrain(w.region(me.region_id)):
			var tr := w.region(me.region_id)
			s["terrain"] = {"dug": (tr.terrain.get("dug", {}) as Dictionary).keys(),
				"digging": (tr.terrain.get("digging", {}) as Dictionary).keys(),
				"supports": tr.terrain.get("supports", {}),
				"me_cell": [Terrain.cell_of(tr, me.position).x, Terrain.cell_of(tr, me.position).y]}
		if me != null:
			s["region"] = me.region_id
			s["carried"] = me.carried
			s["gear"] = me.gear
			s["equipped"] = me.equipped
			s["hunger"] = me.hunger
			s["unlocks"] = w.meta.get("unlocks", {})
			s["health"] = me.health
			s["hydration"] = me.hydration
			s["dead"] = me.dead
			s["weapon"] = me.weapon
			s["attention"] = w.threat.local_attention(me.region_id, me.position)
			var total := 0.0
			for key in w.threat.zones:
				total += float(w.threat.zones[key])
			s["attention_total"] = total
			s["me_x"] = me.position.x
			s["me_y"] = me.position.y
			s["threat_label"] = Hud.threat_label(me)
	var view: RegionView = main.region_view if main != null else null
	var v := {"exists": view != null and is_instance_valid(view)}
	if v["exists"]:
		v["instance_id"] = view.get_instance_id()
		v["region"] = view.region_id
		var stages := {}
		for n in view.find_children("*", "EntityView", true, false):
			var ev := n as EntityView
			stages[ev.entity_id] = {"visible": ev.is_visible_in_tree(),
				"enabled": ev.interact.enabled if ev.interact != null else false,
				"stage": str(ev.state().get("stage", "")), "felled": bool(ev.state().get("felled", false))}
		v["entities"] = stages
		v["map_open"] = main.map_panel.visible
		v["zombies"] = view.zombie_count()
		var tv := view.get_node_or_null("Terrain") as TerrainView
		if tv != null:
			v["terrain_target"] = [tv._target.x, tv._target.y]
			v["terrain_mode"] = tv._mode
		v["map_legend"] = main.map_panel._legend.text if main.map_panel.visible else ""
		v["avatars"] = view.avatar_count()
		if view.local_avatar != null:
			v["local_x"] = view.local_avatar.global_position.x
			v["local_y"] = view.local_avatar.global_position.y
		var doors := {}
		for n in view.find_children("*", "DoorView", true, false):
			var dv := n as DoorView
			doors[dv.entity_id] = {"open_visual": dv.is_open()}
		v["doors"] = doors
		var lamps := {}
		for n in view.find_children("*", "LampView", true, false):
			lamps[(n as LampView).entity_id] = (n as LampView)._powered
		v["lamps"] = lamps
		v["objects"] = view.object_count()
		v["placing"] = BuildMode.placing
		v["build_problem"] = main.build_mode.problem if BuildMode.placing != "" else ""
		v["panel"] = MachinePanel.current.entity_id if MachinePanel.current != null and is_instance_valid(MachinePanel.current) else ""
		var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
		v["focused"] = sensor.focused.entity_id if sensor != null and sensor.focused != null else ""
	s["view"] = v
	var srcs := {}
	for id in AssetCatalog.ids():
		srcs[id] = Assets.source_of(id)
	s["asset_sources"] = srcs
	return s


func _write(d: Dictionary) -> void:
	var f := FileAccess.open(_outbox + ".tmp", FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	DirAccess.rename_absolute(_outbox + ".tmp", _outbox)
