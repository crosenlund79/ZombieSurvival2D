class_name SleepSim
extends RefCounted
## Sleeping through the night (iteration 011). Host-authoritative.
##
## A bed belongs to a shelter group (the cabin and its bunker share "home"; a
## bunker inherits the group of the building its hatch is in). Sleep is only
## possible in the evening or at night.
## - Alone in the world: sleeping starts at once.
## - Someone online is NOT inside the same shelter group: the sleeper gets a
##   private inner-monologue line instead of an error, chosen from what really
##   happened (a recent screech, a storm, the dark) — never invented events.
## - Everyone inside: a vote starts (world.meta.sleep_vote, replicated). Each
##   player answers once; one "no", a timeout, a disconnect or anyone leaving the
##   shelter cancels it. Unanimous yes sleeps.
## Sleeping returns "sleep_ticks" for GameSession, which advances the shared
## simulation to 07:00 in chunks (fuel, crops, crafting, construction, survivor
## work and needs all progress exactly once), then everyone in the group wakes
## rested and warm.

const VOTE_SECONDS := 45.0


static func shelter_group(world: WorldState, region_id: String, guard: int = 0) -> String:
	if world == null or guard > 6:
		return ""
	var def := world.region_def(region_id)
	if def.has("shelter_group"):
		return str(def["shelter_group"])
	var b := world.bunker_for_region(region_id)
	if b != null:
		return shelter_group(world, b.entrance_region, guard + 1)
	return ""


static func vote(world: WorldState) -> Dictionary:
	return world.meta.get("sleep_vote", {})


static func _sleepy_hour(world: WorldState) -> bool:
	var h := EnvSim.hour(world)
	return h >= float(EnvSim.c("sleep_from_hour", 17.0)) or h < float(EnvSim.c("sleep_until_hour", 6.0))


## Someone online who is not in `group`, or null.
static func _outsider(world: WorldState, group: String) -> PlayerState:
	for p in world.online_players():
		if shelter_group(world, p.region_id) != group:
			return p
	return null


## Inner monologue for "someone is still out there", from real recent events only.
static func _outside_line(world: WorldState, who: PlayerState) -> Dictionary:
	var ls: Dictionary = world.meta.get("last_screech", {})
	if not ls.is_empty() and world.tick - int(ls.get("tick", -100000)) < int(6 * 60 * Simulation.TICK_RATE) \
			and str(ls.get("region", "")) == who.region_id:
		return {"key": "SLEEP_OUT_SCREECH", "args": [who.display_name]}
	if EnvSim.weather(world) in ["blizzard", "thunderstorm"]:
		return {"key": "SLEEP_OUT_STORM", "args": [who.display_name]}
	if EnvSim.is_night(world):
		return {"key": "SLEEP_OUT_DARK", "args": [who.display_name]}
	return {"key": "SLEEP_OUT_GENERIC", "args": [who.display_name]}


## A player uses a bed (WorldActions "bed" entity). Returns a WorldActions result.
static func request(world: WorldState, p: PlayerState) -> Dictionary:
	var group := shelter_group(world, p.region_id)
	if group == "":
		return WorldActions._fail("ACTION_NOT_AVAILABLE")
	if not vote(world).is_empty():
		return answer(world, p.player_id, true)
	if not _sleepy_hour(world):
		var r0 := WorldActions._ok()
		r0["notice"] = {"key": "SLEEP_NOT_TIRED", "args": []}
		return r0
	var out := _outsider(world, group)
	if out != null:
		var r1 := WorldActions._ok()
		r1["notice"] = _outside_line(world, out)
		SessionLog.info("sleep", "refused_outside", {"by": p.player_id.substr(0, 6), "outside": out.player_id.substr(0, 6)})
		return r1
	if world.online_players().size() <= 1:
		return _sleep(world, group)
	var id := int(world.meta.get("sleep_vote_seq", 0)) + 1
	world.meta["sleep_vote_seq"] = id
	world.meta["sleep_vote"] = {"id": id, "group": group, "by": p.player_id, "by_name": p.display_name, "yes": [p.player_id],
		"until": world.tick + int(VOTE_SECONDS * Simulation.TICK_RATE)}
	SessionLog.info("sleep", "vote_started", {"id": id, "by": p.player_id.substr(0, 6), "players": world.online_players().size()})
	var r := WorldActions._ok()
	r["meta"] = true
	r["broadcast_notice"] = {"key": "SLEEP_VOTE_STARTED", "args": [p.display_name]}
	return r


## A player answers the vote (yes / no).
static func answer(world: WorldState, player_id: String, yes: bool) -> Dictionary:
	var v := vote(world)
	var p: PlayerState = world.players.get(player_id)
	if v.is_empty() or p == null:
		return WorldActions._fail("SLEEP_NO_VOTE")
	if shelter_group(world, p.region_id) != str(v["group"]):
		return WorldActions._fail("SLEEP_NOT_HERE")
	if not yes:
		return _cancel(world, "SLEEP_DECLINED", [p.display_name])
	var ys: Array = v["yes"]
	if ys.has(player_id):
		return WorldActions._fail("SLEEP_ALREADY_READY")  # no duplicate votes
	ys.append(player_id)
	v["yes"] = ys
	world.meta["sleep_vote"] = v
	return _check(world)


static func _cancel(world: WorldState, key: String, args: Array) -> Dictionary:
	SessionLog.info("sleep", "vote_cancelled", {"reason": key, "id": vote(world).get("id", 0)})
	world.meta.erase("sleep_vote")
	var r := WorldActions._ok()
	r["meta"] = true
	r["broadcast_notice"] = {"key": key, "args": args}
	return r


## Everyone still online and inside said yes -> sleep; otherwise publish progress.
static func _check(world: WorldState) -> Dictionary:
	var v := vote(world)
	for p in world.online_players():
		if not (v["yes"] as Array).has(p.player_id):
			var r := WorldActions._ok()
			r["meta"] = true
			return r
	return _sleep(world, str(v["group"]))


## Host, every tick: a vote ends when it times out or someone leaves the shelter
## (disconnects only shrink the electorate).
static func step(world: WorldState, _ticks: int) -> Array:
	var v := vote(world)
	if v.is_empty():
		return []
	if world.tick >= int(v.get("until", 0)):
		return [_cancel(world, "SLEEP_VOTE_EXPIRED", [])]
	var out := _outsider(world, str(v["group"]))
	if out != null:
		return [_cancel(world, "SLEEP_VOTE_LEFT", [out.display_name])]
	var ys: Array = (v["yes"] as Array).filter(func(id): return world.players.has(id) and (world.players[id] as PlayerState).online)
	if ys.size() != (v["yes"] as Array).size():
		v["yes"] = ys
		world.meta["sleep_vote"] = v
		if ys.is_empty():
			return [_cancel(world, "SLEEP_VOTE_EXPIRED", [])]
		return [_check(world)]
	return []


static func ticks_until_morning(world: WorldState) -> int:
	var wake := float(EnvSim.c("wake_hour", 7.0))
	var hours := fmod(wake - EnvSim.hour(world) + 24.0, 24.0)
	if hours < 0.05:
		hours = 24.0
	return int(hours / 24.0 * float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)


static func _sleep(world: WorldState, group: String) -> Dictionary:
	world.meta.erase("sleep_vote")
	var r := WorldActions._ok()
	r["meta"] = true
	r["sleep_ticks"] = ticks_until_morning(world)
	r["sleep_group"] = group
	SessionLog.info("sleep", "sleeping", {"group": group, "ticks": r["sleep_ticks"], "from_hour": snappedf(EnvSim.hour(world), 0.01)})
	return r


## After the clock jump: everyone in the group wakes rested and warm.
static func wake(world: WorldState, group: String) -> Dictionary:
	var r := WorldActions._ok()
	var woke: Array = []
	for p in world.online_players():
		if shelter_group(world, p.region_id) == group and not p.dead:
			p.health = minf(100.0, p.health + float(EnvSim.c("sleep_heal", 35)))
			p.warmth = 100.0
			woke.append(p.player_id)
	r["vitals"] = woke
	r["env"] = true
	r["broadcast_notice"] = {"key": "SLEEP_WOKE", "args": [EnvSim.clock_text(world)]}
	return r
