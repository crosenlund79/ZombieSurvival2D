class_name GameSession
extends Node
## The active game session (autoload `Session`).
##
## Owns: session mode, the WorldState (authoritative on host/single player,
## replica on clients), player identities, the shared clock tick loop, and the
## game network protocol (all RPCs live here, at /root/Session on every peer).
##
## Authority rule: clients *request* (join, move, interact, dev commands);
## the host validates with WorldActions, commits to WorldState, and broadcasts
## results. Single player runs the exact same host code path with an offline
## peer. Nothing here depends on which scene anyone is viewing.

signal world_started
signal world_ended(reason_key: String)
signal entity_changed(region_id: String, entity_id: String, state: Dictionary, cause: String)
signal roster_changed
signal local_position_corrected(position: Vector2)
signal notice(text_key: String, args: Array)
signal save_status_changed
signal join_progress(text_key: String)
signal bunker_changed(bunker_id: String)
signal player_resources_changed(player_id: String)
## The local player moved to another region (hatch, ladder, doorway). The app
## shell rebuilds the view; other players are unaffected.
signal local_region_changed(region_id: String)
## Combat/threat events for presentation (swings, hits, deaths, respawns).
signal combat_event(event: Dictionary)
signal vitals_changed(player_id: String)
signal zombies_updated
signal terrain_changed(region_id: String)
## A built structure or ground pile changed, appeared or disappeared.
signal object_changed(region_id: String, object_id: String)
## Weather, threat heat, defence event, discoveries or settlement data changed.
signal world_meta_changed
signal npcs_updated
## Iteration 011: a vehicle's seats / engine / trunk / region changed (full state).
signal vehicle_changed(vehicle_id: String)
## The host rejected the local driver's pose; the vehicle view snaps back.
signal vehicle_corrected(vehicle_id: String)
## Iteration 012: thawed-blood marks were added, changed or erased.
signal blood_changed
## Iteration 015 D: the host's answer to one of the local player's lock actions
## ({entity_id, set, pins, closeness, result: set|open|miss|broken}).
signal lock_feedback(info: Dictionary)

enum Mode { NONE, SINGLE, HOST, CLIENT }

const SNAPSHOT_INTERVAL := 0.1
const JOIN_TIMEOUT := 10.0
const CONNECT_TIMEOUT := 10.0
const AUTOSAVE_SECONDS := 300.0

var mode: int = Mode.NONE
var world: WorldState = null
var local_player_id := ""
var last_save := {}            # {ok, error, unix}
## Set by the menu before starting: "dev" prepares a Developer Test World (new worlds only).
var pending_preset := ""
## Average milliseconds spent in Simulation.advance per frame (diagnostics).
var sim_ms := 0.0

var _peer_to_player := {}      # host: peer id -> player id
var _move_track := {}          # host: player id -> last accepted msec
var _tick_accum := 0.0
## Iteration 014: developer world-time speed (0 = paused, 1 = normal, up to 10×).
## Single player only: the shared clock of a hosted game always runs at 1×, and a
## client never touches it. Runtime only (back to 1× on every start).
var time_scale := 1.0
const TIME_SCALES: Array[float] = [0.0, 1.0, 2.0, 5.0, 10.0]
var _snapshot_accum := 0.0
var _autosave_accum := 0.0
var _pending_join := {}        # client: {"token", "name"} until welcomed
var _join_wait := -1.0
var _connect_wait := -1.0
var _next_request := 1
var _closing := false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Net.status_changed.connect(_on_net_status)


# ======================================================================
# Starting and ending sessions
# ======================================================================

func is_authority() -> bool:
	return mode == Mode.SINGLE or mode == Mode.HOST


func in_world() -> bool:
	return world != null and local_player_id != ""


func mode_name() -> String:
	return Mode.keys()[mode]


## world_id "" = new world. new_seed < 0 = random seed.
func start_single(world_id: String, new_seed: int, player_name: String) -> Dictionary:
	if mode != Mode.NONE:
		return {"ok": false, "error": "SESSION_ALREADY_RUNNING"}
	var res := _open_world(world_id, new_seed)
	if not res["ok"]:
		return res
	mode = Mode.SINGLE
	Net.start_single()
	_admit_host_player(player_name)
	_begin()
	return {"ok": true}


func start_host(port: int, world_id: String, new_seed: int, player_name: String) -> Dictionary:
	if mode != Mode.NONE:
		return {"ok": false, "error": "SESSION_ALREADY_RUNNING"}
	var res := _open_world(world_id, new_seed)
	if not res["ok"]:
		return res
	if Net.host(port) != OK:
		world = null
		return {"ok": false, "error": "NET_HOST_FAILED"}
	mode = Mode.HOST
	_admit_host_player(player_name)
	_begin()
	return {"ok": true}


func start_join(address: String, port: int, player_name: String) -> Dictionary:
	if mode != Mode.NONE:
		return {"ok": false, "error": "SESSION_ALREADY_RUNNING"}
	var name := SettingsService.sanitize_name(player_name)
	_pending_join = {"token": Settings.player_token(name), "name": name}
	mode = Mode.CLIENT
	if Net.join(address, port) != OK:
		mode = Mode.NONE
		return {"ok": false, "error": "NET_CONNECT_FAILED"}
	_connect_wait = 0.0
	join_progress.emit("JOIN_CONNECTING")
	return {"ok": true}


## Leave the session. The authority saves first and tells clients it is closing.
func leave(reason_key: String = "SESSION_LEFT") -> void:
	if mode == Mode.NONE or _closing:
		return
	_closing = true
	if is_authority() and world != null:
		save_world()
	if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
		_rpc_session_closing.rpc("SESSION_HOST_CLOSED")
		await get_tree().create_timer(0.3).timeout
	_end(reason_key)


func _end(reason_key: String) -> void:
	if mode == Mode.NONE:
		_closing = false
		return
	SessionLog.info("session", "ended", {"mode": mode_name(), "reason": reason_key})
	Net.close()
	mode = Mode.NONE
	world = null
	local_player_id = ""
	_peer_to_player.clear()
	_move_track.clear()
	_pending_join.clear()
	_join_wait = -1.0
	_connect_wait = -1.0
	_closing = false
	world_ended.emit(reason_key)


func _open_world(world_id: String, new_seed: int) -> Dictionary:
	if world_id == "":
		var s := new_seed
		if s < 0:
			s = randi() % 1_000_000_000
		world = WorldState.create_new(WorldState.new_world_id(), s)
		# iteration 015 E test start: --test-rifle, or Settings dev/test_rifle_start
		if Paths.has_arg("test-rifle") or Settings.get_value("dev", "test_rifle_start", false) == true:
			world.meta["test_rifle"] = true
		SessionLog.info("session", "world_created", {"world_id": world.world_id, "seed": world.world_seed})
		return {"ok": true}
	var res := Saves.load_world(world_id)
	if not res["ok"]:
		return {"ok": false, "error": "SAVE_LOAD_FAILED", "detail": res["error"]}
	world = res["world"]
	for w in res["warnings"]:
		notice.emit("SAVE_LOAD_WARNING", [w])
	return {"ok": true}


func _begin() -> void:
	if is_authority():
		if not world.threat.ambient:
			# Red Thaw: worlds no longer keep a roaming population; base-population
			# figures from older saves are released here (logged), never duplicated.
			var gone := 0
			for zid in world.zombies.keys():
				if world.zombies[zid].persistent:
					world.zombies.erase(zid)
					gone += 1
			if gone > 0:
				SessionLog.info("threat", "population_released", {"count": gone})
		var added := ZombieSim.ensure_population(world)
		EventSim.resume_after_load(world)
		NpcSim.ensure(world)
		VehicleSim.ensure(world)
		WorldActions.ensure_prebuilt_shelters(world)
		WildlifeSim.ensure(world)
		# Players who are not here cannot stay in a seat (they rejoin beside the car).
		for po in world.players.values():
			if not po.online and po.vehicle_id != "":
				VehicleSim.eject(world, po)
		SessionLog.info("threat", "population_ready", {"zombies": world.zombies.size(), "added": added})
	_tick_accum = 0.0
	_snapshot_accum = 0.0
	_autosave_accum = 0.0
	time_scale = 1.0
	SessionLog.info("session", "started", {"mode": mode_name(), "world_id": world.world_id,
		"seed": world.world_seed, "tick": world.tick, "player": local_player_id})
	world_started.emit()


func _admit_host_player(player_name: String) -> void:
	var name := SettingsService.sanitize_name(player_name)
	var p := _admit_player(1, Settings.player_token(name), name)
	local_player_id = p.player_id
	if pending_preset == "dev" and world.tick == 0:
		DevPreset.apply(world, p.player_id)
	pending_preset = ""


## Host: register (or welcome back) a player for a connected peer.
func _admit_player(peer_id: int, token: String, name: String) -> PlayerState:
	var p: PlayerState = world.players.get(token, null)
	var returning := p != null
	if p == null:
		p = PlayerState.new()
		p.player_id = token
		p.region_id = Content.DEFAULT_REGION
		p.position = Content.spawn_point(p.region_id, world.players.size())
		world.players[token] = p
	p.display_name = name
	p.online = true
	SideSection.settle(world, p)  # iteration 014: interiors became cross-sections
	p.last_seen_unix = int(Time.get_unix_time_from_system())
	_peer_to_player[peer_id] = token
	_move_track[token] = Time.get_ticks_msec()
	SessionLog.info("session", "player_joined", {"peer": peer_id, "player": token.substr(0, 6),
		"name": name, "returning": returning, "position": [p.position.x, p.position.y]})
	return p


# ======================================================================
# Clock, snapshots, autosave (authority)
# ======================================================================

func _physics_process(delta: float) -> void:
	if mode == Mode.CLIENT and _connect_wait >= 0.0:
		_connect_wait += delta
		if _connect_wait > CONNECT_TIMEOUT:
			SessionLog.warn("net", "connect_timeout", {"address": Net.address, "port": Net.port})
			_end("NET_CONNECT_FAILED")
		return
	if mode == Mode.CLIENT and _join_wait >= 0.0:
		_join_wait += delta
		if _join_wait > JOIN_TIMEOUT:
			SessionLog.warn("session", "join_timeout", {})
			_end("JOIN_TIMEOUT")
		return
	if not is_authority() or world == null:
		return
	_tick_accum += delta * (time_scale if mode == Mode.SINGLE else 1.0)
	var step := 1.0 / Simulation.TICK_RATE
	var ticks := 0
	while _tick_accum >= step:
		_tick_accum -= step
		ticks += 1
	_advance(ticks)
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		save_world()
	if mode == Mode.HOST:
		_snapshot_accum += delta
		if _snapshot_accum >= SNAPSHOT_INTERVAL:
			_snapshot_accum = 0.0
			_broadcast_snapshot()
			_broadcast_zombies()


## Advances the shared clock and publishes constructions that completed.
func _advance(ticks: int) -> void:
	var t0 := Time.get_ticks_usec()
	var results := Simulation.advance(world, ticks)
	sim_ms = lerpf(sim_ms, float(Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	for res in results:
		if not (res["changes"] as Array).is_empty() or not (res["bunkers"] as Array).is_empty():
			SessionLog.info("world", "construction_completed", {"changes": res["changes"], "bunkers": res["bunkers"]})
		_publish_result(res)


## Zombie rows for every region: [id, region, x, y, fx, fy, ai, health].
## Sent unreliably at the snapshot rate; clients interpolate. Includes the
## hottest attention zones so players can read the threat level.
func _broadcast_zombies() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var rows := []
	for z in world.zombies.values():
		rows.append([z.zombie_id, z.region_id, snappedf(z.position.x, 0.1), snappedf(z.position.y, 0.1),
			snappedf(z.facing.x, 0.01), snappedf(z.facing.y, 0.01), z.ai, roundi(z.health), z.posture, 1 if z.burst > 0.0 else 0])
	var zones := []
	for key in world.threat.zones:
		if float(world.threat.zones[key]) >= 0.3:
			zones.append([key, snappedf(world.threat.zones[key], 0.01)])
	_rpc_zombies.rpc(rows, zones)


func _broadcast_snapshot() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var rows := []
	for p in world.online_players():
		rows.append([p.player_id, p.position, p.facing])
	_rpc_snapshot.rpc(world.tick, rows)
	if not world.vehicles.is_empty():
		_rpc_vehicles.rpc(VehicleSim.rows(world))
	if not world.animals.is_empty():
		_rpc_animals.rpc(WildlifeSim.rows(world))


func _roster_rows() -> Array:
	var rows := []
	for p in world.online_players():
		rows.append({"id": p.player_id, "name": p.display_name, "region": p.region_id,
			"position": p.position, "facing": p.facing, "carried": p.carried,
			"vitals": _vitals_row(p), "vehicle": p.vehicle_id})
	return rows


func _broadcast_roster() -> void:
	roster_changed.emit()
	if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
		_rpc_roster.rpc(_roster_rows())


# ======================================================================
# Public requests (local player). On the host these run the host handler
# directly; on clients they become RPCs to the host (peer 1).
# ======================================================================

func submit_local_move(pos: Vector2, facing: int) -> void:
	if not in_world():
		return
	var region := local_player().region_id
	if is_authority():
		_host_handle_move(1, pos, facing, region)
	else:
		_rpc_submit_move.rpc_id(1, pos, facing, region)


## Vehicles (iteration 011): enter / exit / engine / store / take.
func request_vehicle(vehicle_id: String, action: String, arg: String = "") -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_vehicle(1, vehicle_id, action, arg)
	else:
		_rpc_request_vehicle.rpc_id(1, vehicle_id, action, arg)


## The local driver reports the predicted pose of the vehicle (20 Hz).
func submit_vehicle_pose(vehicle_id: String, pos: Vector2, rot: float, speed: float, steer: float) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_vehicle_pose(1, vehicle_id, pos, rot, speed, steer)
	else:
		_rpc_submit_vehicle_pose.rpc_id(1, vehicle_id, pos, rot, speed, steer)


func _host_handle_vehicle(peer_id: int, vehicle_id: String, action: String, arg: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := VehicleSim.request(world, pid, vehicle_id, action, arg)
	if res["ok"]:
		_move_track["veh:" + vehicle_id] = Time.get_ticks_msec()
		_publish_result(res)
	else:
		SessionLog.info("vehicle", "request_refused", {"vehicle": vehicle_id, "action": action, "by": pid.substr(0, 6), "reason": res["reason"]})
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


func _host_handle_vehicle_pose(peer_id: int, vehicle_id: String, pos: Vector2, rot: float, speed: float, steer: float) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	var key := "veh:" + vehicle_id
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - int(_move_track.get(key, now))) / 1000.0)
	_move_track[key] = now
	var res := VehicleSim.submit_pose(world, pid, vehicle_id, pos, rot, speed, steer, dt)
	if not res["ok"]:
		if res.get("correct", false):
			var v: VehicleState = world.vehicles.get(vehicle_id)
			if v != null:
				if peer_id == 1:
					vehicle_corrected.emit(vehicle_id)
				else:
					_rpc_vehicle_correct.rpc_id(peer_id, vehicle_id, v.position, v.rotation)
		return
	if not (res.get("vehicles", []) as Array).is_empty() or not (res.get("transitions", []) as Array).is_empty():
		_publish_result(res)


## rev_override >= 0 sends an explicit revision (tests use it to reproduce
## truly simultaneous requests made from the same revision).
func request_interact(entity_id: String, rev_override: int = -1) -> void:
	if not in_world():
		return
	var p: PlayerState = world.players.get(local_player_id)
	var region := world.region(p.region_id)
	var rev := region.rev(entity_id) if region != null else 0
	if rev_override >= 0:
		rev = rev_override
	var req := _next_request
	_next_request += 1
	if is_authority():
		_host_handle_interact(1, req, entity_id, rev)
	else:
		_rpc_request_interact.rpc_id(1, req, entity_id, rev)


## Melee swing toward a direction. The swing animation plays locally at once;
## the host decides whether anything was hit.
func request_attack(aim: Vector2) -> void:
	if not in_world() or local_player().dead:
		return
	if is_authority():
		_host_handle_attack(1, aim)
	else:
		_rpc_request_attack.rpc_id(1, aim)


## Panel action on storage / generator / purifier.
func request_entity_action(entity_id: String, action: String, arg: Variant = "") -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_entity_action(1, entity_id, action, str(arg))
	else:
		_rpc_request_entity_action.rpc_id(1, entity_id, action, str(arg))


func request_drink() -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_drink(1)
	else:
		_rpc_request_drink.rpc_id(1)


func _host_handle_entity_action(peer_id: int, entity_id: String, action: String, arg: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := WorldActions.request_entity_action(world, pid, entity_id, action, arg)
	if res["ok"]:
		SessionLog.info("world", "entity_action", {"entity": entity_id, "action": action, "arg": arg, "by": pid.substr(0, 6)})
		_publish_result(res)
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


func _host_handle_drink(peer_id: int) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := WorldActions.request_drink(world, pid)
	if res["ok"]:
		_publish_result(res)
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


## Inventory action for the local player: equip, unequip, drop, use.
func request_inventory(action: String, arg: String) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_inventory(1, action, arg)
	else:
		_rpc_request_inventory.rpc_id(1, action, arg)


## Eat the most filling food you carry.
func request_eat() -> void:
	var me := local_player()
	if me == null:
		return
	var food := Inv.best_food(me)
	if food == "":
		notice.emit("ACTION_NO_FOOD", [])
		return
	request_inventory("use", food)


## Talk to / assign a survivor.
func request_npc(npc_id: String, action: String, arg: String = "") -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_npc(1, npc_id, action, arg)
	else:
		_rpc_request_npc.rpc_id(1, npc_id, action, arg)


func _host_handle_inventory(peer_id: int, action: String, arg: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := Inv.request(world, pid, action, arg)
	if res["ok"]:
		SessionLog.info("inventory", action, {"arg": arg, "by": pid.substr(0, 6)})
		_publish_result(res)
		if not (res["notice"] as Dictionary).is_empty():
			_send_notice(peer_id, res["notice"]["key"], res["notice"]["args"])
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


func _host_handle_npc(peer_id: int, npc_id: String, action: String, arg: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := NpcSim.request(world, pid, npc_id, action, arg)
	if res["ok"]:
		_publish_result(res)
		if not (res["notice"] as Dictionary).is_empty():
			_send_notice(peer_id, res["notice"]["key"], res["notice"]["args"])
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


## Place a structure (content/buildables.json) at a world position.
func request_build(def_id: String, pos: Vector2) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_build(1, def_id, pos)
	else:
		_rpc_request_build.rpc_id(1, def_id, pos)


## Act on a built object or ground pile in the local player's region.
func request_object(object_id: String, action: String, arg: String = "") -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_object(1, object_id, action, arg)
	else:
		_rpc_request_object.rpc_id(1, object_id, action, arg)


func _host_handle_build(peer_id: int, def_id: String, pos: Vector2) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := Build.request_build(world, pid, def_id, pos)
	if res["ok"]:
		SessionLog.info("world", "build", {"def": def_id, "pos": [pos.x, pos.y], "by": pid.substr(0, 6), "objects": res["objects"]})
		_publish_result(res)
	else:
		SessionLog.info("world", "build_rejected", {"def": def_id, "reason": res["reason"], "by": pid.substr(0, 6)})
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


func _host_handle_object(peer_id: int, object_id: String, action: String, arg: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := Build.request_object(world, pid, object_id, action, arg)
	if res["ok"]:
		SessionLog.info("world", "object_action", {"oid": object_id, "action": action, "arg": arg, "by": pid.substr(0, 6)})
		_publish_result(res)
		if not (res["notice"] as Dictionary).is_empty():
			_send_notice(peer_id, res["notice"]["key"], res["notice"]["args"])
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


## Excavation request: action "dig" (a solid cell) or "support" (an open cell).
func request_terrain(action: String, cell: Vector2i) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_terrain(1, action, cell)
	else:
		_rpc_request_terrain.rpc_id(1, action, cell)


func _host_handle_terrain(peer_id: int, action: String, cell: Vector2i) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := WorldActions.request_terrain(world, pid, action, cell)
	if res["ok"]:
		SessionLog.info("world", "terrain", {"action": action, "cell": [cell.x, cell.y], "by": pid.substr(0, 6)})
		_publish_result(res)
	else:
		SessionLog.warn("world", "terrain_rejected", {"action": action, "cell": [cell.x, cell.y], "reason": res["reason"]})
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


func request_dev_command(cmd: String, arg: Variant = null) -> void:
	if not in_world():
		return
	if is_authority():
		_host_dev_command(1, cmd, arg)
	else:
		_rpc_dev_command.rpc_id(1, cmd, arg)


func save_world() -> Dictionary:
	if not is_authority() or world == null:
		notice.emit("SAVE_HOST_ONLY", [])
		return {"ok": false, "error": "SAVE_HOST_ONLY"}
	for p in world.online_players():
		p.last_seen_unix = int(Time.get_unix_time_from_system())
	var res := Saves.save_world(world)
	last_save = {"ok": res["ok"], "error": res["error"], "unix": int(Time.get_unix_time_from_system())}
	save_status_changed.emit()
	notice.emit("SAVE_OK" if res["ok"] else "SAVE_FAILED", [res["error"]])
	return res


func local_player() -> PlayerState:
	if world == null:
		return null
	return world.players.get(local_player_id, null)


func players_in_region(region_id: String) -> Array:
	var out := []
	if world == null:
		return out
	for p in world.online_players():
		if p.region_id == region_id:
			out.append(p)
	return out


# ======================================================================
# Host handlers (authority). peer_id 1 = the host's own player.
# ======================================================================

func _host_handle_join(peer_id: int, token: String, name: String, protocol: int, fingerprint: String) -> void:
	var reject := ""
	if protocol != BuildInfo.PROTOCOL_VERSION:
		reject = "JOIN_REJECT_VERSION"
	elif fingerprint != Content.fingerprint():
		reject = "JOIN_REJECT_CONTENT"
	elif not _valid_token(token):
		reject = "JOIN_REJECT_IDENTITY"
	elif world.players.has(token) and (world.players[token] as PlayerState).online:
		reject = "JOIN_REJECT_DUPLICATE"
	elif _peer_to_player.has(peer_id):
		return
	if reject != "":
		SessionLog.warn("session", "join_rejected", {"peer": peer_id, "reason": reject,
			"client_protocol": protocol, "client_content": fingerprint})
		_rpc_join_rejected.rpc_id(peer_id, reject)
		get_tree().create_timer(0.5).timeout.connect(func() -> void: Net.kick(peer_id))
		return
	var p := _admit_player(peer_id, token, SettingsService.sanitize_name(name))
	_rpc_welcome.rpc_id(peer_id, SaveCodec.encode(world), p.player_id)
	_broadcast_roster()
	notice.emit("PLAYER_JOINED", [p.display_name])


func _host_handle_move(peer_id: int, pos: Vector2, facing: int, region_id: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	var p: PlayerState = world.players[pid]
	if region_id != p.region_id:
		return  # sent before a region change reached that player; ignore
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - int(_move_track.get(pid, now))) / 1000.0)
	_move_track[pid] = now
	if p.dead or p.vehicle_id != "":
		return  # a seated player moves with the vehicle (VehicleSim.submit_pose)
	var side := SideSection.side_for(world, p)
	if side and _side_move_ok(p, pos, dt):
		p.position = pos
		p.facing = clampi(facing, 0, 3)
		return
	if not WorldActions.is_plausible_move(p.position, pos, dt):
		SessionLog.warn("session", "move_rejected", {"player": pid.substr(0, 6),
			"from": [p.position.x, p.position.y], "to": [pos.x, pos.y], "dt": snappedf(dt, 0.001)})
		_send_correction(peer_id, p.position)
		return
	# Running is loud: speed above walking pace makes a small noise now and then.
	if p.position.distance_to(pos) / dt > PlayerAvatar.SPEED * 1.2:
		var nk := pid + ":run_noise"
		if world.tick - int(world.cooldowns.get(nk, -1000)) >= 5:
			world.cooldowns[nk] = world.tick
			ZombieSim.make_noise(world, p.region_id, pos, "run")
	p.position = pos
	p.facing = clampi(facing, 0, 3)
	# Iteration 015: stepping off the edge of an outdoor region carries you into its neighbour.
	var travel := WorldActions.edge_travel(world, p)
	if not travel.is_empty():
		_publish_result(travel)


## Side view (iteration 012): walking is horizontal, steps are one row, climbing
## follows ladders and supports — so a vertical change can be larger than a
## top-down move in the same time. Accept horizontal speed and an open spot.
func _side_move_ok(p: PlayerState, pos: Vector2, dt: float) -> bool:
	var region := world.region(p.region_id)
	if region == null:
		return false
	var max_dx := WorldActions.MAX_PLAYER_SPEED * dt * 1.5 + WorldActions.MOVE_SLACK
	var max_dy := SideSection.row_h(region) * 1.6 + 420.0 * dt * 1.5
	if absf(pos.x - p.position.x) > max_dx or absf(pos.y - p.position.y) > max_dy:
		return false
	return SideSection.open_at(region, pos + Vector2(0, -6))


## The local player's bunker perspective (iteration 012 experiment).
func request_bunker_view(view: String) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_bunker_view(1, view)
	else:
		_rpc_request_bunker_view.rpc_id(1, view)


func _host_handle_bunker_view(peer_id: int, view: String) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var p: PlayerState = world.players.get(pid)
	if p == null or not (view in ["side", "top"]):
		return
	p.bunker_view = view
	SessionLog.info("bunker_view", "set", {"player": pid.substr(0, 6), "view": view})
	if view == "side" and SideSection.is_level(p.region_id):
		var region := world.region(p.region_id)
		if not SideSection.open_at(region, p.position + Vector2(0, -6)) or not SideSection.climbable(world, region, p.position):
			p.position = SideSection.rest(region, p.position)
		_move_track[pid] = Time.get_ticks_msec()
		_send_correction(peer_id, p.position)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_bunker_view(view: String) -> void:
	if mode == Mode.HOST:
		_host_handle_bunker_view(multiplayer.get_remote_sender_id(), view)


func _host_handle_interact(peer_id: int, request_id: int, entity_id: String, expected_rev: int) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var result := WorldActions.request_interact(world, pid, entity_id, expected_rev)
	if result["ok"]:
		SessionLog.info("world", "interaction", {"entity": entity_id, "by": pid.substr(0, 6),
			"changes": result["changes"], "bunkers": result["bunkers"], "transition": str(result["transition"])})
		_publish_result(result)
		if not (result["notice"] as Dictionary).is_empty():
			_send_notice(peer_id, result["notice"]["key"], result["notice"]["args"])
	elif result["reason"] != "ACTION_TOO_FAST":
		SessionLog.warn("world", "interaction_rejected", {"entity": entity_id, "by": pid.substr(0, 6),
			"reason": result["reason"], "expected_rev": expected_rev})
	_send_action_result(peer_id, request_id, result["ok"], result["reason"], result["reason_args"])


func _host_handle_attack(peer_id: int, aim: Vector2) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	var res := WorldActions.request_attack(world, pid, aim)
	if res["ok"]:
		_publish_result(res)


static func _vitals_row(p: PlayerState) -> Array:
	return [snappedf(p.health, 0.1), snappedf(p.hydration, 0.1), p.dead, p.weapon, snappedf(p.hunger, 0.1), snappedf(p.warmth, 0.1), p.flashlight]


## Sends everything a WorldActions result changed to all peers, in an order
## clients can apply: bunkers (may add regions) -> entities -> carried -> vitals
## -> events -> moves.
func _publish_result(res: Dictionary) -> void:
	for bid in res["bunkers"]:
		var b: BunkerState = world.bunker(bid)
		if b == null:
			continue
		bunker_changed.emit(bid)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_bunker.rpc(bid, b.to_dict())
	for rid in res.get("terrain", []):
		var tr: RegionState = world.region(rid)
		if tr == null:
			continue
		terrain_changed.emit(rid)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_terrain.rpc(rid, tr.terrain)
	for ro in res.get("objects", []):
		var orr: RegionState = world.region(ro[0])
		if orr == null:
			continue
		var data: Dictionary = orr.objects.get(ro[1], {})
		object_changed.emit(ro[0], ro[1])
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_object.rpc(ro[0], ro[1], data)
	if res.get("npcs", false):
		npcs_updated.emit()
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_npcs.rpc(NpcSim.rows(world))
	if res.get("env", false) or res.get("meta", false):
		world_meta_changed.emit()
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_world_meta.rpc(world.env, world.meta)
	if res.get("blood", false):
		blood_changed.emit()
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_blood.rpc(world.blood)
	for vid in res.get("vehicles", []):
		var vs: VehicleState = world.vehicles.get(vid)
		if vs == null:
			continue
		vehicle_changed.emit(vid)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_vehicle.rpc(vid, vs.to_dict())
	for c in res["changes"]:
		var region := world.region(c["region_id"])
		if region != null:
			_publish_entity(c["region_id"], c["entity_id"], region.entity_state(c["entity_id"]),
				region.rev(c["entity_id"]), c["cause"])
	for pid in res["players"]:
		var p: PlayerState = world.players.get(pid)
		if p == null:
			continue
		player_resources_changed.emit(pid)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_player_carried.rpc(pid, p.inventory_dict())
	for pid in res.get("vitals", []):
		var pv: PlayerState = world.players.get(pid)
		if pv == null:
			continue
		vitals_changed.emit(pid)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_vitals.rpc(pid, _vitals_row(pv))
	var events: Array = res.get("events", [])
	if not events.is_empty():
		for ev in events:
			combat_event.emit(ev)
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_events.rpc(events)
	var bn: Dictionary = res.get("broadcast_notice", {})
	if not bn.is_empty():
		notice.emit(str(bn["key"]), bn.get("args", []))
		if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
			_rpc_notice.rpc(str(bn["key"]), bn.get("args", []))
	var lk: Dictionary = res.get("lock", {})
	if not lk.is_empty() and not (res.get("players", []) as Array).is_empty():
		var lpeer := _peer_of(str(res["players"][0]))
		if lpeer == 1:
			lock_feedback.emit(lk)
		elif lpeer != 0:
			_rpc_lock_feedback.rpc_id(lpeer, lk)
	var pn: Dictionary = res.get("private_notice", {})
	if not pn.is_empty():
		var peer := _peer_of(str(pn["player_id"]))
		if peer != 0:
			_send_notice(peer, str(pn["key"]), pn.get("args", []))
	if int(res.get("sleep_ticks", 0)) > 0 and is_authority() and not _sleeping:
		_sleep(int(res["sleep_ticks"]), str(res.get("sleep_group", "")))
	var t: Dictionary = res["transition"]
	if not t.is_empty():
		var pid2: String = t["player_id"]
		_move_track[pid2] = Time.get_ticks_msec()
		SessionLog.info("session", "region_changed", {"player": pid2.substr(0, 6), "region": t["region_id"]})
		_send_correction(_peer_of(pid2), t["position"], t["region_id"])
		_broadcast_roster()
	# Several players changing region together (a vehicle and its occupants).
	for t2 in res.get("transitions", []):
		var pid3: String = t2["player_id"]
		_move_track[pid3] = Time.get_ticks_msec()
		SessionLog.info("session", "region_changed", {"player": pid3.substr(0, 6), "region": t2["region_id"], "by": "vehicle"})
		_send_correction(_peer_of(pid3), t2["position"], t2["region_id"])
	if res.get("roster", false) or not (res.get("transitions", []) as Array).is_empty():
		_broadcast_roster()


## Host: sleep advances the real shared simulation to morning in 50 s chunks
## (each chunk runs every system once with exact elapsed time; nothing is
## simulated per rendered frame and nothing is produced or paid twice).
var _sleeping := false
func _sleep(ticks: int, group: String) -> void:
	_sleeping = true
	var chunk := 50 * Simulation.TICK_RATE
	var left := ticks
	while left > 0:
		var n := mini(chunk, left)
		_advance(n)
		left -= n
	_sleeping = false
	_publish_result(SleepSim.wake(world, group))
	for p in world.online_players():
		_publish_result({"ok": true, "reason": "", "reason_args": [], "changes": [], "players": [p.player_id], "bunkers": [],
			"transition": {}, "notice": {}, "vitals": [p.player_id]})
	_broadcast_snapshot()
	SessionLog.info("sleep", "woke", {"group": group, "hour": snappedf(EnvSim.hour(world), 0.01), "tick": world.tick})


## Local player answers the sleep vote.
func request_sleep_vote(yes: bool) -> void:
	if not in_world():
		return
	if is_authority():
		_host_handle_sleep_vote(1, yes)
	else:
		_rpc_request_sleep_vote.rpc_id(1, yes)


func _host_handle_sleep_vote(peer_id: int, yes: bool) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var res := SleepSim.answer(world, pid, yes)
	if res["ok"]:
		_publish_result(res)
	_send_action_result(peer_id, 0, res["ok"], res["reason"], res["reason_args"])


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sleep_vote(yes: bool) -> void:
	if mode == Mode.HOST:
		_host_handle_sleep_vote(multiplayer.get_remote_sender_id(), yes)


func _peer_of(player_id: String) -> int:
	for peer in _peer_to_player:
		if _peer_to_player[peer] == player_id:
			return peer
	return 0


## Progression cheats (iteration 013): host only, even when the host lets clients
## use other developer commands — a client can never grant XP or change the multiplier.
const HOST_ONLY_DEV: Array[String] = ["xp_multiplier", "grant_xp", "set_skill_level", "reset_skill"]


func _host_dev_command(peer_id: int, cmd: String, arg: Variant) -> void:
	if not BuildInfo.dev_tools_enabled():
		SessionLog.warn("dev", "command_disabled_in_release", {"peer": peer_id, "cmd": cmd})
		_send_action_result(peer_id, 0, false, "DEV_DISABLED")
		return
	if peer_id != 1 and cmd in HOST_ONLY_DEV:
		SessionLog.warn("dev", "progression_command_refused", {"peer": peer_id, "cmd": cmd})
		_send_action_result(peer_id, 0, false, "DEV_HOST_ONLY")
		return
	if peer_id != 1 and not bool(Settings.get_value("dev", "allow_client_dev_commands", false)):
		SessionLog.warn("dev", "client_command_refused", {"peer": peer_id, "cmd": cmd})
		_send_action_result(peer_id, 0, false, "DEV_HOST_ONLY")
		return
	var pid: String = _peer_to_player.get(peer_id, "")
	SessionLog.info("dev", "command", {"peer": peer_id, "cmd": cmd, "arg": str(arg)})
	match cmd:
		"advance_clock":
			_advance(int(float(arg) * Simulation.TICK_RATE))
		"spawn_zombie", "spawn_group":
			if pid != "":
				var p3: PlayerState = world.players[pid]
				var n := 1 if cmd == "spawn_zombie" else 4
				for i in n:
					var ang := TAU * float(i) / n + 0.6
					var z := ZombieSim.spawn(world, p3.region_id, p3.position + Vector2(cos(ang), sin(ang)) * 260.0, false)
					z.ai = ZombieState.AI.INVESTIGATE
					z.goal = p3.position
					z.last_known = p3.position
		"grant":
			# Developer: give the player items, arg "item:amount" (e.g. "fuel:4").
			var p7: PlayerState = world.players.get(pid)
			var parts := str(arg).split(":")
			if p7 != null and Items.exists(parts[0]):
				var n7 := int(parts[1]) if parts.size() > 1 else 1
				var gi := WorldActions._ok()
				gi["players"] = [pid]
				if Items.is_stack(parts[0]):
					var pile7 := Inv.give_stack(world, p7, parts[0], n7)
					if pile7 != "":
						gi["objects"] = [[p7.region_id, pile7]]
				else:
					for k7 in n7:
						var pile8 := Inv.give_gear(world, p7, Inv.new_gear(world, parts[0]))
						if pile8 != "":
							gi["objects"] = [[p7.region_id, pile8]]
				_publish_result(gi)
		"hunger":
			var p10: PlayerState = world.players.get(pid)
			if p10 != null:
				p10.hunger = float(arg) if arg != null else 20.0
				var hu := WorldActions._ok()
				hu["vitals"] = [pid]
				_publish_result(hu)
		"thirst":
			var p8: PlayerState = world.players.get(pid)
			if p8 != null:
				p8.hydration = float(arg) if arg != null else 20.0
				var th := WorldActions._ok()
				th["vitals"] = [pid]
				_publish_result(th)
		"grant_stock":
			# Developer: add wood to the shelter stockpile of the player's bunker (or the first one).
			var p6: PlayerState = world.players.get(pid)
			var bk := world.bunker_for_region(p6.region_id) if p6 != null else null
			if bk == null and not world.bunkers.is_empty():
				bk = world.bunkers.values()[0]
			if bk != null:
				bk.resources["wood"] = bk.amount("wood") + int(float(arg) if arg != null else 20.0)
				var gr := WorldActions._ok()
				gr["bunkers"] = [bk.bunker_id]
				_publish_result(gr)
		"damage_structures", "repair_structures":
			# Developer: damage (arg = amount) or fully repair every structure in the player's region.
			var p9: PlayerState = world.players.get(pid)
			var reg9 := world.region(p9.region_id) if p9 != null else null
			if reg9 != null:
				var out := WorldActions._ok()
				for oid in reg9.objects.keys():
					if Build.is_pile(reg9.objects[oid]):
						continue
					if cmd == "repair_structures":
						reg9.objects[oid]["hp"] = Build.max_hp(reg9.objects[oid])
						out["objects"].append([reg9.region_id, oid])
					else:
						var dr := Build.damage_object(world, reg9, oid, float(arg) if arg != null else 40.0)
						out["objects"].append_array(dr["objects"])
						out["events"].append_array(dr["events"])
				for eid in Content.entity_ids(reg9.def_id):
					if Build.entity_structure(reg9, eid).is_empty():
						continue
					if cmd == "repair_structures":
						reg9.set_fields(eid, {"hp": float(Build.entity_structure(reg9, eid).get("hp", 0)), "broken": false})
						out["changes"].append({"region_id": reg9.region_id, "entity_id": eid, "cause": "repaired"})
					else:
						var de := Build.damage_entity(world, reg9, eid, float(arg) if arg != null else 40.0)
						out["changes"].append_array(de["changes"])
				_publish_result(out)
		"time_scale":
			# Iteration 014: single player only (refused in a hosted game, for host and clients).
			if mode != Mode.SINGLE:
				_send_action_result(peer_id, 0, false, "DEV_SINGLE_PLAYER_ONLY")
				return
			time_scale = clampf(float(str(arg).to_float()) if arg != null else 1.0, 0.0, 10.0)
			_tick_accum = 0.0
			SessionLog.info("dev", "time_scale", {"value": time_scale})
			notice.emit("DEV_TIME_SCALE", [("%.0f" % time_scale) if time_scale > 0.0 else "0"])
		"xp_multiplier":
			world.meta["xp_multiplier"] = SkillSim.clamp_multiplier(str(arg).to_float() if arg != null else 1.0)
			SessionLog.info("dev", "xp_multiplier", {"value": world.meta["xp_multiplier"]})
			_publish_result({"ok": true, "reason": "", "reason_args": [], "changes": [], "players": [], "bunkers": [],
				"transition": {}, "notice": {}, "meta": true})
		"grant_xp", "set_skill_level", "reset_skill":
			# arg "<amount|level>" for the host's own character, "<amount|level>|all" for every player.
			var parts9 := str(arg if arg != null else "").split("|")
			var targets: Array = world.players.values() if parts9.size() > 1 and parts9[1] == "all" else [world.players.get(pid)]
			var touched: Array = []
			for tp in targets:
				if tp == null:
					continue
				match cmd:
					"grant_xp":
						SkillSim.award(world, tp, "scavenging", roundi(parts9[0].to_float()), true)  # raw: the multiplier is for earned XP
					"set_skill_level":
						SkillSim.set_level(tp, "scavenging", roundi(parts9[0].to_float()))
					"reset_skill":
						SkillSim.reset(tp, "scavenging")
				touched.append(tp.player_id)
				SessionLog.info("dev", cmd, {"player": tp.player_id.substr(0, 6), "xp": SkillSim.xp(tp, "scavenging")})
			var sk := WorldActions._ok()
			sk["players"] = touched
			_publish_result(sk)
		"report":
			var path := DevPreset.write_report(world, pid)
			_send_notice(peer_id, "DEV_REPORT_WRITTEN", [path])
		"recruit":
			# Developer: the test survivor moves into the shelter now (needs a shelter).
			var rr := NpcSim.dev_recruit(world, str(arg) if arg != null and str(arg) != "" else "mara")
			_publish_result(rr)
			if not rr["ok"]:
				_send_action_result(peer_id, 0, false, rr["reason"])
		"npc_job":
			for n12 in world.npcs.values():
				if n12.recruit == "home":
					n12.job = str(arg) if arg != null else ""
			var nj := WorldActions._ok()
			nj["npcs"] = true
			_publish_result(nj)
		"siege":
			# Developer: start the homestead defence event now (arg = warning seconds).
			var sr: Array = []
			EventSim.start_warning(world, float(arg) if arg != null else 10.0, sr)
			for r11 in sr:
				_publish_result(r11)
		"heat":
			world.meta["home_heat"] = float(arg) if arg != null else 60.0
			var hm: Dictionary = world.meta.get("heat", {})
			hm["homestead"] = float(arg) if arg != null else 60.0
			world.meta["heat"] = hm
			var hr2 := WorldActions._ok()
			hr2["meta"] = true
			_publish_result(hr2)
		"time":
			# Developer: jump the clock to an hour of the day (game time passes normally).
			var target := fmod(float(arg) if arg != null else 22.0, 24.0)
			var now := EnvSim.hour(world)
			var hours := fmod(target - now + 24.0, 24.0)
			var left := int(hours / 24.0 * float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
			while left > 0:  # chunked like sleep, so every system sees realistic steps
				var n := mini(50 * Simulation.TICK_RATE, left)
				_advance(n)
				left -= n
		"weather":
			EnvSim.set_weather(world, str(arg) if arg != null else "clear")
			var wr := WorldActions._ok()
			wr["env"] = true
			_publish_result(wr)
		"peaceful":
			world.threat.enabled = arg == null or float(arg) == 0.0
			if world.threat.enabled:
				ZombieSim.ensure_population(world)
		"ambient":
			# Developer: the old automatic threat loop (populations, reinforcements,
			# night/heat wanderers, automatic cabin attacks) on (1) or off (0).
			world.threat.ambient = arg == null or float(arg) != 0.0
			if world.threat.ambient:
				ZombieSim.ensure_population(world)
			SessionLog.info("dev", "ambient_threat", {"on": world.threat.ambient})
		"warmth":
			if pid != "":
				var pw: PlayerState = world.players[pid]
				pw.warmth = clampf(float(arg) if arg != null else 30.0, 0.0, 100.0)
				var wr2 := WorldActions._ok()
				wr2["vitals"] = [pid]
				_publish_result(wr2)
		"hunt":
			# Developer-only Burnt One hunt against the caller (or a player id prefix in arg).
			var target := pid
			if arg != null and str(arg) != "" and str(arg) != "0":
				for pid2 in world.players:
					if str(pid2).begins_with(str(arg)) or world.players[pid2].display_name == str(arg):
						target = pid2
			var hres := ZombieSim.start_hunt(world, target)
			if hres["ok"]:
				_send_notice(peer_id, "DEV_HUNT_STARTED", [hres["zombie_id"]])
			else:
				_send_action_result(peer_id, 0, false, hres["reason"])
		"noise":
			if pid != "":
				var p4: PlayerState = world.players[pid]
				ZombieSim.make_noise(world, p4.region_id, p4.position, "dev", float(arg) if arg != null else 1.0)
		"hurt", "heal":
			if pid != "":
				var p5: PlayerState = world.players[pid]
				if cmd == "hurt":
					_publish_result(ZombieSim.damage_player(world, p5, float(arg) if arg != null else 25.0, "dev"))
				else:
					p5.health = 100.0
					p5.hydration = 100.0
					var hr := WorldActions._ok()
					hr["vitals"] = [pid]
					_publish_result(hr)
		"create_level":
			var res := WorldActions.dev_create_level(world, pid)
			if res["ok"]:
				SessionLog.info("dev", "level_created", {"region": res["new_region"], "bunkers": res["bunkers"]})
				_publish_result(res)
				_send_notice(peer_id, res["notice"]["key"], res["notice"]["args"])
			else:
				_send_action_result(peer_id, 0, false, res["reason"])
		"save":
			save_world()
		"goto":
			# Developer: walk into another region at its spawn point (records the discovery).
			var pg: PlayerState = world.players.get(pid)
			var rg := world.region(str(arg))
			if pg != null and rg != null and pg.vehicle_id == "":
				pg.region_id = rg.region_id
				pg.position = Content.spawn_point(rg.def_id, 0)
				var key := str(world.region_def(rg.region_id).get("discovery", ""))
				if key != "" and WorldActions.discover(world, key):
					_publish_result({"ok": true, "reason": "", "reason_args": [], "changes": [], "players": [], "bunkers": [],
						"transition": {}, "notice": {}, "meta": true})
				_move_track[pid] = Time.get_ticks_msec()
				_send_correction(peer_id, pg.position, pg.region_id)
				_broadcast_roster()
		"heat":
			# Developer: a temporary heat source at the caller (thaws nearby Burnt Ones); "heat off" clears.
			var ph: PlayerState = world.players.get(pid)
			if str(arg) == "off":
				world.dev_heat.clear()
			elif ph != null:
				world.dev_heat.append([ph.region_id, ph.position, 300.0])
		"blood":
			# Developer: one thawed-blood mark at the caller (presentation and weather tests).
			var pb: PlayerState = world.players.get(pid)
			if pb != null:
				BloodSim.drip(world, pb.region_id, pb.position + Vector2(60, 0))
				var rb := WorldActions._ok()
				rb["blood"] = true
				_publish_result(rb)
		"vehicle_here":
			# Developer: park the first vehicle beside the player (same region);
			# optional arg = heading in degrees (0 = east, 180 = west).
			var pv: PlayerState = world.players.get(pid)
			if pv != null and not world.vehicles.is_empty() and pv.vehicle_id == "":
				var vv: VehicleState = world.vehicles.values()[0]
				if vv.occupants().is_empty():
					vv.region_id = pv.region_id
					vv.position = pv.position + Vector2(130, 0)
					vv.rotation = deg_to_rad(float(arg)) if (arg is float or arg is int) else 0.0
					var rv := WorldActions._ok()
					rv["vehicles"] = [vv.vehicle_id]
					_publish_result(rv)
		"teleport":
			if pid != "" and arg is Vector2:
				var p: PlayerState = world.players[pid]
				p.position = arg
				_move_track[pid] = Time.get_ticks_msec()
				_send_correction(peer_id, p.position, p.region_id)
		"horde":
			# Developer (iteration 015 E): a roaming horde forms now in your (outdoor) region.
			if pid != "":
				var hr := HordeSim.form(world, world.players[pid].region_id, true)
				if hr["ok"]:
					_publish_result(hr)
				else:
					_send_action_result(peer_id, 0, false, hr["reason"])
		"hordes":
			world.threat.hordes_on = float(arg) > 0.5
			world.threat.hordes_on_set = true
			_send_notice(peer_id, "DEV_HORDES_ON" if world.threat.hordes_on else "DEV_HORDES_OFF", [])
		"hideout_reset":
			for hd in HideoutSim.all(world):
				_publish_result(HideoutSim.reset(world, hd[0], hd[1]))
			_send_notice(peer_id, "DEV_HIDEOUTS_RESET", [HideoutSim.all(world).size()])
		"hideout_goto":
			# Developer: into hideout n (1-based) at its door.
			var hs := HideoutSim.all(world)
			var hn := clampi(int(float(arg)) if arg != null else 1, 1, maxi(1, hs.size())) - 1
			if pid != "" and not hs.is_empty() and world.players[pid].vehicle_id == "":
				var ph: PlayerState = world.players[pid]
				var hreg := world.region(hs[hn][0])
				ph.region_id = hreg.region_id
				var door := ""
				for x in Content.entity_ids(hreg.def_id):
					if x.ends_with(".exit"):
						door = x
				ph.position = Content.entity_position(hreg.entity_def(door)) if door != "" else Content.spawn_point(hreg.def_id, 0)
				ph.position = SideSection.rest(hreg, ph.position)
				_move_track[pid] = Time.get_ticks_msec()
				_send_correction(peer_id, ph.position, ph.region_id)
				_broadcast_roster()
		"test_rifle":
			# Developer / test start (iteration 015 E): starter bags also hold an assault rifle and ammo.
			world.meta["test_rifle"] = arg == null or float(arg) > 0.5
			_publish_result({"ok": true, "reason": "", "reason_args": [], "changes": [], "players": [], "bunkers": [],
				"transition": {}, "notice": {}, "meta": true})
			_send_notice(peer_id, "DEV_TEST_RIFLE_ON" if world.meta["test_rifle"] else "DEV_TEST_RIFLE_OFF", [])
		"zombie_at":
			# Developer (iteration 015): a dormant Burnt One at a point in your region (visibility tests).
			if pid != "" and arg is Vector2:
				var pz: PlayerState = world.players[pid]
				var zz := ZombieSim.spawn(world, pz.region_id, arg, false)
				zz.ai = ZombieState.AI.WANDER
				zz.goal = arg
		"spawn":
			if pid != "":
				var p2: PlayerState = world.players[pid]
				p2.region_id = Content.DEFAULT_REGION
				p2.position = Content.spawn_point(p2.region_id, 0)
				_move_track[pid] = Time.get_ticks_msec()
				_send_correction(peer_id, p2.position, p2.region_id)
				_broadcast_roster()
		_:
			_send_action_result(peer_id, 0, false, "DEV_UNKNOWN_COMMAND")


func _publish_entity(region_id: String, entity_id: String, state: Dictionary, rev: int, cause: String) -> void:
	entity_changed.emit(region_id, entity_id, state, cause)
	if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
		_rpc_entity_changed.rpc(region_id, entity_id, state, rev, cause)


func _send_correction(peer_id: int, pos: Vector2, region_id: String = "") -> void:
	if peer_id == 0:
		return
	if peer_id == 1:
		local_position_corrected.emit(pos)
		if region_id != "":
			local_region_changed.emit(region_id)
	else:
		_rpc_correct_position.rpc_id(peer_id, pos, region_id)


func _send_action_result(peer_id: int, request_id: int, ok: bool, reason: String, args: Array = []) -> void:
	if ok or reason == "ACTION_TOO_FAST":
		return
	if peer_id == 1:
		notice.emit(reason, args)
	elif peer_id != 0:
		_rpc_action_result.rpc_id(peer_id, request_id, ok, reason, args)


func _send_notice(peer_id: int, key: String, args: Array) -> void:
	if peer_id == 1:
		notice.emit(key, args)
	elif peer_id != 0:
		_rpc_notice.rpc_id(peer_id, key, args)


func _on_peer_disconnected(peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	_peer_to_player.erase(peer_id)
	var p: PlayerState = world.players.get(pid)
	if p != null and p.vehicle_id != "":
		_publish_result(VehicleSim.eject(world, p))  # nobody drives or rides while away
	if p != null:
		p.online = false
		p.last_seen_unix = int(Time.get_unix_time_from_system())
		SessionLog.info("session", "player_left", {"peer": peer_id, "player": pid.substr(0, 6),
			"position": [p.position.x, p.position.y]})
		notice.emit("PLAYER_LEFT", [p.display_name])
	_broadcast_roster()


func _on_net_status(status: int, detail: String) -> void:
	if mode != Mode.CLIENT:
		return
	if status == NetService.Status.CONNECTED and not _pending_join.is_empty():
		_connect_wait = -1.0
		_join_wait = 0.0
		join_progress.emit("JOIN_HANDSHAKE")
		_rpc_request_join.rpc_id(1, _pending_join["token"], _pending_join["name"],
			BuildInfo.PROTOCOL_VERSION, Content.fingerprint())
	elif status == NetService.Status.FAILED:
		# Before the welcome this is a failed connection; afterwards the host is gone.
		_end("SESSION_HOST_CLOSED" if world != null else "NET_CONNECT_FAILED")


static func _valid_token(token: String) -> bool:
	if token.length() < 8 or token.length() > 64:
		return false
	for c in token:
		if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")):
			return false
	return true


func _notification(what: int) -> void:
	# Window closed while hosting / in single player: save synchronously.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_authority() and world != null:
		save_world()


# ======================================================================
# RPC endpoints. "any_peer" = client -> host requests (validated);
# "authority" = host -> client results (only the host may send them).
# ======================================================================

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_join(token: String, name: String, protocol: int, fingerprint: String) -> void:
	if mode == Mode.HOST:
		_host_handle_join(multiplayer.get_remote_sender_id(), token, name, protocol, fingerprint)


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(data: Dictionary, player_id: String) -> void:
	if mode != Mode.CLIENT:
		return
	var res := SaveCodec.decode(data)
	if not res["ok"]:
		SessionLog.error("session", "bad_world_snapshot", {"error": res["error"]})
		_end("JOIN_BAD_SNAPSHOT")
		return
	world = res["world"]
	local_player_id = player_id
	_pending_join.clear()
	_join_wait = -1.0
	var p: PlayerState = world.players.get(player_id)
	if p != null:
		p.online = true
	SessionLog.info("session", "joined_world", {"world_id": world.world_id, "tick": world.tick,
		"player": player_id.substr(0, 6)})
	_begin()


@rpc("authority", "call_remote", "reliable")
func _rpc_join_rejected(reason_key: String) -> void:
	SessionLog.warn("session", "join_rejected_by_host", {"reason": reason_key})
	_end(reason_key)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_submit_move(pos: Vector2, facing: int, region_id: String) -> void:
	if mode == Mode.HOST:
		_host_handle_move(multiplayer.get_remote_sender_id(), pos, facing, region_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(tick: int, rows: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	world.tick = tick
	for row in rows:
		var pid := str(row[0])
		if pid == local_player_id:
			continue  # own avatar is predicted locally; host corrects if needed
		var p: PlayerState = world.players.get(pid)
		if p != null:
			p.position = row[1]
			p.facing = int(row[2])


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(rows: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	var seen := {}
	for row in rows:
		var pid := str(row["id"])
		seen[pid] = true
		var p: PlayerState = world.players.get(pid)
		if p == null:
			p = PlayerState.new()
			p.player_id = pid
			world.players[pid] = p
		p.display_name = str(row["name"])
		p.region_id = str(row["region"])
		if pid != local_player_id:
			p.position = row["position"]
		p.facing = int(row["facing"])
		p.carried = (row.get("carried", {}) as Dictionary).duplicate()
		p.vehicle_id = str(row.get("vehicle", ""))
		if row.has("vitals"):
			_apply_vitals(p, row["vitals"])
		p.online = true
	for pid in world.players:
		if not seen.has(pid):
			(world.players[pid] as PlayerState).online = false
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_correct_position(pos: Vector2, region_id: String) -> void:
	if world != null and world.players.has(local_player_id):
		var p: PlayerState = world.players[local_player_id]
		p.position = pos
		if region_id != "":
			p.region_id = region_id
	local_position_corrected.emit(pos)
	if region_id != "":
		local_region_changed.emit(region_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_interact(request_id: int, entity_id: String, expected_rev: int) -> void:
	if mode == Mode.HOST:
		_host_handle_interact(multiplayer.get_remote_sender_id(), request_id, entity_id, expected_rev)


@rpc("authority", "call_remote", "reliable")
func _rpc_action_result(_request_id: int, ok: bool, reason_key: String, args: Array) -> void:
	if not ok:
		notice.emit(reason_key, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_lock_feedback(info: Dictionary) -> void:
	lock_feedback.emit(info)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_entity_action(entity_id: String, action: String, arg: String) -> void:
	if mode == Mode.HOST:
		_host_handle_entity_action(multiplayer.get_remote_sender_id(), entity_id, action, arg)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_drink() -> void:
	if mode == Mode.HOST:
		_host_handle_drink(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_terrain(action: String, cell: Vector2i) -> void:
	if mode == Mode.HOST:
		_host_handle_terrain(multiplayer.get_remote_sender_id(), action, cell)


@rpc("authority", "call_remote", "reliable")
func _rpc_terrain(region_id: String, terrain: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null or world.region(region_id) == null:
		return
	world.region(region_id).terrain = terrain.duplicate(true)
	terrain_changed.emit(region_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_attack(aim: Vector2) -> void:
	if mode == Mode.HOST:
		_host_handle_attack(multiplayer.get_remote_sender_id(), aim)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_zombies(rows: Array, zones: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	var seen := {}
	for r in rows:
		var id := str(r[0])
		seen[id] = true
		var z: ZombieState = world.zombies.get(id)
		if z == null:
			z = ZombieState.new()
			z.zombie_id = id
			world.zombies[id] = z
		z.region_id = str(r[1])
		z.position = Vector2(float(r[2]), float(r[3]))
		z.facing = Vector2(float(r[4]), float(r[5]))
		z.ai = int(r[6])
		z.health = float(r[7])
		if r.size() > 9:
			z.posture = int(r[8])
			z.burst = 1.0 if int(r[9]) == 1 else 0.0
	for id in world.zombies.keys():
		if not seen.has(id):
			world.zombies.erase(id)
	world.threat.zones.clear()
	for zr in zones:
		world.threat.zones[str(zr[0])] = float(zr[1])
	zombies_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_events(events: Array) -> void:
	if mode != Mode.CLIENT:
		return
	for ev in events:
		combat_event.emit(ev)


@rpc("authority", "call_remote", "reliable")
func _rpc_vitals(player_id: String, row: Array) -> void:
	if mode != Mode.CLIENT or world == null or not world.players.has(player_id):
		return
	_apply_vitals(world.players[player_id], row)
	vitals_changed.emit(player_id)


static func _apply_vitals(p: PlayerState, row: Array) -> void:
	p.health = float(row[0])
	p.hydration = float(row[1])
	p.dead = bool(row[2])
	if row.size() > 4:
		p.hunger = float(row[4])
	if row.size() > 5:
		p.warmth = float(row[5])
	if row.size() > 6:
		p.flashlight = bool(row[6])


@rpc("authority", "call_remote", "reliable")
func _rpc_notice(key: String, args: Array) -> void:
	notice.emit(key, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_bunker(bunker_id: String, data: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	world.bunkers[bunker_id] = BunkerState.from_dict(bunker_id, data)
	world.ensure_bunker_regions()
	bunker_changed.emit(bunker_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_carried(player_id: String, inventory: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null or not world.players.has(player_id):
		return
	(world.players[player_id] as PlayerState).apply_inventory(inventory)
	player_resources_changed.emit(player_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_inventory(action: String, arg: String) -> void:
	if mode == Mode.HOST:
		_host_handle_inventory(multiplayer.get_remote_sender_id(), action, arg)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_npc(npc_id: String, action: String, arg: String) -> void:
	if mode == Mode.HOST:
		_host_handle_npc(multiplayer.get_remote_sender_id(), npc_id, action, arg)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_build(def_id: String, pos: Vector2) -> void:
	if mode == Mode.HOST:
		_host_handle_build(multiplayer.get_remote_sender_id(), def_id, pos)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_object(object_id: String, action: String, arg: String) -> void:
	if mode == Mode.HOST:
		_host_handle_object(multiplayer.get_remote_sender_id(), object_id, action, arg)


@rpc("authority", "call_remote", "reliable")
func _rpc_object(region_id: String, object_id: String, data: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null or world.region(region_id) == null:
		return
	var r := world.region(region_id)
	if data.is_empty():
		r.objects.erase(object_id)
	else:
		r.objects[object_id] = data.duplicate(true)
	object_changed.emit(region_id, object_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_npcs(rows: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	NpcSim.apply_rows(world, rows)
	npcs_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_world_meta(env: Dictionary, meta: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	world.env = env.duplicate(true)
	world.meta = meta.duplicate(true)
	world_meta_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_entity_changed(region_id: String, entity_id: String, state: Dictionary, rev: int, cause: String) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	var region := world.region(region_id)
	if region == null or not region.has_entity(entity_id):
		SessionLog.warn("world", "unknown_entity_from_host", {"region": region_id, "entity": entity_id})
		return
	region.apply_remote(entity_id, state, rev)
	entity_changed.emit(region_id, entity_id, region.entity_state(entity_id), cause)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_dev_command(cmd: String, arg: Variant) -> void:
	if mode == Mode.HOST:
		_host_dev_command(multiplayer.get_remote_sender_id(), cmd, arg)


@rpc("authority", "call_remote", "reliable")
func _rpc_session_closing(reason_key: String) -> void:
	if mode == Mode.CLIENT:
		_end(reason_key)


# ---------------------------------------------------------------- vehicles (iteration 011)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_vehicle(vehicle_id: String, action: String, arg: String) -> void:
	if mode == Mode.HOST:
		_host_handle_vehicle(multiplayer.get_remote_sender_id(), vehicle_id, action, arg)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_submit_vehicle_pose(vehicle_id: String, pos: Vector2, rot: float, speed: float, steer: float) -> void:
	if mode == Mode.HOST:
		_host_handle_vehicle_pose(multiplayer.get_remote_sender_id(), vehicle_id, pos, rot, speed, steer)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_vehicles(rows: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	VehicleSim.apply_rows(world, rows, local_player_id)


## Full vehicle state (seats, engine, trunk, region). Seated players follow it.
@rpc("authority", "call_remote", "reliable")
func _rpc_vehicle(vehicle_id: String, data: Dictionary) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	var v := VehicleState.from_dict(vehicle_id, data)
	var old: VehicleState = world.vehicles.get(vehicle_id)
	if old != null and old.driver() == local_player_id and v.driver() == local_player_id and old.region_id == v.region_id:
		# keep the local prediction for the pose while still driving here
		v.position = old.position
		v.rotation = old.rotation
		v.speed = old.speed
	world.vehicles[vehicle_id] = v
	for p in world.players.values():
		if v.seat_of(p.player_id) >= 0:
			p.vehicle_id = vehicle_id
		elif p.vehicle_id == vehicle_id:
			p.vehicle_id = ""
	vehicle_changed.emit(vehicle_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_blood(marks: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	world.blood = marks.duplicate(true)
	blood_changed.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_animals(rows: Array) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	WildlifeSim.apply_rows(world, rows)


@rpc("authority", "call_remote", "reliable")
func _rpc_vehicle_correct(vehicle_id: String, pos: Vector2, rot: float) -> void:
	if mode != Mode.CLIENT or world == null:
		return
	var v: VehicleState = world.vehicles.get(vehicle_id)
	if v != null:
		v.position = pos
		v.rotation = rot
		v.speed = 0.0
	vehicle_corrected.emit(vehicle_id)
