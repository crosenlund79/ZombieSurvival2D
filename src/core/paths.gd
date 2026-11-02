class_name Paths
extends RefCounted
## Command-line arguments and per-instance user folders.
##
## Running two copies of the game on one computer (for multiplayer testing)
## would make them share settings, logs and saves. Pass `--instance=<name>`
## after `--` to give a copy its own folder: user://instances/<name>/.
## External art/audio overrides are shared by every instance: user://overrides/.

static var _args: Dictionary = {}
static var _parsed := false


static func args() -> Dictionary:
	if not _parsed:
		_parsed = true
		for raw in OS.get_cmdline_user_args():
			var a: String = raw
			if not a.begins_with("--"):
				continue
			a = a.substr(2)
			var eq := a.find("=")
			if eq == -1:
				_args[a] = "true"
			else:
				_args[a.substr(0, eq)] = a.substr(eq + 1)
	return _args


static func arg(key: String, default_value: String = "") -> String:
	return str(args().get(key, default_value))


static func has_arg(key: String) -> bool:
	return args().has(key)


static func instance_name() -> String:
	var raw := arg("instance", "")
	var clean := ""
	for c in raw.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			clean += c
	return clean.substr(0, 32)


static func user_root() -> String:
	var inst := instance_name()
	if inst == "":
		return "user://"
	return "user://instances/%s/" % inst


static func saves_dir() -> String:
	return ensure_dir(user_root() + "saves/")


static func logs_dir() -> String:
	return ensure_dir(user_root() + "logs/")


static func settings_file() -> String:
	ensure_dir(user_root())
	return user_root() + "settings.cfg"


static func screenshots_dir() -> String:
	return ensure_dir(user_root() + "screenshots/")


## Shared by all instances on purpose: one place for the creator's replacements.
static func overrides_dir() -> String:
	return ensure_dir("user://overrides/")


static func ensure_dir(path: String) -> String:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path
