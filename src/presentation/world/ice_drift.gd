class_name IceDrift
extends Node2D
## Icebergs and floes drifting along one lane of open water (iteration 014,
## Port Halden). Presentation only, and needs no state: every piece's position
## is a pure function of the shared world clock, so all players see the same ice
## in the same place, and nothing is saved. The open water itself is blocked by
## the region's collision; the ice is scenery that slowly crosses the channel.

@export var lane_y := 2000.0
## Pixels per second of world time (negative = drifting west).
@export var speed := 8.0
## The stretch of the lane the ice crosses before wrapping round (x from, x to).
@export var span := Vector2(-500, 4100)
@export var asset_ids: Array[String] = ["set.iceberg_a"]
@export var count := 3
@export var lane_seed := 1

var _pieces: Array = []   # [Node2D holder, base_x, y_offset, bob_phase]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = lane_seed
	var length := span.y - span.x
	for i in count:
		var aid := asset_ids[i % asset_ids.size()]
		if not AssetCatalog.has(aid):
			continue
		var holder := Node2D.new()
		var sp := Sprite2D.new()
		Assets.apply_to_sprite(sp, aid)
		if rng.randf() < 0.5:
			sp.flip_h = true
		holder.add_child(sp)
		add_child(holder)
		_pieces.append([holder, span.x + length * (float(i) + rng.randf_range(0.0, 0.6)) / float(count),
			rng.randf_range(-60.0, 60.0), rng.randf_range(0.0, TAU)])
	Assets.reloaded.connect(_reapply)
	_place()


func _reapply() -> void:
	var i := 0
	for p in _pieces:
		var sp: Sprite2D = (p[0] as Node2D).get_child(0)
		Assets.apply_to_sprite(sp, asset_ids[i % asset_ids.size()])
		i += 1


func _process(_delta: float) -> void:
	_place()


## Where a piece is now (also used by tests): base + speed × world seconds, wrapped.
static func position_at(base_x: float, seconds: float, v: float, from_x: float, to_x: float) -> float:
	var length := to_x - from_x
	return from_x + fposmod(base_x - from_x + v * seconds, length)


func _place() -> void:
	var t := Session.world.sim_seconds() if Session.world != null else 0.0
	for p in _pieces:
		var holder: Node2D = p[0]
		var bob := sin(t * 0.25 + float(p[3])) * 3.0
		holder.position = Vector2(position_at(float(p[1]), t, speed, span.x, span.y), lane_y + float(p[2]) + bob)
