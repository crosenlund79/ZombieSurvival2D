class_name LampView
extends EntityView
## An electric bunker lamp: lit (sprite + bright light) while the bunker has
## power, dark otherwise. Purely a consumer of the logical power state.

var _light: PointLight2D
var _powered := false


func _build() -> void:
	_light = LightSpot.new()
	_light.color = Color(1.0, 0.95, 0.82)
	_light.texture_scale = 3.6
	_light.energy = 0.42
	_light.position = Vector2(0, 46) if _side else Vector2(0, -60)  # side view: the lamp hangs, light falls below it
	add_child(_light)


func _process(_delta: float) -> void:
	var p := InfraSim.is_powered(Session.world, region_id) if Session.world != null else false
	if p != _powered:
		_powered = p
		_refresh("power")


func _refresh(_cause: String) -> void:
	show_art("Main", "world.lamp_on" if _powered else "world.lamp_off")
	_light.visible = _powered
