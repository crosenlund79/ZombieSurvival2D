extends TestCase
## Iteration 003 milestone C: items and shared storage, scavenging, generator
## and fuel, logical power, water purification, hydration, persistence.

const SITE := "homestead.farmhouse.shelter"
const INTERIOR := "homestead.farmhouse"
const LEVEL := "bunker:homestead.farmhouse.shelter:-1"
const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _pos(def_id: String, eid: String) -> Vector2:
	return Content.entity_position(Content.entity_def(def_id, eid))


## World with a finished shelter; both players stand in level -1.
func _bunker_world() -> WorldState:
	var w := WorldState.create_new("w_infra", 3)
	w.threat.enabled = false
	var site := _pos(INTERIOR, SITE)
	_player(w, PID, INTERIOR, site + Vector2(0, 40))
	check(WorldActions.request_interact(w, PID, SITE, 0)["ok"], "construction starts")
	Simulation.advance(w, 2000)
	check(w.region(LEVEL) != null, "level -1 exists")
	(w.players[PID] as PlayerState).region_id = LEVEL
	_player(w, PID2, LEVEL, Vector2.ZERO)
	return w


func _at(w: WorldState, pid: String, eid: String) -> PlayerState:
	var p: PlayerState = w.players[pid]
	p.position = _pos(w.region(LEVEL).def_id, eid) + Vector2(0, 30)
	return p


func _act(w: WorldState, pid: String, eid: String, action: String, arg: String = "") -> Dictionary:
	return WorldActions.request_entity_action(w, pid, eid, action, arg)


func test_items_move_never_duplicates() -> void:
	var a := {"fuel": 3}
	var b := {}
	eq(Items.move(a, b, "fuel", 5), 3, "moves only what exists")
	eq(Items.total(a) + Items.total(b), 3, "total conserved")
	eq(Items.move(b, a, "fuel", 2, 1), 1, "destination limit respected")
	check(not a.has("water_clean") and Items.move(a, b, "water_clean", 1) == 0, "cannot move what is missing")
	check(Items.exists("water_dirty") and Items.exists("wood"), "catalogue has the core items")


func test_storage_deposit_withdraw_and_timber_share_one_store() -> void:
	var w := _bunker_world()
	var a := _at(w, PID, "storage")
	var b := _at(w, PID2, "storage")
	a.carried = {"fuel": 2, "wood": 3}
	check(_act(w, PID, "storage", "store", "fuel")["ok"], "deposit fuel")
	check(_act(w, PID, "storage", "store", "wood")["ok"], "deposit wood")
	var store := w.bunker(SITE).resources
	eq(Items.amount(store, "fuel"), 2, "fuel stored")
	eq(Items.amount(store, "wood"), 3, "wood joins the timber stockpile (same store)")
	eq(Items.total(a.carried), 0, "player emptied")
	# Two players race for the last units: never more than exist.
	check(_act(w, PID, "storage", "take", "fuel")["ok"], "A takes one")
	check(_act(w, PID2, "storage", "take", "fuel")["ok"], "B takes one")
	var r := _act(w, PID, "storage", "take", "fuel")
	eq(r["reason"], "ACTION_NOTHING_THERE", "third take refused")
	eq(a.carrying("fuel") + b.carrying("fuel") + Items.amount(store, "fuel"), 2, "no duplication")
	eq(_act(w, PID, "storage", "store", "fuel")["ok"], true, "deposit back")
	a.position = Vector2(-600, -300)
	eq(_act(w, PID, "storage", "take", "fuel")["reason"], "ACTION_TOO_FAR", "range checked by host")


func test_scavenge_once_then_restock() -> void:
	var w := WorldState.create_new("w_loot", 3)
	w.threat.enabled = false
	var eid := "homestead.rain_barrel"
	var a := _player(w, PID, "homestead", _pos("homestead", eid) + Vector2(0, 30))
	var b := _player(w, PID2, "homestead", _pos("homestead", eid) + Vector2(10, 30))
	check(WorldActions.request_interact(w, PID, eid, 0)["ok"], "first search succeeds")
	eq(a.carrying("water_dirty"), 2, "found dirty water")
	eq(WorldActions.request_interact(w, PID2, eid, 0)["reason"], "ACTION_LOOT_EMPTY", "second player finds it empty")
	eq(b.carrying("water_dirty"), 0, "no duplicate loot")
	var mins := float(Content.entity_def("homestead", eid)["restock_minutes"])
	Simulation.advance(w, int(mins * 60.0 * Simulation.TICK_RATE) - 1)
	eq(WorldActions.request_interact(w, PID2, eid, 0)["reason"], "ACTION_LOOT_EMPTY", "not restocked early")
	Simulation.advance(w, 1)
	check(WorldActions.request_interact(w, PID2, eid, 0)["ok"], "restocked over sim time (no soft-lock)")
	a.carried = {"wood": Items.carry_slots()}
	var car := "homestead.car_trunk"
	a.position = _pos("homestead", car) + Vector2(0, 30)
	eq(WorldActions.request_interact(w, PID, car, 0)["reason"], "ACTION_NEED_SLOTS", "full bag keeps the loot in place")
	check(WorldActions.loot_ready(w, w.region("homestead"), car), "still available after refusal")


func test_generator_fuel_consumption_and_power() -> void:
	var w := _bunker_world()
	var a := _at(w, PID, "generator")
	eq(_act(w, PID, "generator", "toggle")["reason"], "ACTION_NEED_FUEL", "cannot start dry")
	check(not InfraSim.is_powered(w, LEVEL), "unpowered at start")
	a.carried = {"fuel": 1}
	w.bunker(SITE).resources["fuel"] = 1
	check(_act(w, PID, "generator", "fuel")["ok"], "fuel from hands")
	check(_act(w, PID, "generator", "fuel")["ok"], "fuel from storage when hands are empty")
	eq(_act(w, PID, "generator", "fuel")["reason"], "ACTION_NEED_FUEL", "no fuel left anywhere")
	var gen := w.region(LEVEL)
	eq(float(gen.entity_state("generator")["fuel"]), 2.0, "two units in the tank")
	check(_act(w, PID, "generator", "toggle")["ok"], "start")
	check(InfraSim.is_powered(w, LEVEL), "powered while running")
	var per := int(InfraSim.c("generator_seconds_per_fuel", 180)) * Simulation.TICK_RATE
	Simulation.advance(w, per)
	check(absf(float(gen.entity_state("generator")["fuel"]) - 1.0) < 0.01, "one unit burned per configured time")
	Simulation.advance(w, per + 50)
	eq(bool(gen.entity_state("generator")["running"]), false, "stops itself when empty")
	check(not InfraSim.is_powered(w, LEVEL), "power off when empty")
	w.bunker(SITE).resources["fuel"] = 9
	for i in 4:
		_act(w, PID, "generator", "fuel")
	eq(_act(w, PID, "generator", "fuel")["reason"], "ACTION_TANK_FULL", "tank capacity respected")
	eq(Items.amount(w.bunker(SITE).resources, "fuel"), 5, "refused fuel is not consumed")


func test_purifier_needs_power_and_time() -> void:
	var w := _bunker_world()
	var a := _at(w, PID, "purifier")
	a.carried = {"water_dirty": 2}
	w.bunker(SITE).resources["water_dirty"] = 1
	check(_act(w, PID, "purifier", "fill")["ok"], "fill")
	var reg := w.region(LEVEL)
	eq(int(reg.entity_state("purifier")["input"]), 3, "hands then storage poured in")
	var per := int(InfraSim.c("purifier_seconds_per_unit", 20)) * Simulation.TICK_RATE
	Simulation.advance(w, per * 3)
	eq(int(reg.entity_state("purifier")["output"]), 0, "nothing purified without power")
	reg.set_fields("generator", {"fuel": 4.0, "running": true})
	Simulation.advance(w, per - 1)
	eq(int(reg.entity_state("purifier")["output"]), 0, "not done early")
	Simulation.advance(w, 1)
	eq(int(reg.entity_state("purifier")["output"]), 1, "one clean unit per configured time")
	Simulation.advance(w, per * 2)
	eq(int(reg.entity_state("purifier")["output"]), 3, "all converted")
	eq(int(reg.entity_state("purifier")["input"]), 0, "input consumed 1:1")
	check(_act(w, PID, "purifier", "collect")["ok"], "collect")
	eq(a.carrying("water_clean"), 3, "clean water carried")
	eq(_act(w, PID, "purifier", "collect")["reason"], "ACTION_NOTHING_THERE", "collect once only")


func test_hydration_decays_and_drinking_restores() -> void:
	var w := _bunker_world()
	var a: PlayerState = w.players[PID]
	a.hydration = 50.0
	var loss := float(InfraSim.c("hydration_loss_per_minute", 2.5))
	Simulation.advance(w, 60 * Simulation.TICK_RATE)
	check(absf(a.hydration - (50.0 - loss)) < 0.05, "loses configured amount per minute")
	eq(WorldActions.request_drink(w, PID)["reason"], "ACTION_NO_CLEAN_WATER", "needs clean water")
	a.carried = {"water_clean": 1, "water_dirty": 1}
	var before := a.hydration
	check(WorldActions.request_drink(w, PID)["ok"], "drink")
	check(a.hydration > before + 30.0, "hydration restored")
	eq(a.carrying("water_clean"), 0, "water consumed")
	eq(a.carrying("water_dirty"), 1, "dirty water is not drinkable")
	a.hydration = 0.0
	a.health = 100.0
	Simulation.advance(w, 60 * 60 * Simulation.TICK_RATE)
	check(a.health >= float(InfraSim.c("dehydrated_health_floor", 25)) - 0.01, "dehydration is mild (health floor)")
	check(a.health < 100.0, "dehydration does cost health")
	check(InfraSim.is_thirsty(a), "thirsty flag")


func test_infrastructure_survives_save_roundtrip() -> void:
	var w := _bunker_world()
	var reg := w.region(LEVEL)
	reg.set_fields("generator", {"fuel": 2.5, "running": true})
	reg.set_fields("purifier", {"input": 2, "output": 1, "progress": 0.4})
	w.bunker(SITE).resources["water_dirty"] = 3
	var a: PlayerState = w.players[PID]
	a.carried = {"fuel": 1, "water_clean": 2}
	a.hydration = 61.0
	w.region("homestead").set_fields("homestead.car_trunk", {"looted_at": w.tick})
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes: " + str(res.get("error")))
	var w2: WorldState = res["world"]
	var reg2 := w2.region(LEVEL)
	eq(float(reg2.entity_state("generator")["fuel"]), 2.5, "fuel restored")
	eq(bool(reg2.entity_state("generator")["running"]), true, "running restored")
	eq(int(reg2.entity_state("purifier")["output"]), 1, "purifier output restored")
	eq(int(reg2.entity_state("purifier")["input"]), 2, "purifier input restored")
	eq(Items.amount(w2.bunker(SITE).resources, "water_dirty"), 3, "storage restored")
	var a2: PlayerState = w2.players[PID]
	eq(a2.carrying("water_clean"), 2, "inventory restored")
	check(absf(a2.hydration - 61.0) < 0.2, "hydration restored")
	check(not WorldActions.loot_ready(w2, w2.region("homestead"), "homestead.car_trunk"), "looted state restored")
	check(InfraSim.is_powered(w2, LEVEL), "power derived after load")
