shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(0.83, 0.87, 0.91, 0.28);
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0.0,0.0,0.0),vec4(0.0,length(MODEL_MATRIX[1].xyz),0.0,0.0),vec4(0.0,0.0,length(MODEL_MATRIX[2].xyz),0.0),vec4(0.0,0.0,0.0,1.0));
}
void fragment() {
    float radius = length(UV - vec2(0.5)) * 2.0;
    ALBEDO = tint.rgb * COLOR.rgb;
    ALPHA = (1.0 - smoothstep(0.05, 1.0, radius)) * tint.a * COLOR.a;
}
