class_name Atmosphere
extends Node2D
## Presentation-only mood for a region (Red Thaw: nuclear winter). Outdoors: a cold,
## washed-out grade, slow snowfall, drifting cold fog, paper grain and a vignette;
## falling snow replaces rain. Interiors and the powered bunker use a warm grade
## (warm = true) so heat and light feel rare and meaningful.
## Never affects gameplay or visibility of interactable objects.

@export var tint := Color(0.86, 0.9, 0.96)
## Tint while the bunker this region belongs to has power (electric lights on).
@export var powered_tint := Color(0, 0, 0, 0)
@export var grain_strength := 0.07
@export var vignette_strength := 0.3
@export var contrast := 1.08
@export var saturation := 0.7
## Warm grade (interiors, stove, powered bunker) instead of the cold exterior grade.
@export var warm := false
## Strength of the drifting cold fog (outdoor regions only).
@export var fog_strength := 0.22
@export var drift_amount := 70
@export var drift_texture := "fx.snowflake"
## Night colour grade for outdoor regions (day/night follows the shared clock).
@export var night_tint := Color(0.2, 0.24, 0.36)
var _outdoor := false
var _rain: Control
var _rain_on := false
@export var area := Rect2(0, 0, 2400, 1700)

const OVERLAY_SHADER := """
shader_type canvas_item;
// Screen-space "dirty ink" grade for the world (the HUD sits on a higher layer):
// S-curve contrast, desaturation, split toning (cold or warm), drifting fog that
// is anchored to the world, an ink vignette and paper grain. Presentation only.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform sampler2D fog : repeat_enable, filter_linear;
uniform float grain_strength = 0.07;
uniform float vignette_strength = 0.3;
uniform float contrast = 1.08;
uniform float saturation = 0.7;
uniform float fog_strength = 0.0;
uniform vec3 shadow_tone = vec3(0.84, 0.9, 0.98);
uniform vec3 highlight_tone = vec3(0.98, 1.0, 1.04);
uniform vec3 vignette_tone = vec3(0.42, 0.45, 0.5);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec2 world_origin = vec2(0.0, 0.0);
uniform float world_scale = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	c *= mix(shadow_tone, highlight_tone, smoothstep(0.12, 0.8, l));
	if (fog_strength > 0.0) {
		vec2 wp = (uv * screen_size - world_origin) / world_scale;
		float f1 = texture(fog, wp / 900.0 + vec2(TIME * 0.006, TIME * 0.002)).a;
		float f2 = texture(fog, wp / 1500.0 + vec2(-TIME * 0.004, TIME * 0.003)).a;
		float f = clamp((f1 * 0.6 + f2 * 0.6), 0.0, 1.0) * fog_strength;
		c = mix(c, vec3(0.80, 0.83, 0.86) * (0.55 + 0.45 * smoothstep(0.0, 0.6, l + 0.3)), f);
	}
	float g = texture(grain, uv * screen_size / 256.0).r;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.32, 0.85, length(d * vec2(1.0, 0.8)));
	c = mix(c, c * vignette_tone, clamp(v * vignette_strength * 1.8, 0.0, 1.0));
	c *= 1.0 + (g - 0.5) * grain_strength * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var _overlay: ColorRect


var _cm: CanvasModulate


func _ready() -> void:
	var cm := CanvasModulate.new()
	cm.color = tint
	add_child(cm)
	_cm = cm
	if drift_amount > 0:
		_add_drift()
	_add_overlay()
	var view := RegionView.find_for(self)
	_outdoor = view != null and Session.world != null and Session.world.region_def(view.region_id).has("zombies")
	if _outdoor:
		_add_rain()


func _add_drift() -> void:
	var p := CPUParticles2D.new()
	p.amount = drift_amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.texture = Assets.texture(drift_texture)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area.size * 0.5
	p.position = area.get_center()
	p.direction = Vector2(0.35, 1)
	p.spread = 20.0
	p.gravity = Vector2(3, 6)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.color = Color(1, 1, 1, 0.8)
	p.z_index = 20
	add_child(p)


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	mat.shader = sh
	mat.set_shader_parameter("grain", Assets.texture("fx.paper_grain"))
	mat.set_shader_parameter("grain_strength", grain_strength)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("saturation", saturation)
	if warm:
		mat.set_shader_parameter("shadow_tone", Vector3(0.88, 0.92, 0.96))
		mat.set_shader_parameter("highlight_tone", Vector3(1.08, 1.0, 0.86))
		mat.set_shader_parameter("vignette_tone", Vector3(0.5, 0.44, 0.36))
	mat.set_shader_parameter("fog", Assets.texture("fx.fog"))
	_overlay.material = mat
	layer.add_child(_overlay)


func _add_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_rain = Control.new()
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.draw.connect(_draw_rain)
	_rain.hide()
	layer.add_child(_rain)


func _draw_rain() -> void:
	var sz := _rain.size
	var t := Time.get_ticks_msec() / 1000.0
	# Snowfall (the one weather condition; mechanically it is the old rain spell).
	for i in 220:
		var depth := 0.5 + float(i % 5) * 0.25
		var x := fmod(float(i) * 97.3 + t * 26.0 * depth + sin(t * 0.7 + float(i)) * 14.0, sz.x + 60.0) - 30.0
		var y := fmod(float(i) * 61.7 + t * (55.0 + float(i % 7) * 9.0) * depth, sz.y + 40.0) - 20.0
		_rain.draw_circle(Vector2(x, y), 1.0 + depth * 0.9, Color(0.93, 0.95, 0.97, 0.35 + depth * 0.25))


func _exit_tree() -> void:
	if _rain_on:
		Audio.stop_loop("weather", 0.5)


func _process(delta: float) -> void:
	var mat := _overlay.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	var ct := get_viewport().get_canvas_transform()
	mat.set_shader_parameter("world_origin", ct.origin)
	mat.set_shader_parameter("world_scale", ct.x.x)
	mat.set_shader_parameter("fog_strength", fog_strength if _outdoor else 0.0)
	if _outdoor and Session.world != null:
		var col := night_tint.lerp(tint, EnvSim.daylight(Session.world))
		var raining := EnvSim.is_raining(Session.world)
		if raining:
			col *= Color(0.8, 0.84, 0.9)
		_cm.color = _cm.color.lerp(col, 1.0 - exp(-1.5 * delta))
		if raining != _rain_on:
			_rain_on = raining
			_rain.visible = raining
			if raining:
				Audio.play_loop("weather", "amb.snow_wind", 1.5)
			else:
				Audio.stop_loop("weather", 2.0)
		if _rain_on:
			_rain.queue_redraw()
	if powered_tint.a > 0.0 and Session.world != null:
		var view := RegionView.find_for(self)
		var on := view != null and InfraSim.is_powered(Session.world, view.region_id)
		_cm.color = _cm.color.lerp(powered_tint if on else tint, 1.0 - exp(-3.0 * delta))
