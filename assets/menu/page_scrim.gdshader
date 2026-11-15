shader_type canvas_item;
// Keep the controls on a quiet navy field and leave light on the crew at right.
void fragment() {
	float side = smoothstep(0.30, 0.93, UV.x);
	float footer = smoothstep(0.80, 1.0, UV.y);
	float opacity = mix(0.90, 0.52, side);
	COLOR = vec4(0.022, 0.061, 0.084, mix(opacity, 0.90, footer));
}
