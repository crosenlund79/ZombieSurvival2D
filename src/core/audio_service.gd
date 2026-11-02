class_name AudioService
extends Node
## Central audio playback (autoload `Audio`). Owns buses, pooled one-shot
## players and named loops. Sounds are referenced by stable IDs from
## res://assets/manifest/audio.json and resolved through `Assets`, so the
## creator can replace any sound without touching code.
##
## Gameplay sounds are triggered by authoritative events (e.g. a door state
## change arriving from the host), never by a local key press, so a predicted
## action followed by its network confirmation cannot play twice.

const POOL_SIZE := 12

var _flat: Array[AudioStreamPlayer] = []
var _positional: Array[AudioStreamPlayer2D] = []
var _loops := {}  # loop name -> {"player": AudioStreamPlayer, "id": String, "tween": Tween}
var _missing_reported := {}


func _ready() -> void:
	ensure_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_flat.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 1400.0
		p2.attenuation = 1.6
		add_child(p2)
		_positional.append(p2)
	apply_volumes()
	Settings.changed.connect(func(section: String, _key: String) -> void:
		if section == "audio":
			apply_volumes())
	Assets.reloaded.connect(_on_assets_reloaded)


static func ensure_buses() -> void:
	for bus in SettingsService.BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	for bus in SettingsService.BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx != -1:
			var v := Settings.bus_volume(bus)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)


func _entry(id: String) -> Dictionary:
	return Assets.info(id)


func _stream(id: String) -> AudioStream:
	var s := Assets.audio_stream(id)
	if s == null and not _missing_reported.has(id):
		_missing_reported[id] = true
		SessionLog.warn("audio", "sound_unavailable_silent", {"id": id})
	return s


## One-shot. Pass a world position for positional (2D) playback.
func play(id: String, world_position: Variant = null) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var e := _entry(id)
	var bus := str(e.get("bus", "SFX"))
	var vol := float(e.get("volume_db", 0.0))
	if world_position is Vector2:
		var p2 := _free_player(_positional) as AudioStreamPlayer2D
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = vol
		p2.global_position = world_position
		p2.play()
	else:
		var p := _free_player(_flat) as AudioStreamPlayer
		p.stream = stream
		p.bus = bus
		p.volume_db = vol
		p.play()


func _free_player(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]  # all busy: steal the oldest slot


## Named continuous loop (ambience, music, machinery). Calling again with the
## same id does nothing, so an unchanged ambience never restarts.
func play_loop(loop_name: String, id: String, fade_in: float = 1.5) -> void:
	if _loops.has(loop_name) and _loops[loop_name]["id"] == id:
		return
	if _loops.has(loop_name):
		stop_loop(loop_name, fade_in)
	var stream := _stream(id)
	if stream == null:
		return
	var e := _entry(id)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = str(e.get("bus", "Ambience"))
	var target := float(e.get("volume_db", 0.0))
	p.volume_db = -60.0
	add_child(p)
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target, maxf(fade_in, 0.01))
	_loops[loop_name] = {"player": p, "id": id, "tween": tw}
	SessionLog.info("audio", "loop_started", {"loop": loop_name, "id": id})


func stop_loop(loop_name: String, fade_out: float = 1.0) -> void:
	if not _loops.has(loop_name):
		return
	var info: Dictionary = _loops[loop_name]
	_loops.erase(loop_name)
	var p: AudioStreamPlayer = info["player"]
	if info["tween"] is Tween and (info["tween"] as Tween).is_valid():
		(info["tween"] as Tween).kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, maxf(fade_out, 0.01))
	tw.tween_callback(p.queue_free)


func stop_all_loops(fade_out: float = 0.5) -> void:
	for name in _loops.keys():
		stop_loop(name, fade_out)


func active_loops() -> Dictionary:
	var out := {}
	for name in _loops:
		out[name] = _loops[name]["id"]
	return out


func _on_assets_reloaded() -> void:
	_missing_reported.clear()
	# Restart loops so replaced sounds are heard immediately.
	var current := active_loops()
	for name in current:
		var info: Dictionary = _loops[name]
		_loops.erase(name)
		(info["player"] as AudioStreamPlayer).queue_free()
		play_loop(name, current[name], 0.3)
