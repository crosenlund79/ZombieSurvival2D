extends TestCase
## Iteration 014 "The Five Settlements".

const PID := "aaaaaaaaaaaaaaaa"
const SIDE_INTERIORS := ["homestead.farmhouse", "town.house", "town.house_west", "town.house_east", "town.grocery",
	"town.pharmacy", "town.hardware", "town.clothing", "town.garage"]


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _stairs(r: RegionState) -> Dictionary:
	for eid in Content.entity_ids(r.def_id):
		if str(r.entity_def(eid).get("type", "")) == "stairs":
			return r.entity_def(eid)
	return {}


# ---------------------------------------------------------------- A: side-view interiors

func test_interiors_are_side_views_and_the_outdoors_is_not() -> void:
	var w := WorldState.create_new("w_s1", 401)
	for rid in SIDE_INTERIORS:
		var r := w.region(rid)
		check(SideSection.always_side(r), rid + " is a side view")
		check(SideSection.is_section(r), rid + " reads as a cross-section")
		check(Terrain.is_permanent(r, Vector2i(3, 3)), rid + ": nothing can be dug in a building")
	for rid in ["homestead", "town", "service_station"]:
		check(not SideSection.always_side(w.region(rid)), rid + " stays top-down")


func test_entering_puts_your_feet_on_the_floor_and_leaving_returns_you() -> void:
	var w := WorldState.create_new("w_s2", 402)
	var p := _player(w, PID, "homestead", Vector2.ZERO)
	var home := w.region("homestead")
	p.position = Content.entity_position(home.entity_def("homestead.farmhouse_door"))
	WorldActions.request_interact(w, PID, "homestead.farmhouse_door", home.rev("homestead.farmhouse_door"))
	p.position = Content.entity_position(home.entity_def("homestead.farmhouse_entry"))
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse_entry", -1)["ok"], "into the cabin")
	var cabin := w.region("homestead.farmhouse")
	eq(p.region_id, "homestead.farmhouse", "inside")
	check(absf(SideSection.floor_y(cabin, p.position.x, p.position.y - 4.0) - p.position.y) < 1.0, "standing on the floor")
	check(SideSection.side_for(w, p), "seen from the side")
	p.position = Content.entity_position(cabin.entity_def("homestead.farmhouse.exit"))
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse.exit", -1)["ok"], "back out")
	eq(p.region_id, "homestead", "outdoors again (top-down)")
	check(not SideSection.side_for(w, p), "top-down outside")


func test_the_cabin_keeps_its_shelter_hatch_and_bunker() -> void:
	var w := WorldState.create_new("w_s3", 403)
	var cabin := w.region("homestead.farmhouse")
	var site := Content.entity_position(cabin.entity_def("homestead.farmhouse.shelter"))
	var p := _player(w, PID, "homestead.farmhouse", site)
	var r := WorldActions.request_interact(w, PID, "homestead.farmhouse.shelter", cabin.rev("homestead.farmhouse.shelter"))
	check(r["ok"], "the hatch can be dug from the side view")
	Simulation.advance(w, Simulation.seconds_to_ticks(9.0))
	eq(str(cabin.entity_state("homestead.farmhouse.shelter").get("stage", "")), "built", "hatch built")
	WorldActions.request_interact(w, PID, "homestead.farmhouse.shelter", cabin.rev("homestead.farmhouse.shelter"))
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse.hatch_ladder", -1)["ok"], "down the ladder")
	check(p.region_id.begins_with("bunker:homestead.farmhouse.shelter"), "into the bunker")
	var b := w.bunker("homestead.farmhouse.shelter")
	var lv := w.region(b.level_region(-1))
	p.position = Content.entity_position(lv.entity_def("ladder_up"))
	check(WorldActions.request_interact(w, PID, "ladder_up", -1)["ok"], "and up again")
	eq(p.region_id, "homestead.farmhouse", "back in the cabin")
	check(SideSection.open_at(cabin, p.position + Vector2(0, -6)), "standing in the room, at the hatch")


func test_stairs_landings_and_climbing() -> void:
	var w := WorldState.create_new("w_s4", 404)
	var r := w.region("town.house_west")
	var st := _stairs(r)
	check(not st.is_empty(), "the west house has a staircase")
	var bottom := Content.entity_position(st)
	var top_y := float(st["top"])
	check(SideSection.climbable(w, r, bottom), "the stairs can be climbed from the ground floor")
	check(SideSection.climbable(w, r, Vector2(bottom.x, top_y)), "and from the upper landing")
	eq(SideSection.floor_y(r, bottom.x, top_y - 10.0), top_y, "walking: the upper landing carries you")
	eq(SideSection.floor_y(r, bottom.x, top_y - 10.0, true), bottom.y, "climbing: you pass down through the landing")
	eq(SideSection.floor_y(r, bottom.x - 300.0, top_y - 10.0), top_y, "upstairs elsewhere: the upstairs floor")
	check(not SideSection.climbable(w, r, Vector2(bottom.x - 300.0, bottom.y)), "no climbing away from the stairs")


func test_old_top_down_positions_are_settled_on_load() -> void:
	var w := WorldState.create_new("w_s5", 405)
	for rid in SIDE_INTERIORS:
		var p := _player(w, PID, rid, Vector2(480, 560))  # where top-down interiors used to put you
		SideSection.settle(w, p)
		var r := w.region(rid)
		check(SideSection.open_at(r, p.position + Vector2(0, -6)), rid + ": in a room after settling")
		check(absf(SideSection.floor_y(r, p.position.x, p.position.y - 4.0) - p.position.y) < 1.0, rid + ": on the floor")


func test_containers_keep_their_ids_and_state_in_the_side_view() -> void:
	var w := WorldState.create_new("w_s6", 406)
	var g := w.region("town.grocery")
	var eid := "town.grocery.aisle_a"
	check(g.has_entity(eid), "same container id as before")
	var p := _player(w, PID, "town.grocery", Content.entity_position(g.entity_def(eid)))
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "search starts in the side view")
	for i in 60:
		Simulation.advance(w, 1)
	check(bool(g.entity_state(eid).get("searched", false)), "and finishes")
	check(SkillSim.xp(p, "scavenging") > 0, "with XP")
