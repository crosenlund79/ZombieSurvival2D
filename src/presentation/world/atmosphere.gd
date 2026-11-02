class_name Atmosphere
extends Node2D
## Presentation-only mood for a region: a warm colour grade, drifting seed
## fluff, a faint paper grain and a soft vignette ("dirty ink" finish).
## Never affects gameplay or visibility of interactable objects.

@export var tint := Color(1.0, 0.97, 0.9)
## Tint while the bunker this region belongs to has power (electric lights on).
@export var powered_tint := Color(0, 0, 0, 0)
@export var grain_strength := 0.07
@export var vignette_strength := 0.28
@export var drift_amount := 36
@export var area := Rect2(0, 0, 2400, 1700)

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform float grain_strength = 0.07;
uniform float vignette_strength = 0.28;
uniform vec2 screen_size = vec2(1280.0, 720.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	float g = texture(grain, uv * screen_size / 256.0).r;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.8)));
	float dark = v * vignette_strength;
	float paper = (g - 0.5) * grain_strength * 2.0;
	COLOR = vec4(vec3(0.12, 0.10, 0.07) * (1.0 - paper), clamp(dark + abs(paper) * 0.6, 0.0, 1.0));
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


func _add_drift() -> void:
	var p := CPUParticles2D.new()
	p.amount = drift_amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.texture = Assets.texture("fx.drift_seed")
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area.size * 0.5
	p.position = area.get_center()
	p.direction = Vector2(1, -0.15)
	p.spread = 25.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	p.color = Color(1, 1, 1, 0.75)
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
	_overlay.material = mat
	layer.add_child(_overlay)


func _process(delta: float) -> void:
	(_overlay.material as ShaderMaterial).set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	if powered_tint.a > 0.0 and Session.world != null:
		var view := RegionView.find_for(self)
		var on := view != null and InfraSim.is_powered(Session.world, view.region_id)
		_cm.color = _cm.color.lerp(powered_tint if on else tint, 1.0 - exp(-3.0 * delta))
