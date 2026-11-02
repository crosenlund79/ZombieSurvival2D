extends TestCase

const GATE := "homestead.yard_gate"


func _world_with_player(pos: Vector2) -> WorldState:
	var w := WorldState.create_new("world_test", 42)
	var p := PlayerState.new()
	p.player_id = "aaaaaaaaaaaaaaaa"
	p.region_id = "homestead"
	p.position = pos
	p.online = true
	w.players[p.player_id] = p
	return w


func _gate_pos() -> Vector2:
	return Content.entity_position(Content.entity_def("homestead", GATE))


func test_new_world_has_initial_content() -> void:
	var w := WorldState.create_new("world_x", 7)
	check(w.region("homestead") != null, "homestead region exists")
	eq(w.region("homestead").entity_state(GATE), {"open": false}, "gate starts closed")
	eq(w.region("homestead").rev(GATE), 0, "untouched rev")
	check(w.region("homestead").overrides.is_empty(), "no stored changes for a new world")


func test_only_changes_are_stored() -> void:
	var r := WorldState.create_new("w", 1).region("homestead")
	r.set_fields(GATE, {"open": true})
	eq(r.overrides, {GATE: {"open": true}}, "change stored")
	r.set_fields(GATE, {"open": false})
	check(r.overrides.is_empty(), "back to initial value -> nothing stored")
	eq(r.rev(GATE), 2, "rev counts every change")


func test_seeded_rng_reproducible() -> void:
	var a := WorldState.create_new("w", 99).make_rng("vegetation")
	var b := WorldState.create_new("w2", 99).make_rng("vegetation")
	var c := WorldState.create_new("w3", 99).make_rng("other")
	var x := a.randi()
	eq(b.randi(), x, "same seed + stream -> same numbers")
	check(c.randi() != x, "different stream -> different numbers")


func test_simulation_clock() -> void:
	var w := WorldState.create_new("w", 1)
	Simulation.advance(w, 25)
	Simulation.advance(w, -5)
	eq(w.tick, 25, "advance adds ticks, ignores negative")
	eq(w.sim_seconds(), 2.5, "seconds from ticks")
	Simulation.advance(w, 36000)
	eq(Simulation.format_time(w), "01:00:02", "formatted clock")


func test_interaction_success() -> void:
	var w := _world_with_player(_gate_pos() + Vector2(0, 60))
	var r := WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", GATE, 0)
	check(r["ok"], "in range, correct rev -> ok")
	eq(w.region("homestead").entity_state(GATE), {"open": true}, "gate toggled open")
	eq(w.region("homestead").rev(GATE), 1, "rev 1")
	eq(r["changes"], [{"region_id": "homestead", "entity_id": GATE, "cause": "action"}], "change reported")


func test_interaction_rejections() -> void:
	var w := _world_with_player(_gate_pos() + Vector2(0, 400))
	eq(WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", GATE, 0)["reason"], "ACTION_TOO_FAR", "too far")
	eq(WorldActions.request_interact(w, "bbbbbbbbbbbbbbbb", GATE, 0)["reason"], "ACTION_UNKNOWN_PLAYER", "unknown player")
	(w.players["aaaaaaaaaaaaaaaa"] as PlayerState).position = _gate_pos()
	eq(WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", "nope.entity", 0)["reason"], "ACTION_UNKNOWN_OBJECT", "unknown object")
	eq(WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", GATE, 5)["reason"], "ACTION_STALE", "stale rev")
	(w.players["aaaaaaaaaaaaaaaa"] as PlayerState).online = false
	eq(WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", GATE, 0)["reason"], "ACTION_UNKNOWN_PLAYER", "offline player")
	eq(w.region("homestead").rev(GATE), 0, "no rejected request changed the world")


func test_two_requests_same_rev_only_one_applies() -> void:
	var w := _world_with_player(_gate_pos())
	var p2 := PlayerState.new()
	p2.player_id = "cccccccccccccccc"
	p2.region_id = "homestead"
	p2.position = _gate_pos()
	p2.online = true
	w.players[p2.player_id] = p2
	var r1 := WorldActions.request_interact(w, "aaaaaaaaaaaaaaaa", GATE, 0)
	var r2 := WorldActions.request_interact(w, "cccccccccccccccc", GATE, 0)
	check(r1["ok"] and not r2["ok"], "second request with old rev refused")
	eq(r2["reason"], "ACTION_STALE", "reason stale")
	eq(w.region("homestead").entity_state(GATE), {"open": true}, "gate stays open (not toggled back)")


func test_move_plausibility() -> void:
	check(WorldActions.is_plausible_move(Vector2.ZERO, Vector2(12, 0), 0.05), "normal step ok")
	check(not WorldActions.is_plausible_move(Vector2.ZERO, Vector2(900, 0), 0.05), "teleport refused")
