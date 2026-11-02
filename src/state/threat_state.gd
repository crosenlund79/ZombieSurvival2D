class_name ThreatState
extends RefCounted
## World noise and attention (host). Transient by policy: noise events and
## attention are never saved — a reloaded world starts calm.
##
## Noise events are queued by actions (chopping, fighting, running, doors) and
## processed once per simulation tick by ZombieSim: zombies within hearing
## range investigate the *location*, and the event adds attention to the
## coarse zone it happened in. Attention decays over time; thresholds draw in
## nearby zombies first and, if needed, reinforcements from off-screen entries.

const ZONE_SIZE := 320.0

var queue: Array = []        # [{region_id, position, radius, attention, category}]
var zones := {}              # "region|zx|zy" -> attention (float)
var last_spawn := {}         # zone key -> world tick of the last reinforcement wave
var recent: Array = []       # last few processed events (diagnostics only)
## Developer switch (host, transient): false = peaceful, no zombies at all.
var enabled := true


func add_noise(region_id: String, pos: Vector2, radius: float, attention: float, category: String) -> void:
	queue.append({"region_id": region_id, "position": pos, "radius": radius,
		"attention": attention, "category": category})


static func zone_key(region_id: String, pos: Vector2) -> String:
	return "%s|%d|%d" % [region_id, floori(pos.x / ZONE_SIZE), floori(pos.y / ZONE_SIZE)]


static func zone_center(key: String) -> Vector2:
	var parts := key.split("|")
	return Vector2((int(parts[1]) + 0.5) * ZONE_SIZE, (int(parts[2]) + 0.5) * ZONE_SIZE)


func attention_at(region_id: String, pos: Vector2) -> float:
	return float(zones.get(zone_key(region_id, pos), 0.0))


## Highest attention among the zone and its neighbours (what a player "feels").
func local_attention(region_id: String, pos: Vector2) -> float:
	var best := 0.0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			best = maxf(best, attention_at(region_id, pos + Vector2(dx, dy) * ZONE_SIZE))
	return best
