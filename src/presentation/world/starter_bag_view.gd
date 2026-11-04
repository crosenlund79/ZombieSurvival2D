class_name StarterBagView
extends EntityView
## The bag beside the burned shed (Red Thaw opening). It holds one personal
## starter kit per player: a large bottle of water, crackers and a field map.
## The host records who took theirs (WorldActions._starter_bag); this view only
## shows the bag full or emptied *for the local player* and plays the rummage.


func _taken_by_me() -> bool:
	var taken: Array = state().get("taken_by", [])
	return taken.has(Session.local_player_id)


func _refresh(cause: String) -> void:
	show_art("Main", "prop.starter_bag_empty" if _taken_by_me() else "prop.starter_bag")
	if interact != null:
		interact.prompt_key = "PROMPT_STARTER_BAG"
	if cause == "looted":
		Audio.play("sfx.rummage", global_position)
