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

enum Mode { NONE, SINGLE, HOST, CLIENT }

const SNAPSHOT_INTERVAL := 0.1
const JOIN_TIMEOUT := 10.0
const CONNECT_TIMEOUT := 10.0
const AUTOSAVE_SECONDS := 300.0

var mode: int = Mode.NONE
var world: WorldState = null
var local_player_id := ""
var last_save := {}            # {ok, error, unix}

var _peer_to_player := {}      # host: peer id -> player id
var _move_track := {}          # host: player id -> last accepted msec
var _tick_accum := 0.0
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
	_tick_accum = 0.0
	_snapshot_accum = 0.0
	_autosave_accum = 0.0
	SessionLog.info("session", "started", {"mode": mode_name(), "world_id": world.world_id,
		"seed": world.world_seed, "tick": world.tick, "player": local_player_id})
	world_started.emit()


func _admit_host_player(player_name: String) -> void:
	var name := SettingsService.sanitize_name(player_name)
	var p := _admit_player(1, Settings.player_token(name), name)
	local_player_id = p.player_id


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
	_tick_accum += delta
	var step := 1.0 / Simulation.TICK_RATE
	var ticks := 0
	while _tick_accum >= step:
		_tick_accum -= step
		ticks += 1
	Simulation.advance(world, ticks)
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		save_world()
	if mode == Mode.HOST:
		_snapshot_accum += delta
		if _snapshot_accum >= SNAPSHOT_INTERVAL:
			_snapshot_accum = 0.0
			_broadcast_snapshot()


func _broadcast_snapshot() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var rows := []
	for p in world.online_players():
		rows.append([p.player_id, p.position, p.facing])
	_rpc_snapshot.rpc(world.tick, rows)


func _roster_rows() -> Array:
	var rows := []
	for p in world.online_players():
		rows.append({"id": p.player_id, "name": p.display_name, "region": p.region_id,
			"position": p.position, "facing": p.facing})
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
	if is_authority():
		_host_handle_move(1, pos, facing)
	else:
		_rpc_submit_move.rpc_id(1, pos, facing)


func request_interact(entity_id: String) -> void:
	if not in_world():
		return
	var p: PlayerState = world.players.get(local_player_id)
	var region := world.region(p.region_id)
	var rev := region.rev(entity_id) if region != null else 0
	var req := _next_request
	_next_request += 1
	if is_authority():
		_host_handle_interact(1, req, entity_id, rev)
	else:
		_rpc_request_interact.rpc_id(1, req, entity_id, rev)


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


func _host_handle_move(peer_id: int, pos: Vector2, facing: int) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	var p: PlayerState = world.players[pid]
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - int(_move_track.get(pid, now))) / 1000.0)
	_move_track[pid] = now
	if not WorldActions.is_plausible_move(p.position, pos, dt):
		SessionLog.warn("session", "move_rejected", {"player": pid.substr(0, 6),
			"from": [p.position.x, p.position.y], "to": [pos.x, pos.y], "dt": snappedf(dt, 0.001)})
		_send_correction(peer_id, p.position)
		return
	p.position = pos
	p.facing = clampi(facing, 0, 3)


func _host_handle_interact(peer_id: int, request_id: int, entity_id: String, expected_rev: int) -> void:
	var pid: String = _peer_to_player.get(peer_id, "")
	var result := WorldActions.request_interact(world, pid, entity_id, expected_rev)
	if result["ok"]:
		SessionLog.info("world", "entity_changed", {"entity": entity_id, "by": pid.substr(0, 6),
			"state": result["state"], "rev": result["rev"]})
		_publish_entity(result["region_id"], entity_id, result["state"], result["rev"], "action")
	else:
		SessionLog.warn("world", "interaction_rejected", {"entity": entity_id, "by": pid.substr(0, 6),
			"reason": result["reason"], "expected_rev": expected_rev})
	_send_action_result(peer_id, request_id, result["ok"], result["reason"])


func _host_dev_command(peer_id: int, cmd: String, arg: Variant) -> void:
	if peer_id != 1 and not bool(Settings.get_value("dev", "allow_client_dev_commands", false)):
		SessionLog.warn("dev", "client_command_refused", {"peer": peer_id, "cmd": cmd})
		_send_action_result(peer_id, 0, false, "DEV_HOST_ONLY")
		return
	var pid: String = _peer_to_player.get(peer_id, "")
	SessionLog.info("dev", "command", {"peer": peer_id, "cmd": cmd, "arg": str(arg)})
	match cmd:
		"advance_clock":
			Simulation.advance(world, int(float(arg) * Simulation.TICK_RATE))
		"save":
			save_world()
		"teleport":
			if pid != "" and arg is Vector2:
				var p: PlayerState = world.players[pid]
				p.position = arg
				_move_track[pid] = Time.get_ticks_msec()
				_send_correction(peer_id, p.position)
		"spawn":
			if pid != "":
				var p2: PlayerState = world.players[pid]
				p2.position = Content.spawn_point(p2.region_id, 0)
				_send_correction(peer_id, p2.position)
		_:
			_send_action_result(peer_id, 0, false, "DEV_UNKNOWN_COMMAND")


func _publish_entity(region_id: String, entity_id: String, state: Dictionary, rev: int, cause: String) -> void:
	entity_changed.emit(region_id, entity_id, state, cause)
	if mode == Mode.HOST and not multiplayer.get_peers().is_empty():
		_rpc_entity_changed.rpc(region_id, entity_id, state, rev, cause)


func _send_correction(peer_id: int, pos: Vector2) -> void:
	if peer_id == 1:
		local_position_corrected.emit(pos)
	else:
		_rpc_correct_position.rpc_id(peer_id, pos)


func _send_action_result(peer_id: int, request_id: int, ok: bool, reason: String) -> void:
	if peer_id == 1:
		if not ok:
			notice.emit(reason, [])
	else:
		_rpc_action_result.rpc_id(peer_id, request_id, ok, reason)


func _on_peer_disconnected(peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	var pid: String = _peer_to_player.get(peer_id, "")
	if pid == "":
		return
	_peer_to_player.erase(peer_id)
	var p: PlayerState = world.players.get(pid)
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
func _rpc_submit_move(pos: Vector2, facing: int) -> void:
	if mode == Mode.HOST:
		_host_handle_move(multiplayer.get_remote_sender_id(), pos, facing)


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
		p.online = true
	for pid in world.players:
		if not seen.has(pid):
			(world.players[pid] as PlayerState).online = false
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_correct_position(pos: Vector2) -> void:
	if world != null and world.players.has(local_player_id):
		(world.players[local_player_id] as PlayerState).position = pos
	local_position_corrected.emit(pos)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_interact(request_id: int, entity_id: String, expected_rev: int) -> void:
	if mode == Mode.HOST:
		_host_handle_interact(multiplayer.get_remote_sender_id(), request_id, entity_id, expected_rev)


@rpc("authority", "call_remote", "reliable")
func _rpc_action_result(_request_id: int, ok: bool, reason_key: String) -> void:
	if not ok:
		notice.emit(reason_key, [])


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
