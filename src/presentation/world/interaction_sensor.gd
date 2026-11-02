class_name InteractionSensor
extends Node
## Lives on the local player's avatar. Picks exactly one focused Interactable:
## highest priority first, then nearest, within each target's reach.

var focused: Interactable = null
var avatar: Node2D


func _ready() -> void:
	add_to_group("local_sensor")
	avatar = get_parent()


func _process(_delta: float) -> void:
	var best: Interactable = null
	var best_dist := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var d := avatar.global_position.distance_to(it.global_position)
		if d > it.reach:
			continue
		if best == null or it.priority > best.priority or (it.priority == best.priority and d < best_dist):
			best = it
			best_dist = d
	if best != focused:
		if focused != null and is_instance_valid(focused):
			focused.set_focused(false)
		focused = best
		if focused != null:
			focused.set_focused(true)


func _unhandled_input(event: InputEvent) -> void:
	if PlayerAvatar.input_blocked or BuildMode.placing != "":
		return
	if event.is_action_pressed("repair") and focused != null and focused.on_repair.is_valid() and focused.secondary_key != "":
		get_viewport().set_input_as_handled()
		focused.on_repair.call()
		return
	if event.is_action_pressed("interact") and focused != null:
		get_viewport().set_input_as_handled()
		focused.activate()  # may change region and free this view: do nothing after it
