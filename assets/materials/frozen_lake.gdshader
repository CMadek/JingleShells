shader_type spatial;
render_mode cull_disabled;

varying vec2 ice_pos;
void vertex() {
	ice_pos = VERTEX.xz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	vec2 p = ice_pos;
	float drift = sin(p.y*.17 + sin(p.x*.017)*1.8 + p.x*.046 + sin(p.y*.05+p.x*.038));
	float patch = smoothstep(-.2,.8,sin(p.x*.031+p.y*.008) * cos(p.y*.057-p.x*.024));
	float scuff = smoothstep(.64,.99,drift) * patch;
	float seam = abs(fract((p.x*.79+p.y*.34+abs(p.y+24.)*.32+abs(p.x-p.y*.18)*.19)/82.)-.5)*82.;
	float crack = (1.-smoothstep(.1,.45+fwidth(seam),seam)) * (.3+.7*patch);
	float bank = smoothstep(.84, .995, UV.x + .018 * drift);
	vec3 ice = mix(vec3(.20, .42, .51), vec3(.39, .60, .66), .55 * UV.x + .38 * scuff);
	ALBEDO = mix(ice, vec3(.76, .83, .87), max(bank,crack*.6));
	ROUGHNESS = mix(.52, .94, bank);
}
