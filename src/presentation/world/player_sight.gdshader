shader_type canvas_item;
// Iteration 015 B: player-centred visibility. Outside what the player can see,
// the world is drawn as a dimmed, cooler, desaturated memory; a soft vignette
// darkens the screen edges. `mask` is the view polygon rendered small (white =
// seen); bilinear filtering of the small mask gives the soft edge.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D mask : filter_linear;
uniform float strength = 1.0;
uniform float vignette = 0.55;
uniform float memory = 0.62;   // how dark remembered (unseen) areas are drawn

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float seen = texture(mask, SCREEN_UV).r;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 mem = mix(c.rgb, vec3(lum), 0.55) * (1.0 - memory * 0.62) + vec3(0.0, 0.01, 0.03) * memory;
	vec3 col = mix(c.rgb, mem, (1.0 - seen) * strength);
	vec2 d = SCREEN_UV - vec2(0.5);
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.32, 0.92, length(d) * 1.15);
	col *= 1.0 - v * vignette * 0.75;
	COLOR = vec4(col, 1.0);
}
