class_name PlayerState
extends RefCounted
## Persistent player record inside a world (plain data).
## player_id is the identity token sent by the player's game; it is stable
## across reconnects, so a returning player gets their position back.

var player_id := ""
var display_name := "Survivor"
var region_id := ""
var position := Vector2.ZERO
var facing := 0          # 0 down, 1 up, 2 left, 3 right (presentation hint)
var carried := {}        # resource id -> amount the player is carrying, e.g. {"wood": 4}
var health := 100.0
var hydration := 100.0
var dead := false
var weapon := ""         # "" = bare hands, "club" = wooden club
var respawn_tick := 0    # runtime
var last_hurt_tick := -100000  # runtime
var online := false      # runtime only — never saved
var last_seen_unix := 0


func carrying(resource: String) -> int:
	return int(carried.get(resource, 0))


func to_dict() -> Dictionary:
	return {"name": display_name, "region_id": region_id,
		"position": [snappedf(position.x, 0.01), snappedf(position.y, 0.01)],
		"facing": facing, "last_seen_unix": last_seen_unix, "carried": carried.duplicate(),
		"health": snappedf(health, 0.1), "hydration": snappedf(hydration, 0.1), "weapon": weapon}


static func from_dict(id: String, d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.display_name = str(d.get("name", "Survivor"))
	p.region_id = str(d.get("region_id", Content.DEFAULT_REGION))
	var pos: Array = d.get("position", [0, 0])
	p.position = Vector2(float(pos[0]), float(pos[1]))
	p.facing = int(d.get("facing", 0))
	p.last_seen_unix = int(d.get("last_seen_unix", 0))
	# A player saved while dead comes back alive (respawn rule: keep everything).
	p.health = clampf(float(d.get("health", 100.0)), 1.0, 100.0)
	p.hydration = clampf(float(d.get("hydration", 100.0)), 0.0, 100.0)
	p.weapon = str(d.get("weapon", ""))
	var c: Dictionary = d.get("carried", {})
	for k in c:
		p.carried[str(k)] = maxi(0, int(c[k]))
	return p
