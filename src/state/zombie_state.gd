class_name ZombieState
extends RefCounted
## One zombie (plain data). Simulated only by the host (ZombieSim); clients
## mirror position/state from snapshots for display.
##
## Persistence policy: zombies of the base population (persistent = true) are
## saved with identity, region, position and health; their AI state resets to
## wandering on load. Horde reinforcements (persistent = false) and all AI
## memory are transient and never saved, so a reload cannot duplicate a horde.

enum AI { WANDER, INVESTIGATE, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

var zombie_id := ""
var region_id := "homestead"
var position := Vector2.ZERO
var facing := Vector2.DOWN
var health := 100.0
var persistent := true
var ai: int = AI.WANDER
# --- transient AI memory (never saved) ---
var target_player := ""
var goal := Vector2.ZERO            # where it is walking to
var last_known := Vector2.ZERO      # last seen/heard position of interest
var path: Array = []                # remaining waypoints
var path_goal := Vector2.INF
var timer := 0.0                    # seconds left in the current timed state
var lost_sight := 0.0               # seconds since the target was last seen
var attack_cooldown := 0.0
var dead_time := 0.0
var leaving := false                # transient zombie walking back off the map


func is_dead() -> bool:
	return ai == AI.DEAD


func state_name() -> String:
	return AI.keys()[ai]


func to_dict() -> Dictionary:
	return {"region_id": region_id, "position": [snappedf(position.x, 0.1), snappedf(position.y, 0.1)],
		"health": health}


static func from_dict(id: String, d: Dictionary) -> ZombieState:
	var z := ZombieState.new()
	z.zombie_id = id
	z.region_id = str(d.get("region_id", "homestead"))
	var p: Array = d.get("position", [0, 0])
	z.position = Vector2(float(p[0]), float(p[1]))
	z.health = clampf(float(d.get("health", 100.0)), 1.0, 100.0)
	z.persistent = true
	z.goal = z.position
	return z
