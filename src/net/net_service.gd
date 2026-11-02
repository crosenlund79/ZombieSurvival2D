class_name NetService
extends Node
## Connection lifecycle only (autoload `Net`): creates/closes the ENet peer and
## reports status. It knows nothing about the world — GameSession owns the
## game protocol and authority rules.

signal status_changed(status: int, detail: String)

enum Status { OFFLINE, SINGLE, HOSTING, CONNECTING, CONNECTED, FAILED }

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 7

var status: int = Status.OFFLINE
var detail := ""
var address := ""
var port := 0


func _ready() -> void:
	multiplayer.connected_to_server.connect(func() -> void:
		_set_status(Status.CONNECTED, "%s:%d" % [address, port]))
	multiplayer.connection_failed.connect(func() -> void:
		SessionLog.warn("net", "connection_failed", {"address": address, "port": port})
		_set_status(Status.FAILED, "NET_CONNECT_FAILED"))
	multiplayer.server_disconnected.connect(func() -> void:
		SessionLog.warn("net", "server_disconnected", {})
		_set_status(Status.FAILED, "SESSION_HOST_CLOSED"))
	multiplayer.peer_connected.connect(func(id: int) -> void:
		SessionLog.info("net", "peer_connected", {"peer": id}))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		SessionLog.info("net", "peer_disconnected", {"peer": id}))


func start_single() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_status(Status.SINGLE, "")


func host(p: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p, MAX_CLIENTS)
	if err != OK:
		SessionLog.error("net", "host_failed", {"port": p, "error": error_string(err)})
		_set_status(Status.FAILED, "NET_HOST_FAILED")
		return err
	multiplayer.multiplayer_peer = peer
	port = p
	SessionLog.info("net", "host_created", {"port": p})
	_set_status(Status.HOSTING, "port %d" % p)
	return OK


func join(addr: String, p: int) -> Error:
	address = addr
	port = p
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, p)
	if err != OK:
		SessionLog.error("net", "join_failed", {"address": addr, "port": p, "error": error_string(err)})
		_set_status(Status.FAILED, "NET_CONNECT_FAILED")
		return err
	multiplayer.multiplayer_peer = peer
	SessionLog.info("net", "connecting", {"address": addr, "port": p})
	_set_status(Status.CONNECTING, "%s:%d" % [addr, p])
	return OK


func close() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_status(Status.OFFLINE, "")


func kick(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		(peer as ENetMultiplayerPeer).disconnect_peer(peer_id)


func status_name() -> String:
	return Status.keys()[status]


func _set_status(s: int, d: String) -> void:
	status = s
	detail = d
	status_changed.emit(s, d)
