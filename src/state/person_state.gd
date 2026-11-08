class_name PersonState
extends RefCounted
## One faction member as plain data (iteration 015 F): a Cinder raider, a Hearth
## guard, villager, trader, mechanic or elder, or the Lantern contact. The host
## simulates them (FactionSim); clients mirror compact rows. Rebuilt from
## content/factions.json whenever a world starts; who is dead (and until when)
## is kept in world.meta["factions"]["dead"], so killing raiders persists.
##
## activity: "idle", "walk", "alert" (aiming at a player), "shoot", "down".

var person_id := ""
var faction := ""
var role := ""                # raider, guard, villager, trader, mechanic, elder, contact
var region_id := ""
var position := Vector2.ZERO
var facing := Vector2.DOWN
var activity := "idle"
var health := 100.0
var post := Vector2.ZERO      # where it stands / returns to
var patrol: Array = []        # waypoints (Vector2) walked in turn
var patrol_i := 0
var goal := Vector2.ZERO
var timer := 0.0
var attack_cd := 0.0
var target := ""              # player id it is fighting


func row() -> Array:
	return [person_id, faction, role, region_id, snappedf(position.x, 0.1), snappedf(position.y, 0.1),
		snappedf(facing.x, 0.01), snappedf(facing.y, 0.01), activity, snappedf(health, 0.1)]
