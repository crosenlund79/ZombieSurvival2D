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
var _zombies := {}  # zombie_id -> ZombieView
var _objects := {}  # object_id -> StructureView
var _npcs := {}     # npc_id -> NpcView
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
	Session.vitals_changed.connect(func(_p: String) -> void: _refresh_vitals())
	Session.combat_event.connect(_on_combat_event)
	Session.object_changed.connect(_on_object_changed)
	_sync_avatars()
	_sync_objects()
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


func _process(_delta: float) -> void:
	_sync_zombies()
	_sync_npcs()


func _sync_npcs() -> void:
	if Session.world == null:
		return
	for n in Session.world.npcs.values():
		if n.region_id == region_id and not _npcs.has(n.npc_id):
			var v := NpcView.create(n.npc_id)
			_actors.add_child(v)
			_npcs[n.npc_id] = v
	for id in _npcs.keys():
		var n2: NpcState = Session.world.npcs.get(id)
		if n2 == null or n2.region_id != region_id or not is_instance_valid(_npcs[id]):
			if is_instance_valid(_npcs[id]):
				(_npcs[id] as Node).queue_free()
			_npcs.erase(id)


func npc_count() -> int:
	return _npcs.size()


## Keeps one ZombieView per zombie in this region (world data is the truth).
func _sync_zombies() -> void:
	if Session.world == null:
		return
	for z in Session.world.zombies.values():
		if z.region_id == region_id and not _zombies.has(z.zombie_id):
			var v := ZombieView.new()
			v.name = "Zombie_" + z.zombie_id
			v.setup(z)
			_actors.add_child(v)
			_zombies[z.zombie_id] = v
	for id in _zombies.keys():
		var z: ZombieState = Session.world.zombies.get(id)
		if z == null or z.region_id != region_id:
			(_zombies[id] as Node).queue_free()
			_zombies.erase(id)


## One StructureView per built object / ground pile of this region.
func _sync_objects() -> void:
	var r := Session.world.region(region_id) if Session.world != null else null
	if r == null:
		return
	for oid in r.objects:
		if not _objects.has(oid):
			var v := StructureView.create(region_id, oid)
			_actors.add_child(v)
			_objects[oid] = v
	for oid2 in _objects.keys():
		if not r.objects.has(oid2) or not is_instance_valid(_objects[oid2]):
			if is_instance_valid(_objects[oid2]):
				(_objects[oid2] as Node).queue_free()
			_objects.erase(oid2)


func _on_object_changed(rid: String, _oid: String) -> void:
	if rid == region_id:
		_sync_objects()


func structure_view(oid: String) -> StructureView:
	var v = _objects.get(oid)
	return v if v != null and is_instance_valid(v) else null


func object_count() -> int:
	return _objects.size()


func zombie_count() -> int:
	return _zombies.size()


func _refresh_vitals() -> void:
	for pid in _avatars:
		var p: PlayerState = Session.world.players.get(pid)
		if p != null:
			(_avatars[pid] as PlayerAvatar).set_downed(p.dead)
			(_avatars[pid] as PlayerAvatar).refresh_weapon()


func _on_combat_event(ev: Dictionary) -> void:
	match str(ev.get("kind", "")):
		"swing":
			var a: PlayerAvatar = _avatars.get(ev["player_id"])
			if a != null and not a.is_local:  # the local swing already played on key press
				a.play_swing(ev["aim"])
		"zombie_hit":
			var v: ZombieView = _zombies.get(ev["zombie_id"])
			if v != null:
				v.hit_flash()
				Audio.play("sfx.zombie_death" if ev["killed"] else "sfx.zombie_hit", v.global_position)
		"player_hit":
			var a2: PlayerAvatar = _avatars.get(ev["player_id"])
			if a2 != null:
				a2.hurt_flash()
				Audio.play("sfx.player_hurt", a2.global_position)
		"player_died":
			var a3: PlayerAvatar = _avatars.get(ev["player_id"])
			if a3 != null:
				a3.set_downed(true)
		"struct_hit", "struct_destroyed", "build_started", "build_done", "upgraded", "repaired", "trap_hit", "door_toggled", "dismantled", "crop_ripe", "watered":
			if str(ev.get("region_id", "")) != region_id:
				return
			var at := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
			var sv := structure_view(str(ev.get("oid", "")))
			match str(ev["kind"]):
				"struct_hit":
					Audio.play("sfx.struct_hit", at)
					if sv != null:
						sv.hit_flash()
				"struct_destroyed":
					Audio.play("sfx.struct_break", at)
				"build_started":
					Audio.play("sfx.build_hammer", at)
				"build_done":
					Audio.play("sfx.build_done", at)
				"upgraded":
					Audio.play("sfx.upgrade", at)
				"repaired":
					Audio.play("sfx.build_hammer", at)
				"trap_hit":
					Audio.play("sfx.spikes", at)
				"door_toggled":
					Audio.play("sfx.door_open" if bool(ev.get("open", false)) else "sfx.door_close", at)
				"dismantled":
					Audio.play("sfx.build_hammer", at)
				"watered":
					Audio.play("sfx.water_pour", at)


func avatar_count() -> int:
	return _avatars.size()
