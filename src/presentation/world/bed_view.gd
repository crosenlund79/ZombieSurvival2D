class_name BedView
extends EntityView
## A bed or bedroll (iteration 011). Using it asks the host to sleep
## (SleepSim): alone at once, together by unanimous vote. The cabin's bed is a
## furniture prop, so this view only draws art when the content gives one.


func _build() -> void:
	if def.has("art"):
		show_art("Main", str(def["art"]))
		floor_art = true
		_art_root.z_index = -1
