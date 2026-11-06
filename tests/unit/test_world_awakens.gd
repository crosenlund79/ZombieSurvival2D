extends TestCase
## Iteration 011 "The World Awakens": Burnt One hearing, screeches, alert
## limits and posture; later milestones add their own tests below.

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


func _z(w: WorldState, pos: Vector2, facing := Vector2.LEFT) -> ZombieState:
	var z := ZombieSim.spawn(w, "homestead", pos, false)
	z.facing = facing
	return z


func _run(w: WorldState, seconds: float) -> Array:
	var out: Array = []
	for i in int(seconds * Simulation.TICK_RATE):
		w.tick += 1
		out.append_array(ZombieSim.step(w, 1))
	return out


func _screeches(results: Array) -> Array:
	var s: Array = []
	for r in results:
		for ev in r.get("events", []):
			if str(ev.get("kind", "")) == "screech":
				s.append(ev)
	return s


func test_loud_noise_listen_then_screech_then_investigate() -> void:
	var w := WorldState.create_new("w_scr", 41)
	_player(w, PID, "homestead", Vector2(1150, 1300))
	var z := _z(w, Vector2(400, 1250))
	ZombieSim.make_noise(w, "homestead", Vector2(650, 1250), "fell")
	var r := _run(w, 0.2)
	eq(z.state_name(), "LISTEN", "it stops and listens")
	check(z.facing.dot((Vector2(650, 1250) - z.position).normalized()) > 0.0, "it turns toward the sound")
	r.append_array(_run(w, 2.0))
	eq(_screeches(r).size(), 1, "a significant disturbance makes it screech once")
	eq(z.state_name(), "INVESTIGATE", "then it goes to look")
	eq(z.target_player, "", "hearing never reveals the player")


func test_small_noise_no_screech() -> void:
	var w := WorldState.create_new("w_scr2", 42)
	_player(w, PID, "homestead", Vector2(1150, 1300))
	var z := _z(w, Vector2(400, 1250))
	ZombieSim.make_noise(w, "homestead", Vector2(500, 1250), "run")
	var r := _run(w, 3.0)
	eq(_screeches(r).size(), 0, "a tiny noise does not trigger a screech")
	check(z.state_name() in ["INVESTIGATE", "WANDER"], "at most it wanders over to look")


func test_screech_draws_few_and_never_chains() -> void:
	var w := WorldState.create_new("w_scr3", 43)
	_player(w, PID, "homestead", Vector2(2300, 1650))
	var caller := _z(w, Vector2(1000, 1000))
	var others: Array = []
	for i in 6:
		others.append(_z(w, Vector2(1000 + 70 * (i + 1), 1050)))
	var ev := ZombieSim.screech(w, caller)
	check(not ev.is_empty(), "the screech happens")
	var r := _run(w, 0.3)
	var drawn := others.filter(func(o): return o.state_name() == "INVESTIGATE")
	eq(drawn.size(), 3, "only the nearest three respond (response limit)")
	r.append_array(_run(w, 6.0))
	eq(_screeches(r).size(), 0, "responders never screech back (no chains)")
	check(ZombieSim.screech(w, caller).is_empty(), "the caller is on cooldown")
	var other: ZombieState = others[5]
	check(ZombieSim.screech(w, other).is_empty(), "a region-wide cooldown keeps silence the norm")


func test_postures_and_individual_temperament() -> void:
	var w := WorldState.create_new("w_post", 44)
	var p := _player(w, PID, "homestead", Vector2(1150, 1300))
	var seen := {}
	var bursts := 0
	var zs: Array = []
	for i in 6:
		var z := _z(w, Vector2(900 + i * 40, 1300), Vector2.RIGHT)
		z.ai = ZombieState.AI.CHASE
		z.target_player = PID
		zs.append(z)
	for t in 400:
		w.tick += 1
		ZombieSim.step(w, 1)
		p.position = Vector2(1150 + 600 * sin(t * 0.02), 1300)
		for z in zs:
			seen[z.posture] = true
			if z.burst > 0.0:
				bursts += 1
	check(seen.has(ZombieState.Posture.UPRIGHT), "they run upright")
	check(seen.has(ZombieState.Posture.CRAWL), "and drop to all fours")
	check(bursts > 0, "crawling bursts happen during pursuit")
	var temps := {}
	for z in zs:
		temps[snappedf(z.temperament().x, 0.01)] = true
	check(temps.size() >= 3, "individuals differ in pace (temperament)")


func test_lost_target_searches_ahead_then_around() -> void:
	var w := WorldState.create_new("w_search", 45)
	_player(w, PID, "homestead.farmhouse", Vector2(300, 480))
	var z := _z(w, Vector2(1000, 1100))
	z.ai = ZombieState.AI.CHASE
	z.target_player = PID
	z.last_known = Vector2(1150, 1000)
	z.last_dir = Vector2.RIGHT
	_run(w, 0.2)
	eq(z.state_name(), "INVESTIGATE", "target inside the cabin: it never follows, it searches")
	check(z.region_id == "homestead", "it stays outside")


# ---------------------------------------------------------------- milestone B

func _hour(w: WorldState, h: float) -> void:
	var day := float(EnvSim.c("day_seconds", 1440))
	w.tick = int(fmod(h - float(EnvSim.c("start_hour", 8.0)) + 24.0, 24.0) / 24.0 * day * Simulation.TICK_RATE)


func test_weather_kinds_are_seeded_varied_and_calm_between() -> void:
	var a := WorldState.create_new("w_wx", 77)
	var b := WorldState.create_new("w_wx", 77)
	var kinds := {}
	var prev := "clear"
	var alternates := true
	for i in 60:
		a.tick = int(a.env.get("until", 0)) + 1
		b.tick = int(b.env.get("until", 0)) + 1
		EnvSim.step(a, 1)
		EnvSim.step(b, 1)
		if i < 3:
			eq(EnvSim.weather(a), EnvSim.weather(b), "same seed, same weather (%d)" % i)
		var k := EnvSim.weather(a)
		kinds[k] = true
		if k != "clear" and prev != "clear":
			alternates = false
		prev = k
	check(alternates, "calm spells separate the weather events")
	for k in ["snow", "fog", "heavy_rain", "blizzard", "thunderstorm"]:
		check(kinds.has(k), "%s occurs" % k)


func test_cold_by_region_weather_and_night() -> void:
	var w := WorldState.create_new("w_cold", 78)
	_hour(w, 12.0)
	EnvSim.set_weather(w, "clear")
	var day := EnvSim.cold(w, "homestead")
	check(day > 0.0, "the surface is cold")
	eq(EnvSim.cold(w, "homestead.farmhouse"), 0.0, "the cabin is sheltered")
	check(EnvSim.cold(w, "service_station") > day, "the open settlement road is more exposed than the woods")
	_hour(w, 23.0)
	check(EnvSim.cold(w, "homestead") > day, "nights are colder")
	EnvSim.set_weather(w, "blizzard")
	check(EnvSim.cold(w, "homestead") > day + 0.8, "a blizzard is dangerous")
	check(EnvSim.sight_scale(w, "homestead") < 0.5, "and blinding")


func test_exposure_falls_outside_insulation_helps_shelter_recovers() -> void:
	var w := WorldState.create_new("w_exp", 79)
	_hour(w, 12.0)
	EnvSim.set_weather(w, "clear")
	var bare := _player(w, PID, "homestead", Vector2(400, 1130))
	var coat := _player(w, PID2, "homestead", Vector2(440, 1130))
	coat.gear.append({"uid": "g1", "item": "winter_coat", "cond": 200.0})
	coat.equipped["body"] = "g1"
	SurvivalSim.step(w, 60 * Simulation.TICK_RATE)
	check(bare.warmth < 96.0, "warmth falls outdoors")
	check(coat.warmth > bare.warmth, "a winter coat keeps the cold out")
	EnvSim.set_weather(w, "blizzard")
	var before := bare.warmth
	SurvivalSim.step(w, 60 * Simulation.TICK_RATE)
	check(before - bare.warmth > 8.0, "a blizzard minute bites hard")
	bare.warmth = 10.0
	bare.region_id = "homestead.farmhouse"
	SurvivalSim.step(w, 60 * Simulation.TICK_RATE)
	check(bare.warmth > 18.0, "the cabin warms you back up")
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(absf((res["world"] as WorldState).players[PID].warmth - bare.warmth) < 0.2, "warmth is saved")


func test_freezing_hurts_mildly_to_a_floor() -> void:
	var w := WorldState.create_new("w_frz", 80)
	EnvSim.set_weather(w, "blizzard")
	_hour(w, 2.0)
	var p := _player(w, PID, "homestead", Vector2(400, 1130))
	p.warmth = 2.0
	SurvivalSim.step(w, 600 * Simulation.TICK_RATE)
	check(p.health < 100.0, "freezing costs health")
	check(p.health >= float(SurvivalSim.ec("health_floor", 25)) - 0.01, "but only down to a floor")


func test_lightning_is_deterministic_and_only_in_storms() -> void:
	var w := WorldState.create_new("w_lit", 81)
	EnvSim.set_weather(w, "thunderstorm")
	var n := 0
	for s in 50:
		var b := EnvSim.lightning(w, s)
		if not b.is_empty():
			n += 1
			check(float(b["thunder_delay"]) > 0.3, "thunder follows the flash")
	check(n > 5 and n < 40, "strikes are occasional (%d / 50)" % n)
	EnvSim.set_weather(w, "fog")
	eq(EnvSim.lightning(w, 3), {}, "no lightning outside a thunderstorm")


func _bed(w: WorldState, pid: String) -> Dictionary:
	return WorldActions.request_interact(w, pid, "homestead.farmhouse.bed", 0)


func test_sleep_alone_needs_evening_and_advances_the_world() -> void:
	var w := WorldState.create_new("w_sleep", 82)
	var p := _player(w, PID, "homestead.farmhouse", Vector2(640, 380))
	_hour(w, 12.0)
	var r := _bed(w, PID)
	eq(str(r["notice"].get("key", "")), "SLEEP_NOT_TIRED", "not in the middle of the day")
	_hour(w, 22.0)
	r = _bed(w, PID)
	check(int(r.get("sleep_ticks", 0)) > 0, "alone: sleeps at once")
	var hunger0 := p.hunger
	p.warmth = 40.0
	p.health = 50.0
	var left := int(r["sleep_ticks"])
	while left > 0:
		var n := mini(500, left)
		Simulation.advance(w, n)
		left -= n
	SleepSim.wake(w, "home")
	check(absf(EnvSim.hour(w) - 7.0) < 0.1, "wakes at 07:00")
	check(p.hunger < hunger0, "needs advanced while asleep")
	eq(p.warmth, 100.0, "wakes warm")
	check(p.health > 70.0, "and rested")


func test_sleep_refused_with_monologue_when_someone_is_outside() -> void:
	var w := WorldState.create_new("w_sleep2", 83)
	_player(w, PID, "homestead.farmhouse", Vector2(640, 380))
	var out := _player(w, PID2, "homestead", Vector2(400, 1130))
	out.display_name = "Cleo"
	_hour(w, 22.0)
	var r := _bed(w, PID)
	eq(str(r["notice"]["key"]), "SLEEP_OUT_DARK", "an inner monologue, not an error")
	eq(r["notice"]["args"], ["Cleo"], "it names who is outside")
	w.meta["last_screech"] = {"tick": w.tick - 100, "region": "homestead"}
	r = _bed(w, PID)
	eq(str(r["notice"]["key"]), "SLEEP_OUT_SCREECH", "a real recent screech is remembered")
	eq(int(r.get("sleep_ticks", 0)), 0, "nobody sleeps")


func test_sleep_vote_unanimous_decline_and_leaving() -> void:
	var w := WorldState.create_new("w_vote", 84)
	_player(w, PID, "homestead.farmhouse", Vector2(640, 380))
	var b := _player(w, PID2, "homestead.farmhouse", Vector2(600, 400))
	_hour(w, 22.0)
	var r := _bed(w, PID)
	check(not SleepSim.vote(w).is_empty(), "two players: a vote starts")
	eq(int(r.get("sleep_ticks", 0)), 0, "no sleep yet")
	check(not SleepSim.answer(w, PID, true)["ok"], "no duplicate vote")
	r = SleepSim.answer(w, PID2, false)
	check(SleepSim.vote(w).is_empty(), "one 'not yet' cancels")
	_bed(w, PID)
	b.region_id = "homestead"
	var steps := SleepSim.step(w, 1)
	check(SleepSim.vote(w).is_empty() and steps.size() == 1, "leaving the shelter cancels the vote")
	b.region_id = "homestead.farmhouse"
	_bed(w, PID)
	r = SleepSim.answer(w, PID2, true)
	check(int(r.get("sleep_ticks", 0)) > 0, "unanimous: sleep")
	check(SleepSim.vote(w).is_empty(), "the vote is closed (no second time jump)")


func test_bunker_counts_as_the_cabin_shelter() -> void:
	var w := WorldState.create_new("w_grp", 85)
	eq(SleepSim.shelter_group(w, "homestead.farmhouse"), "home", "the cabin")
	eq(SleepSim.shelter_group(w, "homestead"), "", "the woods are not a shelter")


# ---------------------------------------------------------------- milestone C: vehicles, town, cellar, map

func _wagon_world(seed_value: int) -> WorldState:
	var w := WorldState.create_new("w_car%d" % seed_value, seed_value)
	VehicleSim.ensure(w)
	return w


func _wagon(w: WorldState) -> VehicleState:
	return w.vehicles["wagon"]


func test_vehicle_placed_once_with_key_in_ignition() -> void:
	var w := _wagon_world(61)
	eq(w.vehicles.size(), 1, "the station wagon exists in a new world")
	var v := _wagon(w)
	eq(v.region_id, "service_station", "parked at the service station")
	eq(v.seats.size(), 4, "four seats")
	eq(v.key, "ignition", "the key is in the ignition (no key quest)")
	check(not v.locked and not v.engine_on, "unlocked, engine off")
	eq(VehicleSim.ensure(w), 0, "ensure never duplicates")


func test_enter_exit_seats_and_engine() -> void:
	var w := _wagon_world(62)
	var v := _wagon(w)
	var a := _player(w, PID, "service_station", v.position + Vector2(400, 0))
	var b := _player(w, PID2, "service_station", v.position + Vector2(0, 90))
	eq(VehicleSim.request(w, PID, "wagon", "enter")["reason"], "ACTION_TOO_FAR", "too far to get in")
	a.position = v.position + Vector2(-110, 30)
	check(VehicleSim.request(w, PID, "wagon", "enter")["ok"], "first player gets in")
	eq(v.driver(), PID, "first in takes the wheel")
	eq(a.vehicle_id, "wagon", "player knows they are in it")
	check(VehicleSim.request(w, PID2, "wagon", "enter")["ok"], "second player gets in")
	eq(v.seat_of(PID2), 1, "as passenger")
	eq(VehicleSim.request(w, PID2, "wagon", "enter")["reason"], "VEHICLE_ALREADY_INSIDE", "no double entry")
	eq(VehicleSim.request(w, PID2, "wagon", "engine")["reason"], "VEHICLE_NOT_DRIVER", "only the driver starts it")
	check(VehicleSim.request(w, PID, "wagon", "engine")["ok"] and v.engine_on, "driver starts the engine")
	var r := VehicleSim.request(w, PID2, "wagon", "exit")
	check(r["ok"], "passenger gets out")
	eq(b.vehicle_id, "", "no longer in the car")
	eq(v.seat_of(PID2), -1, "seat freed")
	check(b.position.distance_to(v.position) > 40.0, "stands beside the car, not inside it")
	eq(str(r["transition"].get("player_id", "")), PID2, "the exit position is sent to that player")


func test_driver_poses_validated_and_occupants_follow() -> void:
	var w := _wagon_world(63)
	var v := _wagon(w)
	_player(w, PID, "service_station", v.position)
	var b := _player(w, PID2, "service_station", v.position)
	VehicleSim.request(w, PID, "wagon", "enter")
	VehicleSim.request(w, PID2, "wagon", "enter")
	eq(VehicleSim.submit_pose(w, PID, "wagon", v.position + Vector2(60, 0), 0.0, 100.0, 0.0, 0.1)["reason"], "VEHICLE_POSE_REJECTED", "no driving with the engine off")
	VehicleSim.request(w, PID, "wagon", "engine")
	var start := v.position
	check(VehicleSim.submit_pose(w, PID, "wagon", start + Vector2(30, 0), 0.0, 300.0, 0.0, 0.1)["ok"], "plausible pose accepted")
	eq(b.position, v.position, "passengers ride along")
	var bad := VehicleSim.submit_pose(w, PID, "wagon", start + Vector2(900, 0), 0.0, 300.0, 0.0, 0.1)
	check(not bad["ok"] and bad.get("correct", false), "teleporting is rejected and corrected")
	eq(VehicleSim.submit_pose(w, PID2, "wagon", start, 0.0, 0.0, 0.0, 0.1)["reason"], "VEHICLE_NOT_DRIVER", "passengers cannot steer")


func test_road_exit_moves_car_occupants_and_trunk_together() -> void:
	var w := _wagon_world(64)
	var v := _wagon(w)
	var a := _player(w, PID, "service_station", v.position)
	var b := _player(w, PID2, "service_station", v.position)
	var c := _player(w, "cccccccccccccccc", "service_station", Vector2(1000, 700))
	a.carried["scrap_metal"] = 3
	a.position = v.position + Vector2(0, 100)
	check(VehicleSim.request(w, PID, "wagon", "store", "scrap_metal")["ok"], "trunk takes items from outside")
	a.position = v.position
	VehicleSim.request(w, PID, "wagon", "enter")
	VehicleSim.request(w, PID2, "wagon", "enter")
	eq(VehicleSim.request(w, PID, "wagon", "take", "scrap_metal")["reason"], "VEHICLE_FROM_OUTSIDE", "the trunk is reached from outside")
	VehicleSim.request(w, PID, "wagon", "engine")
	# drive up to the west exit in plausible steps
	v.position = Vector2(140, 710)
	v.rotation = PI
	var r := VehicleSim.submit_pose(w, PID, "wagon", Vector2(120, 710), PI, -300.0, 0.0, 0.1)
	check(r["ok"], "pose into the road exit accepted")
	eq(v.region_id, "homestead", "the car arrives in the next region")
	eq(a.region_id, "homestead", "the driver arrives with it")
	eq(b.region_id, "homestead", "the passenger arrives with it")
	eq(c.region_id, "service_station", "players outside the car are never moved")
	eq((r.get("transitions", []) as Array).size(), 2, "one transition per occupant")
	eq(int(v.cargo["items"].get("scrap_metal", 0)), 3, "the trunk travels with the car")
	eq(v.seats.filter(func(s): return s != "").size(), 2, "nobody lost or duplicated")


func test_vehicle_persists_and_seats_stay_consistent() -> void:
	var w := _wagon_world(65)
	var v := _wagon(w)
	var a := _player(w, PID, "service_station", v.position)
	VehicleSim.request(w, PID, "wagon", "enter")
	VehicleSim.request(w, PID, "wagon", "engine")
	v.cargo["items"]["fuel"] = 2
	v.rotation = 1.25
	var res := SaveCodec.decode(SaveCodec.encode(w))
	check(res["ok"], "save round-trip")
	var w2: WorldState = res["world"]
	var v2: VehicleState = w2.vehicles["wagon"]
	eq(v2.region_id, v.region_id, "region kept")
	check(v2.position.distance_to(v.position) < 0.2, "position kept")
	check(absf(v2.rotation - 1.25) < 0.01, "heading kept")
	check(v2.engine_on, "engine state kept")
	eq(int(v2.cargo["items"]["fuel"]), 2, "trunk kept")
	eq(v2.driver(), PID, "seat kept")
	eq((w2.players[PID] as PlayerState).vehicle_id, "wagon", "player still in the car")
	# a seat whose player disagrees is cleared on load
	var d := SaveCodec.encode(w)
	d["players"][PID]["vehicle_id"] = ""
	var w3: WorldState = SaveCodec.decode(d)["world"]
	eq((w3.vehicles["wagon"] as VehicleState).driver(), "", "inconsistent seat cleared")
	a.dead = true
	var out := VehicleSim.step(w, 1)
	eq(a.vehicle_id, "", "a downed driver slumps out of the car")
	check(not out.is_empty(), "and that is published")


func test_closed_car_hides_from_burnt_ones_but_engine_is_heard() -> void:
	var w := _wagon_world(66)
	var v := _wagon(w)
	_player(w, PID, "service_station", v.position)
	var z := ZombieSim.spawn(w, "service_station", v.position + Vector2(-120, 0), false)
	z.facing = Vector2.RIGHT
	VehicleSim.request(w, PID, "wagon", "enter")
	w.threat.queue.clear()
	for i in 10:
		w.tick += 1
		ZombieSim.step(w, 1)
	eq(z.target_player, "", "nobody is seen inside a closed vehicle")
	w.threat.queue.clear()
	VehicleSim.request(w, PID, "wagon", "engine")
	check(w.threat.queue.any(func(n): return n["category"] == "engine_start"), "starting the engine is loud")
	w.threat.queue.clear()
	for i in 40:
		w.tick += 1
		VehicleSim.step(w, 1)
	check(w.threat.queue.any(func(n): return n["category"] == "engine"), "a running engine keeps making noise")


func test_town_cellar_is_a_prebuilt_separate_base() -> void:
	var w := WorldState.create_new("w_cellar", 67)
	eq(WorldActions.ensure_prebuilt_shelters(w), 1, "the town house cellar exists from the start")
	eq(WorldActions.ensure_prebuilt_shelters(w), 0, "never created twice")
	var b := w.bunker("town.house.cellar")
	check(b != null, "it is a bunker of its own")
	eq(b.entrance_region, "town.house", "entered from the town house")
	eq(str(b.levels[-1]), "town_cellar", "with the concrete cellar level")
	check(w.region(b.level_region(-1)) != null, "its level region exists")
	check(w.bunker("homestead.farmhouse.shelter") == null, "the cabin's shelter is unaffected")
	eq(SleepSim.shelter_group(w, b.level_region(-1)), "town_house", "the cellar shares the house's shelter group")
	var p := _player(w, PID, "town.house", Vector2(300, 480))
	var hatch := w.region("town.house")
	check(WorldActions.request_interact(w, PID, "town.house.cellar", hatch.rev("town.house.cellar"))["ok"], "the hatch opens")
	var down := WorldActions.request_interact(w, PID, "town.house.cellar_ladder", -1)
	check(down["ok"], "and leads down")
	eq(p.region_id, b.level_region(-1), "into the cellar")


func test_town_ruin_was_picked_clean() -> void:
	# Iteration 013: the stores' and houses' finds moved inside, into searchable
	# containers (test_scavengers_circuit.gd); the ruin stays a bare street spot.
	var w := WorldState.create_new("w_town", 68)
	var p := _player(w, PID, "town", Vector2.ZERO)
	var town := w.region("town")
	p.position = Content.entity_position(town.entity_def("town.house_ruin"))
	eq(WorldActions.request_interact(w, PID, "town.house_ruin", -1)["reason"], "ACTION_LOOT_GONE", "the ruin was picked clean")


func test_map_marks_unexplored_road_exits() -> void:
	var w := WorldState.create_new("w_map", 69)
	var shown := ["homestead", "service_station"]
	var ex := MapPanel.unexplored_exits(w, shown)
	eq(ex.size(), 1, "one road leads somewhere unexplored")
	eq(str(ex[0]["region_id"]), "service_station", "it leaves the settlement")
	eq(ex[0]["dir"], Vector2.RIGHT, "heading east")
	eq(MapPanel.unexplored_exits(w, ["homestead", "service_station", "town"]).size(), 0, "nothing once the town is found")


# ---------------------------------------------------------------- milestone D: wildlife, flashlight

func test_wildlife_roams_notices_and_backs_off_never_attacks() -> void:
	var w := WorldState.create_new("w_wild", 71)
	var n := WildlifeSim.ensure(w)
	check(n >= 4, "wolves and bears are placed from content")
	eq(WildlifeSim.ensure(w), 0, "never duplicated")
	var wolf: AnimalState = null
	for a in w.animals.values():
		if a.species == "wolf" and a.region_id == "homestead":
			wolf = a
			break
	check(wolf != null, "a wolf lives in the woods north of the cabin")
	var start := wolf.position
	# alone: it idles and wanders within its home area
	for i in 400:
		w.tick += 1
		WildlifeSim.step(w, 1)
	check(wolf.position.distance_to(start) > 5.0, "it roams on its own")
	check(wolf.home.grow(600).has_point(wolf.position), "and stays near home")
	# a player approaching: it stops to watch, then bolts when too close
	var p := _player(w, PID, "homestead", wolf.position + Vector2(420, 0))
	var hp := p.health
	WildlifeSim.step(w, 1)
	eq(wolf.activity, "alert", "it notices the player and watches")
	p.position = wolf.position + Vector2(150, 0)
	var res := WildlifeSim.step(w, 1)
	eq(wolf.activity, "flee", "too close: it runs")
	check(res.size() == 1 and (res[0]["events"] as Array).any(func(e): return e["kind"] == "animal_call"), "with an alarm call")
	var d0 := wolf.position.distance_to(p.position)
	for i in 20:
		w.tick += 1
		WildlifeSim.step(w, 1)
	check(wolf.position.distance_to(p.position) > d0, "away from the player")
	eq(p.health, hp, "it never attacks")
	var rows := WildlifeSim.rows(w)
	var w2 := WorldState.new()
	WildlifeSim.apply_rows(w2, rows)
	eq(w2.animals.size(), w.animals.size(), "clients mirror every animal")
	check((w2.animals[wolf.animal_id] as AnimalState).position.distance_to(wolf.position) < 0.2, "at the host's position")
	WildlifeSim.apply_rows(w2, [])
	eq(w2.animals.size(), 0, "and drop the ones the host no longer has")


func test_flashlight_toggle_needs_one_and_goes_with_it() -> void:
	var w := WorldState.create_new("w_torch", 72)
	var p := _player(w, PID, "homestead.farmhouse", Vector2(630, 520))
	eq(Inv.request(w, PID, "flashlight", "")["reason"], "FLASHLIGHT_NONE", "no flashlight, no light")
	var house := w.region("homestead.farmhouse")
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse.flashlight", -1)["ok"], "the cabin has a flashlight for each player")
	eq(WorldActions.request_interact(w, PID, "homestead.farmhouse.flashlight", -1)["reason"], "FLASHLIGHT_ALREADY", "one per player")
	var r := Inv.request(w, PID, "flashlight", "")
	check(r["ok"] and p.flashlight, "switched on")
	check((r["vitals"] as Array).has(PID), "and replicated with the vitals")
	eq(GameSession._vitals_row(p).size(), 7, "the vitals row carries it")
	check(p.has_gear_item("flashlight"), "never used up")
	var uid := ""
	for g in p.gear:
		if g["item"] == "flashlight":
			uid = g["uid"]
	Inv.request(w, PID, "drop", uid)
	SurvivalSim.step(w, 1)
	check(not p.flashlight, "dropping it switches the light off")
	check(house != null, "")
