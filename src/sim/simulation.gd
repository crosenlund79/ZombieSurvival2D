class_name Simulation
extends RefCounted
## The one shared world clock. Only the authority advances it; clients receive
## the tick in snapshots. Timed systems hang off advance() instead of keeping
## their own clocks: construction, zombies/noise/attention (ZombieSim),
## player vitals (SurvivalSim), machines and hydration (InfraSim), production
## by built objects (FarmSim), weather (EnvSim) and container searches (ScavengeSim).

const TICK_RATE := 10  # ticks per real second


## Advances the clock and completes any constructions that are due.
## Returns WorldActions results (one per completed job) for the caller to publish.
static func advance(world: WorldState, ticks: int) -> Array:
	if ticks <= 0:
		return []
	world.tick += ticks
	var done: Array = []
	var remaining: Array = []
	for j in world.jobs:
		if world.tick >= int(j["done_tick"]):
			done.append(j)
		else:
			remaining.append(j)
	world.jobs = remaining
	var results: Array = []
	done.sort_custom(func(a, b): return a["done_tick"] < b["done_tick"])
	for j in done:
		var res := WorldActions.complete_construction(world, j["region_id"], j["entity_id"])
		if res["ok"]:
			results.append(res)
	results.append_array(ZombieSim.step(world, ticks))
	results.append_array(SurvivalSim.step(world, ticks))
	results.append_array(InfraSim.step(world, ticks))
	results.append_array(FarmSim.step(world, ticks))
	results.append_array(EnvSim.step(world, ticks))
	results.append_array(EventSim.step(world, ticks))
	results.append_array(NpcSim.step(world, ticks))
	results.append_array(SleepSim.step(world, ticks))
	results.append_array(VehicleSim.step(world, ticks))
	results.append_array(WildlifeSim.step(world, ticks))
	results.append_array(BloodSim.step(world, ticks))
	results.append_array(ScavengeSim.step(world, ticks))
	results.append_array(HideoutSim.step(world, ticks))
	results.append_array(HordeSim.step(world, ticks))  # iteration 015 E
	results.append_array(WorldGeo.step(world, ticks))
	return results


static func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * TICK_RATE))


static func format_time(world: WorldState) -> String:
	var s := int(world.sim_seconds())
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
