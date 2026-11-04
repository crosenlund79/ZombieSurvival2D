class_name OmenView
extends Node2D
## Plays a region's omens for the local player (Red Thaw). The schedule comes
## from OmenSim (seeded by the shared world seed and clock), so nearby players
## hear the same laugh from the same spot and see the same silhouette on the
## same path; each player's own position decides whether they hear or see it.
## Laughter is positional sound only — there is never anything to find.
## The silhouette is a world sprite in the depth-sorted layer, so houses and
## trees hide it naturally; it simply walks its path and fades.

## Recent omens this window experienced (diagnostics and tests).
static var recent: Array = []

var region_id := ""
var actors: Node2D
var _laugh_done := -1
var _shadow_done := -1
var _shadow: Sprite2D
var _shadow_ev := {}
var _shadow_t := 0.0


static func create(rid: String, actor_layer: Node2D) -> OmenView:
	var v := OmenView.new()
	v.name = "Omens"
	v.region_id = rid
	v.actors = actor_layer
	return v


static func _note(entry: Dictionary) -> void:
	recent.append(entry)
	if recent.size() > 20:
		recent.pop_front()


func _ready() -> void:
	var w := Session.world
	if w != null:  # anything scheduled before we arrived is not replayed
		_laugh_done = w.tick / OmenSim.slot_ticks("laugh") - 1
		_shadow_done = w.tick / OmenSim.slot_ticks("shadow") - 1


func _process(delta: float) -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null or me.region_id != region_id:
		return
	_laughter(w, me)
	_shadows(w, delta)


func _laughter(w: WorldState, me: PlayerState) -> void:
	var slot := w.tick / OmenSim.slot_ticks("laugh")
	for s in [slot - 1, slot]:
		if s <= _laugh_done:
			continue
		var ev := OmenSim.laugh(w, region_id, s)
		if ev.is_empty():
			if s < slot:
				_laugh_done = s
			continue
		if w.tick < int(ev["tick"]):
			continue
		_laugh_done = s
		var near: bool = me.position.distance_to(ev["spot"]) <= float(ev["radius"])
		if near and w.tick - int(ev["tick"]) < 3 * Simulation.TICK_RATE:
			Audio.play(str(ev["sound"]), ev["spot"])
			_note({"kind": "laugh", "slot": s, "spot": [roundi(ev["spot"].x), roundi(ev["spot"].y)], "sound": ev["sound"],
				"distance": roundi(me.position.distance_to(ev["spot"])), "region": region_id})
			SessionLog.info("omen", "laugh", {"slot": s, "sound": ev["sound"], "distance": roundi(me.position.distance_to(ev["spot"]))})


func _shadows(w: WorldState, delta: float) -> void:
	if _shadow != null:
		_shadow_t += delta
		var dur := float(_shadow_ev["seconds"])
		var k := clampf(_shadow_t / dur, 0.0, 1.0)
		_shadow.global_position = (_shadow_ev["from"] as Vector2).lerp(_shadow_ev["to"], k)
		var fade := minf(minf(_shadow_t / 0.7, (dur - _shadow_t) / 0.9), 1.0)
		_shadow.modulate.a = clampf(fade, 0.0, 1.0) * 0.82
		(_shadow.get_child(0) as Sprite2D).position.y = -absf(sin(_shadow_t * 6.0)) * 1.5 + _shadow.get_meta("base_y", 0.0)
		if _shadow_t >= dur:
			_shadow.queue_free()
			_shadow = null
		return
	var slot := w.tick / OmenSim.slot_ticks("shadow")
	for s in [slot - 1, slot]:
		if s <= _shadow_done:
			continue
		var ev := OmenSim.shadow(w, region_id, s)
		if ev.is_empty():
			if s < slot:
				_shadow_done = s
			continue
		if w.tick < int(ev["tick"]):
			continue
		_shadow_done = s
		var late := float(w.tick - int(ev["tick"])) / Simulation.TICK_RATE
		if late >= float(ev["seconds"]):
			continue
		_start_shadow(ev, late)


func _start_shadow(ev: Dictionary, late: float) -> void:
	_shadow_ev = ev
	_shadow_t = late
	_shadow = Sprite2D.new()  # holder node at the feet, so depth sorting uses the ground point
	var art := Sprite2D.new()
	_shadow.add_child(art)
	Assets.apply_to_sprite(art, "char.shadow_figure")
	_shadow.set_meta("base_y", art.position.y)
	art.flip_h = (ev["to"] as Vector2).x < (ev["from"] as Vector2).x
	_shadow.modulate.a = 0.0
	actors.add_child(_shadow)
	_shadow.global_position = ev["from"]
	_note({"kind": "shadow", "slot": ev["slot"], "from": [roundi(ev["from"].x), roundi(ev["from"].y)],
		"to": [roundi(ev["to"].x), roundi(ev["to"].y)], "region": region_id})
	SessionLog.info("omen", "shadow", {"slot": ev["slot"], "seconds": snappedf(float(ev["seconds"]), 0.1)})
