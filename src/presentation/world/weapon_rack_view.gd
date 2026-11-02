class_name WeaponRackView
extends EntityView
## A rack of improvised clubs. Taking one equips the player (one each; the
## rack never runs out). The host records the weapon on the player.


func _build() -> void:
	show_art("Main", "item.club_rack")
	Session.vitals_changed.connect(func(_p: String) -> void: _refresh("vitals"))


func _refresh(_cause: String) -> void:
	show_art("Main", "item.club_rack")
	if interact != null:
		var me := Session.local_player()
		var has := false
		if me != null:
			for g in me.gear:
				has = has or str(g.get("item", "")) == str(def.get("weapon", "club"))
		interact.enabled = not has
