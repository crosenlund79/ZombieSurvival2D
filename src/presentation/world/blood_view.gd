class_name BloodView
extends Node2D
## Thawed-blood marks on the snow of one region (iteration 012). Presentation of
## WorldState.blood: small refrozen drops, buried under fresh snow (whitened),
## washed out by rain (paler), and hard to make out in fog or blowing snow or at
## a distance (BloodSim.visibility, from the local player's point of view).
## No markers, glow or HUD hints — just what an attentive eye could notice.

const ART := ["fx.blood_drop_a", "fx.blood_drop_b", "fx.blood_drop_c"]
const SNOW := Color(0.86, 0.88, 0.88)

var region_id := ""
var _marks := {}   # id -> Sprite2D
var _accum := 0.0


static func create(rid: String) -> BloodView:
	var v := BloodView.new()
	v.region_id = rid
	v.name = "BloodTraces"
	v.z_index = -2
	return v


func _ready() -> void:
	Session.blood_changed.connect(_sync)
	Assets.reloaded.connect(func() -> void:
		for id in _marks:
			(_marks[id] as Node).queue_free()
		_marks.clear()
		_sync())
	_sync()


func _sync() -> void:
	if Session.world == null:
		return
	var wanted := {}
	for b in BloodSim.in_region(Session.world, region_id):
		var id := str(b[0])
		wanted[id] = b
		if not _marks.has(id):
			var sp := Sprite2D.new()
			Assets.apply_to_sprite(sp, ART[absi(id.hash()) % ART.size()])
			var holder := Node2D.new()
			holder.position = Vector2(float(b[2]), float(b[3]))
			holder.rotation = float(absi(id.hash()) % 628) / 100.0
			holder.scale = Vector2.ONE * float(b[5])
			holder.add_child(sp)
			add_child(holder)
			_marks[id] = holder
	for id in _marks.keys():
		if not wanted.has(id):
			(_marks[id] as Node).queue_free()
			_marks.erase(id)
	_update_looks()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= 0.25:
		_accum = 0.0
		_update_looks()


func _update_looks() -> void:
	if Session.world == null or _marks.is_empty():
		return
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var viewer: Vector2 = avatar.global_position if avatar != null else Vector2.INF
	for b in BloodSim.in_region(Session.world, region_id):
		var holder: Node2D = _marks.get(str(b[0]))
		if holder == null:
			continue
		var vis := BloodSim.visibility(Session.world, b, viewer) if viewer != Vector2.INF else 0.0
		# buried under fresh snow: whiter; washed by rain: paler
		var col := Color(1, 1, 1).lerp(SNOW * 1.15, float(b[6]) * 0.85)
		col = col.lerp(Color(1.25, 0.95, 0.95), float(b[7]) * 0.6)
		col.a = clampf(vis, 0.0, 1.0) * 0.92
		holder.modulate = col
