extends TestCase
## Iteration 006: construction placement, material transactions, upgrades,
## structural damage and repair, breaching, traps, bunker construction rules,
## hatch upgrade, persistence and the schema 3 -> 4 migration.

const SITE := "homestead.farmhouse.shelter"
const INTERIOR := "homestead.farmhouse"
const LEVEL := "bunker:homestead.farmhouse.shelter:-1"
const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"
const YARD := Vector2(1300, 800)


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _world() -> WorldState:
	var w := WorldState.create_new("w_build", 5)
	w.threat.enabled = false
	return w


func _bunker_world() -> WorldState:
	var w := _world()
	var site := Content.entity_position(Content.entity_def(INTERIOR, SITE))
	_player(w, PID, INTERIOR, site + Vector2(0, 40))
	check(WorldActions.request_interact(w, PID, SITE, 0)["ok"], "construction starts")
	Simulation.advance(w, 2000)
	(w.players[PID] as PlayerState).region_id = LEVEL
	return w


func _built(w: WorldState, rid: String, oid: String) -> Dictionary:
	Simulation.advance(w, 100)
	return w.region(rid).objects.get(oid, {})


func _place(w: WorldState, pid: String, def_id: String, pos: Vector2) -> Dictionary:
	return Build.request_build(w, pid, def_id, pos)


func _oid(res: Dictionary) -> String:
	return str(res["objects"][0][1]) if res["ok"] else ""


func test_place_spend_once_and_complete_on_time() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 7}
	var r := _place(w, PID, "barricade", YARD + Vector2(0, -90))
	check(r["ok"], "placed: " + str(r["reason"]))
	eq(a.carrying("wood"), 4, "3 wood spent once")
	var oid := _oid(r)
	var o: Dictionary = w.region("homestead").objects[oid]
	eq(str(o["stage"]), "building", "timed construction")
	eq(_place(w, PID, "barricade", YARD + Vector2(0, -90))["reason"], "ACTION_BUILD_OCCUPIED", "same spot refused")
	eq(a.carrying("wood"), 4, "refusal spends nothing")
	var ticks := int(o["ticks"])
	Simulation.advance(w, ticks - 1)
	eq(str(o["stage"]), "building", "not done early")
	Simulation.advance(w, 1)
	eq(str(o["stage"]), "built", "built on time")
	eq(float(o["hp"]), 120.0, "full condition")


func test_placement_rules() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", Vector2(300, 1300))
	a.carried = {"wood": 30}
	eq(_place(w, PID, "barricade", Vector2(300, 1220))["reason"], "ACTION_BUILD_OUTSIDE_ZONE", "outside the homestead build zone")
	a.position = Vector2(1150, 960)
	eq(_place(w, PID, "barricade", Vector2(1150, 940))["reason"], "ACTION_BUILD_BLOCKS_ACCESS", "never on the gate")
	a.position = YARD
	eq(_place(w, PID, "barricade", YARD + Vector2(0, 10))["reason"], "ACTION_BUILD_PLAYER_IN_WAY", "not on top of a player")
	eq(_place(w, PID, "planter", YARD + Vector2(0, -90))["reason"], "ACTION_BUILD_NOT_HERE", "planters only underground")
	a.carried = {"wood": 1}
	var r := _place(w, PID, "barricade", YARD + Vector2(0, -90))
	eq(r["reason"], "ACTION_NEED_MATERIALS", "materials checked")
	eq(a.carrying("wood"), 1, "nothing spent")
	a.region_id = INTERIOR
	a.position = Content.entity_position(Content.entity_def("homestead.farmhouse", "homestead.farmhouse.shelter")) + Vector2(60, 0)
	a.carried = {"wood": 30}
	eq(_place(w, PID, "crate", Content.entity_position(Content.entity_def("homestead.farmhouse", "homestead.farmhouse.shelter")))["reason"], "ACTION_BUILD_NOT_HERE", "no building inside the farmhouse")


func test_concurrent_placement_one_wins() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var b := _player(w, PID2, "homestead", YARD + Vector2(60, 0))
	a.carried = {"wood": 3}
	b.carried = {"wood": 3}
	var spot := YARD + Vector2(30, -100)
	var ra := _place(w, PID, "barricade", spot)
	var rb := _place(w, PID2, "barricade", spot)
	check(ra["ok"] and not rb["ok"], "exactly one placement")
	eq(a.carrying("wood") + b.carrying("wood"), 3, "only the winner paid")
	eq(w.region("homestead").objects.size(), 1, "one object")


func test_upgrade_damage_repair_and_destroy() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 5, "scrap_metal": 4, "cement": 1}
	var oid := _oid(_place(w, PID, "barricade", YARD + Vector2(0, -90)))
	var o := _built(w, "homestead", oid)
	var r := Build.request_object(w, PID, oid, "upgrade", "")
	check(r["ok"], "upgrade to metal")
	eq(int(o["tier"]), 1, "tier 1")
	eq(float(o["hp"]), 260.0, "stronger")
	eq(a.carrying("scrap_metal"), 1, "metal spent")
	eq(Build.request_object(w, PID, oid, "upgrade", "")["reason"], "ACTION_NEED_MATERIALS", "concrete needs more")
	eq(Build.request_object(w, PID, oid, "repair", "")["reason"], "ACTION_NOT_DAMAGED", "no repair chores when intact")
	var reg := w.region("homestead")
	Build.damage_object(w, reg, oid, 23.0)
	eq(float(o["hp"]), 240.0, "armor 3 reduces a 23 hit to 20")
	check(Build.request_object(w, PID, oid, "repair", "")["ok"], "repair")
	eq(float(o["hp"]), 260.0, "repaired (capped at max)")
	eq(a.carrying("scrap_metal"), 0, "one metal used")
	var res := {}
	for i in 40:
		res = Build.damage_object(w, reg, oid, 30.0)
		if not reg.objects.has(oid):
			break
	check(not reg.objects.has(oid), "destroyed when condition reaches zero")
	eq(str(res["events"][0]["kind"]), "struct_destroyed", "destruction event")


func test_dismantle_refund_and_crate_contents_kept() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 8, "fuel": 2}
	var oid := _oid(_place(w, PID, "crate", YARD + Vector2(0, -90)))
	_built(w, "homestead", oid)
	check(Build.request_object(w, PID, oid, "store", "fuel")["ok"], "store fuel in crate")
	eq(a.carrying("fuel"), 0, "moved out of the bag")
	check(Build.request_object(w, PID, oid, "dismantle", "")["ok"], "dismantle")
	eq(a.carrying("wood"), 6, "half the wood back (4 -> 2)")
	var piles := 0
	for k in w.region("homestead").objects:
		var o: Dictionary = w.region("homestead").objects[k]
		if Build.is_pile(o):
			piles += 1
			eq(Items.amount(o["items"], "fuel"), 2, "crate contents left on the ground")
			check(Build.request_object(w, PID, k, "pickup", "")["ok"], "pick up")
	eq(piles, 1, "one ground pile")
	eq(a.carrying("fuel"), 2, "nothing lost or duplicated")


func test_zombie_breaks_structure_and_gate() -> void:
	var w := WorldState.create_new("w_breach", 7)
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 3}
	var oid := _oid(_place(w, PID, "barricade", YARD + Vector2(0, -90)))
	var o := _built(w, "homestead", oid)
	w.zombies.clear()
	var z := ZombieSim.spawn(w, "homestead", Build.pos_of(o) + Vector2(0, -50), false)
	z.ai = ZombieState.AI.INVESTIGATE
	z.goal = YARD
	z.target_struct = "o:" + oid
	a.position = Vector2(300, 1300)  # out of sight
	for i in 60:
		Simulation.advance(w, 1)
	check(float(o.get("hp", 120)) < 120.0, "zombie damages the barricade (%s)" % str(o.get("hp")))
	var gate := "homestead.yard_gate"
	var reg := w.region("homestead")
	var z2 := ZombieSim.spawn(w, "homestead", Vector2(1150, 940), false)
	z2.ai = ZombieState.AI.INVESTIGATE
	z2.goal = Vector2(1150, 800)
	z2.target_struct = "e:" + gate
	for i in 1500:  # AI catches up at most a few ticks per call, so step like the live clock
		Simulation.advance(w, 1)
		if bool(reg.entity_state(gate).get("broken", false)):
			break
	check(bool(reg.entity_state(gate).get("broken", false)), "the gate breaks under sustained attack")
	check(bool(reg.entity_state(gate).get("open", false)), "a broken gate stands open")
	a.position = Vector2(1150, 960)
	a.carried = {"wood": 2}
	check(WorldActions.request_entity_action(w, PID, gate, "repair", "")["ok"], "repair the gate")
	check(not bool(reg.entity_state(gate).get("broken", false)), "gate whole again")


func test_breach_target_prefers_structure_toward_goal() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 6}
	var o1 := _oid(_place(w, PID, "barricade", Vector2(1300, 700)))
	a.position = Vector2(1420, 800)
	var o2 := _oid(_place(w, PID, "barricade", Vector2(1420, 700)))
	Simulation.advance(w, 100)
	eq(Build.breach_target(w, "homestead", Vector2(1310, 640), Vector2(1300, 800)), "o:" + o1, "the one in the way")
	eq(Build.breach_target(w, "homestead", Vector2(1420, 640), Vector2(1420, 800)), "o:" + o2, "the other one in the way")


func test_spike_trap_hurts_slows_and_wears() -> void:
	var w := _world()
	w.threat.enabled = true
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"spike_kit": 1}
	var oid := _oid(_place(w, PID, "spike_trap", YARD + Vector2(0, -90)))
	var o := _built(w, "homestead", oid)
	w.zombies.clear()
	var z := ZombieSim.spawn(w, "homestead", Build.footprint(w.region("homestead"), o).get_center(), false)
	z.ai = ZombieState.AI.WANDER
	z.timer = 100.0
	for i in 20:
		Simulation.advance(w, 1)
	check(z.health < 100.0, "zombie on spikes takes damage (%s)" % z.health)
	check(float(o["hp"]) < 60.0, "trap wears while it works")


func test_bunker_construction_rules() -> void:
	var w := _bunker_world()
	var a: PlayerState = w.players[PID]
	var reg := w.region(LEVEL)
	var cell := Vector2i(20, 12)
	a.position = Terrain.cell_center(reg, cell) + Vector2(0, 70)
	w.bunker(SITE).resources = {"wood": 20, "grow_light": 1}
	var r := _place(w, PID, "barricade", Terrain.cell_center(reg, cell))
	check(r["ok"], "wall on open floor, paid from shelter storage: " + str(r["reason"]))
	eq(w.bunker(SITE).amount("wood"), 17, "storage paid")
	check("bunkers" in r and not (r["bunkers"] as Array).is_empty(), "storage change published")
	eq(Build.footprint(reg, reg.objects[_oid(r)]), Terrain.cell_rect(reg, cell), "occupies exactly one cell")
	a.position = Terrain.cell_center(reg, Vector2i(13, 11))
	eq(_place(w, PID, "barricade", Terrain.cell_center(reg, Vector2i(12, 11)))["reason"], "ACTION_BUILD_NEEDS_FLOOR", "solid earth refused")
	reg.terrain["dug"] = {"12,12": true, "11,12": true}
	a.position = Terrain.cell_center(reg, Vector2i(13, 13))
	eq(_place(w, PID, "barricade", Terrain.cell_center(reg, Vector2i(12, 12)))["reason"], "ACTION_BUILD_WOULD_TRAP", "never cut off a dug chamber")
	a.position = Terrain.cell_center(reg, Vector2i(12, 13)) + Vector2(0, 20)
	check(_place(w, PID, "planter", Terrain.cell_center(reg, Vector2i(11, 12)))["ok"], "planter at the far end is fine")


func test_hatch_upgrade() -> void:
	var w := _bunker_world()
	var a: PlayerState = w.players[PID]
	a.region_id = INTERIOR
	a.position = Content.entity_position(Content.entity_def(INTERIOR, SITE)) + Vector2(0, 40)
	eq(WorldActions.request_entity_action(w, PID, SITE, "upgrade", "")["reason"], "ACTION_NEED_MATERIALS", "needs metal and cement")
	a.carried = {"scrap_metal": 2}
	w.bunker(SITE).resources = {"scrap_metal": 2, "cement": 1}
	check(WorldActions.request_entity_action(w, PID, SITE, "upgrade", "")["ok"], "upgrade with bag + storage")
	eq(str(w.region(INTERIOR).entity_state(SITE)["tier"]), "steel", "steel hatch")
	eq(Items.total(a.carried) + Items.total(w.bunker(SITE).resources), 0, "cost spent exactly")
	eq(WorldActions.request_entity_action(w, PID, SITE, "upgrade", "")["reason"], "ACTION_ALREADY_DONE", "no further tier")


func test_structures_persist_and_unfinished_build_completes_after_load() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 10, "scrap_metal": 3}
	var done := _oid(_place(w, PID, "barricade", YARD + Vector2(0, -90)))
	Simulation.advance(w, 100)
	Build.request_object(w, PID, done, "upgrade", "")
	Build.damage_object(w, w.region("homestead"), done, 50.0)
	var crate := _oid(_place(w, PID, "crate", YARD + Vector2(100, -90)))
	Simulation.advance(w, 5)
	w.region("homestead").set_fields("homestead.yard_gate", {"hp": 40.0})
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes: " + str(res.get("error")))
	var w2: WorldState = res["world"]
	var o: Dictionary = w2.region("homestead").objects[done]
	eq(int(o["tier"]), 1, "upgrade persisted")
	eq(float(o["hp"]), 213.0, "damage persisted (260 - (50 - 3))")
	eq(str(w2.region("homestead").objects[crate]["stage"]), "building", "unfinished build restored")
	eq(w2.next_uid, w.next_uid, "uid counter persisted")
	Simulation.advance(w2, 100)
	eq(str(w2.region("homestead").objects[crate]["stage"]), "built", "and completes exactly once after load")
	eq(float(w2.region("homestead").entity_state("homestead.yard_gate")["hp"]), 40.0, "gate damage persisted")


func test_schema3_save_migrates_club_to_gear() -> void:
	var d := {"schema_version": 3, "game": "Aftergrowth", "world": {"world_id": "w_old", "seed": 1, "tick": 50,
		"regions": {}, "bunkers": {}, "zombies": {}, "next_zombie": 0},
		"players": {PID: {"name": "Old", "region_id": "homestead", "position": [100, 100], "weapon": "club", "carried": {"wood": 2}}}}
	var res := SaveCodec.decode(d)
	check(res["ok"], "migrates: " + str(res.get("error")))
	var p: PlayerState = res["world"].players[PID]
	eq(p.weapon, "club", "club equipped after migration")
	eq(p.gear.size(), 1, "as one gear item")
	eq(p.carrying("wood"), 2, "stacks kept")
	eq(p.hunger, 100.0, "fed by default")
