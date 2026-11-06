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
## Interiors with windows (iteration 013): the grade still follows day and night,
## between `tint` (noon) and `indoor_night_tint`, without any outdoor weather effects.
@export var follow_daylight := false
@export var indoor_night_tint := Color(0.16, 0.17, 0.22)
var _outdoor := false
var _rain: Control
var _rain_on := false
var _weather := ""
var _fog_now := 0.0
var _flash := 0.0
var _bolt_done := -1
var _frost_now := 0.0
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
uniform float flash = 0.0;            // lightning (0..1), iteration 011
uniform float frost = 0.0;            // local player's cold (0..1): frost creeping in from the edges
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
	if (frost > 0.0) {
		float fe = smoothstep(0.55 - 0.25 * frost, 0.95, length(d * vec2(1.0, 0.75)) + (g - 0.5) * 0.12);
		c = mix(c, vec3(0.86, 0.92, 0.97), clamp(fe * frost * 0.85, 0.0, 0.85));
	}
	c = c + vec3(0.75, 0.82, 0.95) * flash * (0.35 + 0.65 * l);
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
	match _weather:
		"heavy_rain", "thunderstorm":
			# Long, fast, slightly slanted streaks.
			var n := 300 if _weather == "heavy_rain" else 240
			for i in n:
				var depth := 0.5 + float(i % 5) * 0.25
				var x := fmod(float(i) * 97.3 + t * 120.0 * depth, sz.x + 80.0) - 40.0
				var y := fmod(float(i) * 61.7 + t * (720.0 + float(i % 7) * 40.0) * depth, sz.y + 60.0) - 30.0
				_rain.draw_line(Vector2(x, y), Vector2(x - 4.0 * depth, y + 16.0 * depth), Color(0.74, 0.8, 0.86, 0.22 + depth * 0.18), 1.0 + depth * 0.4)
		"blizzard":
			# Dense, wind-driven snow almost sideways.
			for i in 460:
				var depth := 0.5 + float(i % 5) * 0.3
				var x := fmod(float(i) * 97.3 + t * 260.0 * depth + sin(t * 1.3 + float(i)) * 20.0, sz.x + 120.0) - 60.0
				var y := fmod(float(i) * 61.7 + t * (110.0 + float(i % 7) * 14.0) * depth, sz.y + 40.0) - 20.0
				_rain.draw_line(Vector2(x, y), Vector2(x - 7.0 * depth, y - 1.5 * depth), Color(0.93, 0.95, 0.97, 0.3 + depth * 0.25), 1.4 + depth)
		_:
			# Snowfall.
			for i in 220:
				var depth := 0.5 + float(i % 5) * 0.25
				var x := fmod(float(i) * 97.3 + t * 26.0 * depth + sin(t * 0.7 + float(i)) * 14.0, sz.x + 60.0) - 30.0
				var y := fmod(float(i) * 61.7 + t * (55.0 + float(i % 7) * 9.0) * depth, sz.y + 40.0) - 20.0
				_rain.draw_circle(Vector2(x, y), 1.0 + depth * 0.9, Color(0.93, 0.95, 0.97, 0.35 + depth * 0.25))


const WEATHER_LOOPS := {"snow": "amb.snow_wind", "blizzard": "amb.blizzard", "heavy_rain": "amb.heavy_rain", "thunderstorm": "amb.thunderstorm"}


## Lightning (pure function of seed + clock, so every peer flashes together).
func _lightning(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.5)
	if Session.world == null or EnvSim.weather(Session.world) != "thunderstorm":
		return
	var w := Session.world
	var slot := w.tick / EnvSim.lightning_slot_ticks()
	for s in [slot - 1, slot]:
		if s <= _bolt_done:
			continue
		var b := EnvSim.lightning(w, s)
		if b.is_empty():
			if s < slot:
				_bolt_done = s
			continue
		if w.tick < int(b["tick"]):
			continue
		_bolt_done = s
		if w.tick - int(b["tick"]) > 2 * Simulation.TICK_RATE:
			continue
		_flash = float(b["strength"])
		var near: bool = b["near"]
		get_tree().create_timer(float(b["thunder_delay"])).timeout.connect(func() -> void:
			if is_inside_tree():
				Audio.play("sfx.thunder_near" if near else "sfx.thunder_far"))
		SessionLog.info("weather", "lightning", {"slot": s, "near": near})


func _exit_tree() -> void:
	if _rain_on:
		Audio.stop_loop("weather", 0.5)


func _process(delta: float) -> void:
	var mat := _overlay.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	var ct := get_viewport().get_canvas_transform()
	mat.set_shader_parameter("world_origin", ct.origin)
	mat.set_shader_parameter("world_scale", ct.x.x)
	# Fog: the region's base, thicker in fog / blizzard, denser in forested regions.
	var fog_target := 0.0
	if _outdoor and Session.world != null:
		var view := RegionView.find_for(self)
		var regional := float(EnvSim.climate(Session.world, view.region_id).get("fog", 1.0)) if view != null else 1.0
		fog_target = (fog_strength + float(EnvSim.wcfg(EnvSim.weather(Session.world)).get("fog", 0.0))) * regional
	_fog_now = lerpf(_fog_now, fog_target, 1.0 - exp(-0.6 * delta))
	mat.set_shader_parameter("fog_strength", minf(_fog_now, 0.85))
	# Frost creeping in when the local player is cold (local presentation only).
	var me := Session.local_player()
	var frost_target := 0.0
	if me != null:
		frost_target = clampf((float(SurvivalSim.ec("chilled_below", 40)) - me.warmth) / float(SurvivalSim.ec("chilled_below", 40)), 0.0, 1.0)
	_frost_now = lerpf(_frost_now, frost_target, 1.0 - exp(-1.0 * delta))
	mat.set_shader_parameter("frost", _frost_now)
	if follow_daylight and not _outdoor and Session.world != null:
		var ic := indoor_night_tint.lerp(tint, EnvSim.daylight(Session.world))
		_cm.color = _cm.color.lerp(ic, 1.0 - exp(-1.5 * delta))
	if _outdoor and Session.world != null:
		_lightning(delta)
		mat.set_shader_parameter("flash", _flash)
		var col := night_tint.lerp(tint, EnvSim.daylight(Session.world))
		var wk := EnvSim.weather(Session.world)
		match wk:
			"snow":
				col *= Color(0.86, 0.89, 0.94)
			"heavy_rain", "thunderstorm":
				col *= Color(0.72, 0.76, 0.82)
			"blizzard":
				col *= Color(0.84, 0.87, 0.92)
			"fog":
				col *= Color(0.9, 0.92, 0.94)
		col = col.lerp(Color(1.4, 1.45, 1.6), _flash * 0.5)
		_cm.color = _cm.color.lerp(col, 1.0 - exp(-(9.0 if _flash > 0.05 else 1.5) * delta))
		var falling := EnvSim.is_raining(Session.world)
		if wk != _weather:
			_weather = wk
			_rain.visible = falling
			_rain_on = falling
			if WEATHER_LOOPS.has(wk):
				Audio.play_loop("weather", WEATHER_LOOPS[wk], 2.0)
			else:
				Audio.stop_loop("weather", 2.5)
		if _rain_on:
			_rain.queue_redraw()
	if powered_tint.a > 0.0 and Session.world != null:
		var view := RegionView.find_for(self)
		var on := view != null and InfraSim.is_powered(Session.world, view.region_id)
		_cm.color = _cm.color.lerp(powered_tint if on else tint, 1.0 - exp(-3.0 * delta))
