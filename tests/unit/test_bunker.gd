extends TestCase
## Iteration 002 rules: shelter construction, portals, trees, stockpile,
## reinforcement, unlimited developer levels, schema 1 -> 2 migration.

const SITE := "homestead.farmhouse.shelter"
const INTERIOR := "homestead.farmhouse"
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


func _site_pos() -> Vector2:
	return Content.entity_position(Content.entity_def(INTERIOR, SITE))


func _built_world() -> WorldState:
	var w := WorldState.create_new("w_bunker", 9)
	_player(w, PID, INTERIOR, _site_pos() + Vector2(0, 40))
	var r := WorldActions.request_interact(w, PID, SITE, 0)
	check(r["ok"], "construction starts: " + str(r["reason"]))
	Simulation.advance(w, 10000)
	return w


func test_shelter_construction_is_timed_and_creates_bunker() -> void:
	var w := WorldState.create_new("w1", 1)
	_player(w, PID, INTERIOR, _site_pos() + Vector2(0, 40))
	_player(w, PID2, INTERIOR, _site_pos() + Vector2(30, 40))
	var r := WorldActions.request_interact(w, PID, SITE, 0)
	check(r["ok"], "start construction")
	eq(w.region(INTERIOR).entity_state(SITE)["stage"], "building", "building")
	var r2 := WorldActions.request_interact(w, PID2, SITE, 0)
	check(not r2["ok"], "second simultaneous request refused (no duplicate hatch)")
	var r3 := WorldActions.request_interact(w, PID2, SITE, 1)
	eq(r3["reason"], "ACTION_BUSY", "request during construction refused as busy")
	var need := int(w.region(INTERIOR).entity_state(SITE)["ticks"])
	eq(Simulation.advance(w, need - 1).size(), 0, "not finished one tick early")
	var done := Simulation.advance(w, 1)
	eq(done.size(), 1, "finishes exactly on time")
	eq(w.region(INTERIOR).entity_state(SITE)["stage"], "built", "built")
	check(w.bunker(SITE) != null and w.bunker(SITE).has_level(-1), "bunker with level -1 exists")
	check(w.region("bunker:%s:-1" % SITE) != null, "level -1 region exists")
	eq(Simulation.advance(w, 100).size(), 0, "completes only once")


func test_hatch_portal_needs_open_hatch_and_moves_player() -> void:
	var w := _built_world()
	var ladder := "homestead.farmhouse.hatch_ladder"
	(w.players[PID] as PlayerState).position = _site_pos()
	eq(WorldActions.request_interact(w, PID, ladder, 0)["reason"], "ACTION_CLOSED", "closed hatch blocks the ladder")
	check(WorldActions.request_interact(w, PID, SITE, w.region(INTERIOR).rev(SITE))["ok"], "open hatch")
	var r := WorldActions.request_interact(w, PID, ladder, 0)
	check(r["ok"], "climb down")
	eq((w.players[PID] as PlayerState).region_id, "bunker:%s:-1" % SITE, "player now in level -1")
	var r_up := WorldActions.request_interact(w, PID, "ladder_up", 0)
	check(r_up["ok"], "climb back up")
	eq((w.players[PID] as PlayerState).region_id, INTERIOR, "back in the farmhouse")


func test_tree_gives_wood_once() -> void:
	var w := WorldState.create_new("w2", 1)
	var tree := "homestead.tree_01"
	var tp := Content.entity_position(Content.entity_def("homestead", tree))
	var a := _player(w, PID, "homestead", tp + Vector2(0, 40))
	var b := _player(w, PID2, "homestead", tp + Vector2(30, 40))
	var chops := int(Content.entity_def("homestead", tree)["chops"])
	for i in chops:
		w.tick += 10
		var r := WorldActions.request_interact(w, PID, tree, 0)
		check(r["ok"], "chop %d ok" % i)
	check(w.region("homestead").entity_state(tree)["felled"], "felled")
	eq(a.carrying("wood"), int(Content.entity_def("homestead", tree)["wood"]), "chopper got the wood")
	w.tick += 10
	eq(WorldActions.request_interact(w, PID2, tree, 0)["reason"], "ACTION_ALREADY_FELLED", "no second reward")
	eq(b.carrying("wood"), 0, "other player got nothing")
	eq(WorldActions.request_interact(w, PID, tree, 0)["reason"], "ACTION_ALREADY_FELLED", "felled stays felled")


func test_chop_cooldown() -> void:
	var w := WorldState.create_new("w3", 1)
	var tree := "homestead.tree_02"
	_player(w, PID, "homestead", Content.entity_position(Content.entity_def("homestead", tree)) + Vector2(0, 40))
	check(WorldActions.request_interact(w, PID, tree, 0)["ok"], "first chop")
	eq(WorldActions.request_interact(w, PID, tree, 0)["reason"], "ACTION_TOO_FAST", "spam in the same tick refused")


func test_deposit_and_reinforce_spend_once() -> void:
	var w := _built_world()
	var level := "bunker:%s:-1" % SITE
	var p := w.players[PID] as PlayerState
	p.carried["wood"] = 6
	var pile := "homestead.farmhouse.timber"
	p.position = Content.entity_position(Content.entity_def(INTERIOR, pile))
	check(WorldActions.request_interact(w, PID, pile, 0)["ok"], "deposit")
	eq(w.bunker(SITE).amount("wood"), 6, "stockpile has 6")
	eq(p.carrying("wood"), 0, "player emptied")
	eq(WorldActions.request_interact(w, PID, pile, 0)["reason"], "ACTION_NOTHING_TO_DEPOSIT", "nothing more to deposit")
	# Underground: two players try the same support at once with the same revision.
	p.region_id = level
	var sp := Content.entity_position(w.region(level).entity_def("support_1"))
	p.position = sp
	_player(w, PID2, level, sp + Vector2(20, 0))
	var r1 := WorldActions.request_interact(w, PID, "support_1", 0)
	var r2 := WorldActions.request_interact(w, PID2, "support_1", 0)
	check(r1["ok"] and not r2["ok"], "exactly one construction")
	eq(w.bunker(SITE).amount("wood"), 2, "wood spent once (6 - 4)")
	var sp2 := Content.entity_position(w.region(level).entity_def("support_2"))
	(w.players[PID2] as PlayerState).position = sp2
	var r3 := WorldActions.request_interact(w, PID2, "support_2", 0)
	eq(r3["reason"], "ACTION_NEED_WOOD", "not enough wood for a second support")
	Simulation.advance(w, 1000)
	eq(w.region(level).entity_state("support_1")["stage"], "reinforced", "reinforced after build time")


func test_dev_levels_unlimited_and_never_duplicated() -> void:
	var w := _built_world()
	var b := w.bunker(SITE)
	for expected in [-2, -3, -4, -5, -6]:
		var r := WorldActions.dev_create_level(w, PID)
		check(r["ok"], "create level %d" % expected)
		eq(b.deepest(), expected, "deepest is %d" % expected)
		check(w.region(b.level_region(expected)) != null, "region for %d exists" % expected)
		check(w.region(b.level_region(expected + 1)).entity_state("ladder_down")["enabled"], "ladder down from %d enabled" % (expected + 1))
	eq(b.levels.size(), 6, "six levels, no duplicates")
	eq(w.add_level(b, -3, "bunker_concrete"), "", "existing depth cannot be re-created")
	# Walk down the whole chain and back up.
	var p := w.players[PID] as PlayerState
	p.region_id = b.level_region(-1)
	for d in range(-1, -6, -1):
		p.position = Content.entity_position(w.region(p.region_id).entity_def("ladder_down"))
		check(WorldActions.request_interact(w, PID, "ladder_down", 0)["ok"], "down from %d" % d)
		eq(p.region_id, b.level_region(d - 1), "arrived at %d" % (d - 1))
	p.position = Content.entity_position(w.region(p.region_id).entity_def("ladder_down"))
	eq(WorldActions.request_interact(w, PID, "ladder_down", 0)["reason"], "ACTION_NOT_AVAILABLE", "no ladder below the deepest level")


func test_save_roundtrip_with_bunker() -> void:
	var w := _built_world()
	WorldActions.dev_create_level(w, PID)
	w.bunker(SITE).resources["wood"] = 11
	(w.players[PID] as PlayerState).carried["wood"] = 5
	(w.players[PID] as PlayerState).region_id = w.bunker(SITE).level_region(-2)
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes: " + str(res.get("error")))
	var w2: WorldState = res["world"]
	var b2 := w2.bunker(SITE)
	check(b2 != null and b2.has_level(-1) and b2.has_level(-2), "levels restored")
	eq(b2.amount("wood"), 11, "stockpile restored")
	eq((w2.players[PID] as PlayerState).carrying("wood"), 5, "carried wood restored")
	eq((w2.players[PID] as PlayerState).region_id, b2.level_region(-2), "underground position restored")
	check(w2.region(b2.level_region(-2)) != null, "level region rebuilt")
	eq(w2.region(b2.level_region(-2)).def_id, "level:bunker_concrete", "template restored")


func test_interrupted_construction_completes_after_load() -> void:
	var w := WorldState.create_new("w4", 1)
	_player(w, PID, INTERIOR, _site_pos() + Vector2(0, 40))
	WorldActions.request_interact(w, PID, SITE, 0)
	Simulation.advance(w, 5)
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	var w2: WorldState = res["world"]
	eq(w2.jobs.size(), 1, "job rebuilt from saved state")
	Simulation.advance(w2, 1000)
	check(w2.bunker(SITE) != null, "construction finished after reload")
	eq(w2.bunkers.size(), 1, "exactly one bunker")


func test_schema1_save_migrates() -> void:
	var raw = SafeFile.read_json("res://tests/fixtures/saves/world_v1.json")
	var res := SaveCodec.decode(raw)
	check(res["ok"], "v1 save loads through migration: " + str(res.get("error")))
	if res["ok"]:
		var w: WorldState = res["world"]
		eq(w.bunkers.size(), 0, "no bunkers")
		eq((w.players.values()[0] as PlayerState).carried, {}, "no carried wood")
		check(w.region(INTERIOR) != null, "new static region added to old world")
