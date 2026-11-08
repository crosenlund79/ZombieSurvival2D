class_name AnimalView
extends Node2D
## Shows one wild animal from world data (iteration 011 D): interpolated
## position, facing art (side with a two-frame walk, front, back), a small
## head-up pause when alert. Presentation only; WildlifeSim decides behaviour.

## Art ids per species: side frames (face right, flipped for left), front, back.
const ART := {
	"wolf": {"side": ["char.wolf_side_0", "char.wolf_side_1"], "down": "char.wolf_down", "up": "char.wolf_up"},
	"bear": {"side": ["char.bear_side_0", "char.bear_side_1"], "down": "char.bear_down", "up": "char.bear_up"},
}

var animal_id := ""
var _sprite: Sprite2D
var _shown := ""
var _walk := 0.0
var _last := Vector2.ZERO
var _alert := 0.0


static func create(a: AnimalState) -> AnimalView:
	var v := AnimalView.new()
	v.animal_id = a.animal_id
	v.name = "Animal_" + a.animal_id.replace(":", "_")
	v.position = a.position
	v._last = a.position
	return v


func state() -> AnimalState:
	return Session.world.animals.get(animal_id) if Session.world != null else null


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	Assets.reloaded.connect(func() -> void: _shown = "")


var _sight := 1.0


func _process(delta: float) -> void:
	var a := state()
	if a == null:
		return
	if PlayerSight.current != null:
		_sight = move_toward(_sight, PlayerSight.current.visibility(global_position), delta * 3.0)
		modulate.a = _sight
	if position.distance_to(a.position) > 300.0:
		position = a.position
	position = position.lerp(a.position, 1.0 - exp(-10.0 * delta))
	var moved := position.distance_to(_last) / maxf(delta, 0.001)
	_last = position
	var arts: Dictionary = ART.get(a.species, ART["wolf"])
	var id := ""
	var f := a.facing
	if absf(f.x) >= absf(f.y) * 0.8:
		if moved > 12.0:
			_walk += delta * clampf(moved / 40.0, 1.5, 6.0)
		var frames: Array = arts["side"]
		id = frames[int(_walk) % frames.size()]
		_sprite.flip_h = f.x < 0.0
	else:
		id = arts["down"] if f.y > 0.0 else arts["up"]
		_sprite.flip_h = false
	if id != _shown and AssetCatalog.has(id):
		_shown = id
		Assets.apply_to_sprite(_sprite, id)
	# alert: a brief, tense lift; fleeing: a quicker bob
	# iteration 015 E: a warning bear rears up; stalking / attacking moves like running
	_alert = move_toward(_alert, (2.2 if a.activity == "warn" else 1.0) if a.activity in ["alert", "warn"] else 0.0, delta * 4.0)
	var bob := 0.0
	if moved > 12.0:
		bob = -absf(sin(_walk * PI)) * (3.0 if a.activity in ["flee", "attack", "stalk"] else 1.5)
	_sprite.position.y = bob - _alert * 3.0
