extends TestCase
## Iteration 007: inventory (stacks + gear), equip / drop / pick up / use,
## crafting (spend once, timed, persistent, unlocks), equipment effects
## (damage, chopping, armour, wear and repair), hunger and food, planter food
## production tied to water and power, scavenging of new supplies.

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
	var w := WorldState.create_new("w_cycle", 11)
	w.threat.enabled = false
	return w


func _bench(w: WorldState, pid: String) -> String:
	var p: PlayerState = w.players[pid]
	p.carried["wood"] = p.carrying("wood") + 5
	p.carried["scrap_metal"] = p.carrying("scrap_metal") + 2
	var r := Build.request_build(w, pid, "workbench", p.position + Vector2(0, -80))
	check(r["ok"], "workbench placed: " + str(r["reason"]))
	Simulation.advance(w, 100)
	return str(r["objects"][0][1])


func _step(w: WorldState, ticks: int) -> void:
	for i in ticks:
		Simulation.advance(w, 1)


func test_equip_drop_pickup_and_use() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var axe := Inv.new_gear(w, "hatchet")
	a.gear.append(axe)
	check(Inv.request(w, PID, "equip", axe["uid"])["ok"], "equip")
	eq(a.weapon, "hatchet", "held")
	check(Inv.request(w, PID, "unequip", "hand")["ok"], "unequip")
	eq(a.weapon, "", "bare hands")
	a.carried = {"canned_food": 2}
	a.hunger = 50.0
	check(Inv.request(w, PID, "use", "canned_food")["ok"], "eat")
	eq(a.hunger, 90.0, "+40 food")
	eq(a.carrying("canned_food"), 1, "one eaten")
	a.health = 40.0
	a.carried["bandage"] = 1
	check(Inv.request(w, PID, "use", "bandage")["ok"], "bandage")
	eq(a.health, 75.0, "+35 health")
	eq(Inv.request(w, PID, "use", "wood")["reason"], "ACTION_CANT_USE", "wood cannot be used")
	a.carried["wood"] = 5
	var r := Inv.request(w, PID, "drop", "wood")
	check(r["ok"], "drop a stack")
	eq(a.carrying("wood"), 0, "gone from the bag")
	check(Inv.request(w, PID, "drop", axe["uid"])["ok"], "drop gear")
	eq(a.gear.size(), 0, "gear dropped")
	var b := _player(w, PID2, "homestead", YARD + Vector2(20, 0))
	var pile := ""
	for k in w.region("homestead").objects:
		pile = k
	check(Build.request_object(w, PID2, pile, "pickup", "")["ok"], "someone else picks it up")
	eq(b.carrying("wood"), 5, "stack moved")
	eq(b.gear.size(), 1, "gear moved with its identity")
	eq(str(b.gear[0]["uid"]), str(axe["uid"]), "same item (uid kept)")
	eq(Build.request_object(w, PID, pile, "pickup", "")["reason"], "ACTION_UNKNOWN_OBJECT", "a pile can only be emptied once")


func test_carry_limit_counts_gear() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 29}
	a.gear.append(Inv.new_gear(w, "club"))
	eq(Inv.free_slots(a), 0, "29 + 1 gear = full")
	var oid := Inv.give_stack(w, a, "scrap_metal", 2)
	check(oid != "", "overflow goes to a ground pile, never lost")


func test_crafting_spends_once_and_delivers() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var b := _player(w, PID2, "homestead", YARD + Vector2(40, 0))
	var bench := _bench(w, PID)
	a.carried = {"wood": 2, "scrap_metal": 1}
	b.carried = {"wood": 2, "scrap_metal": 1}
	var ra := Build.request_object(w, PID, bench, "craft", "hatchet")
	var rb := Build.request_object(w, PID2, bench, "craft", "hatchet")
	check(ra["ok"], "craft starts: " + str(ra["reason"]))
	eq(rb["reason"], "ACTION_BUSY", "one job per bench")
	eq(Items.total(a.carried), 0, "inputs spent")
	eq(Items.total(b.carried), 3, "refused crafter keeps everything")
	var o: Dictionary = w.region("homestead").objects[bench]
	var ticks := int(o["job"]["ticks"])
	_step(w, ticks - 1)
	check(o.has("job"), "not done early")
	_step(w, 1)
	check(not o.has("job") and o.has("output"), "done on time")
	check(Build.request_object(w, PID2, bench, "collect", "")["ok"], "anyone can collect")
	eq(b.gear.size(), 1, "one hatchet")
	eq(str(b.gear[0]["item"]), "hatchet", "it is a hatchet")
	eq(b.weapon, "hatchet", "auto-equipped into an empty hand")
	eq(Build.request_object(w, PID, bench, "collect", "")["reason"], "ACTION_NOTHING_THERE", "collected once")


func test_recipe_unlock_and_missing_materials() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var bench := _bench(w, PID)
	a.carried = {"wood": 2, "scrap_metal": 3}
	eq(Build.request_object(w, PID, bench, "craft", "felling_axe")["reason"], "ACTION_RECIPE_LOCKED", "needs the manual")
	var manual := Inv.new_gear(w, "workshop_manual")
	a.gear.append(manual)
	check(Inv.request(w, PID, "use", manual["uid"])["ok"], "read the manual")
	check(Craft.unlocked(w, "felling_axe"), "unlocked for the world")
	eq(a.gear.size(), 0, "manual is used up")
	a.carried = {"wood": 1}
	eq(Build.request_object(w, PID, bench, "craft", "felling_axe")["reason"], "ACTION_NEED_MATERIALS", "materials checked")
	eq(a.carrying("wood"), 1, "nothing spent on refusal")


func test_crafting_job_survives_save_and_finishes_once() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var bench := _bench(w, PID)
	a.carried = {"cloth": 2}
	check(Build.request_object(w, PID, bench, "craft", "bandage")["ok"], "craft bandages")
	_step(w, 5)
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	var o2: Dictionary = w2.region("homestead").objects[bench]
	check(o2.has("job"), "job restored")
	_step(w2, 100)
	eq(Items.amount(o2["output"]["items"], "bandage"), 2, "two bandages, once")
	_step(w2, 100)
	eq(Items.amount(o2["output"]["items"], "bandage"), 2, "never twice")


func test_equipment_changes_gameplay() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", Vector2(200, 730))
	var tree := "homestead.tree_03"
	var tp := Content.entity_position(Content.entity_def("homestead", tree))
	a.position = tp + Vector2(0, 40)
	var chops_bare := 0
	while not bool(w.region("homestead").entity_state(tree).get("felled", false)) and chops_bare < 20:
		w.tick += 10
		WorldActions.request_interact(w, PID, tree, 0)
		chops_bare += 1
	var w2 := _world()
	var b := _player(w2, PID, "homestead", tp + Vector2(0, 40))
	var axe := Inv.new_gear(w2, "felling_axe")
	b.gear.append(axe)
	b.equipped["hand"] = axe["uid"]
	var chops_axe := 0
	while not bool(w2.region("homestead").entity_state(tree).get("felled", false)) and chops_axe < 20:
		w2.tick += 10
		WorldActions.request_interact(w2, PID, tree, 0)
		chops_axe += 1
	check(chops_axe < chops_bare, "felling axe fells faster (%d vs %d chops)" % [chops_axe, chops_bare])
	check(b.carrying("wood") > a.carrying("wood"), "and yields more timber")
	check(float(axe["cond"]) < 220.0, "tool wears a little with use")
	# Armour: a padded jacket takes a share off zombie hits and wears.
	var w3 := _world()
	var c := _player(w3, PID, "homestead", YARD)
	var jacket := Inv.new_gear(w3, "padded_jacket")
	c.gear.append(jacket)
	c.equipped["body"] = jacket["uid"]
	ZombieSim.damage_player(w3, c, 20.0, "z1")
	eq(c.health, 87.0, "35% less damage")
	check(float(jacket["cond"]) < 150.0, "jacket wears")
	jacket["cond"] = 0.0
	ZombieSim.damage_player(w3, c, 20.0, "z1")
	eq(c.health, 67.0, "a worn-out jacket no longer protects")


func test_gear_repair_at_bench() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	var bench := _bench(w, PID)
	var club := Inv.new_gear(w, "club")
	club["cond"] = 0.0
	a.gear.append(club)
	a.equipped["hand"] = club["uid"]
	eq(a.weapon, "", "a broken club is bare hands")
	eq(Build.request_object(w, PID, bench, "repair_gear", club["uid"])["reason"], "ACTION_NEED_MATERIALS", "repair costs wood")
	a.carried = {"wood": 1}
	check(Build.request_object(w, PID, bench, "repair_gear", club["uid"])["ok"], "repaired")
	eq(a.weapon, "club", "usable again")
	eq(a.carrying("wood"), 0, "wood spent")


func test_hunger_decays_food_restores_starvation_is_mild() -> void:
	var w := _world()
	var a := _player(w, PID, "homestead", YARD)
	a.hunger = 50.0
	var loss := float(InfraSim.c("hunger_loss_per_minute", 1.4))
	Simulation.advance(w, 60 * Simulation.TICK_RATE)
	check(absf(a.hunger - (50.0 - loss)) < 0.05, "loses the configured amount per minute")
	check(not InfraSim.is_hungry(a), "not hungry yet")
	a.hunger = 0.0
	a.hydration = 100.0
	a.health = 100.0
	Simulation.advance(w, 60 * 60 * Simulation.TICK_RATE)
	check(a.health >= float(InfraSim.c("starving_health_floor", 20)) - 0.01, "starvation never kills by itself")
	check(a.health < 100.0, "but it costs health")
	check(InfraSim.is_hungry(a), "hungry flag")
	a.carried = {"potato": 1}
	check(Inv.request(w, PID, "use", "potato")["ok"], "eat a potato")
	eq(a.hunger, 20.0, "+20 food")
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	eq((res["world"].players[PID] as PlayerState).hunger, 20.0, "hunger persists")


func test_planter_needs_water_and_power_and_never_makes_free_food() -> void:
	var w := WorldState.create_new("w_farm", 12)
	w.threat.enabled = false
	var site := Content.entity_position(Content.entity_def(INTERIOR, SITE))
	var a := _player(w, PID, INTERIOR, site + Vector2(0, 40))
	WorldActions.request_interact(w, PID, SITE, 0)
	Simulation.advance(w, 2000)
	a.region_id = LEVEL
	var reg := w.region(LEVEL)
	var cell := Vector2i(20, 12)
	a.position = Terrain.cell_center(reg, cell) + Vector2(0, 70)
	w.bunker(SITE).resources = {"wood": 4, "grow_light": 1}
	var r := Build.request_build(w, PID, "planter", Terrain.cell_center(reg, cell))
	check(r["ok"], "planter built from storage: " + str(r["reason"]))
	var oid := str(r["objects"][0][1])
	Simulation.advance(w, 100)
	var o: Dictionary = reg.objects[oid]
	Simulation.advance(w, 3000)
	eq(str(o.get("crop", "")), "", "no water: nothing grows")
	eq(Build.request_object(w, PID, oid, "water", "")["reason"], "ACTION_NEED_MATERIALS", "needs clean water")
	a.carried = {"water_clean": 1}
	check(Build.request_object(w, PID, oid, "water", "")["ok"], "water it")
	Simulation.advance(w, 1)
	eq(str(o["crop"]), "growing", "a crop starts and uses the water")
	Simulation.advance(w, int(FarmSim.c("grow_seconds", 150)) * Simulation.TICK_RATE * 2)
	eq(str(o["crop"]), "growing", "without power it waits")
	reg.set_fields("generator", {"fuel": 4.0, "running": true})
	Simulation.advance(w, int(FarmSim.c("grow_seconds", 150)) * Simulation.TICK_RATE)
	eq(str(o["crop"]), "ripe", "with power it ripens")
	check(Build.request_object(w, PID, oid, "harvest", "")["ok"], "harvest")
	eq(a.carrying("potato"), int(FarmSim.c("yield", 3)), "potatoes")
	Simulation.advance(w, 5000)
	eq(str(o.get("crop", "")), "", "no water, no next crop")


func test_new_scavenging_supplies() -> void:
	var w := _world()
	var a := _player(w, PID, INTERIOR, Content.entity_position(Content.entity_def("homestead.farmhouse", "homestead.farmhouse.pantry")))
	var r := WorldActions.request_interact(w, PID, "homestead.farmhouse.pantry", 0)
	check(r["ok"], "pantry searched: " + str(r["reason"]))
	check(a.carrying("canned_food") >= 1, "found food")
	a.position = Content.entity_position(Content.entity_def("homestead.farmhouse", "homestead.farmhouse.linen"))
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse.linen", 0)["ok"], "linen chest searched")
	check(a.carrying("cloth") >= 2, "found cloth")
