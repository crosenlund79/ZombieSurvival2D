class_name ZombieState
extends RefCounted
## One zombie (plain data). Simulated only by the host (ZombieSim); clients
## mirror position/state from snapshots for display.
##
## Persistence policy: zombies of the base population (persistent = true) are
## saved with identity, region, position and health; their AI state resets to
## wandering on load. Horde reinforcements (persistent = false) and all AI
## memory are transient and never saved, so a reload cannot duplicate a horde.

## LISTEN (iteration 011): stopped, turned toward a disturbance, listening; may
## screech before investigating. Appended last so replicated ints stay stable.
enum AI { WANDER, INVESTIGATE, CHASE, WINDUP, RECOVER, STAGGER, DEAD, LISTEN }
## Body posture (presentation + speed): upright, crouched (lowered), crawling on all fours.
enum Posture { UPRIGHT, CROUCH, CRAWL }

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
var target_struct := ""             # "o:<oid>" / "e:<eid>": structure it is breaking through
var stuck := 0.0                    # seconds without progress toward a structure
var trap_time := 0.0                # seconds spent on spikes since the last trap hit
var siege := false                  # part of a defence event (EventSim)
var extra := false                  # extra wanderer from regional heat / night (EventSim)
var hunter := false                 # Red Thaw: a Burnt One hunting one player (ZombieSim.start_hunt)
var hunt_target := ""               # player id it hunts
var hunt_until := 0                 # world tick when the hunt gives up
# --- iteration 011: body and hearing (transient, never saved) ---
var posture: int = Posture.UPRIGHT
var posture_timer := 0.0            # seconds before the posture may change again
var burst := 0.0                    # seconds left of a crawling burst (fast scramble)
var burst_cd := 0.0                 # seconds before another burst is allowed
var screech_cd := 0.0               # seconds before this one may screech again
var listen_level := 0.0             # attention of the sound it is listening to
var heard_screech := false          # current investigation was triggered by a screech
var search_left := 0                # extra search points after losing a target
var last_dir := Vector2.ZERO        # last seen direction of travel of its target


## Stable per-individual temperament from the id (same on every peer): speed
## factor 0.85..1.15 and crawl affinity 0..1, so they do not all behave alike.
func temperament() -> Vector2:
	var h := zombie_id.hash()
	return Vector2(0.85 + float(h % 31) / 100.0, float((h / 31) % 101) / 100.0)


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
