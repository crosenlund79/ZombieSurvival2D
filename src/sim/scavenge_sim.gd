class_name ScavengeSim
extends RefCounted
## Physical containers (iteration 013): shelves, cupboards, drawers, lockers,
## crates, toolboxes, fridges, medical cabinets and garage storage placed in the
## Ashgrove interiors (entity type "container").
##
## A container is searched once, by one player at a time, over a few seconds
## (SkillSim.search_seconds: the searcher's Scavenging level). The host commits
## everything:
##   * start   — request_interact on an unsearched container: state {by, from, until}
##   * cancel  — the same request again, or the searcher walks away, leaves the
##               region, gets into a vehicle, dies or disconnects (no reward, no XP)
##   * finish  — step(): state {searched: true, items, gear} = the authored contents,
##               or (iteration 014) a seeded roll from the container's "pool" (LootPools);
##               the searcher gets Scavenging XP once (an empty container still
##               teaches a little, once); noise by container kind
## Afterwards the container is a small shared box: anyone can take what is left
## (request_entity_action "take" / "take_all", Inv.transfer, so nothing duplicates).
## Contents never regenerate — not on re-entry, region change, reload or restart.
##
## Iteration 015 D — progressive discovery: a search reveals one slot at a time
## (the container's finds, plus a few empty slots), each taking a skill-scaled
## moment (SkillSim: slower at low Scavenging, faster later, never instant).
## Revealed finds go straight into the visible contents ("items"/"gear") where
## anyone can take them, so nothing duplicates; what is not yet revealed is never
## stored or sent — it is re-derived from the deterministic roll when its slot
## comes up. A stopped search keeps what it revealed ("revealed"/"total") and
## resumes there; XP only for completing a search, once. Locked containers
## (LockSim) must be unlocked first.
##
## Entity state: {"searched", "items", "gear", "by", "from", "until", "revealed",
## "total", "locked"}. A search in progress when the world is saved resumes later
## from its revealed slots.

const REACH_SLACK := 40.0


static func is_container(def: Dictionary) -> bool:
	return str(def.get("type", "")) == "container"


static func searching(st: Dictionary) -> String:
	return str(st.get("by", ""))


## Search progress 0..1 at the current tick (presentation).
static func progress(world: WorldState, st: Dictionary) -> float:
	var a := int(st.get("from", 0))
	var b := int(st.get("until", 0))
	if searching(st) == "" or b <= a:
		return 0.0
	return clampf(float(world.tick - a) / float(b - a), 0.0, 1.0)


## E on a container (host).
static func request(world: WorldState, p: PlayerState, region: RegionState, eid: String, def: Dictionary) -> Dictionary:
	var st := region.entity_state(eid)
	if bool(st.get("searched", false)):
		return WorldActions._fail("ACTION_ALREADY_SEARCHED")
	if LockSim.is_locked(region, eid):
		return WorldActions._fail("ACTION_LOCKED")
	var by := searching(st)
	if by == p.player_id:
		return _cancel(region, eid, p.player_id, "SEARCH_CANCELLED")
	if by != "" and _active(world, region, eid, by):
		return WorldActions._fail("ACTION_SOMEONE_SEARCHING")
	if p.vehicle_id != "":
		return WorldActions._fail("VEHICLE_FROM_OUTSIDE")
	# One search at a time per player: an older one is abandoned.
	var res := WorldActions._ok()
	for other in Content.entity_ids(region.def_id):
		if other != eid and searching(region.entity_state(other)) == p.player_id:
			region.set_fields(other, {"by": "", "from": 0, "until": 0})
			res["changes"].append({"region_id": region.region_id, "entity_id": other, "cause": "search_cancelled"})
	var total := int(st.get("total", 0))
	if total <= 0:
		total = slot_count(world, region, eid)
	var secs := slot_seconds(p, def, total)
	region.set_fields(eid, {"by": p.player_id, "from": world.tick, "until": world.tick + Simulation.seconds_to_ticks(secs),
		"total": total, "revealed": int(st.get("revealed", 0))})
	res["changes"].append({"region_id": region.region_id, "entity_id": eid, "cause": "search_started"})
	SessionLog.info("scavenge", "search_started", {"entity": eid, "player": p.player_id.substr(0, 6), "slot_seconds": snappedf(secs, 0.01),
		"slots": total, "revealed": int(st.get("revealed", 0))})
	return res


## Everything a container holds, in reveal order: authored loot and gear, then its pool.
static func finds(world: WorldState, region: RegionState, eid: String) -> Array:
	var def := region.entity_def(eid)
	var out: Array = []
	# iteration 015 D: a guaranteed find placed first (a ring of keys, a keycard, a lockpick)
	var extra: Dictionary = def.get("extra", {})
	for item in extra:
		if Items.exists(str(item)) and int(extra[item]) > 0:
			out.append({"item": str(item), "qty": int(extra[item]), "gear": not Items.is_stack(str(item)), "cond": 1.0, "loaded": 0})
	var base := out.size()
	var loot: Dictionary = def.get("loot", {})
	var keys := loot.keys()
	keys.sort()
	for item in keys:
		if Items.exists(str(item)) and int(loot[item]) > 0:
			out.append({"item": str(item), "qty": int(loot[item]), "gear": false, "cond": 1.0, "loaded": 0})
	for g in def.get("gear", []):
		if Items.exists(str(g)):
			out.append({"item": str(g), "qty": 1, "gear": true, "cond": 1.0, "loaded": 0})
	if def.has("pool") and out.size() == base:
		out.append_array(LootPools.roll_list(world, str(def["pool"]), eid))
	return out


## How many slots the search grid has: the finds plus a few that turn out empty.
static func slot_count(world: WorldState, region: RegionState, eid: String) -> int:
	var rng := world.make_rng("slots:" + eid)
	return clampi(finds(world, region, eid).size() + rng.randi_range(1, 3), 3, 10)


## Seconds per revealed slot: the kind's search time spread over its slots (a whole
## search takes a little longer than the old single bar), scaled by the searcher's level.
static func slot_seconds(p: PlayerState, def: Dictionary, total: int) -> float:
	var whole := SkillSim.search_seconds(p, str(def.get("kind", "shelf"))) * 1.4
	return maxf(0.45, whole / float(maxi(1, total)))


## Is `pid` really still searching this container (online, here, close, on foot)?
static func _active(world: WorldState, region: RegionState, eid: String, pid: String) -> bool:
	var p: PlayerState = world.players.get(pid)
	if p == null or not p.online or p.dead or p.vehicle_id != "" or p.region_id != region.region_id:
		return false
	var def := region.entity_def(eid)
	var reach := float(def.get("interact_range", 72.0)) + WorldActions.RANGE_TOLERANCE + REACH_SLACK
	return SideSection.in_reach(region, p.position, Content.entity_position(def), reach)


static func _cancel(region: RegionState, eid: String, pid: String, key: String) -> Dictionary:
	region.set_fields(eid, {"by": "", "from": 0, "until": 0})
	var r := WorldActions._changed(region, eid, "search_cancelled")
	if key != "":
		r["private_notice"] = {"player_id": pid, "key": key, "args": []}
	return r


## Host: advances searches in regions where players are (cheap: a few entities).
static func step(world: WorldState, _ticks: int) -> Array:
	var out: Array = []
	var seen := {}
	for p in world.online_players():
		if seen.has(p.region_id):
			continue
		seen[p.region_id] = true
		var region := world.region(p.region_id)
		if region == null:
			continue
		for eid in Content.entity_ids(region.def_id):
			var st := region.entity_state(eid)
			var by := searching(st)
			if by == "":
				continue
			if not _active(world, region, eid, by):
				out.append(_cancel(region, eid, by, "SEARCH_INTERRUPTED"))
			else:
				# every slot whose time has come (a long step can reveal several)
				for _i in 12:
					var st2 := region.entity_state(eid)
					if searching(st2) == "" or bool(st2.get("searched", false)) or world.tick < int(st2.get("until", 0)):
						break
					out.append(_reveal(world, world.players[by], region, eid))
	return out


## The next slot of a search comes up: a find (into the visible contents) or nothing.
static func _reveal(world: WorldState, p: PlayerState, region: RegionState, eid: String) -> Dictionary:
	var st := region.entity_state(eid)
	var total := maxi(1, int(st.get("total", 1)))
	var idx := int(st.get("revealed", 0))
	var all := finds(world, region, eid)
	var box := {"items": (st.get("items", {}) as Dictionary).duplicate(), "gear": (st.get("gear", []) as Array).duplicate(true)}
	var found := ""
	if idx < all.size():
		LootPools.add_find(world, box, all[idx])
		found = str(all[idx]["item"])
	idx += 1
	if idx >= total:
		region.set_fields(eid, {"items": box["items"], "gear": box["gear"], "revealed": total})
		return _finish(world, p, region, eid)
	var secs := slot_seconds(p, region.entity_def(eid), total)
	var due := int(st.get("until", world.tick))
	region.set_fields(eid, {"items": box["items"], "gear": box["gear"], "revealed": idx, "from": due,
		"until": due + Simulation.seconds_to_ticks(secs)})
	var res := WorldActions._changed(region, eid, "search_revealed")
	res["events"] = [{"kind": "search_reveal", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid, "item": found}]
	return res


static func _finish(world: WorldState, p: PlayerState, region: RegionState, eid: String) -> Dictionary:
	var def := region.entity_def(eid)
	var st := region.entity_state(eid)
	var items: Dictionary = st.get("items", {})
	var gear: Array = st.get("gear", [])
	var all := finds(world, region, eid)
	var n_finds := 0
	for f in all:
		n_finds += int(f.get("qty", 1))  # every piece found counts (as before iteration 015)
	if not st.has("total"):
		# an older save or a direct call: reveal everything at once
		var box := {"items": items.duplicate(), "gear": gear.duplicate(true)}
		for f in all:
			LootPools.add_find(world, box, f)
		items = box["items"]
		gear = box["gear"]
	region.set_fields(eid, {"searched": true, "items": items, "gear": gear, "by": "", "from": 0, "until": 0, "revealed": int(st.get("total", 0))})
	var loud := str(def.get("kind", "")) in (SkillSim.cfg("scavenging").get("loud_kinds", []) as Array)
	ZombieSim.make_noise(world, region.region_id, Content.entity_position(def), "search_loud" if loud else "search")
	var aw := SkillSim.award(world, p, "scavenging", SkillSim.search_xp(n_finds))
	var res := WorldActions._changed(region, eid, "searched")
	res["players"] = [p.player_id]
	res["events"] = [{"kind": "search_done", "player_id": p.player_id, "region_id": region.region_id, "entity_id": eid,
		"xp": int(aw["gained"]), "skill": "scavenging", "level": int(aw["level_after"]),
		"level_up": int(aw["level_after"]) > int(aw["level_before"]), "finds": n_finds}]
	res["private_notice"] = {"player_id": p.player_id, "key": "SEARCH_FOUND" if n_finds > 0 else "SEARCH_EMPTY",
		"args": [describe(items, gear)]}
	if def.has("discovery") and WorldActions.discover(world, str(def["discovery"])):
		res["meta"] = true
	SessionLog.info("scavenge", "searched", {"entity": eid, "player": p.player_id.substr(0, 6), "finds": n_finds,
		"xp": aw["gained"], "level": aw["level_after"]})
	return res


## Saves never hold a search in progress (it is abandoned on load, never completed).
## Works on SaveCodec.encode output; used by SaveService before writing.
static func strip_searches(data: Dictionary) -> void:
	var regions: Dictionary = (data.get("world", {}) as Dictionary).get("regions", {})
	for rid in regions:
		var ents: Dictionary = (regions[rid] as Dictionary).get("entities", {})
		for eid in ents:
			var st: Dictionary = (ents[eid] as Dictionary).get("state", {})
			if st.has("by"):
				st["by"] = ""
				st["from"] = 0
				st["until"] = 0


static func describe(items: Dictionary, gear: Array) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append("%d %s" % [int(items[item]), TranslationServer.translate(Items.name_key(str(item)))])
	for g in gear:
		parts.append(TranslationServer.translate(Items.name_key(str(g.get("item", "")))))
	return ", ".join(parts)


## Taking from a searched container (host). what = item id, gear uid, or "*" for everything that fits.
static func take(world: WorldState, p: PlayerState, region: RegionState, eid: String, what: String) -> Dictionary:
	var st := region.entity_state(eid)
	if not bool(st.get("searched", false)) and int(st.get("revealed", 0)) <= 0:
		return WorldActions._fail("ACTION_SEARCH_FIRST")
	var box := {"items": (st.get("items", {}) as Dictionary).duplicate(), "gear": (st.get("gear", []) as Array).duplicate(true)}
	var moved := 0
	if what == "*":
		for g in (box["gear"] as Array).duplicate():
			moved += Inv.transfer(p, box, false, str(g.get("uid", "")), 0)
		for item in (box["items"] as Dictionary).keys():
			moved += Inv.transfer(p, box, false, str(item), 0)
	else:
		moved = Inv.transfer(p, box, false, what, 0)
	if moved <= 0:
		var left := Inv.box_used(box)
		return WorldActions._fail("ACTION_CARRY_FULL" if left > 0 else "ACTION_NOTHING_THERE", [Items.carry_slots()])
	region.set_fields(eid, {"items": box["items"], "gear": box["gear"]})
	var res := WorldActions._changed(region, eid, "taken")
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	# iteration 015 F: taking from a community's store is theft, if someone sees it
	for lr in FactionSim.noted_take(world, p, region.entity_def(eid)):
		res["events"] = (res.get("events", []) as Array) + (lr.get("events", []) as Array)
		res["private_notice"] = lr["private_notice"]
		res["meta"] = true
	return res
