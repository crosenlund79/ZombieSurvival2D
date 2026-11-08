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
## A second ambience loop (iteration 011), e.g. the cabin's stove under the wind.
@export var ambience2_id := ""
## Kept for scene compatibility; the camera always frames the region bounds
## (rooms smaller than the view stay centred, larger maps are followed).
@export var camera_limits := true
## Give the local player a small carried light (dark underground spaces).
@export var player_light := false
var def_id := ""
## Iteration 012 (experiment): this view draws a bunker level as a side view
## (SideBunkerView). Views read it to place themselves in the cross-section.
var side := false

var local_avatar: PlayerAvatar
var _avatars := {}  # player_id -> PlayerAvatar
var _zombies := {}  # zombie_id -> ZombieView
var _objects := {}  # object_id -> StructureView
var _npcs := {}     # npc_id -> NpcView
var _vehicles := {} # vehicle_id -> VehicleView
var _animals := {}  # animal_id -> AnimalView
var _people := {}   # person_id -> PersonView (iteration 015 F)
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
	_rebuild_walls()
	if not side and not Content.region_def(def_id).has("view"):
		add_child(PlayerSight.create(self))  # iteration 015: what your character can actually see
	_sync_avatars()
	_sync_objects()
	if Content.region_def(def_id).has("zombies"):
		add_child(BloodView.create(region_id))  # iteration 012: thawed-blood marks on the snow
	if Content.region_def(def_id).has("omens"):
		add_child(OmenView.create(region_id, _actors))
	if ambience_id != "":
		Audio.play_loop("ambience", ambience_id)
	if ambience2_id != "":
		Audio.play_loop("ambience2", ambience2_id)
	else:
		Audio.stop_loop("ambience2", 1.0)
	SessionLog.info("view", "region_view_built", {"region": region_id, "def": def_id})


## Iteration 015: outdoor regions take their boundary walls from the world
## geography — closed where nothing lies beyond, set back where a neighbouring
## region continues (so you can walk or drive over the edge into it).
func _rebuild_walls() -> void:
	if side or not WorldGeo.is_outdoor(Content.region_def(def_id)):
		return
	var body := get_node_or_null("Bounds") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "Bounds"
		add_child(body)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for r in WorldGeo.walls(def_id):
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = (r as Rect2).size
		cs.shape = rs
		cs.position = (r as Rect2).get_center()
		body.add_child(cs)


func region_state() -> RegionState:
	return Session.world.region(region_id) if Session.world != null else null


## Bounds as drawn (the side view draws rows shorter).
func screen_bounds() -> Rect2:
	var r := region_state()
	return SideSection.screen_rect(r, bounds()) if side and r != null else bounds()


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
			var a := PlayerAvatar.create(p, local, screen_bounds() if side else bounds(), player_light)
			if side:
				a.side_region_id = region_id
				a.position = a.side_display(p.position)
				a.target_position = a.position
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
	_sync_vehicles()
	_sync_animals()
	_sync_people()


func _sync_animals() -> void:
	if Session.world == null:
		return
	for a in Session.world.animals.values():
		if a.region_id == region_id and not _animals.has(a.animal_id):
			var av := AnimalView.create(a)
			_actors.add_child(av)
			_animals[a.animal_id] = av
	for id in _animals.keys():
		var a2: AnimalState = Session.world.animals.get(id)
		if a2 == null or a2.region_id != region_id or not is_instance_valid(_animals[id]):
			if is_instance_valid(_animals[id]):
				(_animals[id] as Node).queue_free()
			_animals.erase(id)


func _sync_people() -> void:
	if Session.world == null:
		return
	for p in Session.world.people.values():
		if p.region_id == region_id and not _people.has(p.person_id):
			var pv := PersonView.create(p)
			_actors.add_child(pv)
			_people[p.person_id] = pv
	for id in _people.keys():
		var p2: PersonState = Session.world.people.get(id)
		if p2 == null or p2.region_id != region_id or not is_instance_valid(_people[id]):
			if is_instance_valid(_people[id]):
				(_people[id] as Node).queue_free()
			_people.erase(id)


func person_count() -> int:
	return _people.size()


func animal_count() -> int:
	return _animals.size()


func _sync_vehicles() -> void:
	if Session.world == null:
		return
	for v in Session.world.vehicles.values():
		if v.region_id == region_id and not _vehicles.has(v.vehicle_id):
			var vv := VehicleView.create(v)
			_actors.add_child(vv)
			_vehicles[v.vehicle_id] = vv
	for id in _vehicles.keys():
		var v2: VehicleState = Session.world.vehicles.get(id)
		if v2 == null or v2.region_id != region_id or not is_instance_valid(_vehicles[id]):
			if is_instance_valid(_vehicles[id]):
				(_vehicles[id] as Node).queue_free()
			_vehicles.erase(id)


func vehicle_view(vehicle_id: String) -> VehicleView:
	var v = _vehicles.get(vehicle_id)
	return v if v != null and is_instance_valid(v) else null


func vehicle_count() -> int:
	return _vehicles.size()


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
				Audio.play("sfx.burnt_death" if ev["killed"] else "sfx.burnt_hit", v.global_position)
				if ev["killed"]:  # the body hits the snow a moment later (audio inbox clip)
					var at_body := v.global_position
					get_tree().create_timer(0.45).timeout.connect(func() -> void: Audio.play("sfx.body_drop", at_body))
		"screech":
			if str(ev.get("region_id", "")) != region_id:
				return
			var sv2: ZombieView = _zombies.get(ev["zombie_id"])
			var at2 := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
			Audio.play(["sfx.burnt_screech", "sfx.burnt_screech_b", "sfx.burnt_screech_c"][randi() % 3], sv2.global_position if sv2 != null else at2,
				EnvSim.sound_mask_db(Session.world))
			if sv2 != null:
				sv2.screech()
		"shot", "dry_fire", "reload":
			# Iteration 014: firearms — sound, a muzzle flash and a faint tracer.
			if str(ev.get("region_id", "")) != region_id:
				return
			var at5 := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
			if side:
				at5 = SideSection.to_screen(region_state(), at5) + Vector2(0, -44)
			match str(ev["kind"]):
				"shot":
					var snd := str(Firearms.spec(str(ev.get("item", ""))).get("sound", "sfx.gun_pistol"))
					Audio.play(snd, at5)
					var to5 := Vector2(float(ev.get("tx", at5.x)), float(ev.get("ty", at5.y)))
					if side:
						to5 = Vector2(to5.x, at5.y)
					_muzzle(at5, to5)
				"dry_fire":
					Audio.play("sfx.gun_dry", at5)
				"reload":
					Audio.play("sfx.gun_mag_out", at5)
					get_tree().create_timer(0.5).timeout.connect(func() -> void: Audio.play("sfx.gun_mag_in", at5))
		"zombie_through_door":
			if str(ev.get("region_id", "")) == region_id:
				Audio.play("sfx.door_open", Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))))
		"npc_met":
			var nv: Node2D = _npcs.get(str(ev.get("npc_id", "")))
			if nv != null and is_instance_valid(nv):
				Audio.play("sfx.voice_trust", nv.global_position)  # the first frightened whisper
		"animal_call":
			if str(ev.get("region_id", "")) == region_id and str(ev.get("sound", "")) != "":
				Audio.play(str(ev["sound"]), Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))))
		"animal_hit", "animal_killed":
			# iteration 015 E: a wolf or bear struck (a thud; a last cry when killed)
			if str(ev.get("region_id", "")) == region_id:
				var at6 := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
				Audio.play("sfx.struct_hit", at6, -6.0)
				if str(ev["kind"]) == "animal_killed":
					Audio.play("sfx.body_drop", at6)
		"person_shot":
			# iteration 015 F: a raider or guard fires (sound + a brief tracer)
			if str(ev.get("region_id", "")) == region_id:
				var from := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
				Audio.play(str(ev.get("sound", "sfx.gun_rifle")), from)
				_muzzle(from, Vector2(float(ev.get("tx", 0)), float(ev.get("ty", 0))))
		"person_alert":
			if str(ev.get("region_id", "")) == region_id:
				Audio.play("sfx.mutter_a", Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))), -4.0)
		"person_hit", "person_killed":
			if str(ev.get("region_id", "")) == region_id:
				var at7 := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
				Audio.play("sfx.struct_hit", at7, -6.0)
				if str(ev["kind"]) == "person_killed":
					Audio.play("sfx.body_drop", at7)
		"horde_forming":
			# iteration 015 E: the far-off sound of many coming (everyone in that region hears it)
			if str(ev.get("region_id", "")) == region_id:
				Audio.play("sfx.horde_warning")
		"vehicle_door", "vehicle_engine":
			if str(ev.get("region_id", "")) != region_id:
				return
			var at3 := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
			if str(ev["kind"]) == "vehicle_door":
				Audio.play("sfx.car_door", at3)
			else:
				Audio.play("sfx.engine_start" if bool(ev.get("on", false)) else "sfx.engine_stop", at3)
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



## A muzzle flash (a short, hard light) and a faint tracer line. Presentation only.
func _muzzle(from: Vector2, to: Vector2) -> void:
	var l := PointLight2D.new()
	l.set_script(LightSpot)
	l.color = Color(1.0, 0.86, 0.6)
	l.energy = 1.6
	l.texture_scale = 2.0
	l.position = from
	add_child(l)
	var line := Line2D.new()
	line.points = PackedVector2Array([from + (to - from).normalized() * 30.0, to])
	line.width = 1.5
	line.default_color = Color(1.0, 0.92, 0.75, 0.55)
	line.z_index = 20
	add_child(line)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, 0.09)
	tw.parallel().tween_property(line, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		l.queue_free()
		line.queue_free())
