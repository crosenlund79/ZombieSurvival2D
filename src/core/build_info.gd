class_name BuildInfo
extends RefCounted
## Build identity shown in the bottom-right developer label and written into
## logs and saves. Update ITERATION/STAGE when a new iteration begins.

const GAME_TITLE := "Aftergrowth"
const VERSION := "0.1.0"
const ITERATION := "003"
const STAGE := "survival-slice"
const STATUS := "DEV"
## Bumped whenever the network protocol changes incompatibly.
const PROTOCOL_VERSION := 3

static var _commit := ""


## Short commit id, read from .git when running from a git checkout.
## A GitHub ZIP download or an exported build has no .git folder: returns "n/a".
## Git itself is never executed.
static func commit() -> String:
	if _commit == "":
		_commit = _read_git_commit()
	return _commit


static func label() -> String:
	return "%s %s · iter %s · %s · %s · commit %s · save v%d" % [
		GAME_TITLE, VERSION, ITERATION, STAGE, STATUS, commit(), SaveCodec.SCHEMA_VERSION]


static func as_dict() -> Dictionary:
	return {
		"title": GAME_TITLE, "version": VERSION, "iteration": ITERATION,
		"stage": STAGE, "status": STATUS, "commit": commit(),
		"protocol": PROTOCOL_VERSION, "save_schema": SaveCodec.SCHEMA_VERSION,
		"engine": Engine.get_version_info().get("string", "?"),
	}


static func _read_git_commit() -> String:
	if OS.has_feature("template"):
		return "n/a"
	var git_dir := ProjectSettings.globalize_path("res://").path_join(".git")
	var head_path := git_dir.path_join("HEAD")
	if not FileAccess.file_exists(head_path):
		return "n/a"
	var head := FileAccess.get_file_as_string(head_path).strip_edges()
	if not head.begins_with("ref: "):
		return head.substr(0, 8)
	var ref := head.substr(5)
	var ref_path := git_dir.path_join(ref)
	if FileAccess.file_exists(ref_path):
		return FileAccess.get_file_as_string(ref_path).strip_edges().substr(0, 8)
	var packed := git_dir.path_join("packed-refs")
	if FileAccess.file_exists(packed):
		for line in FileAccess.get_file_as_string(packed).split("\n"):
			if line.ends_with(" " + ref):
				return line.substr(0, 8)
	return "n/a"
