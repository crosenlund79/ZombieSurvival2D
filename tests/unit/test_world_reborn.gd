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


# ---------------------------------------------------------------- B: atmosphere

func test_rural_and_residential_buildings_are_timber() -> void:
	var timber := 0
	var other_homes := 0
	for scene in ["res://scenes/regions/town/town.tscn", "res://scenes/regions/service_station/service_station.tscn",
			"res://scenes/regions/settlements/junction.tscn", "res://scenes/regions/settlements/greyhollow.tscn",
			"res://scenes/regions/settlements/stillwater.tscn", "res://scenes/regions/settlements/harbor.tscn"]:
		var txt := FileAccess.get_file_as_string(scene)
		timber += txt.count('asset_id = "world.cabin_')
		for old in ["world.house_a", "world.house_b", "set.worker_house", "set.rowhouse", "set.town_house_a", "set.harbor_house", "set.quiet_house"]:
			other_homes += txt.count('asset_id = "%s"' % old)
	check(timber >= 20, "timber homes across the settlements (%d)" % timber)
	eq(other_homes, 0, "no clapboard or brick homes left (industrial, civic and harbour buildings keep their own)")


func test_interiors_are_dressed_and_outfitters_reworked() -> void:
	var w := WorldState.create_new("w_r8", 1508)
	for rid in ["town.house_west", "stillwater.outfitters", "harbor.cottage", "wild.corran_forest.hollow_house"]:
		var props: Array = w.region_def(rid).get("side_props", [])
		var walls := props.filter(func(p): return bool(p.get("wall", false)))
		var lamps := props.filter(func(p): return str(p.get("asset", "")) == "side.lamp_hanging")
		check(props.size() >= 8, "%s is furnished (%d props)" % [rid, props.size()])
		check(walls.size() >= 2, "%s has pictures / signs on its walls" % rid)
		check(not lamps.is_empty(), "%s has a ceiling lamp" % rid)
	var o := w.region_def("stillwater.outfitters")
	check(SideSection.flights(w.region("stillwater.outfitters")).size() >= 1, "the outfitters has an upper floor")
	for key in ["rack_coats", "rack_b", "boots", "packs", "stock"]:
		check(Content.entity_ids("stillwater.outfitters").has("stillwater.outfitters." + key), "container %s kept its id" % key)
	check(str(o.get("section", {}).get("exterior", "")) == "side.ext_logs", "timber walls")


func test_camera_cannot_zoom_out_omnisciently() -> void:
	check(SettingsService.ZOOM_MIN >= 0.8, "zoom-out is limited (%.2f)" % SettingsService.ZOOM_MIN)


# ---------------------------------------------------------------- D: scavenging grid, locks

func _run(w: WorldState, seconds: float) -> Array:
	var out: Array = []
	for i in int(ceilf(seconds * Simulation.TICK_RATE)):
		out.append_array(Simulation.advance(w, 1))
	return out


func _at(w: WorldState, p: PlayerState, eid: String) -> void:
	p.position = Content.entity_position(w.region(p.region_id).entity_def(eid)) + Vector2(0, 40)


func test_a_search_reveals_slot_by_slot_and_resumes() -> void:
	var w := WorldState.create_new("w_d1", 1511)
	var p := _player(w, PID, "town.grocery", Vector2.ZERO)
	var eid := "town.grocery.aisle_a"
	var g := w.region("town.grocery")
	_at(w, p, eid)
	var all := ScavengeSim.finds(w, g, eid)
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "the search starts")
	var total := int(g.entity_state(eid).get("total", 0))
	check(total >= all.size() + 1 and total >= 3, "a grid of %d slots for %d finds" % [total, all.size()])
	var slot := ScavengeSim.slot_seconds(p, g.entity_def(eid), total)
	check(slot >= 0.45, "never instant (%.2f s a slot)" % slot)
	eq(Items.total(g.entity_state(eid).get("items", {})), 0, "nothing shown before the first slot comes up")
	_run(w, slot + 0.15)
	eq(int(g.entity_state(eid).get("revealed", 0)), 1, "one slot revealed")
	eq(Items.total(g.entity_state(eid).get("items", {})), int(all[0]["qty"]), "exactly the first find is visible")
	# stop: what was revealed stays, the rest is not stored anywhere
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "E stops")
	_run(w, 6.0)
	eq(int(g.entity_state(eid).get("revealed", 0)), 1, "no progress while stopped")
	eq(SkillSim.xp(p, "scavenging"), 0, "no XP for a partial search")
	check(WorldActions.request_entity_action(w, PID, eid, "take", str(all[0]["item"]))["ok"], "a revealed find can be taken mid-search")
	# resume from the same slot, same grid
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "resumes")
	eq(int(g.entity_state(eid).get("total", 0)), total, "the same grid")
	_run(w, slot * total + 0.5)
	check(bool(g.entity_state(eid).get("searched", false)), "finishes")
	var xp := SkillSim.xp(p, "scavenging")
	check(xp > 0, "XP once, for completing")
	var left := Items.total(g.entity_state(eid).get("items", {}))
	var expect := 0
	for i in range(1, all.size()):
		expect += int(all[i]["qty"])
	eq(left, expect, "the rest of the finds, nothing doubled")
	eq(WorldActions.request_interact(w, PID, eid, -1)["reason"], "ACTION_ALREADY_SEARCHED", "never again")
	eq(SkillSim.xp(p, "scavenging"), xp, "and no more XP")


func test_skill_speeds_the_search_with_diminishing_returns() -> void:
	var p := PlayerState.new()
	var def := {"kind": "shelf"}
	var t1 := ScavengeSim.slot_seconds(p, def, 5)
	SkillSim.set_level(p, "scavenging", 5)
	var t5 := ScavengeSim.slot_seconds(p, def, 5)
	SkillSim.set_level(p, "scavenging", SkillSim.max_level("scavenging"))
	var tmax := ScavengeSim.slot_seconds(p, def, 5)
	check(t1 > t5 and t5 >= tmax, "faster with skill (%.2f > %.2f >= %.2f)" % [t1, t5, tmax])
	check(tmax >= 0.45, "never instant")
	check(t1 - t5 >= t5 - tmax - 0.001, "diminishing returns")


func test_locked_containers_need_a_key_or_a_pick() -> void:
	var w := WorldState.create_new("w_d2", 1512)
	var p := _player(w, PID, "stillwater.police", Vector2.ZERO)
	var eid := "stillwater.police.armory"
	var r := w.region("stillwater.police")
	_at(w, p, eid)
	check(LockSim.is_locked(r, eid), "the armory starts locked")
	eq(WorldActions.request_interact(w, PID, eid, -1)["reason"], "ACTION_LOCKED", "no search while locked")
	eq(WorldActions.request_entity_action(w, PID, eid, "key", "")["reason"], "ACTION_NO_KEY", "no keycard, no key")
	eq(WorldActions.request_entity_action(w, PID, eid, "pick", "0.5")["reason"], "ACTION_NO_LOCKPICK", "no pick without a lockpick")
	p.carried["keycard"] = 1
	var res := WorldActions.request_entity_action(w, PID, eid, "key", "")
	check(res["ok"], "the keycard opens it")
	check(not LockSim.is_locked(r, eid), "unlocked")
	eq(p.carrying("keycard"), 1, "keys are not used up")
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "now it can be searched")
	# persistent
	var back: WorldState = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))["world"]
	check(not LockSim.is_locked(back.region("stillwater.police"), eid), "stays unlocked after a save")
	check(LockSim.is_locked(back.region("stillwater.police"), "stillwater.police.evidence"), "the evidence locker is still locked")


func test_lockpicking_is_decided_by_the_host() -> void:
	var w := WorldState.create_new("w_d3", 1513)
	var p := _player(w, PID, "town.hardware", Vector2.ZERO)
	var eid := "town.hardware.locked_case"
	var r := w.region("town.hardware")
	_at(w, p, eid)
	p.gear.append(Inv.new_gear(w, "lockpick"))
	var def := r.entity_def(eid)
	eq(LockSim.pins(def), 2, "a level 1 lock has two pins")
	# a miss: wear, closeness feedback, no pin
	var s0 := LockSim.sweet(w, eid, 0)
	var far := 0.0 if s0 > 0.5 else 1.0
	var miss := WorldActions.request_entity_action(w, PID, eid, "pick", str(far))
	check(miss["ok"] and str(miss["lock"]["result"]) == "miss", "far off misses")
	check(float(miss["lock"]["closeness"]) < 0.5, "and says it was not close")
	check(float(p.gear[0]["cond"]) < float(Items.info("lockpick").get("durability", 100)), "the pick wears")
	eq(WorldActions.request_entity_action(w, PID, eid, "pick", str(s0))["reason"], "ACTION_TOO_FAST", "no spamming turns")
	_run(w, 0.3)
	var hit := WorldActions.request_entity_action(w, PID, eid, "pick", str(s0))
	eq(str(hit["lock"]["result"]), "set", "the sweet spot sets the pin")
	eq(int(hit["lock"]["set"]), 1, "one of two")
	_run(w, 0.3)
	var st := WorldActions.request_entity_action(w, PID, eid, "status", "")
	eq(int(st["lock"]["set"]), 1, "the host remembers progress for this player")
	var open := WorldActions.request_entity_action(w, PID, eid, "pick", str(LockSim.sweet(w, eid, 1)))
	eq(str(open["lock"]["result"]), "open", "second pin opens it")
	check(not LockSim.is_locked(r, eid), "the real container is unlocked")
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "and can be searched")


func test_a_worn_pick_snaps_and_the_pins_drop() -> void:
	var w := WorldState.create_new("w_d4", 1514)
	var p := _player(w, PID, "stillwater.police", Vector2.ZERO)
	var eid := "stillwater.police.evidence"
	_at(w, p, eid)
	p.gear.append(Inv.new_gear(w, "lockpick"))
	check(WorldActions.request_entity_action(w, PID, eid, "pick", str(LockSim.sweet(w, eid, 0)))["ok"], "one pin set")
	var s1 := LockSim.sweet(w, eid, 1)
	var far := 0.0 if s1 > 0.5 else 1.0
	var broke := false
	for i in 30:
		_run(w, 0.3)
		var res := WorldActions.request_entity_action(w, PID, eid, "pick", str(far))
		if str(res.get("lock", {}).get("result", "")) == "broken":
			broke = true
			break
	check(broke, "repeated bad turns snap the pick")
	check(not p.has_gear_item("lockpick"), "the pick is gone")
	eq(LockSim.progress(w, PID, eid), 0, "and the pins dropped")
	check(LockSim.is_locked(w.region("stillwater.police"), eid), "still locked")


func test_locked_doors_and_old_saves() -> void:
	var w := WorldState.create_new("w_d5", 1515)
	var p := _player(w, PID, "wild.corran_forest", Vector2.ZERO)
	var door := "wild.corran_forest.trapper_door"
	_at(w, p, door)
	eq(WorldActions.request_interact(w, PID, door, -1)["reason"], "ACTION_LOCKED", "a locked cabin door does not open")
	eq(p.region_id, "wild.corran_forest", "you stay outside")
	# a container searched in an older save (before it had a lock) counts as opened
	var r := w.region("town.pharmacy")
	r.set_fields("town.pharmacy.wall_cabinet", {"searched": true})
	check(not LockSim.is_locked(r, "town.pharmacy.wall_cabinet"), "already searched: not locked")
	# keys found where they belong
	var finds := ScavengeSim.finds(w, w.region("town.garage"), "town.garage.office_desk")
	eq(str(finds[0]["item"]), "keys", "the garage office desk holds the keys")


# ---------------------------------------------------------------- E: hordes, hideouts, wildlife, test rifle

func _night(w: WorldState) -> void:
	# jump the clock (directly, no simulation) to 23:00 of the current day
	var day_ticks := int(float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	var h := EnvSim.hour(w)
	w.tick += int(fmod(23.0 - h + 24.0, 24.0) / 24.0 * day_ticks)


func test_a_horde_forms_out_of_sight_and_is_bounded() -> void:
	var w := WorldState.create_new("w_e1", 1521)
	var p := _player(w, PID, "wild.corran_forest", Vector2(7000, 3300))
	var r := HordeSim.form(w, "wild.corran_forest", true)
	check(r["ok"], "a horde forms (%s)" % r.get("reason", ""))
	eq(w.threat.hordes.size(), 1, "one horde")
	var h: Dictionary = w.threat.hordes.values()[0]
	var members: Array = h["members"]
	check(members.size() >= 4 and members.size() <= int(HordeSim.cfg("max_size")), "%d Burnt Ones" % members.size())
	for zid in members:
		var z: ZombieState = w.zombies[zid]
		check(not z.persistent and z.horde == h["id"], "transient horde member")
		check(z.position.distance_to(p.position) >= 980.0, "out of sight (%d px)" % z.position.distance_to(p.position))
	# bounded escalation: days survived never push it past the cap
	w.tick += int(30.0 * float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	check(HordeSim.size_for(w, "wild.corran_forest") <= int(HordeSim.cfg("max_size")), "size capped after 30 days")
	_player(w, "bbbbbbbbbbbbbbbb", "wild.birchwater", Vector2(4000, 2500))
	check(HordeSim.form(w, "wild.birchwater", true)["ok"], "a second horde elsewhere")
	_player(w, "cccccccccccccccc", "wild.stillwater_road", Vector2(6000, 3000))
	eq(HordeSim.form(w, "wild.stillwater_road", true)["reason"], "DEV_HORDE_LIMIT", "never more than two at once")
	eq(HordeSim.form(w, "town.grocery", true)["reason"], "DEV_HORDE_NOT_HERE", "never indoors")
	# not saved
	var back: WorldState = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))["world"]
	eq(back.zombies.values().filter(func(z): return z.horde != "" or not z.persistent).size(), 0, "hordes are never saved")
	eq(back.threat.hordes.size(), 0, "a reload starts calm")


func test_a_horde_closes_in_then_breaks_up() -> void:
	var w := WorldState.create_new("w_e2", 1522)
	var p := _player(w, PID, "wild.corran_forest", Vector2(7000, 3300))
	check(HordeSim.form(w, "wild.corran_forest", true)["ok"], "forms")
	var h: Dictionary = w.threat.hordes.values()[0]
	var dist := func() -> float:
		var t := 0.0
		var n := 0
		for zid in h["members"]:
			var z: ZombieState = w.zombies.get(zid)
			if z != null:
				t += z.position.distance_to(p.position)
				n += 1
		return t / maxf(1.0, n)
	var d0: float = dist.call()
	_run(w, 25.0)
	var d1: float = dist.call()
	check(d1 < d0 - 300.0, "it closes in on the player (%d -> %d px)" % [d0, d1])
	h["born"] = w.tick - int((float(HordeSim.cfg("life_seconds")) + 1.0) * Simulation.TICK_RATE)
	_run(w, 1.2)
	check(bool(h["breaking"]), "after its life it breaks up")


func test_ai_level_of_detail_updates_far_zombies_less_often_but_keeps_them_moving() -> void:
	var w := WorldState.create_new("w_e3", 1523)
	w.threat.enabled = true
	_player(w, PID, "homestead", Vector2(600, 1100))
	var z := ZombieSim.spawn(w, "wild.corran_forest", Vector2(7000, 3300), false)  # nobody there
	z.goal = Vector2(7400, 3300)
	var start := z.position
	_run(w, 0.1)
	check(ZombieSim.lod_counts["near"] == 0 or ZombieSim.lod_counts["away"] >= 0, "counted")
	var away_ticks := 0
	for i in 16:
		Simulation.advance(w, 1)
		away_ticks += int(ZombieSim.lod_counts["away"])
	check(away_ticks <= 4, "a zombie nobody is near is updated about every 8th tick (%d in 16)" % away_ticks)
	_run(w, 10.0)
	check(z.position.distance_to(start) > 20.0, "but it still moves")


func test_three_hideouts_in_different_places_with_dev_reset() -> void:
	var w := WorldState.create_new("w_e4", 1524)
	var hs := HideoutSim.all(w)
	check(hs.size() >= 3, "%d hideouts" % hs.size())
	var places := {}
	for hd in hs:
		places[str(hd[0]).split(".")[0]] = true
	check(places.size() >= 3, "in different settlements %s" % str(places.keys()))
	var rid := "harbor.cottage"
	var r := w.region(rid)
	var p := _player(w, PID, rid, Content.entity_position(r.entity_def("harbor.cottage.exit")))
	SideSection.settle(w, p)
	for i in 6:
		ZombieSim.make_noise(w, rid, p.position, "melee")
	_run(w, 0.5)
	var st := r.entity_state("harbor.cottage.hideout")
	check(bool(st.get("triggered", false)), "the harbour hideout can be disturbed")
	check(not (st.get("zombies", []) as Array).is_empty(), "and its Burnt One emerges")
	var res := HideoutSim.reset(w, rid, "harbor.cottage.hideout")
	check(res["ok"], "dev reset")
	st = r.entity_state("harbor.cottage.hideout")
	check(not bool(st.get("triggered", true)) and float(st.get("disturbance", 1.0)) == 0.0, "back to calm")
	eq(w.zombies.values().filter(func(z): return z.region_id == rid).size(), 0, "its Burnt Ones removed")


func test_a_wolf_pack_hunts_at_night_and_can_be_escaped() -> void:
	var w := WorldState.create_new("w_e5", 1525)
	w.threat.enabled = true
	WildlifeSim.ensure(w)
	_night(w)
	var p := _player(w, PID, "homestead", Vector2(1575, 1130))
	p.position += Vector2(0, 260)
	var hurt := false
	var stalked := false
	for i in 300:
		Simulation.advance(w, 1)
		for a in w.animals.values():
			if a.species == "wolf" and a.activity in ["stalk", "attack"]:
				stalked = true
		if p.health < 100.0:
			hurt = true
			break
	check(stalked, "the pack stalks the player at night")
	check(hurt, "and bites (health %.0f)" % p.health)
	# escape: get well away from their home ground
	p.health = 100.0
	p.position = Vector2(300, 1700)
	_run(w, 3.0)
	var still := w.animals.values().filter(func(a): return a.species == "wolf" and a.activity in ["stalk", "attack"])
	eq(still.size(), 0, "far from their ground they give up")
	# peaceful: harmless again
	w.threat.enabled = false
	p.position = Vector2(1575, 1250)
	_run(w, 10.0)
	eq(p.health, 100.0, "peaceful mode: no attacks")


func test_a_bear_warns_before_it_charges_and_can_be_killed() -> void:
	var w := WorldState.create_new("w_e6", 1526)
	w.threat.enabled = true
	WildlifeSim.ensure(w)
	var bear: AnimalState = null
	for a in w.animals.values():
		if a.species == "bear" and a.region_id == "service_station":
			bear = a
	check(bear != null, "the station's bear")
	var p := _player(w, PID, "service_station", bear.position + Vector2(330, 0))
	_run(w, 0.3)
	eq(bear.activity, "warn", "entering its ground: it warns first")
	eq(p.health, 100.0, "a warning, not a hit")
	p.position = bear.position + Vector2(900, 0)
	_run(w, 0.5)
	check(bear.activity != "warn" and bear.activity != "attack", "back off and it lets you go (%s)" % bear.activity)
	bear.calm = 0.0
	bear.activity = "idle"
	p.position = bear.position + Vector2(150, 0)
	var hit := false
	for i in 80:
		Simulation.advance(w, 1)
		if p.health < 100.0:
			hit = true
			break
	check(hit, "too close: it charges and swipes (%.0f)" % p.health)
	var id := bear.animal_id
	for i in 10:
		WildlifeSim.damage(w, bear, 40.0, p)
		if not w.animals.has(id):
			break
	check(not w.animals.has(id), "it can be killed")


func test_the_test_rifle_start() -> void:
	var w := WorldState.create_new("w_e7", 1527)
	var p := _player(w, PID, "homestead", Vector2(420, 1140))
	w.meta["test_rifle"] = true
	var res := WorldActions.request_interact(w, PID, "homestead.starter_bag", -1)
	check(res["ok"], "the starter bag opens (%s)" % res.get("reason", ""))
	var rifle := p.gear.filter(func(g): return str(g.get("item", "")) == WorldActions.TEST_RIFLE)
	eq(rifle.size(), 1, "an assault rifle in the starter bag")
	eq(int(rifle[0].get("loaded", 0)), int(Firearms.spec(WorldActions.TEST_RIFLE)["capacity"]), "loaded")
	eq(p.carrying("rifle_rounds"), 60, "and spare rounds")
	var w2 := WorldState.create_new("w_e8", 1528)
	var p2 := _player(w2, PID, "homestead", Vector2(420, 1140))
	WorldActions.request_interact(w2, PID, "homestead.starter_bag", -1)
	eq(p2.gear.filter(func(g): return str(g.get("item", "")) == WorldActions.TEST_RIFLE).size(), 0, "not without the test switch")
