shader_type canvas_item;
// Burnt One silhouette (iteration 012). The figure is drawn as a dark, inked
// shape: only a whisper of its form value survives (no colour, no face, no
// clothing detail), and light — moon, flashlight, headlights, lamps, fire —
// catches only its outline, never the interior. Lightning lifts the whole
// screen evenly, so the inside stays flat. The art itself is untouched (it
// can still be replaced); this is presentation only.

uniform vec4 ink : source_color = vec4(0.055, 0.048, 0.045, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // hit flash / wind-up warmth
uniform float form = 0.12;       // how much of the drawn light/dark form survives (0 = flat)
uniform float rim_width = 3.0;   // outline band, in texture pixels
uniform float rim_base = 0.14;   // faint outline even in the dark
uniform float rim_light = 0.6;   // how strongly light catches the outline
uniform float grain = 0.05;

varying float v_rim;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
	float mn = 1.0;
	mn = min(mn, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	mn = min(mn, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	mn = min(mn, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	mn = min(mn, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	mn = min(mn, texture(TEXTURE, UV + px * 0.7).a);
	mn = min(mn, texture(TEXTURE, UV - px * 0.7).a);
	float rim = clamp(c.a - mn, 0.0, 1.0);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float n = (hash(floor(UV / TEXTURE_PIXEL_SIZE / 3.0)) - 0.5) * grain;
	vec3 body = ink.rgb + vec3((l - 0.35) * form + n);
	body += vec3(0.55, 0.6, 0.66) * rim * rim_base;
	body *= tint.rgb;
	v_rim = rim;
	COLOR = vec4(max(body, vec3(0.0)), COLOR.a);  // COLOR.a = texture alpha x fade
}

void light() {
	// The interior drinks the light; the outline catches it.
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb + LIGHT_COLOR.rgb * v_rim * rim_light * 0.5, LIGHT_COLOR.a);
}
