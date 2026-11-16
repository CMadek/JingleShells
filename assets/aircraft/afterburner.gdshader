shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

varying float distance_from_nozzle;

void vertex() {
	distance_from_nozzle = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	float d = distance_from_nozzle;
	float bands = 0.82 + 0.18 * cos(30.0 * d - TIME * 8.0);
	float edge = smoothstep(0.0, 0.30, abs(dot(normalize(NORMAL), VIEW)));
	vec3 flame = mix(vec3(1.8, 0.74, 0.21), vec3(0.30, 0.47, 1.1), smoothstep(0.04, 0.66, d));
	ALBEDO = flame;
	ALPHA = (1.0 - smoothstep(0.24, 1.0, d)) * bands * (0.30 + 0.70 * edge);
}
