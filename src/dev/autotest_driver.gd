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
		"devworld":
			Session.pending_preset = "dev"
			var rdw := Session.start_single("", 12345, a[0] if a.size() > 0 else "Tester")
			ok = rdw["ok"]
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
		"hold2":
			# Two actions at once (driving: throttle + steering): hold2 move_up move_left 1.5
			Input.action_press(a[0])
			Input.action_press(a[1])
			await get_tree().create_timer(float(a[2])).timeout
			Input.action_release(a[0])
			Input.action_release(a[1])
		"drive_to_region":
			# Iteration 015: drive the car you are driving along the mapped roads until
			# you arrive in <region> (crossing as many region edges as it takes).
			# drive_to_region <region_id> [max_seconds]
			ok = await _drive_to_region(a[0], float(a[1]) if a.size() > 1 else 240.0)
			if not ok:
				err = "did not arrive in " + a[0]
		"flash":
			# Presentation test: a lightning flash right now (the real ones are seeded by the world).
			var atm: Node = main.region_view.get_node_or_null("Atmosphere") if main.region_view != null else null
			if atm != null:
				atm.set("_flash", 1.0)
			await get_tree().process_frame
		"custom_graphics":
			Assets.set_custom_graphics(a[0] == "on")
			await get_tree().process_frame
		"equip_item":
			# equip_item <item>: equip the first gear item of that kind (e.g. club)
			var mei := Session.local_player()
			for g in mei.gear:
				if str(g["item"]) == a[0]:
					Session.request_inventory("equip", str(g["uid"]))
					break
			await get_tree().create_timer(0.4).timeout
		"vehicle":
			# vehicle <vehicle_id> <enter|exit|engine|store|take> [arg]
			Session.request_vehicle(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
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
				# Aim from where the avatar really is (a client's own replica row is not
				# updated while it walks; the avatar is, and that is what it reports).
				var from := me.position
				if main.region_view != null and main.region_view.local_avatar != null:
					from = main.region_view.local_avatar.global_position
				var best: ZombieState = null
				for z in Session.world.zombies.values():
					if z.region_id == me.region_id and not z.is_dead():
						if best == null or z.position.distance_to(from) < best.position.distance_to(from):
							best = z
				var aim := Vector2.DOWN if best == null else (best.position - from).normalized()
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
		"tap_key":
			# Tap a physical key (e.g. Left, Space) — for panels that read keys directly.
			var kk := InputEventKey.new()
			kk.keycode = OS.find_keycode_from_string(a[0])
			kk.pressed = true
			Input.parse_input_event(kk)
			await get_tree().create_timer(0.05).timeout
			var kr := kk.duplicate() as InputEventKey
			kr.pressed = false
			Input.parse_input_event(kr)
			await get_tree().create_timer(0.3).timeout
		"build":
			Session.request_build(a[0], Vector2(float(a[1]), float(a[2])))
			await get_tree().create_timer(0.5).timeout
		"obj":
			Session.request_object(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
		"inv":
			Session.request_inventory(a[0], a[1] if a.size() > 1 else "")
			await get_tree().create_timer(0.4).timeout
		"sleep_vote":
			Session.request_sleep_vote(a[0] == "yes")
			await get_tree().create_timer(0.4).timeout
		"eat":
			Session.request_eat()
			await get_tree().create_timer(0.4).timeout
		"npc":
			Session.request_npc(a[0], a[1], a[2] if a.size() > 2 else "")
			await get_tree().create_timer(0.5).timeout
		"tips":
			Settings.set_value("guide", "tips", a[0] == "on")
			if a[0] != "on":
				main.guide.dismiss()
		"panel":
			# Open a UI panel: inventory / guide / settlement (screenshots).
			var pnl: Control = {"inventory": main.inventory_panel, "guide": main.guide, "settlement": main.settlement_panel, "skills": main.skills_panel}.get(a[0])
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
			LockpickPanel.close_current()
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
				"dev_tab":
					# "ui dev_tab <n>": show the developer menu on tab n (iteration 013 screenshots)
					main.dev_overlay.visible = true
					main.dev_overlay.select_tab(int(a[1]))
				"pause":
					main.pause_menu.visible = on
				"map":
					main.map_panel.visible = on
				"inventory":
					main.inventory_panel.visible = on
				"map_local":
					main.map_panel.visible = true
					main.map_panel.set_mode("local" if on else "world")
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


## Steering along a region's mapped road toward the road end nearest the destination.
func _drive_to_region(dest: String, max_seconds: float) -> bool:
	var keys := ["move_up", "move_down", "move_left", "move_right"]
	var t := 0.0
	var region := ""
	var route: Array = []
	var dir := 1
	var dest_c := WorldGeo.world_rect(dest).get_center()
	var arrived := false
	var stall := 0.0
	var reverse_t := 0.0
	while t < max_seconds:
		var me := Session.local_player()
		if me == null or me.vehicle_id == "":
			break
		if me.region_id == dest:
			arrived = true
			break
		var v: VehicleState = Session.world.vehicles.get(me.vehicle_id)
		if v == null:
			break
		if me.region_id != region:
			region = me.region_id
			route = _best_road(region, dest_c)
			dir = 1
			if route.size() > 1:
				var off := WorldGeo.offset(region)
				var a0 := (route[0] as Vector2) + off
				var a1 := (route[route.size() - 1] as Vector2) + off
				dir = 1 if a1.distance_to(dest_c) < a0.distance_to(dest_c) else -1
		var pos := v.position
		var target := pos + Vector2.from_angle(v.rotation) * 200.0
		if route.size() > 1:
			var best := 0
			for i in route.size():
				if (route[i] as Vector2).distance_to(pos) < (route[best] as Vector2).distance_to(pos):
					best = i
			var ahead := clampi(best + dir * 2, 0, route.size() - 1)
			if (route[best] as Vector2).distance_to(pos) > 160.0:
				ahead = best  # off the road (arriving at a junction): get onto it first
			target = route[ahead]
			if ahead == best:  # at the road's end: keep going straight off the edge
				target = pos + ((route[ahead] as Vector2) - (route[clampi(ahead - dir, 0, route.size() - 1)] as Vector2)).normalized() * 400.0
		var want := (target - pos).angle()
		var diff := wrapf(want - v.rotation, -PI, PI)
		for k in keys:
			Input.action_release(k)
		# stalled against something: back off for a moment, steering the other way
		stall = stall + get_physics_process_delta_time() if absf(v.speed) < 25.0 else 0.0
		if stall > 1.2:
			reverse_t = 1.0
			stall = 0.0
		if reverse_t > 0.0:
			reverse_t -= get_physics_process_delta_time()
			Input.action_press("move_down")
			Input.action_press("move_left" if diff > 0.0 else "move_right")
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			continue
		if absf(diff) > 0.9 and absf(v.speed) > 180.0:
			Input.action_press("move_down")
		else:
			Input.action_press("move_up")
		if diff > 0.06:
			Input.action_press("move_right")
		elif diff < -0.06:
			Input.action_press("move_left")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for k in keys:
		Input.action_release(k)
	await get_tree().create_timer(0.3).timeout
	return arrived


## The mapped road of a region whose far end lies nearest a world point (local points).
func _best_road(region_id: String, toward: Vector2) -> Array:
	var off := WorldGeo.offset(region_id)
	var best: Array = []
	var best_d := INF
	for road in Content.region_def(region_id).get("map", {}).get("roads", []):
		if str(road.get("kind", "road")) != "road":
			continue
		var pts: Array = []
		for p in road.get("points", []):
			pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() < 2:
			continue
		var d := minf(((pts[0] as Vector2) + off).distance_to(toward), ((pts[pts.size() - 1] as Vector2) + off).distance_to(toward))
		if d < best_d:
			best_d = d
			best = pts
	# densify straight settlement roads so steering has waypoints every ~200 px
	var dense: Array = []
	for i in best.size() - 1:
		var a: Vector2 = best[i]
		var b: Vector2 = best[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 200.0))
		for k in n:
			dense.append(a.lerp(b, float(k) / n))
	if not best.is_empty():
		dense.append(best[best.size() - 1])
	return dense


func _walk_to(target: Vector2, limit: float) -> bool:
	var t := 0.0
	var actions := ["move_left", "move_right", "move_up", "move_down"]
	var result := false
	var start_region := Session.local_player().region_id if Session.local_player() != null else ""
	while t < 15.0:
		var view: RegionView = main.region_view
		if view == null or view.local_avatar == null:
			break
		# iteration 015: walking off a region edge carries you across — stop there
		if Session.local_player() != null and Session.local_player().region_id != start_region:
			result = true
			break
		var d := target - view.local_avatar.global_position
		if view.side:  # side-view bunker: walk along the floor toward the target's x
			d = Vector2(target.x - view.local_avatar.global_position.x, 0.0)
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
		s["omens"] = OmenView.recent.duplicate()
		s["hunts"] = ZombieSim.hunt_lines(w)
		s["ambient"] = w.threat.ambient
		s["zombie_rows"] = w.zombies.values().map(func(z): return {"id": z.zombie_id, "ai": z.state_name(), "hunter": z.hunter,
			"x": z.position.x, "y": z.position.y, "region": z.region_id, "hp": z.health, "target": z.target_player, "posture": z.posture})
		s["seed"] = w.world_seed
		var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
		if sensor != null and sensor.focused != null:
			s["focused"] = {"id": sensor.focused.entity_id, "lit": sensor.focused._lit.size()}
		s["blood_count"] = w.blood.size()
		s["xp_multiplier"] = SkillSim.multiplier(w)
		var meb := Session.local_player()
		if meb != null and w.region(meb.region_id) != null:
			s["terrain_dug"] = (w.region(meb.region_id).terrain.get("dug", {}) as Dictionary).size()
		s["animals"] = w.animals.values().map(func(an): return {"id": an.animal_id, "species": an.species, "region": an.region_id,
			"x": an.position.x, "y": an.position.y, "activity": an.activity})
		s["vehicles"] = w.vehicles.values().map(func(v): return {"id": v.vehicle_id, "region": v.region_id,
			"x": v.position.x, "y": v.position.y, "rot": v.rotation, "engine": v.engine_on, "seats": v.seats.duplicate(),
			"speed": v.speed, "cargo": v.cargo.duplicate(true)})
		s["tick"] = w.tick
		s["time_scale"] = Session.time_scale
		var players := []
		for pid in w.players:
			var p: PlayerState = w.players[pid]
			players.append({"gear": p.gear.map(func(g): return g["item"]), "hunger": p.hunger, "warmth": p.warmth, "vehicle": p.vehicle_id, "flashlight": p.flashlight, "id": pid, "name": p.display_name, "online": p.online,
				"x": p.position.x, "y": p.position.y, "region": p.region_id, "carried": p.carried,
				"health": p.health, "dead": p.dead, "hydration": p.hydration, "skills": p.skills.duplicate(true),
				"scav_level": SkillSim.level(p, "scavenging"), "scav_xp": SkillSim.xp(p, "scavenging"),
				"loaded": Firearms.loaded(Firearms.held(p)) if not Firearms.held(p).is_empty() else -1,
				"capacity": Inv.capacity(p)})
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
		s["sim_ms"] = Session.sim_ms
		var npcs := {}
		for n in w.npcs.values():
			npcs[n.npc_id] = {"region": n.region_id, "x": n.position.x, "y": n.position.y, "recruit": n.recruit, "job": n.job,
				"activity": n.activity, "status": n.status, "fed": n.fed}
		s["npcs"] = npcs
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
			s["heated"] = Build.heated(w, me.region_id)
			s["warmth_rate"] = SurvivalSim.warmth_rate(w, me)
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
			# Where the local player really is (a client's own replica row is not
			# updated while it walks; its avatar is). The raw row stays available.
			s["me_row_x"] = me.position.x
			s["me_row_y"] = me.position.y
			var av: Node2D = main.region_view.local_avatar if main.region_view != null else null
			var pos: Vector2 = av.global_position if av != null and main.region_view.region_id == me.region_id else me.position
			s["me_x"] = pos.x
			s["me_y"] = pos.y
			s["threat_label"] = Hud.threat_label(me)
	var view: RegionView = main.region_view if main != null else null
	var v := {"exists": view != null and is_instance_valid(view)}
	if v["exists"]:
		v["instance_id"] = view.get_instance_id()
		v["region"] = view.region_id
		v["side"] = view.side
		var stages := {}
		for n in view.find_children("*", "EntityView", true, false):
			var ev := n as EntityView
			stages[ev.entity_id] = {"visible": ev.is_visible_in_tree(),
				"enabled": ev.interact.enabled if ev.interact != null else false,
				"stage": str(ev.state().get("stage", "")), "felled": bool(ev.state().get("felled", false))}
		v["entities"] = stages
		v["map_open"] = main.map_panel.visible
		v["zombies"] = view.zombie_count()
		# iteration 015: how many of them the local player can actually see (PlayerSight)
		var seen := 0
		for zv in view.find_children("*", "ZombieView", true, false):
			if (zv as CanvasItem).modulate.a > 0.5:
				seen += 1
		v["zombies_seen"] = seen
		v["sight"] = PlayerSight.current != null
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
		v["npcs"] = view.npc_count()
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
