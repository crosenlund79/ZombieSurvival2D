class_name EntityView
extends Node2D
## Base for views of one world entity (tree, hatch, stockpile, ladder, support).
## Reads position and reach from the region's content definition and the
## current state from Session.world; never changes state itself — the
## Interactable it creates only *requests* actions from the host.
## Subclasses override _build() once and _refresh(cause) on every change.

@export var entity_id := ""
## Floor-level art (hatches, slabs, mats) draws beneath characters instead of depth-sorting.
@export var floor_art := false
## Fade the art while the local player stands behind it (tall objects).
@export var occlude := false
var _fade := 1.0

var region_id := ""
var def_id := ""
var def := {}
var interact: Interactable
var _art_root: Node2D


func _ready() -> void:
	var view := RegionView.find_for(self)
	region_id = view.region_id if view != null else Content.DEFAULT_REGION
	def_id = view.def_id if view != null else region_id
	def = Content.entity_def(def_id, entity_id)
	if def.is_empty():
		SessionLog.error("world", "view_without_entity", {"entity": entity_id, "def": def_id, "node": str(get_path())})
		return
	position = Content.entity_position(def)
	_art_root = Node2D.new()
	_art_root.name = "Art"
	if floor_art:
		_art_root.z_index = -1
	add_child(_art_root)
	_build()
	if def.has("interact_range"):
		interact = Interactable.new()
		interact.setup(def_id, entity_id)
		interact.prompt_key = str(def.get("prompt_key", "PROMPT_USE"))
		interact.focus_changed.connect(func(f: bool) -> void:
			_art_root.modulate = Color(1.25, 1.18, 1.0) if f else Color.WHITE)
		add_child(interact)
	Session.entity_changed.connect(_on_entity_changed)
	Session.bunker_changed.connect(func(_b: String) -> void: _refresh("bunker"))
	Assets.reloaded.connect(func() -> void: _refresh("assets"))
	_refresh("")


func _process(delta: float) -> void:
	if not occlude or _art_root == null:
		return
	var main: Sprite2D = _art_root.get_node_or_null("Main")
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var target := 1.0
	if main != null and avatar != null:
		var local := to_local(avatar.global_position)
		var r := Rect2(main.position, main.texture.get_size() * main.scale) if main.texture != null else Rect2()
		if local.y < -4.0 and r.grow_individual(-8, 0, -8, 0).has_point(local + Vector2(0, -30)):
			target = 0.42
	_fade = move_toward(_fade, target, delta * 3.0)
	_art_root.modulate.a = _fade


func region_state() -> RegionState:
	return Session.world.region(region_id) if Session.world != null else null


func state() -> Dictionary:
	var r := region_state()
	return r.entity_state(entity_id) if r != null else {}


## Ids of other entities whose changes should also refresh this view.
func _watched_entities() -> Array:
	return []


func _on_entity_changed(rid: String, eid: String, _state: Dictionary, cause: String) -> void:
	if rid != region_id:
		return
	if eid == entity_id:
		_refresh(cause)
	elif eid in _watched_entities():
		_refresh("watched")


## Shows one asset in a sprite under the art root (creates it on first use).
func show_art(sprite_name: String, asset_id: String, offset := Vector2.ZERO) -> Sprite2D:
	var s: Sprite2D = _art_root.get_node_or_null(sprite_name)
	if s == null:
		s = Sprite2D.new()
		s.name = sprite_name
		_art_root.add_child(s)
	Assets.apply_to_sprite(s, asset_id)
	s.position += offset
	s.visible = true
	return s


func hide_art(sprite_name: String) -> void:
	var s: Node2D = _art_root.get_node_or_null(sprite_name)
	if s != null:
		s.visible = false


## Progress of a timed construction (stage "building"), 0..1, from the shared clock.
func build_progress() -> float:
	var st := state()
	var ticks := maxi(1, int(st.get("ticks", 1)))
	return clampf(float(Session.world.tick - int(st.get("started", 0))) / ticks, 0.0, 1.0)


func _build() -> void:
	pass


func _refresh(_cause: String) -> void:
	pass
