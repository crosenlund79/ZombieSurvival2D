class_name SettingsService
extends Node
## Client-local preferences (autoload `Settings`). Never part of the shared world.
## Stored in user://[instances/<name>/]settings.cfg.
## Also owns: input map defaults/remapping, language, and the local player
## identity tokens (one per player name on this computer).

signal changed(section: String, key: String)

const BUSES: Array[String] = ["Master", "Music", "Ambience", "SFX", "UI"]
const LANGUAGES: Array[String] = ["en", "da"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440)]
const UI_SCALE_MIN := 0.75
const UI_SCALE_MAX := 2.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5

## Default bindings. Keys are physical keycodes (layout independent).
const DEFAULT_BINDINGS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"world_map": [KEY_M],
	"attack": [KEY_F],
	"sprint": [KEY_SHIFT],
	"drink": [KEY_Q],
	"build_menu": [KEY_B],
	"inventory": [KEY_I, KEY_TAB],
	"eat": [KEY_X],
	"guide": [KEY_H],
	"settlement": [KEY_N],
	"skills": [KEY_K],
	"repair": [KEY_R],
	"vehicle_engine": [KEY_G],
	"flashlight": [KEY_L],
	"bunker_view": [KEY_F7],
	"pause_menu": [KEY_ESCAPE],
	"quick_save": [KEY_F5],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"dev_overlay": [KEY_F3],
	"screenshot": [KEY_F12],
}
## Actions shown in the controls list (dev/debug keys are listed but grouped last).
const REMAPPABLE: Array[String] = ["move_up", "move_down", "move_left", "move_right",
	"interact", "attack", "sprint", "drink", "eat", "build_menu", "repair", "vehicle_engine", "flashlight", "inventory", "guide", "settlement", "skills", "world_map", "pause_menu", "quick_save", "zoom_in", "zoom_out", "dev_overlay", "bunker_view", "screenshot"]

var _cfg := ConfigFile.new()
var _path := ""


func _ready() -> void:
	_path = Paths.settings_file()
	var err := _cfg.load(_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		SessionLog.warn("settings", "load_failed_using_defaults", {"error": error_string(err)})
	Localization.load_strings()
	_apply_input_map()
	apply_language()
	apply_display.call_deferred()


# ---------- generic access ----------

func get_value(section: String, key: String, default_value: Variant) -> Variant:
	return _cfg.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	save()
	changed.emit(section, key)


func save() -> void:
	var err := _cfg.save(_path)
	if err != OK:
		SessionLog.error("settings", "save_failed", {"error": error_string(err)})


# ---------- audio ----------

func bus_volume(bus: String) -> float:
	return clampf(float(get_value("audio", bus, 0.8)), 0.0, 1.0)


func set_bus_volume(bus: String, linear: float) -> void:
	set_value("audio", bus, clampf(linear, 0.0, 1.0))


# ---------- display ----------

func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func fullscreen() -> bool:
	return bool(get_value("display", "fullscreen", false))


func window_size() -> Vector2i:
	var v = get_value("display", "window_size", Vector2i(1600, 900))
	return v if v is Vector2i else Vector2i(1600, 900)


func ui_scale() -> float:
	return clampf(float(get_value("display", "ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)


## Iteration 012 (experiment): how bunker levels are shown, "side" (default) or "top".
func bunker_view() -> String:
	var v := str(get_value("dev", "bunker_view", "side"))
	return v if v in ["side", "top"] else "side"


func camera_zoom() -> float:
	return clampf(float(get_value("display", "camera_zoom", 1.0)), ZOOM_MIN, ZOOM_MAX)


func apply_display() -> void:
	if is_headless() or Paths.has_arg("autotest"):
		return
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen := DisplayServer.screen_get_usable_rect()
		var size := window_size()
		size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


# ---------- language ----------

func language() -> String:
	var lang := str(get_value("general", "language", "en"))
	return lang if lang in LANGUAGES else "en"


func apply_language() -> void:
	TranslationServer.set_locale(language())


# ---------- identity (client-local) ----------

func player_name() -> String:
	return sanitize_name(str(get_value("general", "player_name", "Survivor")))


static func sanitize_name(raw: String) -> String:
	var n := raw.strip_edges().substr(0, 20)
	return n if n != "" else "Survivor"


## Stable identity token for a player name on this computer/instance.
## The host uses it to recognise a returning player.
func player_token(name: String) -> String:
	var tokens: Dictionary = get_value("identity", "tokens", {})
	var key := sanitize_name(name).to_lower()
	if not tokens.has(key):
		var bytes := Crypto.new().generate_random_bytes(12)
		tokens[key] = bytes.hex_encode()
		set_value("identity", "tokens", tokens)
	return str(tokens[key])


# ---------- input ----------

func _apply_input_map() -> void:
	var saved: Dictionary = get_value("input", "bindings", {})
	for action in DEFAULT_BINDINGS:
		var keys: Array = saved.get(action, DEFAULT_BINDINGS[action])
		_set_action_keys(action, keys)
	# Mouse wheel zoom is always available in addition to keys.
	_add_mouse(&"zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse(&"zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse(&"attack", MOUSE_BUTTON_LEFT)


func _set_action_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for code in keys:
		var e := InputEventKey.new()
		e.physical_keycode = int(code)
		InputMap.action_add_event(action, e)


func _add_mouse(action: StringName, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func action_keys(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.physical_keycode)
	return out


func key_label(physical_code: int) -> String:
	var code := physical_code
	if not is_headless():
		code = DisplayServer.keyboard_get_keycode_from_physical(physical_code)
	return OS.get_keycode_string(code)


## Replace the primary key of an action (secondary defaults are dropped).
func rebind(action: String, physical_code: int) -> void:
	var saved: Dictionary = get_value("input", "bindings", {})
	saved[action] = [physical_code]
	_set_action_keys(action, [physical_code])
	set_value("input", "bindings", saved)
	SessionLog.info("settings", "rebind", {"action": action, "key": key_label(physical_code)})


func reset_bindings() -> void:
	set_value("input", "bindings", {})
	_apply_input_map()
