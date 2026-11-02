class_name SessionLogService
extends Node
## Black box: structured, bounded diagnostic records (autoload `SessionLog`).
## Observes only — never changes game state.
##
## Each entry: {t, ms, lvl, cat, ev, data}. Kept in memory (last MAX_MEMORY)
## and appended as JSON lines to user://[instances/<name>/]logs/session_*.jsonl.
## Older log files beyond KEEP_FILES are deleted; one file stops growing at
## MAX_FILE_BYTES. Repeated identical events are throttled.

signal entry_added(entry: Dictionary)

const MAX_MEMORY := 400
const MAX_FILE_BYTES := 1_000_000
const KEEP_FILES := 5
const THROTTLE_PER_SECOND := 5

var entries: Array[Dictionary] = []
var log_path := ""
var _file: FileAccess
var _bytes := 0
var _limit_noted := false
var _throttle := {}  # "cat/ev" -> [second, count]


func _ready() -> void:
	_open_file()
	info("app", "started", BuildInfo.as_dict().merged({"instance": Paths.instance_name(), "args": Paths.args()}))


func info(cat: String, ev: String, data: Dictionary = {}) -> void:
	_add("INFO", cat, ev, data)


func warn(cat: String, ev: String, data: Dictionary = {}) -> void:
	_add("WARN", cat, ev, data)


func error(cat: String, ev: String, data: Dictionary = {}) -> void:
	_add("ERROR", cat, ev, data)


func recent(count: int = 20) -> Array[Dictionary]:
	return entries.slice(maxi(0, entries.size() - count))


func _add(level: String, cat: String, ev: String, data: Dictionary) -> void:
	var key := cat + "/" + ev
	var sec := Time.get_ticks_msec() / 1000
	var slot: Array = _throttle.get(key, [sec, 0])
	if slot[0] != sec:
		slot = [sec, 0]
	slot[1] += 1
	_throttle[key] = slot
	if slot[1] > THROTTLE_PER_SECOND:
		return
	var entry := {
		"t": Time.get_datetime_string_from_system(false, true),
		"ms": Time.get_ticks_msec(),
		"lvl": level, "cat": cat, "ev": ev, "data": data,
	}
	entries.append(entry)
	if entries.size() > MAX_MEMORY:
		entries.pop_front()
	var line := JSON.stringify(entry)
	print("[%s] %s %s %s" % [level, cat, ev, JSON.stringify(data) if not data.is_empty() else ""])
	if level == "ERROR":
		push_error("%s/%s %s" % [cat, ev, JSON.stringify(data)])
	elif level == "WARN":
		push_warning("%s/%s %s" % [cat, ev, JSON.stringify(data)])
	_write(line)
	entry_added.emit(entry)


func _open_file() -> void:
	var dir := Paths.logs_dir()
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	log_path = dir + "session_%s_%d.jsonl" % [stamp, OS.get_process_id()]
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	_prune(dir)


func _prune(dir: String) -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("session_") and f.ends_with(".jsonl"):
			files.append(f)
	files.sort()
	while files.size() > KEEP_FILES:
		DirAccess.remove_absolute(dir + files.pop_front())


func _write(line: String) -> void:
	if _file == null:
		return
	if _bytes + line.length() > MAX_FILE_BYTES:
		if not _limit_noted:
			_limit_noted = true
			_file.store_line(JSON.stringify({"lvl": "WARN", "cat": "log", "ev": "file_limit_reached"}))
			_file.flush()
		return
	_file.store_line(line)
	_file.flush()
	_bytes += line.length() + 1
