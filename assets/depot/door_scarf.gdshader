shader_type spatial;
render_mode cull_disabled;

// The top hem is sewn to the rail. The free end catches the crosswind.
void vertex() {
	float loose = UV.y * UV.y;
	float ripple = sin(TIME * 1.35 - UV.y * 6.2 + UV.x * 2.3);
	float gust = sin(TIME * .58 - UV.y * 2.0);
	VERTEX.x += loose * (.10 * gust + .043 * ripple);
	VERTEX.z += loose * (.055 * gust + .025 * ripple);
	VERTEX.y += loose * .018 * cos(TIME * 1.35 - UV.y * 6.2);
}

void fragment() {
	float weave = .97 + .03 * sin(UV.x * 610.) * cos(UV.y * 980.);
	float selvedge = min(UV.x, 1.-UV.x);
	float width = max(fwidth(selvedge), .001);
	float stripe = 1.-smoothstep(.009-width, .009+width, abs(selvedge-.046));
	stripe += 1.-smoothstep(.004-width,.004+width,abs(selvedge-.075));
	ALBEDO = mix(vec3(.60,.47,.29),vec3(.39,.075,.045),min(stripe,1.)) * weave;
	ROUGHNESS = .94;
}
