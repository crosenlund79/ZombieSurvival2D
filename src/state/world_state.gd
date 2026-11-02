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
var regions := {}             # region_id -> RegionState
var players := {}             # player_id -> PlayerState


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


func ensure_region(region_id: String) -> RegionState:
	if not regions.has(region_id):
		var r := RegionState.new()
		r.region_id = region_id
		regions[region_id] = r
	return regions[region_id]


func region(region_id: String) -> RegionState:
	return regions.get(region_id, null)


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
