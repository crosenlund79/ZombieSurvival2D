class_name SaveService
extends Node
## World saves (autoload `Saves`). One folder per world:
##   user://[instances/<name>/]saves/<world_id>/world.json  (+ world.json.bak)
## Only the authority calls save_world(); clients never write world saves.

const FILE_NAME := "world.json"


func world_dir(world_id: String) -> String:
	return Paths.saves_dir() + world_id + "/"


func world_file(world_id: String) -> String:
	return world_dir(world_id) + FILE_NAME


## Returns {ok, error, path}.
func save_world(world: WorldState) -> Dictionary:
	if world == null:
		return {"ok": false, "error": "no world"}
	if not _safe_id(world.world_id):
		return {"ok": false, "error": "invalid world id"}
	Paths.ensure_dir(world_dir(world.world_id))
	var path := world_file(world.world_id)
	var data := SaveCodec.encode(world)
	# The developer XP multiplier is a runtime tool, never written to a save (back to 1x on load).
	((data.get("world", {}) as Dictionary).get("meta", {}) as Dictionary).erase("xp_multiplier")
	ScavengeSim.strip_searches(data)
	var err := SafeFile.write_json(path, data, SaveCodec.validate)
	if err != "":
		SessionLog.error("save", "save_failed", {"world_id": world.world_id, "error": err})
		return {"ok": false, "error": err, "path": path}
	SessionLog.info("save", "save_completed", {"world_id": world.world_id, "tick": world.tick,
		"players": world.players.size(), "path": ProjectSettings.globalize_path(path)})
	return {"ok": true, "error": "", "path": path}


## Returns {ok, world, error, warnings, used_backup}. Falls back to the .bak
## file when the main save is unreadable or invalid.
func load_world(world_id: String) -> Dictionary:
	if not _safe_id(world_id):
		return {"ok": false, "error": "invalid world id", "warnings": [], "used_backup": false}
	var path := world_file(world_id)
	var first := _try_load(path)
	if first["ok"]:
		first["used_backup"] = false
		_log_loaded(world_id, first, false)
		return first
	SessionLog.warn("save", "main_save_unusable", {"world_id": world_id, "error": first["error"]})
	var second := _try_load(path + ".bak")
	if second["ok"]:
		second["used_backup"] = true
		second["warnings"].append("main save was unusable (%s); loaded the backup" % first["error"])
		_log_loaded(world_id, second, true)
		return second
	SessionLog.error("save", "load_failed", {"world_id": world_id, "error": first["error"], "backup_error": second["error"]})
	return {"ok": false, "error": first["error"], "warnings": [], "used_backup": false}


func _try_load(path: String) -> Dictionary:
	var raw = SafeFile.read_json(path)
	if raw is String:
		return {"ok": false, "error": raw, "warnings": []}
	return SaveCodec.decode(raw)


func _log_loaded(world_id: String, result: Dictionary, used_backup: bool) -> void:
	SessionLog.info("save", "world_loaded", {"world_id": world_id, "tick": (result["world"] as WorldState).tick,
		"used_backup": used_backup, "warnings": result["warnings"]})
	for w in result["warnings"]:
		SessionLog.warn("save", "load_warning", {"detail": w})


## [{world_id, saved_unix, seed, tick}] newest first.
func list_worlds() -> Array:
	var out := []
	var dir := Paths.saves_dir()
	for id in DirAccess.get_directories_at(dir):
		var raw = SafeFile.read_json(dir + id + "/" + FILE_NAME)
		if raw is String:
			raw = SafeFile.read_json(dir + id + "/" + FILE_NAME + ".bak")
		if raw is String:
			continue
		out.append({"world_id": id, "saved_unix": int(raw.get("saved_unix", 0)),
			"seed": int(raw.get("world", {}).get("seed", 0)), "tick": int(raw.get("world", {}).get("tick", 0))})
	out.sort_custom(func(a, b): return a["saved_unix"] > b["saved_unix"])
	return out


func most_recent_world_id() -> String:
	var l := list_worlds()
	return "" if l.is_empty() else str(l[0]["world_id"])


static func _safe_id(id: String) -> bool:
	if id == "" or id.length() > 64:
		return false
	for c in id:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-"):
			return false
	return true
