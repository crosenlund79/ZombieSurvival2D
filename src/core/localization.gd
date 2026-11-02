class_name Localization
extends RefCounted
## Loads UI strings from res://locale/strings.json into TranslationServer.
## Format: {"KEY": {"en": "...", "da": "..."}}. Persistent game IDs are never
## translated; only display text goes through keys.

const PATH := "res://locale/strings.json"
static var _loaded := false


static func load_strings() -> void:
	if _loaded:
		return
	_loaded = true
	var data = SafeFile.read_json(PATH)
	if data is String:
		push_error("Localization: cannot read %s: %s" % [PATH, data])
		return
	var by_locale := {}
	for key in data:
		var entry: Dictionary = data[key]
		for loc in entry:
			if not by_locale.has(loc):
				var t := Translation.new()
				t.locale = loc
				by_locale[loc] = t
			(by_locale[loc] as Translation).add_message(key, str(entry[loc]))
	for loc in by_locale:
		TranslationServer.add_translation(by_locale[loc])


## Keys referenced in code, used by the content check.
static func keys() -> Array:
	var data = SafeFile.read_json(PATH)
	return [] if data is String else data.keys()
