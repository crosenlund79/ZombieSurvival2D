shader_type canvas_item;
// Gentle wind sway for vegetation. Presentation only. The top of the image
// moves, the base stays planted; each object gets its own phase from its
// world position so neighbours do not move in lockstep.
uniform float strength = 2.2;
uniform float speed = 1.3;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = world.x * 0.013 + world.y * 0.007;
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + phase) * strength * top * top * 3.0;
}
