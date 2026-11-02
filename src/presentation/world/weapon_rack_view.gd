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
		interact.enabled = me == null or me.weapon != str(def.get("weapon", "club"))
