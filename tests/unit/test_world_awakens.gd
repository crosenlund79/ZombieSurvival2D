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
