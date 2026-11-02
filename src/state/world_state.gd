class_name WorldState
extends RefCounted
## The authoritative shared world as plain data. Lives on the host (or in
## single player); clients hold a read-only replica built from the host's
## snapshots. No scene owns this — views read it and request changes.

var world_id := ""
var world_seed := 0
var tick := 0                 # shared simulation clock (Simulation.TICK_RATE per second)
var created_unix := 0
var content_fingerprint := ""
var regions := {}             # region_id -> RegionState (static regions + created bunker levels)
var players := {}             # player_id -> PlayerState
var bunkers := {}             # bunker_id -> BunkerState
## Timed constructions in progress: [{region_id, entity_id, done_tick}]. Rebuilt
## from entity state (stage "building" + started + ticks) — never saved itself.
var jobs: Array = []
## Runtime-only per-player cooldowns ("<player_id>:<action>" -> tick). Never saved.
var cooldowns := {}


static func create_new(id: String, seed_value: int) -> WorldState:
	var w := WorldState.new()
	w.world_id = id
	w.world_seed = seed_value
	w.created_unix = int(Time.get_unix_time_from_system())
	w.content_fingerprint = Content.fingerprint()
	for rid in Content.region_ids():
		w.ensure_region(rid)
	return w


static func new_world_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(4)
	return "world_%s_%s" % [Time.get_date_string_from_system().replace("-", ""), bytes.hex_encode()]


func ensure_region(region_id: String, def_id: String = "") -> RegionState:
	if not regions.has(region_id):
		regions[region_id] = RegionState.make(region_id, def_id)
	return regions[region_id]


func region(region_id: String) -> RegionState:
	return regions.get(region_id, null)


## Content definition of a region (works for static regions and bunker levels).
func region_def(region_id: String) -> Dictionary:
	var r := region(region_id)
	return r.definition() if r != null else {}


func sim_seconds() -> float:
	return float(tick) / Simulation.TICK_RATE


## Reproducible random stream for one purpose, derived from the world seed.
## The same world + stream name always yields the same sequence, on every peer.
func make_rng(stream: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [world_seed, stream])
	return rng


func online_players() -> Array:
	var out := []
	for id in players:
		if (players[id] as PlayerState).online:
			out.append(players[id])
	return out


# ---------------------------------------------------------------- bunkers

func bunker(bunker_id: String) -> BunkerState:
	return bunkers.get(bunker_id, null)


## Bunker a region belongs to (a level of it, or the region holding its entrance).
func bunker_for_region(region_id: String) -> BunkerState:
	var parsed := BunkerState.parse_region_id(region_id)
	if not parsed.is_empty():
		return bunker(parsed["bunker_id"])
	for id in bunkers:
		if (bunkers[id] as BunkerState).entrance_region == region_id:
			return bunkers[id]
	return null


## Creates a bunker with its first level (-1). Idempotent: returns the existing one.
func create_bunker(bunker_id: String, entrance_region: String, template_id: String) -> BunkerState:
	if bunkers.has(bunker_id):
		return bunkers[bunker_id]
	var b := BunkerState.new()
	b.bunker_id = bunker_id
	b.entrance_region = entrance_region
	b.entrance_entity = bunker_id
	bunkers[bunker_id] = b
	add_level(b, -1, template_id)
	return b


## Adds one level at `depth` (must be free). Returns the new region id or "".
func add_level(b: BunkerState, depth: int, template_id: String) -> String:
	if depth >= 0 or b.has_level(depth) or Content.region_def(Content.level_def_id(template_id)).is_empty():
		return ""
	b.levels[depth] = template_id
	var rid := b.level_region(depth)
	ensure_region(rid, Content.level_def_id(template_id))
	return rid


## Makes sure every bunker level has a RegionState (after loading or on clients).
func ensure_bunker_regions() -> void:
	for id in bunkers:
		var b: BunkerState = bunkers[id]
		for depth in b.levels:
			ensure_region(b.level_region(depth), Content.level_def_id(b.levels[depth]))


# ---------------------------------------------------------------- timed jobs

func rebuild_jobs() -> void:
	jobs.clear()
	for rid in regions:
		var r: RegionState = regions[rid]
		for eid in r.overrides:
			var st := r.entity_state(eid)
			if str(st.get("stage", "")) == "building":
				jobs.append({"region_id": rid, "entity_id": eid,
					"done_tick": int(st.get("started", 0)) + int(st.get("ticks", 0))})


func add_job(region_id: String, entity_id: String, done_tick: int) -> void:
	for j in jobs:
		if j["region_id"] == region_id and j["entity_id"] == entity_id:
			return
	jobs.append({"region_id": region_id, "entity_id": entity_id, "done_tick": done_tick})
