class_name LightSpot
extends PointLight2D
## A soft scene light (lantern glow, window daylight, ladder shaft) using the
## shared generated radial texture. Presentation only.
## daylight = true: a window — it follows the shared clock and dims in heavy weather.

@export var daylight := false
var _base_energy := 1.0


func _ready() -> void:
	texture = LightFactory.radial_texture()
	_base_energy = energy
	set_process(daylight)


func _process(_delta: float) -> void:
	if Session.world == null:
		return
	var k := lerpf(0.06, 1.0, EnvSim.daylight(Session.world))
	match EnvSim.weather(Session.world):
		"heavy_rain", "thunderstorm", "blizzard":
			k *= 0.7
		"snow", "fog":
			k *= 0.85
	energy = _base_energy * k
