shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D coat_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 coat_color : source_color = vec4(0.145, 0.306, 0.22, 1.0);
uniform float cloth_specular : hint_range(0.0, 1.0) = 0.5;
const vec3 AUTHORED_COAT = vec3(0.035, 0.145, 0.106);
void fragment() {
	vec3 painted = texture(surface_color, UV).rgb;
	float mask = texture(coat_mask, UV).r;
	float grain = clamp(dot(painted, vec3(0.2126, 0.7152, 0.0722)) / dot(AUTHORED_COAT, vec3(0.2126, 0.7152, 0.0722)), 0.97, 1.03);
	// Change the cloth beneath the decoration; keep its cream/gold stitch colors.
	ALBEDO = clamp(painted + mask * (coat_color.rgb - AUTHORED_COAT) * grain, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.92;
	SPECULAR = cloth_specular;
}
