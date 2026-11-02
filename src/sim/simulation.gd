class_name Simulation
extends RefCounted
## The one shared world clock. Only the authority advances it; clients receive
## the tick in snapshots. Future timed systems (production, schedules, events)
## must hang off advance() instead of keeping their own clocks.

const TICK_RATE := 10  # ticks per real second


static func advance(world: WorldState, ticks: int) -> void:
	if ticks <= 0:
		return
	world.tick += ticks
	# Extension point: scheduled events / timed systems step here, in tick order.


static func format_time(world: WorldState) -> String:
	var s := int(world.sim_seconds())
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
