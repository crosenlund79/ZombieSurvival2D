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
var carried := {}        # stackable item id -> amount the player is carrying, e.g. {"wood": 4}
var gear: Array = []     # individual items: [{uid, item, cond}] (tools, weapons, clothing, unique finds)
var equipped := {}       # slot ("hand", "body") -> gear uid
var hunger := 100.0      # 100 = fed, 0 = starving
var health := 100.0
var hydration := 100.0
## Iteration 011: body warmth, 100 = warm, 0 = freezing (cold exposure, SurvivalSim).
var warmth := 100.0
## Iteration 011: id of the vehicle this player sits in ("" = on foot). Saved.
var vehicle_id := ""
## Iteration 011: flashlight switched on (replicated presentation state).
var flashlight := false
## Iteration 012 (experimental): how this player views bunker levels, "side" or
## "top". Runtime only; the client reports it, the host uses it to snap feet to
## the floor in the side view. Both read the same bunker data.
var bunker_view := "side"
## Iteration 013: skills, {"scavenging": {"xp": n}} (SkillSim). Saved, replicated
## with the inventory; levels are derived from XP.
var skills := {}
var dead := false
## Item id of the usable tool/weapon in the hand ("" = bare hands). Derived from
## the equipped gear (a broken item counts as bare hands); read-only.
var weapon: String:
	get:
		var g := equipped_gear("hand")
		return str(g.get("item", "")) if not g.is_empty() and float(g.get("cond", 1.0)) > 0.0 else ""
	set(_v):
		pass
var respawn_tick := 0    # runtime
var last_hurt_tick := -100000  # runtime
var online := false      # runtime only — never saved
var last_seen_unix := 0


func carrying(resource: String) -> int:
	return int(carried.get(resource, 0))


## Index of a gear item in `gear` by uid (-1 if not carried).
## Iteration 011: carries at least one gear item of this kind (e.g. a flashlight).
func has_gear_item(item: String) -> bool:
	for g in gear:
		if str(g.get("item", "")) == item:
			return true
	return false


func find_gear(uid: String) -> int:
	for i in gear.size():
		if str(gear[i].get("uid", "")) == uid:
			return i
	return -1


## The gear record equipped in a slot, or {}.
func equipped_gear(slot: String) -> Dictionary:
	var i := find_gear(str(equipped.get(slot, "")))
	return gear[i] if i >= 0 else {}


## Inventory snapshot replicated to clients: stacks, gear and equipped slots.
func inventory_dict() -> Dictionary:
	return {"carried": carried.duplicate(), "gear": gear.duplicate(true), "equipped": equipped.duplicate(),
		"skills": skills.duplicate(true)}


func apply_inventory(d: Dictionary) -> void:
	carried = (d.get("carried", {}) as Dictionary).duplicate()
	gear = (d.get("gear", []) as Array).duplicate(true)
	equipped = (d.get("equipped", {}) as Dictionary).duplicate()
	if d.has("skills"):
		skills = (d.get("skills", {}) as Dictionary).duplicate(true)


func to_dict() -> Dictionary:
	return {"name": display_name, "region_id": region_id,
		"position": [snappedf(position.x, 0.01), snappedf(position.y, 0.01)],
		"facing": facing, "last_seen_unix": last_seen_unix, "carried": carried.duplicate(),
		"health": snappedf(health, 0.1), "hydration": snappedf(hydration, 0.1),
		"hunger": snappedf(hunger, 0.1), "gear": gear.duplicate(true), "equipped": equipped.duplicate(),
		"warmth": snappedf(warmth, 0.1), "vehicle_id": vehicle_id, "skills": skills.duplicate(true)}


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
	p.hunger = clampf(float(d.get("hunger", 100.0)), 0.0, 100.0)
	p.warmth = clampf(float(d.get("warmth", 100.0)), 0.0, 100.0)
	p.vehicle_id = str(d.get("vehicle_id", ""))
	p.skills = SkillSim.sanitize(d.get("skills", {}))
	for g in d.get("gear", []):
		if g is Dictionary and Items.exists(str(g.get("item", ""))) and str(g.get("uid", "")) != "":
			p.gear.append({"uid": str(g["uid"]), "item": str(g["item"]), "cond": float(g.get("cond", 100.0))})
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		if p.find_gear(str(eq[slot])) >= 0:
			p.equipped[str(slot)] = str(eq[slot])
	var c: Dictionary = d.get("carried", {})
	for k in c:
		p.carried[str(k)] = maxi(0, int(c[k]))
	return p
