shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Stable world-space snow grain: no animated glitter, textures or extra passes.
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),u.x),
		mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),u.x),u.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float drift = noise(world_position.xz * .13);
	float detail = noise(world_position.xz * 22.0);
	float fade = 1.0 - smoothstep(.03,.15,length(fwidth(world_position.xz)));
	ALBEDO = mix(vec3(.76,.83,.89), vec3(.90,.94,.98), drift*.45+.35);
	ALBEDO *= 1.0 + (detail-.5)*.035*fade;
	ROUGHNESS = .91 + detail*.055;
	SPECULAR = .24;
}
