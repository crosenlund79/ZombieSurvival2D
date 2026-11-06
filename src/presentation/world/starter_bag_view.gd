class_name StarterBagView
extends EntityView
## The bag beside the burned shed (Red Thaw opening). It holds one personal
## starter kit per player: a large bottle of water, crackers and a field map.
## The host records who took theirs (WorldActions._starter_bag); this view only
## shows the bag full or emptied *for the local player* and plays the rummage.


func _taken_by_me() -> bool:
	var taken: Array = state().get("taken_by", [])
	return taken.has(Session.local_player_id)


## Iteration 011: the same per-player kit mechanism serves other pickups (the
## cabin's flashlight). Content may set "art", "art_empty" ("" = nothing left
## to show), "art_offset" and "prompt_key".
func _refresh(cause: String) -> void:
	var full := str(def.get("art", "prop.starter_bag"))
	var empty := str(def.get("art_empty", "prop.starter_bag_empty"))
	var off: Array = def.get("art_offset", [0, 0])
	var id := empty if _taken_by_me() else full
	if id == "":
		hide_art("Main")
	else:
		var sp := show_art("Main", id)
		sp.position += Vector2(float(off[0]), float(off[1]))
	if interact != null:
		interact.prompt_key = str(def.get("prompt_key", "PROMPT_STARTER_BAG"))
	if cause == "looted":
		Audio.play("sfx.rummage", global_position)
