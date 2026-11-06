class_name VehicleSim
extends RefCounted
## Host-authoritative vehicles (iteration 011). Filled in by milestone C.


static func heater_on(world: WorldState, vehicle_id: String) -> bool:
	var v = world.vehicles.get(vehicle_id)
	return v != null and bool(v.engine_on)
