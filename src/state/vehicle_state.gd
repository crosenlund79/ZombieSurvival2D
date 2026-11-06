class_name VehicleState
extends RefCounted
## One vehicle as plain data (iteration 011). The host owns it (VehicleSim);
## the driver's client predicts its motion and reports poses, the host
## validates and broadcasts them. Everything except `speed` is saved.
##
## seats: player ids, index 0 is the driver ("" = empty seat).
## cargo: {"items": {item: n}, "gear": [gear dicts]} — the trunk, same shape
## as a storage container so Inventory.transfer works unchanged.
## locked / key are reserved for a later keys-and-locks feature: today every
## vehicle has its key in the ignition (key = "ignition") and is unlocked.

var vehicle_id := ""
var def_id := "station_wagon"
var region_id := ""
var position := Vector2.ZERO
var rotation := 0.0           # radians, 0 = facing +x (east)
var engine_on := false
var seats: Array = []
var cargo := {"items": {}, "gear": []}
var key := "ignition"
var locked := false
# --- transient ---
var speed := 0.0              # signed px/s along the heading (driver-reported)
var steer := 0.0              # -1..1, presentation only


static func make(id: String, def_id_value: String, region: String, pos: Vector2, rot: float, seat_count: int) -> VehicleState:
	var v := VehicleState.new()
	v.vehicle_id = id
	v.def_id = def_id_value
	v.region_id = region
	v.position = pos
	v.rotation = rot
	v.seats = []
	for i in seat_count:
		v.seats.append("")
	return v


func driver() -> String:
	return str(seats[0]) if not seats.is_empty() else ""


func occupants() -> Array:
	var out := []
	for s in seats:
		if str(s) != "":
			out.append(str(s))
	return out


func seat_of(player_id: String) -> int:
	return seats.find(player_id)


func heading() -> Vector2:
	return Vector2.from_angle(rotation)


func to_dict() -> Dictionary:
	return {"def": def_id, "region_id": region_id,
		"position": [snappedf(position.x, 0.1), snappedf(position.y, 0.1)],
		"rotation": snappedf(rotation, 0.001), "engine_on": engine_on, "seats": seats.duplicate(),
		"cargo": cargo.duplicate(true), "key": key, "locked": locked}


static func from_dict(id: String, d: Dictionary) -> VehicleState:
	var v := VehicleState.new()
	v.vehicle_id = id
	v.def_id = str(d.get("def", "station_wagon"))
	v.region_id = str(d.get("region_id", ""))
	var p: Array = d.get("position", [0, 0]) if d.get("position") is Array else [0, 0]
	v.position = Vector2(float(p[0]), float(p[1])) if p.size() >= 2 else Vector2.ZERO
	v.rotation = float(d.get("rotation", 0.0))
	v.engine_on = bool(d.get("engine_on", false))
	v.seats = []
	for s in d.get("seats", []):
		v.seats.append(str(s))
	var c = d.get("cargo", {})
	if c is Dictionary:
		v.cargo = {"items": (c.get("items", {}) as Dictionary).duplicate(true) if c.get("items") is Dictionary else {},
			"gear": (c.get("gear", []) as Array).duplicate(true) if c.get("gear") is Array else []}
	v.key = str(d.get("key", "ignition"))
	v.locked = bool(d.get("locked", false))
	return v


## Compact row for the frequent unreliable broadcast.
func row() -> Array:
	return [vehicle_id, region_id, snappedf(position.x, 0.1), snappedf(position.y, 0.1), snappedf(rotation, 0.001),
		snappedf(speed, 0.1), engine_on, snappedf(steer, 0.01)]
