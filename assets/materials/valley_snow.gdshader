shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform mat4 world_to_plane;
uniform vec3 cabin_min;
uniform vec3 cabin_max;
uniform vec3 viewer_velocity;
uniform float intensity = 0.58;
varying float opacity;

bool sheltered(vec3 p, vec3 low, vec3 high) {
	return all(greaterThanEqual(p, low)) && all(lessThanEqual(p, high));
}

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	vec3 center = MODEL_MATRIX[3].xyz;
	// Interleave close flakes and a deeper curtain in one instanced draw.
	float distant = step(0.40, seed.w);
	float span = mix(34.0, 104.0, distant);
	float phase = seed.x * 6.283;
	vec3 wind = vec3(2.2 + 3.6*seed.z, -2.3 - 2.6*seed.x, 1.3+seed.y);
	vec3 drift = TIME*wind + vec3(sin(TIME*1.1+phase),0.,cos(TIME*.8+phase))*.52;
	vec3 offset = mod(seed.xyz*span + drift - center + span*.5,span) - span*.5;
	vec3 pos = center + offset;
	float edge = max(max(abs(offset.x),abs(offset.y)),abs(offset.z)) / span;
	opacity = (1.0-smoothstep(.41,.495,edge)) * smoothstep(.75,2.4,length(offset));
	opacity *= mix(.54,.94,seed.z) * mix(.78,1.,intensity);
	vec3 local = (world_to_plane * vec4(pos,1.0)).xyz;
	if (pos.y < .12 || sheltered(local,cabin_min,cabin_max)
			|| sheltered(pos,vec3(-36.4,-.2,831.6),vec3(-19.6,4.85,850.4))) {
		opacity = 0.0;
	}
	vec3 eye = (VIEW_MATRIX * vec4(pos,1.0)).xyz;
	vec3 apparent = mat3(VIEW_MATRIX) * (wind-viewer_velocity);
	// Perspective makes head-on snow streak radially past the windscreen.
	vec2 flow = apparent.xy + eye.xy * apparent.z / max(1.,-eye.z);
	vec2 axis = flow / max(.001,length(flow));
	vec2 across = vec2(axis.y,-axis.x);
	float width = mix(.035,.090,seed.y) * mix(1.,2.0,distant);
	float height = min(width*1.25 + min(length(flow)*.005,.27), max(0.,-eye.z)*.032);
	width = min(width, max(0.,-eye.z)*.011);
	eye.xy += across * VERTEX.x * width + axis * VERTEX.y * height;
	POSITION = PROJECTION_MATRIX * vec4(eye,1.);
}

void fragment() {
	float disk = dot(UV-.5,UV-.5)*4.;
	ALBEDO = vec3(.87,.93,1.);
	ALPHA = opacity * (1.-smoothstep(.16,1.,disk));
}
