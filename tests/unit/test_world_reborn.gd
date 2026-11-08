extends TestCase
## Iteration 015 "The World Reborn".

const PID := "aaaaaaaaaaaaaaaa"
const SETTLEMENTS := ["town", "junction", "greyhollow", "stillwater", "harbor"]


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


# ---------------------------------------------------------------- A: geography

func test_outdoor_regions_tile_one_world_without_overlaps() -> void:
	var ids := WorldGeo.outdoor_ids()
	check(ids.size() >= 12, "all outdoor regions placed (%d)" % ids.size())
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := WorldGeo.world_rect(ids[i])
			var b := WorldGeo.world_rect(ids[j])
			check(not a.grow(-1.0).intersects(b.grow(-1.0)), "%s and %s do not overlap" % [ids[i], ids[j]])


func test_settlements_are_separated_by_wilderness() -> void:
	for s in SETTLEMENTS:
		var open := WorldGeo.open_edges(s)
		for side in open:
			for span in open[side]:
				var b := WorldGeo.local_bounds(s)
				var mid := (float(span[0]) + float(span[1])) * 0.5
				var p: Vector2 = {"west": Vector2(b.position.x - 40, mid), "east": Vector2(b.end.x + 40, mid),
					"north": Vector2(mid, b.position.y - 40), "south": Vector2(mid, b.end.y + 40)}[side]
				var n := WorldGeo.region_at(WorldGeo.to_world(s, p), s)
				check(not (n in SETTLEMENTS), "%s's %s edge leads into wilderness, not straight into %s" % [s, side, n])
	var a := WorldGeo.world_rect("town").get_center()
	var b2 := WorldGeo.world_rect("harbor").get_center()
	check(a.distance_to(b2) > 40000.0, "Ashgrove and Port Halden are far apart (%d px)" % roundi(a.distance_to(b2)))
	check(WorldGeo.world_rect("wild.corran_forest").size.x >= 10000.0, "the forest between Ashgrove and the junction is many screens wide")


func test_walking_off_an_edge_continues_at_the_same_world_point() -> void:
	var w := WorldState.create_new("w_r1", 1501)
	var p := _player(w, PID, "town", Vector2(3200 + 20, 600))
	var before := WorldGeo.to_world("town", p.position)
	var r := WorldActions.edge_travel(w, p)
	check(r.get("ok", false), "crossed")
	eq(p.region_id, "wild.corran_forest", "into the Corran Forest (off the road)")
	var after := WorldGeo.to_world(p.region_id, p.position)
	check(absf(after.y - before.y) < 2.0, "same latitude: no teleport along the edge")
	check(after.x > before.x and after.x - before.x < 120.0, "a few steps further east, inside the forest")
	check(r.has("transition"), "the client is moved by a normal transition")
	check(w.meta.get("discoveries", {}).has("wild_corran"), "arriving discovers the region")
	var p2 := _player(w, "bbbbbbbbbbbbbbbb", "town", Vector2(1600, 1000))
	check(WorldActions.edge_travel(w, p2).is_empty(), "walking about inside a region never crosses")


func test_closed_edges_lead_nowhere_and_arrivals_avoid_obstacles() -> void:
	var w := WorldState.create_new("w_r2", 1502)
	var p := _player(w, PID, "homestead", Vector2(-30, 300))
	check(WorldActions.edge_travel(w, p).is_empty(), "the far side of the Pine Woods is the edge of the world")
	eq(p.region_id, "homestead", "still home")
	for rid in WorldGeo.outdoor_ids():
		var b := WorldGeo.local_bounds(rid)
		var open := WorldGeo.open_edges(rid)
		for span in open["east"]:
			var cr := WorldGeo.crossing(rid, Vector2(b.end.x + 20, (float(span[0]) + float(span[1])) * 0.5))
			if cr.is_empty():
				continue
			var g := NavGrid.for_def(str(cr["region"]))
			check(not g.is_blocked(g.to_cell(cr["position"]), {}), "%s → %s arrives on open ground" % [rid, cr["region"]])


func test_driving_off_an_edge_moves_car_occupants_and_trunk() -> void:
	var w := WorldState.create_new("w_r3", 1503)
	VehicleSim.ensure(w)
	var v: VehicleState = w.vehicles.values()[0]
	v.region_id = "junction"
	v.position = Vector2(1600, 140)
	v.rotation = -PI / 2.0
	v.engine_on = true
	var a := _player(w, PID, "junction", v.position)
	v.seats[0] = PID
	a.vehicle_id = v.vehicle_id
	v.cargo = {"items": {"fuel": 2}, "gear": []}
	var r := VehicleSim.submit_pose(w, PID, v.vehicle_id, Vector2(1600, 60), -PI / 2.0, 300.0, 0.0, 0.1)
	check(r.get("ok", false), "pose accepted")
	eq(v.region_id, "wild.greyhollow_pass", "north out of the junction into the Greyhollow Pass")
	eq(a.region_id, "wild.greyhollow_pass", "the driver comes along")
	check(absf(wrapf(v.rotation + PI / 2.0, -PI, PI)) < 0.01, "heading kept")
	eq(int(v.cargo["items"].get("fuel", 0)), 2, "the trunk travels with it")
	check(v.position.y < WorldGeo.local_bounds("wild.greyhollow_pass").end.y - 100.0, "placed clear of the edge it came over")


func test_every_settlement_reachable_through_the_wilderness() -> void:
	var seen := {"homestead": true}
	var todo := ["homestead"]
	while not todo.is_empty():
		var rid: String = todo.pop_back()
		var b := WorldGeo.local_bounds(rid)
		var open := WorldGeo.open_edges(rid)
		for side in open:
			for span in open[side]:
				var mid := (float(span[0]) + float(span[1])) * 0.5
				var p: Vector2 = {"west": Vector2(b.position.x - 40, mid), "east": Vector2(b.end.x + 40, mid),
					"north": Vector2(mid, b.position.y - 40), "south": Vector2(mid, b.end.y + 40)}[side]
				var n := WorldGeo.region_at(WorldGeo.to_world(rid, p), rid)
				if n != "" and not seen.has(n):
					seen[n] = true
					todo.append(n)
	for s in SETTLEMENTS:
		check(seen.has(s), s + " can be reached from the cabin")


func test_main_road_continues_across_every_edge_it_meets() -> void:
	# A road reaching one side of an edge carries on in the neighbouring region, at the same point.
	var pairs := [["service_station", "wild.birchwater"], ["wild.birchwater", "town"], ["town", "wild.corran_forest"],
		["wild.corran_forest", "junction"], ["junction", "wild.greyhollow_pass"], ["wild.greyhollow_pass", "greyhollow"],
		["junction", "wild.stillwater_road"], ["wild.stillwater_road", "stillwater"], ["stillwater", "wild.halden_coast"],
		["wild.halden_coast", "harbor"]]
	for pr in pairs:
		var a: String = pr[0]
		var b: String = pr[1]
		var ends_a := _road_ends(a)
		var ends_b := _road_ends(b)
		var joined := false
		for ea in ends_a:
			for eb in ends_b:
				if (ea as Vector2).distance_to(eb) < 160.0:
					joined = true
		check(joined, "the road from %s continues into %s" % [a, b])


func _road_ends(rid: String) -> Array:
	var out := []
	for road in Content.region_def(rid).get("map", {}).get("roads", []):
		if str(road.get("kind", "road")) != "road":
			continue
		var pts: Array = road.get("points", [])
		for pt in [pts[0], pts[pts.size() - 1]]:
			out.append(WorldGeo.to_world(rid, Vector2(float(pt[0]), float(pt[1]))))
	return out


func test_greyhollow_south_entrance_is_open() -> void:
	var w := WorldState.create_new("w_r4", 1504)
	var g := NavGrid.for_def("greyhollow")
	for y in range(1300, 2200, 40):
		check(not g.is_blocked(g.to_cell(Vector2(1400, y)), {}), "the south road is open at y %d" % y)
	var scene := (load(str(Content.region_def("greyhollow")["scene"])) as PackedScene).instantiate()
	var blocking := 0
	for n in scene.get_node("YSort").get_children():
		if n is Prop and (n as Prop).footprint.x > 0 and absf((n as Prop).position.x - 1400.0) < 110.0 and (n as Prop).position.y > 1250.0:
			blocking += 1
	scene.free()
	eq(blocking, 0, "no trees or props stand on the south road (it was blocked by pines)")
	check(w.region("greyhollow") != null, "greyhollow exists")


func test_exploration_is_recorded_and_migrated() -> void:
	var w := WorldState.create_new("w_r5", 1505)
	var p := _player(w, PID, "wild.corran_forest", Vector2(5000, 3000))
	check(not WorldGeo.is_explored(w, WorldGeo.to_world(p.region_id, p.position)), "nothing explored before you go there")
	w.meta["explored"] = {}
	w.tick = 0
	WorldGeo.step(w, Simulation.TICK_RATE)
	check(WorldGeo.is_explored(w, WorldGeo.to_world(p.region_id, p.position)), "where you stand becomes explored")
	check(not WorldGeo.is_explored(w, WorldGeo.to_world("harbor", Vector2(1800, 1300))), "the rest of the world is not")
	# an older save: discovered settlements are marked explored once
	var old := WorldState.create_new("w_r6", 1506)
	old.meta["discoveries"] = {"town": 1}
	old.meta.erase("explored")
	WorldGeo.step(old, Simulation.TICK_RATE)
	check(WorldGeo.is_explored(old, WorldGeo.to_world("town", Vector2(1600, 1000))), "Ashgrove, found before iteration 015, is on the map")
	check(not WorldGeo.is_explored(old, WorldGeo.to_world("junction", Vector2(1600, 1000))), "places not found stay blank")


func test_old_save_positions_stay_valid() -> void:
	# Settlements kept their local coordinates; only their place in the world moved.
	var w := WorldState.create_new("w_r7", 1507)
	var p := _player(w, PID, "town", Vector2(1240, 1510))
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var p2: PlayerState = (res["world"] as WorldState).players[PID]
	eq(p2.region_id, "town", "still in Ashgrove")
	eq(p2.position, p.position, "same spot")
	for rid in ["town", "junction", "greyhollow", "stillwater", "harbor", "homestead", "service_station"]:
		check(Content.region_def(rid).get("vehicle_exits", []).is_empty(), rid + ": no road-end exits left over")


func test_wilderness_has_cabins_landmarks_and_enterable_interiors() -> void:
	var cabins := 0
	var enterable := 0
	for rid in WorldGeo.outdoor_ids():
		var d := Content.region_def(rid)
		if not bool(d.get("wilderness", false)):
			continue
		check(d.has("wild") and (d["wild"]["scatter"] as Array).size() > 500, rid + " is dressed (trees, rocks, cabins)")
		for lm in d.get("map", {}).get("landmarks", []):
			if str(lm.get("kind", "")) == "cabin":
				cabins += 1
				check(bool(lm.get("hidden", false)), "cabins are found, not shown in advance")
		for e in d.get("entities", []):
			if str(e.get("type", "")) == "portal":
				enterable += 1
				var to := str(e["target"]["region"])
				check(Content.region_def(to).get("view", "") == "side", to + " is a side-view interior")
	check(cabins >= 15, "isolated cabins across the wilderness (%d)" % cabins)
	check(enterable >= 10, "many can be entered (%d)" % enterable)
