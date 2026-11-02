class_name SupportView
extends EntityView
## A reinforcement location in a bunker level (support_site entity).
## exposed (unreinforced earth) -> building (wood already spent from the
## shelter stockpile; timed) -> reinforced (timber frame). The state, not the
## art, is what future excavation rules will check.

@export var exposed_asset := "bunker.support_exposed"
@export var building_asset := "bunker.support_building"
@export var done_asset := "bunker.support_done"
var _progress: ProgressMarker


func _build() -> void:
	_progress = ProgressMarker.new()
	_progress.position = Vector2(0, -190)
	_progress.source = build_progress
	add_child(_progress)


func _refresh(cause: String) -> void:
	var stage := str(state().get("stage", "exposed"))
	_progress.visible = stage == "building"
	match stage:
		"exposed":
			show_art("Main", exposed_asset)
		"building":
			show_art("Main", building_asset)
		_:
			show_art("Main", done_asset)
	if interact != null:
		interact.enabled = stage == "exposed"
		interact.prompt_key = "PROMPT_REINFORCE"
		var b := Session.world.bunker_for_region(region_id) if Session.world != null else null
		interact.prompt_args = [int(def.get("wood_cost", 4)), b.amount("wood") if b != null else 0]
	match cause:
		"build_started":
			Audio.play("sfx.build_hammer", global_position)
		"completed":
			Audio.play("sfx.build_done", global_position)


func is_reinforced() -> bool:
	return str(state().get("stage", "exposed")) == "reinforced"
