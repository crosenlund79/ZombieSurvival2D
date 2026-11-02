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
			Session.request_interact(a[0])
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
				arg = float(a[1])
			Session.request_dev_command(a[0], arg)
			await get_tree().create_timer(0.3).timeout
		"zoom":
			var view: RegionView = main.region_view
			if view != null and view.local_avatar != null:
				view.local_avatar.camera.zoom = Vector2(float(a[0]), float(a[0]))
				view.local_avatar.camera.reset_smoothing()
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
			players.append({"id": pid, "name": p.display_name, "online": p.online,
				"x": p.position.x, "y": p.position.y, "region": p.region_id})
		s["players"] = players
		var ents := {}
		for rid in w.regions:
			var r: RegionState = w.regions[rid]
			for eid in Content.entity_ids(rid):
				ents[eid] = {"state": r.entity_state(eid), "rev": r.rev(eid)}
		s["entities"] = ents
	var view: RegionView = main.region_view if main != null else null
	var v := {"exists": view != null and is_instance_valid(view)}
	if v["exists"]:
		v["instance_id"] = view.get_instance_id()
		v["avatars"] = view.avatar_count()
		if view.local_avatar != null:
			v["local_x"] = view.local_avatar.global_position.x
			v["local_y"] = view.local_avatar.global_position.y
		var doors := {}
		for n in view.find_children("*", "DoorView", true, false):
			var dv := n as DoorView
			doors[dv.entity_id] = {"open_visual": dv.is_open()}
		v["doors"] = doors
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
