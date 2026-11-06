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


# ---------------------------------------------------------------- B/C: settlements, harbor, mine, civic hall

const SETTLEMENTS := ["town", "junction", "greyhollow", "stillwater", "harbor"]


## Regions reachable by road (vehicle exits and on-foot road portals) from the cabin.
func _road_graph(w: WorldState) -> Dictionary:
	var seen := {"homestead": true}
	var todo := ["homestead"]
	while not todo.is_empty():
		var rid: String = todo.pop_back()
		var def := w.region_def(rid)
		var next: Array = []
		for ex in def.get("vehicle_exits", []):
			next.append(str(ex["target"]["region"]))
		for eid in Content.entity_ids(rid):
			var e := Content.entity_def(rid, eid)
			if str(e.get("type", "")) == "portal" and e.get("target", {}).has("region"):
				next.append(str(e["target"]["region"]))
		for n in next:
			if not seen.has(n) and w.region(n) != null:
				seen[n] = true
				todo.append(n)
	return seen


func _walk(w: WorldState, r: RegionState, from: Vector2, to_x: float) -> Vector2:
	var p := from
	for i in 400:
		if absf(p.x - to_x) < 12.0:
			break
		var np := SideSection.walk(w, r, p, signf(to_x - p.x) * 10.0)
		if np == p:
			break
		p = np
		p.y = SideSection.floor_y(r, p.x, p.y - 4.0)
	return p


func test_five_major_settlements_reachable_by_road() -> void:
	var w := WorldState.create_new("w_b1", 411)
	var reach := _road_graph(w)
	for s in SETTLEMENTS:
		check(reach.has(s), s + " can be reached by road from the cabin")
		var d := w.region_def(s)
		check(d.has("zombies") and d.has("climate") and d.has("map") and d.has("discovery"), s + ": a full outdoor settlement")
	var interiors := 0
	for rid in Content.region_ids():
		var d2 := w.region_def(rid)
		if str(d2.get("surface", {}).get("region", "")) in SETTLEMENTS and SideSection.always_side(w.region(rid)):
			interiors += 1
	check(interiors >= 30, "many enterable buildings across the settlements (%d)" % interiors)
	for s in ["junction", "greyhollow", "stillwater", "harbor"]:
		var n := 0
		for rid in Content.region_ids():
			if str(w.region_def(rid).get("surface", {}).get("region", "")) == s:
				n += 1
		check(n >= 5, s + " has at least five interiors (%d)" % n)


func test_every_entrance_leads_in_and_back_out() -> void:
	var w := WorldState.create_new("w_b2", 412)
	var p := _player(w, PID, "junction", Vector2.ZERO)
	for s in ["junction", "greyhollow", "stillwater", "harbor"]:
		for eid in Content.entity_ids(s):
			var e := Content.entity_def(s, eid)
			if str(e.get("type", "")) != "portal" or not eid.ends_with("_entrance"):
				continue
			p.region_id = s
			p.position = Content.entity_position(e)
			check(WorldActions.request_interact(w, PID, eid, -1)["ok"], eid + " opens")
			var inside := w.region(p.region_id)
			check(SideSection.open_at(inside, p.position + Vector2(0, -6)), eid + ": you stand inside a room")
			var exit := ""
			for x in Content.entity_ids(inside.def_id):
				if x.ends_with(".exit"):
					exit = x
			p.position = Content.entity_position(inside.entity_def(exit))
			check(WorldActions.request_interact(w, PID, exit, -1)["ok"] and p.region_id == s, eid + ": and back out to " + s)
			check(p.position.distance_to(Content.entity_position(e)) < 90.0, eid + ": outside its own door")


func test_icebergs_drift_with_the_shared_clock() -> void:
	var a := IceDrift.position_at(100.0, 0.0, 9.0, -500.0, 4100.0)
	var b := IceDrift.position_at(100.0, 60.0, 9.0, -500.0, 4100.0)
	eq(b - a, 540.0, "nine pixels a second, a minute later")
	var c := IceDrift.position_at(4000.0, 60.0, 9.0, -500.0, 4100.0)
	check(c >= -500.0 and c < 4100.0, "wraps round the channel")
	eq(IceDrift.position_at(100.0, 60.0, -6.0, -600.0, 4200.0), -260.0, "and drifts west too")
	var w := WorldState.create_new("w_b3", 413)
	var h := w.region_def("harbor")
	check(str(h.get("ambience2", "")) == "amb.harbor_ice", "the harbor creaks")


func test_civic_hall_four_floors_by_stairs() -> void:
	var w := WorldState.create_new("w_c1", 421)
	var r := w.region("stillwater.civic_hall")
	var flights: Array = []
	for eid in Content.entity_ids(r.def_id):
		var e := r.entity_def(eid)
		if str(e.get("type", "")) == "stairs":
			flights.append(e)
	eq(flights.size(), 3, "three flights: basement, first and second floor")
	var floors := {}
	for f in flights:
		floors[Content.entity_position(f).y] = true
		floors[float(f["top"])] = true
	eq(floors.size(), 4, "four distinct floors")
	# walk the building: from the door to each flight, climb, step off
	var p := Content.spawn_point(r.def_id, 0)
	p = SideSection.rest(r, p)
	var ys: Array = floors.keys()
	ys.sort()
	for f in flights:
		var bottom := Content.entity_position(f)
		var on := _walk(w, r, Vector2(p.x, bottom.y), bottom.x)
		check(absf(on.x - bottom.x) < 14.0, "can walk to the stairs on floor y=%d" % bottom.y)
		check(SideSection.climbable(w, r, Vector2(bottom.x, bottom.y)), "and climb from there")
		check(SideSection.climbable(w, r, Vector2(bottom.x, float(f["top"]))), "to the floor above")
		var off := _walk(w, r, Vector2(bottom.x, float(f["top"])), bottom.x + (200.0 if bottom.x < 800.0 else -200.0))
		eq(off.y, float(f["top"]), "and step off onto that floor")
	var conts := 0
	for eid in Content.entity_ids(r.def_id):
		if ScavengeSim.is_container(r.entity_def(eid)):
			conts += 1
	check(conts >= 12, "something to search on every floor (%d)" % conts)


func test_the_mine_has_three_levels_and_a_way_out() -> void:
	var w := WorldState.create_new("w_c2", 422)
	var g := w.region("greyhollow")
	var p := _player(w, PID, "greyhollow", Content.entity_position(g.entity_def("greyhollow.mine_entrance")))
	check(WorldActions.request_interact(w, PID, "greyhollow.mine_entrance", -1)["ok"], "into the adit")
	eq(p.region_id, "greyhollow.mine", "in the mine")
	var m := w.region("greyhollow.mine")
	eq(str(m.definition().get("style", "")), "mine", "drawn as a mine")
	var levels := {}
	var ladders := 0
	for eid in Content.entity_ids(m.def_id):
		var e := m.entity_def(eid)
		if str(e.get("type", "")) == "stairs":
			ladders += 1
			levels[Content.entity_position(e).y] = true
			levels[float(e["top"])] = true
			check(SideSection.climbable(w, m, Content.entity_position(e)), eid + " can be climbed")
	eq(ladders, 2, "a ladder shaft and a winze")
	eq(levels.size(), 3, "three levels")
	check(Terrain.is_permanent(m, Vector2i(10, 10)), "the rock is fixed (no arbitrary digging)")
	p.position = Content.entity_position(m.entity_def("greyhollow.mine.exit"))
	check(WorldActions.request_interact(w, PID, "greyhollow.mine.exit", -1)["ok"] and p.region_id == "greyhollow", "and back out")
