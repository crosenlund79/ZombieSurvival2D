class_name StockpileView
extends EntityView
## The shared shelter timber stockpile. The amount lives in the bunker's
## resources (BunkerState); the pile art grows with it. Hidden until the
## shelter it belongs to exists.

var _label: Label
var _last_wood := -1


func _build() -> void:
	_label = Label.new()
	_label.position = Vector2(-70, -86)
	_label.size = Vector2(140, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	Session.player_resources_changed.connect(func(_p: String) -> void: _refresh("carried"))


func _bunker() -> BunkerState:
	if Session.world == null:
		return null
	if def.has("bunker_of"):
		return Session.world.bunker(str(def["bunker_of"]))
	return Session.world.bunker_for_region(region_id)


func _refresh(cause: String) -> void:
	var b := _bunker()
	visible = b != null
	if b == null:
		return
	var wood := b.amount("wood")
	var art := "world.timber_pile_empty"
	if wood >= 20:
		art = "world.timber_pile_large"
	elif wood >= 8:
		art = "world.timber_pile_medium"
	elif wood > 0:
		art = "world.timber_pile_small"
	show_art("Main", art)
	_label.text = UITheme.fmt("STOCKPILE_LABEL", [wood])
	if interact != null:
		var me := Session.local_player()
		interact.prompt_key = "PROMPT_DEPOSIT_WOOD"
		interact.prompt_args = [me.carrying("wood") if me != null else 0]
	if cause == "bunker" and _last_wood >= 0 and wood > _last_wood:
		Audio.play("sfx.wood_drop", global_position)
	_last_wood = wood
