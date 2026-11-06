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


static var _cone: ImageTexture


## A soft cone pointing +x from the texture centre (headlights, flashlight).
## Rotate the light node to aim it; generated once, no image file needed.
static func cone_texture() -> Texture2D:
	# The beam shape is a replaceable asset (fx.flashlight_cone); the generated cone is the fallback.
	if AssetCatalog.has("fx.flashlight_cone"):
		var t := Assets.texture("fx.flashlight_cone")
		if t != null:
			return t
	if _cone == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var half := deg_to_rad(26.0)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5, y - n * 0.5)
				var r := d.length() / (n * 0.5)
				var a := 0.0
				if d.x > 0.0 and r < 1.0:
					var ang := absf(d.angle())
					var edge := clampf(1.0 - (ang - half * 0.55) / (half * 0.45), 0.0, 1.0) if ang > half * 0.55 else 1.0
					a = edge * pow(1.0 - r, 0.8) * smoothstep(0.0, 0.08, r)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cone = ImageTexture.create_from_image(img)
	return _cone


static func cone_light(color: Color, scale: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = cone_texture()
	l.color = color
	l.texture_scale = scale
	l.energy = energy
	return l
