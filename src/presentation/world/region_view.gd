class_name RegionView
extends Node2D
## Presentation of one region for the *local* player. Built from WorldState
## and region content; can be freed and rebuilt at any time without losing
## anything (all state lives in Session.world). Other players may be viewing
## other regions — this view only shows players in its own region.
##
## Static regions set region_id in the scene. Bunker levels share one scene per
## level template; the app shell sets region_id and def_id before adding it.

@export var region_id := "homestead"
@export var ambience_id := ""
## Kept for scene compatibility; the camera always frames the region bounds
## (rooms smaller than the view stay centred, larger maps are followed).
@export var camera_limits := true
## Give the local player a small carried light (dark underground spaces).
@export var player_light := false
var def_id := ""

var local_avatar: PlayerAvatar
var _avatars := {}  # player_id -> PlayerAvatar
var _actors: Node2D


static func find_for(node: Node) -> RegionView:
	var n := node.get_parent()
	while n != null and not (n is RegionView):
		n = n.get_parent()
	return n as RegionView


func _enter_tree() -> void:
	if def_id == "":
		var r := Session.world.region(region_id) if Session.world != null else null
		def_id = r.def_id if r != null else region_id


func _ready() -> void:
	_actors = get_node_or_null("YSort")
	if _actors == null:
		_actors = Node2D.new()
		_actors.name = "YSort"
		_actors.y_sort_enabled = true
		add_child(_actors)
	Session.roster_changed.connect(_sync_avatars)
	_sync_avatars()
	if ambience_id != "":
		Audio.play_loop("ambience", ambience_id)
	SessionLog.info("view", "region_view_built", {"region": region_id, "def": def_id})


func bounds() -> Rect2:
	var b: Array = Content.region_def(def_id).get("bounds", [0, 0, 1600, 1100])
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))


func _sync_avatars() -> void:
	if Session.world == null:
		return
	var wanted := {}
	for p in Session.players_in_region(region_id):
		wanted[p.player_id] = true
		if not _avatars.has(p.player_id):
			var local: bool = p.player_id == Session.local_player_id
			if local and p.region_id != region_id:
				continue
			var a := PlayerAvatar.create(p, local, bounds(), player_light)
			_actors.add_child(a)
			_avatars[p.player_id] = a
			if local:
				local_avatar = a
	for pid in _avatars.keys():
		if not wanted.has(pid) and pid != Session.local_player_id:
			(_avatars[pid] as Node).queue_free()
			_avatars.erase(pid)


func avatar_count() -> int:
	return _avatars.size()
