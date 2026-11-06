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


# ---------------------------------------------------------------- D: firearms, hideout

func _armed(w: WorldState, region: String, pos: Vector2, gun := "handgun") -> PlayerState:
	var p := _player(w, PID, region, pos)
	var g := Inv.new_gear(w, gun)
	p.gear.append(g)
	p.equipped["hand"] = g["uid"]
	return p


func test_handgun_reload_fire_ammo_and_noise() -> void:
	var w := WorldState.create_new("w_d1", 431)
	w.threat.enabled = true
	var p := _armed(w, "homestead", Vector2(1200, 1200))
	var g := Firearms.held(p)
	check(not g.is_empty(), "holding a handgun")
	eq(Firearms.loaded(g), 0, "found empty")
	var r := WorldActions.request_attack(w, PID, Vector2.RIGHT)
	eq(r["events"][0]["kind"], "dry_fire", "an empty gun clicks")
	eq(Inv.request(w, PID, "reload", "")["reason"], "ACTION_NO_AMMO", "no rounds, no reload")
	p.carried["ammo_pistol"] = 12
	check(Inv.request(w, PID, "reload", "")["ok"], "reload")
	eq(Firearms.loaded(g), 8, "eight in the magazine")
	eq(p.carrying("ammo_pistol"), 4, "four left in the pocket")
	w.tick += 40
	var z := ZombieSim.spawn(w, "homestead", Vector2(1500, 1200), false)
	var hp := z.health
	w.threat.queue.clear()
	r = WorldActions.request_attack(w, PID, Vector2.RIGHT)
	check(r["ok"], "fire")
	eq(Firearms.loaded(g), 7, "one round used")
	check(z.health < hp, "the Burnt One in the line of fire is hit (%d -> %d)" % [hp, z.health])
	var loud := false
	for n in w.threat.queue:
		loud = loud or str(n.get("category", "")) == "gunshot" and float(n.get("radius", 0)) >= 1000.0
	check(loud, "a gunshot is heard far away")
	eq(WorldActions.request_attack(w, PID, Vector2.RIGHT)["reason"], "ACTION_TOO_FAST", "the trigger needs a moment")
	w.tick += 10
	var miss := WorldActions.request_attack(w, PID, Vector2.LEFT)
	check(miss["ok"] and Firearms.loaded(g) == 6, "a miss still spends a round")
	p.carried["loaded_magazine"] = 1
	w.tick += 20
	check(Inv.request(w, PID, "reload", "")["ok"], "swap in a loaded magazine")
	eq(Firearms.loaded(g), 8, "full again")
	eq(p.carrying("ammo_pistol"), 10, "the six left over went back to the pocket")
	var data := SaveCodec.encode(w)
	var w2: WorldState = SaveCodec.decode(JSON.parse_string(JSON.stringify(data)))["world"]
	eq(Firearms.loaded(Firearms.held(w2.players[PID])), 8, "rounds in the gun survive a save")


func test_shotgun_hits_several_and_rifle_reaches_far() -> void:
	var w := WorldState.create_new("w_d2", 432)
	var p := _armed(w, "homestead", Vector2(1200, 1200), "shotgun")
	p.carried["shotgun_shells"] = 4
	Inv.request(w, PID, "reload", "")
	w.tick += 60
	var a := ZombieSim.spawn(w, "homestead", Vector2(1400, 1190), false)
	var b := ZombieSim.spawn(w, "homestead", Vector2(1420, 1215), false)
	var ha := a.health
	var hb := b.health
	WorldActions.request_attack(w, PID, Vector2.RIGHT)
	check(a.health < ha and b.health < hb, "one blast, two hit")
	var q := _armed(w, "harbor", Vector2(300, 900), "hunting_rifle")  # the open coast road
	q.carried["rifle_rounds"] = 5
	Inv.request(w, PID, "reload", "")
	w.tick += 60
	var far := ZombieSim.spawn(w, "harbor", Vector2(1150, 900), false)
	var hf := far.health
	WorldActions.request_attack(w, PID, Vector2.RIGHT)
	check(far.health < hf, "the rifle reaches 850 px")


func test_hideout_wakes_once_and_follows_you_outside() -> void:
	var w := WorldState.create_new("w_d3", 433)
	w.threat.enabled = true
	var house := w.region("stillwater.quiet_house")
	var hid := "stillwater.quiet_house.hideout"
	check(house.has_entity(hid), "the quiet house hides something")
	var p := _player(w, PID, "stillwater.quiet_house", Content.spawn_point(house.def_id, 0))
	p.position = SideSection.rest(house, p.position)
	var before := w.zombies.size()
	ZombieSim.make_noise(w, house.region_id, p.position, "search")  # a quiet search: not enough
	HideoutSim.step(w, 1)
	eq(w.zombies.size(), before, "a little noise is not enough")
	ZombieSim.make_noise(w, house.region_id, p.position, "search_loud")
	ZombieSim.make_noise(w, house.region_id, p.position, "search_loud")
	var out := HideoutSim.step(w, 1)
	eq(w.zombies.size(), before + 2, "two Burnt Ones emerge")
	check(bool(house.entity_state(hid).get("triggered", false)), "triggered")
	var ids: Array = house.entity_state(hid).get("zombies", [])
	for zid in ids:
		var z: ZombieState = w.zombies[zid]
		eq(z.region_id, "stillwater.quiet_house", "inside the house")
		eq(z.target_player, PID, "hunting the player")
		check(z.persistent, "saved with the world")
	ZombieSim.make_noise(w, house.region_id, p.position, "gunshot")
	HideoutSim.step(w, 1)
	eq(w.zombies.size(), before + 2, "never more than once")
	# flee outside: they make for the door and follow
	var exit := Content.entity_position(house.entity_def("stillwater.quiet_house.exit"))
	p.position = exit
	WorldActions.request_interact(w, PID, "stillwater.quiet_house.exit", -1)
	eq(p.region_id, "stillwater", "the player is outside")
	var followed := 0
	for i in 600:
		Simulation.advance(w, 1)
		followed = 0
		for zid in ids:
			if w.zombies.has(zid) and (w.zombies[zid] as ZombieState).region_id == "stillwater":
				followed += 1
		if followed == ids.size():
			break
	check(followed >= 1, "they follow through the door (%d of %d)" % [followed, ids.size()])
	for zid in ids:
		if w.zombies.has(zid):
			(w.zombies[zid] as ZombieState).health = 0.0
	Simulation.advance(w, 1)
	HideoutSim.step(w, 1)
	var data := SaveCodec.encode(w)
	var w2: WorldState = SaveCodec.decode(JSON.parse_string(JSON.stringify(data)))["world"]
	check(bool(w2.region("stillwater.quiet_house").entity_state(hid).get("triggered", false)), "the hideout stays triggered after a save")


# ---------------------------------------------------------------- E: item catalogue

func test_every_item_has_the_full_catalogue_record() -> void:
	var cats: Dictionary = Items.data().get("categories", {})
	check(Items.ids().size() >= 170, "the complete catalogue (%d items)" % Items.ids().size())
	var bad: Array = []
	for id in Items.ids():
		var info := Items.info(id)
		for k in ["name_key", "desc_key", "cat", "weight", "stack_limit", "icon"]:
			if not info.has(k):
				bad.append("%s lacks %s" % [id, k])
		if not cats.has(str(info.get("cat", ""))):
			bad.append(id + ": unknown category")
		if not AssetCatalog.has(Items.icon_id(id)):
			bad.append(id + ": no icon asset")
		if TranslationServer.translate(Items.name_key(id)) == Items.name_key(id):
			bad.append(id + ": no name text")
		if info.has("slot") and str(info["slot"]) != "" and not (str(info["slot"]) in InventoryPanel.SLOTS):
			bad.append(id + ": unknown slot")
		var fa: Dictionary = info.get("firearm", {})
		if not fa.is_empty() and not Items.exists(str(fa.get("ammo", ""))):
			bad.append(id + ": unknown ammo")
		if str(info.get("slot", "")) == "hand" and not AssetCatalog.has("item." + id):
			bad.append(id + ": no held art")
	eq(bad, [], "every item: id, name, description, category, weight, stack limit, icon")


func test_stack_limits_decide_slots_and_a_backpack_adds_room() -> void:
	var w := WorldState.create_new("w_e1", 501)
	var p := _player(w, PID, "homestead", Vector2(0, 0))
	eq(Items.slots_of("ammo_pistol", 30), 1, "30 pistol rounds share one slot")
	eq(Items.slots_of("ammo_pistol", 31), 2, "the 31st needs another")
	eq(Items.slots_of("wood", 3), 3, "firewood stays one per slot")
	p.carried = {"ammo_pistol": 25}
	eq(Inv.slots_used(p), 1, "a part stack is one slot")
	eq(Inv.room_for(p, "ammo_pistol"), 5 + (Items.carry_slots() - 1) * 30, "room = the rest of the stack + whole stacks")
	var base := Inv.capacity(p)
	var bag := Inv.new_gear(w, "backpack")
	p.gear.append(bag)
	check(Inv.request(w, PID, "equip", str(bag["uid"]))["ok"], "the backpack is worn")
	eq(Inv.capacity(p), base + 10, "a worn backpack adds 10 slots")
	p.carried = {"nails": Items.carry_slots() * 30}
	check(Inv.free_slots(p) > 0, "so a full pocket still has room")
	var box := {"items": {"nails": 40}, "gear": []}
	var before: int = p.carrying("nails") + 40
	Inv.transfer(p, box, false, "nails", 10)
	eq(p.carrying("nails") + Items.amount(box["items"], "nails"), before, "nothing lost or duplicated")


func test_worn_clothes_add_up_to_insulation() -> void:
	var w := WorldState.create_new("w_e2", 502)
	var p := _player(w, PID, "homestead", Vector2.ZERO)
	var coat := Inv.new_gear(w, "winter_coat")
	p.gear.append(coat)
	Inv.request(w, PID, "equip", str(coat["uid"]))
	var coat_only := SurvivalSim.insulation(p)
	for it in ["hat", "insulated_gloves", "boots", "thermal_underwear", "scarf"]:
		var g := Inv.new_gear(w, it)
		p.gear.append(g)
		check(Inv.request(w, PID, "equip", str(g["uid"]))["ok"], "wear " + it)
	check(SurvivalSim.insulation(p) > coat_only, "a full outfit keeps out more cold than the coat alone")
	check(SurvivalSim.insulation(p) <= 0.85, "capped")


func test_new_use_effects_warm_repair_and_light() -> void:
	var w := WorldState.create_new("w_e3", 503)
	var p := _player(w, PID, "homestead", Vector2.ZERO)
	p.warmth = 40.0
	p.carried = {"hand_warmer": 2}
	check(Inv.request(w, PID, "use", "hand_warmer")["ok"], "a heat pack")
	check(p.warmth > 60.0 and p.carrying("hand_warmer") == 1, "warms and is used up")
	var blanket := Inv.new_gear(w, "thermal_blanket")
	p.gear.append(blanket)
	p.warmth = 40.0
	check(Inv.request(w, PID, "use", str(blanket["uid"]))["ok"] and p.find_gear(str(blanket["uid"])) >= 0, "the blanket is kept")
	# maintenance kits restore the held weapon of the right kind
	var gun := Inv.new_gear(w, "handgun")
	gun["cond"] = 100.0
	p.gear.append(gun)
	Inv.request(w, PID, "equip", str(gun["uid"]))
	p.carried["gun_oil"] = 1
	p.carried["sharpening_stone"] = 1
	check(not Inv.request(w, PID, "use", "sharpening_stone")["ok"], "a whetstone does nothing for a gun")
	check(Inv.request(w, PID, "use", "gun_oil")["ok"], "gun oil")
	check(float(gun["cond"]) > 100.0, "restores the gun")
	# glow sticks: snapped (used up), burn out on their own
	p.carried["glow_sticks"] = 2
	check(Inv.request(w, PID, "use", "glow_sticks")["ok"] and p.flashlight, "a glow stick lights")
	eq(p.carrying("glow_sticks"), 1, "one used")
	w.tick = p.light_until + 1
	SurvivalSim.step(w, 1)
	check(not p.flashlight, "and burns out")
	# eating spoiled food hurts
	p.carried["spoiled_food"] = 1
	p.health = 80.0
	Inv.request(w, PID, "use", "spoiled_food")
	check(p.health < 80.0, "spoiled food makes you ill")


func test_tooltips_describe_items() -> void:
	var t := InventoryPanel.describe("handgun", {"loaded": 3, "cond": 200.0})
	check(t.find("3 /") >= 0 or t.find("3 / 8") >= 0, "the tooltip shows the rounds loaded")
	check(InventoryPanel.describe("ammo_pistol").find(TranslationServer.translate("ITEM_HANDGUN")) >= 0, "ammunition names its gun")
	check("BUILD_BARRICADE" in InventoryPanel.crafting_uses("wood"), "materials know what they build")
	check(InventoryPanel.describe("wood").find(TranslationServer.translate("INV_TIP_USED_FOR").split("%")[0]) >= 0, "and the tooltip says so")


# ---------------------------------------------------------------- F: contextual loot

## Every item a player can come by: pools, authored containers and finds, recipes,
## and what the world makes (trees, rain collector, purifier, planter).
func _acquirable(w: WorldState) -> Dictionary:
	var out := LootPools.all_items()
	for k in ["wood", "water_dirty", "water_clean", "potato"]:
		out[k] = true
	var recipes := Craft.recipes()
	for rid in recipes:
		for k2 in (recipes[rid] as Dictionary).get("out", {}):
			out[str(k2)] = true
	for rid2 in w.regions:
		var r: RegionState = w.regions[rid2]
		for eid in Content.entity_ids(r.def_id):
			var d := r.entity_def(eid)
			for key in ["loot", "items"]:
				if d.get(key) is Dictionary:
					for k3 in d[key]:
						out[str(k3)] = true
			if d.get("gear") is Array:
				for k4 in d["gear"]:
					out[str(k4)] = true
	return out


func test_every_item_can_be_found_or_made() -> void:
	var w := WorldState.create_new("w_f1", 601)
	var got := _acquirable(w)
	var missing: Array = []
	for id in Items.ids():
		if not got.has(id):
			missing.append(id)
	eq(missing, [], "every catalogue item has an acquisition route")


func test_every_container_pool_exists() -> void:
	var w := WorldState.create_new("w_f2", 602)
	var bad: Array = []
	var n := 0
	for rid in w.regions:
		var r: RegionState = w.regions[rid]
		for eid in Content.entity_ids(r.def_id):
			var d := r.entity_def(eid)
			if d.has("pool"):
				n += 1
				if not LootPools.has_pool(str(d["pool"])):
					bad.append(eid)
	check(n > 150, "many pooled containers (%d)" % n)
	eq(bad, [], "every pool name resolves")


func test_pool_rolls_are_seeded_contextual_and_balanced() -> void:
	var w := WorldState.create_new("w_f3", 603)
	var a := LootPools.roll(w, "grocery_shelf", "x.shelf_1")
	var w2 := WorldState.create_new("w_f3b", 603)
	var b := LootPools.roll(w2, "grocery_shelf", "x.shelf_1")
	eq(a["items"], b["items"], "same world seed + container -> same contents")
	var empty := 0
	var junk_only := 0
	var guns := 0
	var food_in_grocery := 0
	var junk: Array = LootPools.data()["junk"]
	for i in 400:
		var r := LootPools.roll(w, "home_bedroom", "t.bed_%d" % i)
		var items: Dictionary = r["items"]
		if items.is_empty() and (r["gear"] as Array).is_empty():
			empty += 1
		elif (r["gear"] as Array).is_empty() and items.keys().all(func(k): return k in junk):
			junk_only += 1
		for g in r["gear"]:
			if Firearms.is_firearm(str(g["item"])):
				guns += 1
		var gr := LootPools.roll(w, "grocery_shelf", "t.shelf_%d" % i)
		for k in gr["items"]:
			if Items.category(str(k)) in ["food", "drink"]:
				food_in_grocery += 1
	check(empty > 20, "some containers are empty (%d/400)" % empty)
	check(junk_only > 20, "some hold only junk (%d/400)" % junk_only)
	check(guns >= 1 and guns < 40, "firearms are rare (%d in 400 bedrooms)" % guns)
	check(food_in_grocery > 200, "grocery shelves hold food (%d)" % food_in_grocery)
	var tools_found := 0
	for i2 in 200:
		for g2 in LootPools.roll(w, "workshop_tools", "t.box_%d" % i2)["gear"]:
			if Items.category(str(g2["item"])) == "tool":
				tools_found += 1
	check(tools_found > 30, "workshops hold tools (%d)" % tools_found)


func test_searching_a_pooled_container_rolls_once_and_never_again() -> void:
	var w := WorldState.create_new("w_f4", 604)
	var p := _player(w, PID, "harbor.cannery", Vector2.ZERO)
	var r := w.region("harbor.cannery")
	var eid := ""
	for e in Content.entity_ids(r.def_id):
		var d := r.entity_def(e)
		if d.has("pool") and not bool(r.entity_state(e).get("searched", false)):
			eid = e
			break
	check(eid != "", "an unsearched pooled container")
	p.position = Content.entity_position(r.entity_def(eid))
	check(WorldActions.request_interact(w, PID, eid, -1)["ok"], "search starts")
	w.tick += 2000
	ScavengeSim.step(w, 1)
	var st := r.entity_state(eid)
	check(bool(st.get("searched", false)), "searched")
	var first := JSON.stringify([st.get("items", {}), (st.get("gear", []) as Array).map(func(g): return g["item"])])
	var expect := LootPools.roll(WorldState.create_new("w_f4", 604), str(r.entity_def(eid)["pool"]), eid)
	eq(JSON.stringify([expect["items"], (expect["gear"] as Array).map(func(g): return g["item"])]), first, "the contents are the seeded roll")
	var xp_before := SkillSim.xp(p, "scavenging")
	WorldActions.request_interact(w, PID, eid, -1)
	w.tick += 2000
	ScavengeSim.step(w, 1)
	eq(SkillSim.xp(p, "scavenging"), xp_before, "no XP for searching it again")
	eq(r.entity_state(eid).get("items", {}), st.get("items", {}), "contents unchanged")
