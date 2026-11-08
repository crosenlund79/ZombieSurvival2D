extends TestCase
## Iteration 013 "The Scavenger's Circuit": Ashgrove interiors, physical
## containers (timed, persistent searches) and the Scavenging skill.

const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"
const SHOPS := ["grocery", "pharmacy", "hardware", "clothing", "garage", "house_west", "house_east"]


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _run(w: WorldState, seconds: float) -> Array:
	var out: Array = []
	for i in int(ceilf(seconds * Simulation.TICK_RATE)):
		out.append_array(Simulation.advance(w, 1))
	return out


## Stands the player at a container's front and starts searching it.
func _start(w: WorldState, p: PlayerState, eid: String) -> Dictionary:
	var region := w.region(p.region_id)
	p.position = Content.entity_position(region.entity_def(eid)) + Vector2(0, 40)
	return WorldActions.request_interact(w, p.player_id, eid, -1)


func _contents(w: WorldState, rid: String) -> Dictionary:
	var total := {}
	var region := w.region(rid)
	for eid in Content.entity_ids(region.def_id):
		var d := region.entity_def(eid)
		if ScavengeSim.is_container(d):
			for item in (d.get("loot", {}) as Dictionary):
				total[item] = int(total.get(item, 0)) + int(d["loot"][item])
	return total


func test_every_store_and_house_is_enterable_and_leads_back() -> void:
	var w := WorldState.create_new("w_i1", 131)
	var p := _player(w, PID, "town", Vector2.ZERO)
	var town := w.region("town")
	for name in SHOPS:
		var entry := "town.%s_entrance" % name
		check(town.has_entity(entry), entry + " exists on the street")
		var d := town.entity_def(entry)
		if d.has("requires_open"):
			p.position = Content.entity_position(town.entity_def(str(d["requires_open"])))
			WorldActions.request_interact(w, PID, str(d["requires_open"]), town.rev(str(d["requires_open"])))
		p.region_id = "town"
		p.position = Content.entity_position(d)
		var r := WorldActions.request_interact(w, PID, entry, -1)
		check(r["ok"], "entering " + name)
		eq(p.region_id, "town." + name, "now inside " + name)
		var inside := w.region(p.region_id)
		check(not inside.definition().has("zombies"), name + ": Burnt Ones never wander inside")
		check(float(EnvSim.climate(w, p.region_id).get("shelter", 1.0)) < 0.5, name + ": sheltered from the wind")
		eq(str(inside.definition().get("surface", {}).get("region", "")), "town", name + ": sound leaks to the street")
		var ex := "town.%s.exit" % name
		p.position = Content.entity_position(inside.entity_def(ex))
		check(WorldActions.request_interact(w, PID, ex, -1)["ok"], "leaving " + name)
		eq(p.region_id, "town", "back on the street")
		check(p.position.distance_to(Content.entity_position(d)) < 80.0, name + ": you come out at its own door")


func test_old_street_search_spots_are_gone() -> void:
	var town := WorldState.create_new("w_i2", 132).region("town")
	for eid in ["town.grocery_shelves", "town.hardware_case", "town.clothing_stockroom", "town.pharmacy_counter", "town.garage_bench"]:
		check(not town.has_entity(eid), eid + " moved inside")


func test_loot_fits_the_location() -> void:
	var w := WorldState.create_new("w_i3", 133)
	var food := ["canned_food", "crackers", "water_bottle", "water_clean", "water_dirty"]
	for item in _contents(w, "town.grocery"):
		check(item in food, "grocery holds food and water, not " + str(item))
	check(_contents(w, "town.pharmacy").has("bandage"), "the pharmacy has bandages")
	var hw := _contents(w, "town.hardware")
	check(hw.has("wood") and hw.has("scrap_metal") and hw.has("electrical_parts"), "hardware: wood, fasteners, electrical")
	check(_contents(w, "town.clothing").has("cloth"), "clothing: fabric")
	var gar := _contents(w, "town.garage")
	check(gar.has("scrap_metal") and gar.has("fuel"), "garage: scrap and fuel")
	var case_def := w.region("town.hardware").entity_def("town.hardware.locked_case")
	check("flashlight" in case_def.get("gear", []), "the hardware case still holds the flashlight")
	var coat := w.region("town.clothing").entity_def("town.clothing.stockroom_crate")
	check("winter_coat" in coat.get("gear", []), "the clothing stockroom still holds the winter coat")
	# some containers were picked clean before you got there
	var pre := 0
	for name in SHOPS:
		var region := w.region("town." + name)
		for eid in Content.entity_ids(region.def_id):
			if ScavengeSim.is_container(region.entity_def(eid)) and bool(region.entity_state(eid).get("searched", false)):
				pre += 1
	check(pre >= 7, "several containers are already empty (%d)" % pre)


func test_a_search_takes_time_then_reveals_the_contents() -> void:
	var w := WorldState.create_new("w_i4", 134)
	var p := _player(w, PID, "town.grocery", Vector2.ZERO)
	var eid := "town.grocery.aisle_a"
	var r := _start(w, p, eid)
	check(r["ok"], "the search starts")
	var region := w.region("town.grocery")
	eq(ScavengeSim.searching(region.entity_state(eid)), PID, "it is mine")
	_run(w, 4.0)
	check(not bool(region.entity_state(eid).get("searched", false)), "not done after 4 s at level 1")
	eq(p.carrying("canned_food"), 0, "nothing handed out early")
	var out := _run(w, 3.4)
	check(bool(region.entity_state(eid).get("searched", false)), "done after about 7 s (iteration 015: slot by slot, 1.4x)")
	eq((region.entity_state(eid).get("items", {}) as Dictionary), {"canned_food": 2, "crackers": 1}, "the real contents are revealed")
	check(out.any(func(x): return not (x.get("events", []) as Array).is_empty() and str(x["events"][0].get("kind", "")) == "search_done"), "a search_done event")
	check(SkillSim.xp(p, "scavenging") > 0, "Scavenging XP for a completed search")
	var xp1 := SkillSim.xp(p, "scavenging")
	eq(WorldActions.request_interact(w, PID, eid, -1)["reason"], "ACTION_ALREADY_SEARCHED", "no second search")
	eq(SkillSim.xp(p, "scavenging"), xp1, "no XP for re-opening")
	# take: one item, then everything; nothing duplicates
	check(WorldActions.request_entity_action(w, PID, eid, "take", "crackers")["ok"], "take crackers")
	check(WorldActions.request_entity_action(w, PID, eid, "take", "*")["ok"], "take the rest")
	eq(p.carrying("canned_food") + p.carrying("crackers"), 3, "exactly what was there")
	eq(Items.total(region.entity_state(eid).get("items", {})), 0, "and it is gone from the shelf")
	eq(WorldActions.request_entity_action(w, PID, eid, "take", "*")["reason"], "ACTION_NOTHING_THERE", "empty now")


func test_cancel_and_interrupt_give_nothing() -> void:
	var w := WorldState.create_new("w_i5", 135)
	var p := _player(w, PID, "town.pharmacy", Vector2.ZERO)
	var eid := "town.pharmacy.dispensary_a"
	var region := w.region("town.pharmacy")
	_start(w, p, eid)
	_run(w, 2.0)
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "pressing E again stops")
	eq(ScavengeSim.searching(region.entity_state(eid)), "", "no longer searching")
	_run(w, 6.0)
	check(not bool(region.entity_state(eid).get("searched", false)), "still unsearched")
	eq(SkillSim.xp(p, "scavenging"), 0, "a cancelled search gives no XP")
	_start(w, p, eid)
	_run(w, 1.0)
	p.position += Vector2(600, 0)  # walk away (side view: along the floor)
	_run(w, 0.3)
	eq(ScavengeSim.searching(region.entity_state(eid)), "", "walking away interrupts")
	_start(w, p, eid)
	p.online = false
	_run(w, 6.0)
	check(not bool(region.entity_state(eid).get("searched", false)), "disconnecting abandons it")
	eq(SkillSim.xp(p, "scavenging"), 0, "and gives no XP")


func test_one_searcher_per_container_but_two_containers_at_once() -> void:
	var w := WorldState.create_new("w_i6", 136)
	var a := _player(w, PID, "town.garage", Vector2.ZERO)
	var b := _player(w, PID2, "town.garage", Vector2.ZERO)
	check(_start(w, a, "town.garage.tool_chest")["ok"], "A searches the tool chest")
	eq(_start(w, b, "town.garage.tool_chest")["reason"], "ACTION_SOMEONE_SEARCHING", "B must wait")
	check(_start(w, b, "town.garage.parts_shelf")["ok"], "B searches the shelf meanwhile")
	_run(w, 11.0)
	var g := w.region("town.garage")
	check(bool(g.entity_state("town.garage.tool_chest").get("searched", false)), "A finished")
	check(bool(g.entity_state("town.garage.parts_shelf").get("searched", false)), "B finished")
	check(SkillSim.xp(a, "scavenging") > 0 and SkillSim.xp(b, "scavenging") > 0, "each earns their own XP")
	var xa := SkillSim.xp(a, "scavenging")
	# B takes from A's container: shared box, still no extra XP for anyone
	b.position = Content.entity_position(g.entity_def("town.garage.tool_chest")) + Vector2(0, 40)
	check(WorldActions.request_entity_action(w, PID2, "town.garage.tool_chest", "take", "*")["ok"], "B can take what A found")
	eq(SkillSim.xp(a, "scavenging"), xa, "A's XP unchanged")
	eq(WorldActions.request_entity_action(w, PID, "town.garage.tool_chest", "take", "*")["reason"], "ACTION_NOTHING_THERE", "nothing twice")


func test_empty_containers_teach_once_and_pre_searched_never() -> void:
	var w := WorldState.create_new("w_i7", 137)
	var p := _player(w, PID, "town.hardware", Vector2.ZERO)
	eq(_start(w, p, "town.hardware.aisle_bare")["reason"], "ACTION_ALREADY_SEARCHED", "pre-searched shelf: nothing to search")
	eq(SkillSim.xp(p, "scavenging"), 0, "and no XP")
	# an unsearched container with nothing in it (the town house pantry is pre-searched; use a cleared def)
	var h := w.region("town.house_east")
	_player(w, PID2, "town.house_east", Vector2.ZERO)
	var q: PlayerState = w.players[PID2]
	check(_start(w, q, "town.house_east.dresser")["ok"], "search a dresser")
	_run(w, 6.0)
	var x := SkillSim.xp(q, "scavenging")
	check(x > 0, "XP once")
	check(bool(h.entity_state("town.house_east.dresser").get("searched", false)), "searched for good")


func test_search_time_curve() -> void:
	var t1 := SkillSim.search_seconds_at("shelf", 1)
	var t2 := SkillSim.search_seconds_at("shelf", 2)
	var t3 := SkillSim.search_seconds_at("shelf", 3)
	var t9 := SkillSim.search_seconds_at("shelf", 9)
	var t10 := SkillSim.search_seconds_at("shelf", 10)
	check(absf(t1 - 5.0) < 0.01, "level 1: about 5 s for an ordinary search (%.2f)" % t1)
	check(t1 - t2 >= 0.6, "the first level-up is clearly felt (%.2f -> %.2f)" % [t1, t2])
	check((t1 - t2) > (t9 - t10), "diminishing returns")
	check(t10 >= 1.5 and t10 <= 2.0, "high level: 1.5–2 s (%.2f)" % t10)
	check(SkillSim.search_seconds_at("toolbox", 1) > t1, "a tool chest takes longer than a shelf")
	check(SkillSim.search_seconds_at("drawer", 10) >= float(SkillSim.cfg("scavenging").get("min_seconds", 1.2)), "never instant")
	eq(SkillSim.search_seconds_at("shelf", 99), t10, "level cap")
	var p := PlayerState.new()
	eq(SkillSim.level(p, "scavenging"), 1, "everyone starts at level 1")
	SkillSim.set_level(p, "scavenging", 4)
	eq(SkillSim.level(p, "scavenging"), 4, "set level")
	SkillSim.award(null, p, "scavenging", 100000, true)
	eq(SkillSim.level(p, "scavenging"), SkillSim.max_level("scavenging"), "capped at the max level")
	check(SkillSim.progress(p, "scavenging")["max"], "progress knows it is maxed")
	SkillSim.reset(p, "scavenging")
	eq(SkillSim.xp(p, "scavenging"), 0, "reset")


func test_xp_multiplier_scales_only_new_awards() -> void:
	var w := WorldState.create_new("w_i8", 138)
	var p := _player(w, PID, "town", Vector2.ZERO)
	eq(SkillSim.multiplier(w), 1.0, "default 1x")
	SkillSim.award(w, p, "scavenging", 10)
	eq(SkillSim.xp(p, "scavenging"), 10, "1x")
	w.meta["xp_multiplier"] = 5.0
	eq(SkillSim.xp(p, "scavenging"), 10, "not retroactive")
	SkillSim.award(w, p, "scavenging", 10)
	eq(SkillSim.xp(p, "scavenging"), 60, "5x on the next award")
	w.meta["xp_multiplier"] = 0.0
	SkillSim.award(w, p, "scavenging", 10)
	eq(SkillSim.xp(p, "scavenging"), 60, "0x gives nothing")
	eq(SkillSim.clamp_multiplier(40.0), 25.0, "max 25x")
	eq(SkillSim.clamp_multiplier(-1.0), 0.0, "min 0x")


func test_containers_and_skills_survive_a_save() -> void:
	var w := WorldState.create_new("w_i9", 139)
	var p := _player(w, PID, "town.clothing", Vector2.ZERO)
	_start(w, p, "town.clothing.rack_coats")
	_run(w, 9.0)
	_start(w, p, "town.clothing.stock_boxes")
	_run(w, 2.0)  # mid-search when saved
	w.meta["xp_multiplier"] = 10.0
	var xp := SkillSim.xp(p, "scavenging")
	var data := SaveCodec.encode(w)
	((data["world"] as Dictionary)["meta"] as Dictionary).erase("xp_multiplier")  # as SaveService writes it
	ScavengeSim.strip_searches(data)
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(data)))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	var c := w2.region("town.clothing")
	check(bool(c.entity_state("town.clothing.rack_coats").get("searched", false)), "searched stays searched")
	eq(Items.total(c.entity_state("town.clothing.rack_coats").get("items", {})), 2, "with what is left inside")
	eq(SkillSim.xp(w2.players[PID], "scavenging"), xp, "XP saved")
	eq(SkillSim.multiplier(w2), 1.0, "the XP multiplier is back to 1x")
	var p2: PlayerState = w2.players[PID]
	p2.online = true
	_run(w2, 0.2)
	eq(ScavengeSim.searching(c.entity_state("town.clothing.stock_boxes")), "", "a half-done search is abandoned, not completed")
	check(not bool(c.entity_state("town.clothing.stock_boxes").get("searched", false)), "and the boxes are still unsearched")


func test_search_noise_reaches_the_street() -> void:
	var w := WorldState.create_new("w_i10", 140)
	var p := _player(w, PID, "town.garage", Vector2.ZERO)
	_start(w, p, "town.garage.scrap_crate")
	var g := w.region("town.garage")
	var heard := false
	for i in 100:
		Simulation.advance(w, 1)
		if bool(g.entity_state("town.garage.scrap_crate").get("searched", false)):
			for n in w.threat.queue:
				heard = heard or (str(n.get("region_id", "")) == "town" and str(n.get("category", "")).begins_with("search_loud"))
			break
	check(heard, "rummaging through a crate is heard on the street")


func test_skills_screen_text() -> void:
	var p := PlayerState.new()
	var r: Dictionary = SkillsPanel.rows_for(p)[0]
	eq(r["skill"], "scavenging", "Scavenging is listed")
	eq(r["level"], 1, "level 1 to start")
	check(str(r["lines"][0]).contains("30"), "XP to the next level is shown: " + str(r["lines"][0]))
	check(str(r["lines"][1]).contains("5.0"), "the search time is shown: " + str(r["lines"][1]))
	SkillSim.award(null, p, "scavenging", 40, true)
	r = SkillsPanel.rows_for(p)[0]
	eq(r["level"], 2, "level 2 after 40 XP")
	check(float(r["fraction"]) > 0.0 and float(r["fraction"]) < 1.0, "partway to level 3")
	SkillSim.set_level(p, "scavenging", 10)
	r = SkillsPanel.rows_for(p)[0]
	eq(r["fraction"], 1.0, "full bar at the top level")


# ---------------------------------------------------------------- milestone D: trunk + stove

func test_trunk_load_and_unload_everything() -> void:
	var w := WorldState.create_new("w_d1", 141)
	VehicleSim.ensure(w)
	var v: VehicleState = w.vehicles["wagon"]
	var p := _player(w, PID, v.region_id, v.position + Vector2(0, 90))
	p.carried = {"canned_food": 4, "scrap_metal": 6, "wood": 5}
	var torch := Inv.new_gear(w, "flashlight")
	var coat := Inv.new_gear(w, "winter_coat")
	p.gear = [torch, coat]
	p.equipped = {"hand": torch["uid"]}
	var r := VehicleSim.request(w, PID, "wagon", "store_all")
	check(r["ok"], "load everything")
	eq(Items.total(v.cargo["items"]) + (v.cargo["gear"] as Array).size(), 12, "the trunk takes exactly 12")
	eq(Items.total(p.carried) + Items.total(v.cargo["items"]), 15, "nothing lost or duplicated")
	check(p.gear.any(func(g): return g["uid"] == torch["uid"]), "the flashlight in hand stays with you")
	eq(VehicleSim.request(w, PID, "wagon", "store_all")["reason"], "VEHICLE_TRUNK_FULL", "full trunk says so")
	check(VehicleSim.request(w, PID, "wagon", "take_all")["ok"], "unload everything")
	eq(Items.total(v.cargo.get("items", {})) + (v.cargo.get("gear", []) as Array).size(), 0, "trunk empty")
	eq(p.carrying("canned_food") + p.carrying("scrap_metal") + p.carrying("wood"), 15, "all back on the player")
	check(p.gear.any(func(g): return g["uid"] == coat["uid"]), "the coat came back too")


func test_stove_needs_scavenged_parts_and_heats_the_shelter() -> void:
	var w := WorldState.create_new("w_d2", 142)
	WorldActions.ensure_prebuilt_shelters(w)
	var b := w.bunker("town.house.cellar")
	var lv := b.level_region(-1)
	var reg := w.region(lv)
	var room := SideSection.room_rect(reg)
	var spot := Vector2(room.get_center().x, room.end.y - 30.0)
	var p := _player(w, PID, lv, spot + Vector2(60, 0))
	p.warmth = 40.0
	var before := SurvivalSim.warmth_rate(w, p)
	b.resources = {"scrap_metal": 3, "cement": 1}
	var r := Build.request_build(w, PID, "stove", spot)
	check(not r["ok"], "no stove without a stovepipe (%s)" % r["reason"])
	b.resources["stovepipe"] = 1
	r = Build.request_build(w, PID, "stove", spot)
	check(r["ok"], "the stove is built from scavenged parts (%s)" % r.get("reason", ""))
	eq(b.amount("stovepipe") + b.amount("scrap_metal") + b.amount("cement"), 0, "parts consumed exactly once")
	check(not Build.heated(w, lv), "not warm while it is being built")
	_run(w, 7.0)
	check(Build.heated(w, lv), "lit once finished")
	var after := SurvivalSim.warmth_rate(w, p)
	check(after >= before + 10.0, "you warm up much faster (%.1f -> %.1f / min)" % [before, after])
	var data := SaveCodec.encode(w)
	var w2: WorldState = SaveCodec.decode(JSON.parse_string(JSON.stringify(data)))["world"]
	check(Build.heated(w2, lv), "the stove survives a save")


func test_stovepipes_are_found_in_ashgrove() -> void:
	var w := WorldState.create_new("w_d3", 143)
	var n := 0
	for name in SHOPS:
		n += int(_contents(w, "town." + name).get("stovepipe", 0))
	check(n >= 2, "stovepipes in Ashgrove (%d)" % n)
	check(_contents(w, "town.hardware").has("stovepipe"), "the hardware store has one")
