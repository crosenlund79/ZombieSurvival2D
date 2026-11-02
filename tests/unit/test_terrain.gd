extends TestCase
## Iteration 003 milestone B: excavation grid, support rule, concurrency, persistence.

const SITE := "homestead.farmhouse.shelter"
const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"


func _setup() -> Array:
	var w := WorldState.create_new("w_terrain", 5)
	var b := w.create_bunker(SITE, "homestead.farmhouse", "bunker_earth")
	var r := w.region(b.level_region(-1))
	for id in [PID, PID2]:
		var p := PlayerState.new()
		p.player_id = id
		p.region_id = r.region_id
		p.online = true
		w.players[id] = p
	return [w, r, b]


func _stand(w: WorldState, id: String, r: RegionState, c: Vector2i) -> void:
	(w.players[id] as PlayerState).position = Terrain.cell_center(r, c)


func test_grid_and_initial_chamber() -> void:
	var s := _setup()
	var r: RegionState = s[1]
	check(Terrain.has_terrain(r), "earth level has an excavation grid")
	check(Terrain.is_open(r, Vector2i(13, 10)) and Terrain.is_open(r, Vector2i(26, 16)), "original chamber is open")
	check(not Terrain.is_open(r, Vector2i(12, 12)), "earth beside the chamber is solid")
	var ladder := Content.entity_position(r.entity_def("ladder_up"))
	check(Terrain.is_open(r, Terrain.cell_of(r, ladder)), "ladder stands on open floor")


func test_dig_flow_and_validation() -> void:
	var s := _setup()
	var w: WorldState = s[0]
	var r: RegionState = s[1]
	_stand(w, PID, r, Vector2i(13, 12))
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(13, 12))["reason"], "ACTION_DIG_OPEN", "open cell refused")
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(10, 12))["reason"], "ACTION_TOO_FAR", "out of reach refused")
	var res := WorldActions.request_terrain(w, PID, "dig", Vector2i(12, 12))
	check(res["ok"], "dig next to the chamber (inside the safe margin) starts")
	_stand(w, PID2, r, Vector2i(13, 13))
	eq(WorldActions.request_terrain(w, PID2, "dig", Vector2i(12, 12))["reason"], "ACTION_BUSY", "same cell twice refused (no duplicate)")
	check(not Terrain.is_open(r, Vector2i(12, 12)), "still solid while digging")
	Simulation.advance(w, 30)
	check(Terrain.is_open(r, Vector2i(12, 12)), "open after the dig time")
	_stand(w, PID, r, Vector2i(12, 12))
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(11, 12))["reason"], "ACTION_DIG_UNSUPPORTED", "beyond the safe margin needs support")
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(10, 10))["reason"], "ACTION_TOO_FAR", "can't reach diagonally far cells")
	_stand(w, PID, r, Vector2i(19, 10))
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(19, 9))["reason"], "ACTION_DIG_PERMANENT", "ladder shaft is permanent")


func test_support_extends_safe_range_and_spends_once() -> void:
	var s := _setup()
	var w: WorldState = s[0]
	var r: RegionState = s[1]
	var b: BunkerState = s[2]
	_stand(w, PID, r, Vector2i(13, 12))
	WorldActions.request_terrain(w, PID, "dig", Vector2i(12, 12))
	Simulation.advance(w, 30)
	_stand(w, PID, r, Vector2i(12, 12))
	eq(WorldActions.request_terrain(w, PID, "support", Vector2i(12, 12))["reason"], "ACTION_NEED_WOOD", "support needs stockpile wood")
	b.resources["wood"] = 6
	_stand(w, PID2, r, Vector2i(12, 12))
	var r1 := WorldActions.request_terrain(w, PID, "support", Vector2i(12, 12))
	var r2 := WorldActions.request_terrain(w, PID2, "support", Vector2i(12, 12))
	check(r1["ok"] and not r2["ok"], "one support per spot")
	eq(b.amount("wood"), 2, "wood spent once")
	eq(WorldActions.request_terrain(w, PID, "dig", Vector2i(11, 12))["reason"], "ACTION_DIG_UNSUPPORTED", "support only counts once built")
	Simulation.advance(w, 40)
	eq(str(r.terrain["supports"]["12,12"]["stage"]), "reinforced", "support reinforced")
	check(WorldActions.request_terrain(w, PID, "dig", Vector2i(11, 12))["ok"], "now the next cell can be dug")
	Simulation.advance(w, 30)
	check(Terrain.is_supported(r, Vector2i(9, 12)), "support covers ~3 cells")
	check(not Terrain.is_supported(r, Vector2i(7, 12)), "but not unlimited distance")
	_stand(w, PID, r, Vector2i(11, 12))
	eq(Terrain.support_problem(r, Vector2i(11, 12)), "ACTION_SUPPORT_TOO_CLOSE", "supports need spacing")


func test_terrain_persists_and_resumes_interrupted_dig() -> void:
	var s := _setup()
	var w: WorldState = s[0]
	var r: RegionState = s[1]
	_stand(w, PID, r, Vector2i(13, 12))
	WorldActions.request_terrain(w, PID, "dig", Vector2i(12, 12))
	Simulation.advance(w, 30)
	_stand(w, PID, r, Vector2i(13, 11))
	WorldActions.request_terrain(w, PID, "dig", Vector2i(12, 11))
	Simulation.advance(w, 5)  # save mid-dig
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	var r2 := w2.region(r.region_id)
	check(Terrain.is_open(r2, Vector2i(12, 12)), "dug cell persisted")
	check(not Terrain.is_open(r2, Vector2i(12, 11)), "in-progress cell still solid after load")
	Simulation.advance(w2, 40)
	check(Terrain.is_open(r2, Vector2i(12, 11)), "interrupted dig finishes after load (exactly once)")
	eq((r2.terrain["dug"] as Dictionary).size(), 2, "two dug cells, no duplicates")


func test_concrete_test_level_has_no_excavation() -> void:
	var s := _setup()
	var w: WorldState = s[0]
	var b: BunkerState = s[2]
	(w.players[PID] as PlayerState).region_id = b.level_region(-1)
	WorldActions.dev_create_level(w, PID)
	check(not Terrain.has_terrain(w.region(b.level_region(-2))), "dev test level stays a fixed concrete room")
