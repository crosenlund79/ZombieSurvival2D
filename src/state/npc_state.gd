class_name NpcState
extends RefCounted
## One survivor (plain data). The host simulates survivors (NpcSim); clients
## mirror position and activity from snapshots for display.
##
## recruit: "waiting" (in the world, not met), "met" (talked to, needs help),
## "travelling" (recruited, walking home off-screen), "home" (lives in the
## bunker). job: "" (free), "water", "farm". Everything here is saved.

var npc_id := ""
var name := "Survivor"
var desc_key := ""
var region_id := ""
var position := Vector2.ZERO
var facing := Vector2.DOWN
var recruit := "waiting"
var health := 100.0
var job := ""
var activity := "idle"        # idle, walking, working, resting, sheltering, travelling
var status := ""              # translation key explaining what blocks work ("" = fine)
var bunker_id := ""           # settlement the survivor belongs to
var arrive_tick := 0          # travelling: when they reach the bunker
var work_timer := 0.0         # seconds until the next work action
var upkeep_tick := 0          # last daily food/water upkeep
var fed := true               # false when the settlement could not supply food/water
# --- transient ---
var path: Array = []
var goal := Vector2.ZERO
var timer := 0.0


func to_dict() -> Dictionary:
	return {"name": name, "desc_key": desc_key, "region_id": region_id,
		"position": [snappedf(position.x, 0.1), snappedf(position.y, 0.1)], "recruit": recruit,
		"health": snappedf(health, 0.1), "job": job, "activity": activity, "status": status,
		"bunker_id": bunker_id, "arrive_tick": arrive_tick, "work_timer": snappedf(work_timer, 0.01),
		"upkeep_tick": upkeep_tick, "fed": fed}


static func from_dict(id: String, d: Dictionary) -> NpcState:
	var n := NpcState.new()
	n.npc_id = id
	n.name = str(d.get("name", "Survivor"))
	n.desc_key = str(d.get("desc_key", ""))
	n.region_id = str(d.get("region_id", ""))
	var p: Array = d.get("position", [0, 0])
	n.position = Vector2(float(p[0]), float(p[1]))
	n.recruit = str(d.get("recruit", "waiting"))
	n.health = clampf(float(d.get("health", 100.0)), 1.0, 100.0)
	n.job = str(d.get("job", ""))
	n.activity = str(d.get("activity", "idle"))
	n.status = str(d.get("status", ""))
	n.bunker_id = str(d.get("bunker_id", ""))
	n.arrive_tick = int(d.get("arrive_tick", 0))
	n.work_timer = float(d.get("work_timer", 0.0))
	n.upkeep_tick = int(d.get("upkeep_tick", 0))
	n.fed = bool(d.get("fed", true))
	n.goal = n.position
	return n


static func encode_all(world: WorldState) -> Dictionary:
	var out := {}
	for id in world.npcs:
		out[id] = (world.npcs[id] as NpcState).to_dict()
	return out


static func decode_all(world: WorldState, d, warnings: Array) -> void:
	if not (d is Dictionary):
		return
	for id in d:
		if not (d[id] is Dictionary):
			continue
		var n := NpcState.from_dict(str(id), d[id])
		if n.region_id != "" and world.region(n.region_id) == null:
			warnings.append("survivor %s was in missing region %s; moved to their recruitment spot" % [id, n.region_id])
			n.region_id = ""
		world.npcs[str(id)] = n
