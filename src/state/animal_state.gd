class_name AnimalState
extends RefCounted
## One wild animal as plain data (iteration 011 D). The host simulates it
## (WildlifeSim); clients mirror position, facing and activity from rows.
## Transient by design: wildlife is rebuilt from content whenever a world
## starts, so nothing here is saved.
##
## activity: "idle", "walk", "alert" (stopped, watching a player), "flee";
## iteration 015 E: "stalk" (wolves circling a player), "attack" (closing in to
## bite / charge), "warn" (a bear standing its ground), "retreat" (going home).

var animal_id := ""
var species := "wolf"
var region_id := ""
var position := Vector2.ZERO
var facing := Vector2.RIGHT
var activity := "idle"
var home := Rect2()           # roaming area
var goal := Vector2.ZERO
var timer := 0.0
var call_timer := 0.0
var watching := ""            # player id it is wary of
## Iteration 015 E (host only, transient)
var health := 0.0             # 0 = not set yet (WildlifeSim fills it from the species)
var group := ""               # pack / family id ("species:region:group")
var attack_cd := 0.0          # seconds before the next bite / swipe
var engaged := 0.0            # seconds spent stalking / attacking the current target
var calm := 0.0               # seconds before it may engage again after giving up
var warned := false           # a bear has already warned this target
var day_aggression := -1.0    # per-group override of the species' daytime aggression (-1 = species value)


func row() -> Array:
	return [animal_id, species, region_id, snappedf(position.x, 0.1), snappedf(position.y, 0.1),
		snappedf(facing.x, 0.01), snappedf(facing.y, 0.01), activity, snappedf(health, 0.1)]
