shader_type canvas_item;
// Focus highlight (iteration 011 D): a soft warm ink-light rim around the
// sprite and a slight lift, breathing slowly. Applied only to the one
// interactable the local player would use (InteractionSensor focus).
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float strength = 0.75;
uniform float width = 4.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float m = 0.0;
	m = max(m, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	m = max(m, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	m = max(m, texture(TEXTURE, UV + px * 0.7).a);
	m = max(m, texture(TEXTURE, UV - px * 0.7).a);
	m = max(m, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
	m = max(m, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
	float rim = clamp(m - c.a, 0.0, 1.0);
	float pulse = 0.8 + 0.2 * sin(TIME * 2.6);
	vec3 lifted = c.rgb * (1.0 + 0.10 * pulse);
	float ra = rim * strength * pulse;
	vec4 outc = vec4(mix(lifted, rim_color.rgb, ra / max(c.a + ra, 0.001)), max(c.a, ra));
	COLOR = outc;  // COLOR already holds the texture sample here; the rim lies outside it
}
