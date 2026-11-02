class_name TreeView
extends EntityView
## A harvestable tree (tree entity). Each interaction is one chop request; the
## host counts chops, fells the tree once and gives its wood to whoever landed
## the last blow. Presentation: shake + chips per chop, a simple fall
## animation, then a stump. Collision comes from the footprints, not the art.

@export var tree_asset := "env.tree_oak_a"
@export var stump_asset := "env.tree_stump"
@export var flip_h := false
@export var trunk_footprint := Vector2(36, 14)

var _tree: Prop
var _stump: Prop
var _chips: CPUParticles2D
var _falling := false


func _build() -> void:
	_tree = Prop.new()
	_tree.asset_id = tree_asset
	_tree.flip_h = flip_h
	_tree.occlude = true
	_tree.sway = true
	_tree.footprint = trunk_footprint
	add_child(_tree)
	_stump = Prop.new()
	_stump.asset_id = stump_asset
	_stump.footprint = Vector2(trunk_footprint.x, 10)
	_stump.visible = false
	add_child(_stump)
	_chips = CPUParticles2D.new()
	_chips.emitting = false
	_chips.one_shot = true
	_chips.amount = 10
	_chips.lifetime = 0.6
	_chips.explosiveness = 0.95
	_chips.position = Vector2(0, -30)
	_chips.direction = Vector2(0, -1)
	_chips.spread = 70.0
	_chips.gravity = Vector2(0, 420)
	_chips.initial_velocity_min = 80.0
	_chips.initial_velocity_max = 160.0
	_chips.scale_amount_min = 2.0
	_chips.scale_amount_max = 4.0
	_chips.color = Color("#C69464")
	_chips.z_index = 5
	add_child(_chips)


func _refresh(cause: String) -> void:
	var st := state()
	var felled := bool(st.get("felled", false))
	if interact != null:
		interact.enabled = not felled
		interact.prompt_key = "PROMPT_CHOP"
		interact.prompt_args = [maxi(0, int(def.get("chops", 5)) - int(st.get("chops", 0)))]
	match cause:
		"chop":
			_chop_fx()
		"felled":
			_chop_fx()
			_fall()
			return
	if not _falling:
		_tree.visible = not felled
		_stump.visible = felled
		_set_tree_collision(not felled)


func _chop_fx() -> void:
	Audio.play("sfx.chop", global_position)
	_chips.restart()
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_tree, "rotation", deg_to_rad(2.5 if i % 2 == 0 else -2.0), 0.05)
	tw.tween_property(_tree, "rotation", 0.0, 0.06)


func _fall() -> void:
	_falling = true
	_set_tree_collision(false)
	_stump.visible = true
	Audio.play("sfx.tree_fall", global_position)
	var dir := -1.0 if flip_h else 1.0
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_tree, "rotation", deg_to_rad(88.0 * dir), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_tree, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		_tree.visible = false
		_tree.rotation = 0.0
		_tree.modulate.a = 1.0
		_falling = false)


func _set_tree_collision(on: bool) -> void:
	for c in _tree.get_children(true):
		if c is StaticBody2D:
			for s in c.get_children():
				if s is CollisionShape2D:
					(s as CollisionShape2D).set_deferred("disabled", not on)
