class_name SurvivalSim
extends RefCounted
## Host-only player vitals on the shared clock: slow health recovery when not
## recently hurt, and respawn after defeat.
##
## Defeat rule (prototype, deliberately forgiving): a defeated player keeps
## everything they carried and, after RESPAWN_SECONDS, wakes up inside the
## farmhouse (the safe area) at RESPAWN_HEALTH. Nothing is dropped or lost.

const RESPAWN_SECONDS := 5.0
const RESPAWN_HEALTH := 70.0
const RESPAWN_REGION := "homestead.farmhouse"
const REGEN_DELAY_SECONDS := 8.0
const REGEN_PER_SECOND := 1.5


static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	var seconds := float(ticks) / Simulation.TICK_RATE
	for p in world.online_players():
		if p.dead:
			if world.tick >= p.respawn_tick:
				results.append(respawn(world, p))
			continue
		# No recovery while thirsty: clean water matters.
		if p.health < 100.0 and not InfraSim.is_thirsty(p) and world.tick - p.last_hurt_tick >= int(REGEN_DELAY_SECONDS * Simulation.TICK_RATE):
			var before := floorf(p.health)
			p.health = minf(100.0, p.health + REGEN_PER_SECOND * seconds)
			if floorf(p.health) != before and int(p.health) % 5 == 0:
				var r := WorldActions._ok()
				r["vitals"] = [p.player_id]
				results.append(r)
	return results


static func respawn(world: WorldState, p: PlayerState) -> Dictionary:
	p.dead = false
	p.health = RESPAWN_HEALTH
	p.last_hurt_tick = world.tick
	p.region_id = RESPAWN_REGION if world.region(RESPAWN_REGION) != null else Content.DEFAULT_REGION
	p.position = Content.spawn_point(world.region(p.region_id).def_id, 0)
	var r := WorldActions._ok()
	r["vitals"] = [p.player_id]
	r["events"] = [{"kind": "player_respawned", "player_id": p.player_id}]
	r["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": p.position}
	return r
