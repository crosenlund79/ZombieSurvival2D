class_name LightFactory
extends RefCounted
## Builds soft 2D point lights from a generated radial gradient (no image file
## needed). Presentation only — light never affects gameplay.

static var _texture: GradientTexture2D


static func radial_texture() -> GradientTexture2D:
	if _texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(0.5, 0.0)
		_texture.width = 256
		_texture.height = 256
	return _texture


static func lantern_light(color: Color, scale: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = radial_texture()
	l.color = color
	l.texture_scale = scale * 2.2
	l.energy = energy
	l.position = Vector2(0, -40)
	return l
