class_name LightSpot
extends PointLight2D
## A soft scene light (lantern glow, window daylight, ladder shaft) using the
## shared generated radial texture. Presentation only.


func _ready() -> void:
	texture = LightFactory.radial_texture()
