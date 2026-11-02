class_name ShelterSiteView
extends EntityView
## A place where a shelter can be dug (shelter_site entity). Stages:
## none -> building (timed on the shared clock) -> built (a wooden floor hatch
## that opens and closes). The hatch can be upgraded (tier wood -> steel) with
## the repair/upgrade key; a steel hatch keeps bunker noise in.

var _progress: ProgressMarker


func _build() -> void:
	_progress = ProgressMarker.new()
	_progress.position = Vector2(0, -110)
	_progress.source = build_progress
	add_child(_progress)


func _refresh(cause: String) -> void:
	var st := state()
	var stage := str(st.get("stage", "none"))
	var open := bool(st.get("open", false))
	_progress.visible = stage == "building"
	match stage:
		"none":
			show_art("Main", "world.shelter_site_marked")
			_set_prompt(true, "PROMPT_BUILD_SHELTER")
		"building":
			show_art("Main", "world.shelter_site_digging")
			_set_prompt(false, "PROMPT_BUILD_SHELTER")
		_:
			var steel := str(st.get("tier", "wood")) == "steel"
			if steel:
				show_art("Main", "world.hatch_steel_open" if open else "world.hatch_steel_closed")
			else:
				show_art("Main", "world.hatch_open" if open else "world.hatch_closed")
			_set_prompt(true, "PROMPT_CLOSE_HATCH" if open else "PROMPT_OPEN_HATCH")
			if interact != null:
				var up: Dictionary = def.get("upgrades", {}).get(str(st.get("tier", "wood")), {})
				interact.on_repair = func() -> void: Session.request_entity_action(entity_id, "upgrade")
				interact.secondary_key = "PROMPT_UPGRADE_HATCH" if not up.is_empty() else ""
				interact.secondary_args = [Items.describe(up.get("cost", {}))]
	match cause:
		"build_started":
			Audio.play("sfx.dig", global_position)
		"completed":
			Audio.play("sfx.build_done", global_position)
			Session.notice.emit("SHELTER_COMPLETE", [])
		"action":
			Audio.play("sfx.hatch_open" if open else "sfx.hatch_close", global_position)
		"upgraded":
			Audio.play("sfx.upgrade", global_position)


func _set_prompt(on: bool, key: String) -> void:
	if interact != null:
		interact.enabled = on
		interact.prompt_key = key
