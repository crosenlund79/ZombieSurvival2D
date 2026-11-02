extends TestCase
## Iteration 009: the survivor — encounter, recruitment conditions, travel,
## life in the bunker, water and farm jobs using only real resources, clear
## status when blocked, daily upkeep, sheltering during a horde, work while
## nobody watches, persistence without double-processing.

const SITE := "homestead.farmhouse.shelter"
const INTERIOR := "homestead.farmhouse"
const LEVEL := "bunker:homestead.farmhouse.shelter:-1"
const PID := "aaaaaaaaaaaaaaaa"


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _world(with_shelter: bool) -> WorldState:
	var w := WorldState.create_new("w_npc", 31)
	w.threat.enabled = false
	NpcSim.ensure(w)
	if with_shelter:
		var site := Content.entity_position(Content.entity_def(INTERIOR, SITE))
		_player(w, "builder000000000", INTERIOR, site + Vector2(0, 40))
		WorldActions.request_interact(w, "builder000000000", SITE, 0)
		Simulation.advance(w, 2000)
		w.players.erase("builder000000000")
	return w


func _home(w: WorldState) -> NpcState:
	check(NpcSim.dev_recruit(w, "mara")["ok"], "recruited")
	return w.npcs["mara"]


func _step(w: WorldState, ticks: int) -> void:
	for i in ticks:
		Simulation.advance(w, 1)


func test_encounter_and_recruitment() -> void:
	var w := _world(false)
	var n: NpcState = w.npcs["mara"]
	eq(n.region_id, "service_station", "waits at the service station")
	eq(n.recruit, "waiting", "not met yet")
	var a := _player(w, PID, "service_station", n.position + Vector2(0, 50))
	check(NpcSim.request(w, PID, "mara", "talk", "")["ok"], "talk")
	eq(n.recruit, "met", "met")
	eq(NpcSim.request(w, PID, "mara", "talk", "")["reason"], "NPC_NEEDS_SHELTER", "needs a shelter first")
	w = _world(true)
	n = w.npcs["mara"]
	n.recruit = "met"
	a = _player(w, PID, "service_station", n.position + Vector2(0, 50))
	a.carried = {"canned_food": 1}
	eq(NpcSim.request(w, PID, "mara", "talk", "")["reason"], "NPC_STILL_NEEDS", "still needs clean water")
	eq(a.carrying("canned_food"), 1, "nothing taken on refusal")
	a.carried["water_clean"] = 1
	check(NpcSim.request(w, PID, "mara", "talk", "")["ok"], "recruited")
	eq(Items.total(a.carried), 0, "gift handed over once")
	eq(n.recruit, "travelling", "on the way")
	_step(w, int(NpcSim.c("travel_seconds", 60)) * Simulation.TICK_RATE - 5)
	eq(n.recruit, "travelling", "still travelling")
	_step(w, 10)
	eq(n.recruit, "home", "arrived")
	eq(n.region_id, LEVEL, "in the bunker")
	eq(NpcSim.request(w, PID, "mara", "talk", "")["reason"], "ACTION_TOO_FAR", "she is no longer at the station")


func test_water_job_uses_real_resources_and_power() -> void:
	var w := _world(true)
	var n := _home(w)
	var b := w.bunker(SITE)
	var reg := w.region(LEVEL)
	n.job = "water"
	_step(w, 300)
	eq(n.status, "NPC_STATUS_NO_DIRTY_WATER", "nothing to purify: says so")
	eq(int(reg.entity_state("purifier").get("input", 0)), 0, "no water appears from nowhere")
	b.resources["water_dirty"] = 3
	_step(w, 400)
	eq(int(reg.entity_state("purifier").get("input", 0)), 3, "fills the purifier from storage")
	eq(b.amount("water_dirty"), 0, "storage paid")
	_step(w, 300)
	eq(n.status, "NPC_STATUS_NO_POWER", "no power: says so")
	eq(b.amount("water_clean"), 0, "no clean water without power")
	reg.set_fields("generator", {"fuel": 4.0, "running": true})
	_step(w, int(InfraSim.c("purifier_seconds_per_unit", 20)) * 3 * Simulation.TICK_RATE + 300)
	eq(b.amount("water_clean"), 3, "collects exactly what was purified into storage")


func test_farm_job_waters_and_harvests() -> void:
	var w := _world(true)
	var n := _home(w)
	var b := w.bunker(SITE)
	var reg := w.region(LEVEL)
	n.job = "farm"
	_step(w, 50)
	eq(n.status, "NPC_STATUS_NO_PLANTER", "needs a planter")
	var a := _player(w, PID, LEVEL, Terrain.cell_center(reg, Vector2i(20, 12)) + Vector2(0, 70))
	b.resources = {"wood": 4, "grow_light": 1, "water_clean": 1}
	var r := Build.request_build(w, PID, "planter", Terrain.cell_center(reg, Vector2i(20, 12)))
	check(r["ok"], "planter")
	var oid := str(r["objects"][0][1])
	w.players.erase(PID)
	reg.set_fields("generator", {"fuel": 4.0, "running": true})
	_step(w, 500)
	var o: Dictionary = reg.objects[oid]
	eq(b.amount("water_clean"), 0, "waters the planter from storage")
	check(str(o.get("crop", "")) in ["growing", "ripe"], "crop started")
	_step(w, int(FarmSim.c("grow_seconds", 150)) * Simulation.TICK_RATE + 400)
	eq(b.amount("potato"), int(FarmSim.c("yield", 3)), "harvested into shared storage")
	_step(w, 600)
	eq(n.status, "NPC_STATUS_NO_CLEAN_WATER", "out of water: says so")
	eq(b.amount("potato"), int(FarmSim.c("yield", 3)), "no food without inputs")


func test_upkeep_and_unfed() -> void:
	var w := _world(true)
	var n := _home(w)
	var b := w.bunker(SITE)
	b.resources = {"potato": 1, "water_clean": 1}
	var day := int(float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	Simulation.advance(w, day + 5)
	eq(b.amount("potato") + b.amount("water_clean"), 0, "a day costs 1 food + 1 water")
	check(n.fed, "fed")
	Simulation.advance(w, day + 5)
	check(not n.fed, "unfed when storage runs out")


func test_shelters_during_horde_and_resumes() -> void:
	var w := _world(true)
	var n := _home(w)
	n.job = "water"
	w.threat.enabled = true
	w.meta["siege"] = {"phase": "active", "id": 1, "ends": w.tick + 100000, "remaining": 1}
	EventSim.spawn_horde(w, 1)
	_step(w, 20)
	eq(n.activity, "sheltering", "shelters while the horde is outside")
	w.meta["siege"] = {"phase": "idle", "id": 1}
	_step(w, 20)
	check(n.activity != "sheltering", "back to work afterwards")


func test_persistence_and_no_double_processing() -> void:
	var w := _world(true)
	var n := _home(w)
	n.job = "water"
	var b := w.bunker(SITE)
	b.resources["water_dirty"] = 4
	_step(w, 50)
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	var n2: NpcState = w2.npcs["mara"]
	eq(n2.recruit, "home", "still lives here")
	eq(n2.job, "water", "job kept")
	eq(n2.region_id, LEVEL, "location kept")
	var total := func(ww: WorldState) -> int:
		var r := ww.region(LEVEL)
		return ww.bunker(SITE).amount("water_dirty") + int(r.entity_state("purifier").get("input", 0)) \
			+ int(r.entity_state("purifier").get("output", 0)) + ww.bunker(SITE).amount("water_clean")
	_step(w2, 600)
	eq(total.call(w2), 4, "water is conserved: moved, never duplicated")
	NpcSim.ensure(w2)
	eq(w2.npcs.size(), 1, "no second copy of the survivor after loading")
