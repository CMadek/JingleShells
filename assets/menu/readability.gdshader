shader_type canvas_item;
uniform float rail_end = 0.4;
void fragment() {
    // The action lives on the right. Text stays on a quiet, solid-enough scrim.
    float rail = 1.0 - smoothstep(rail_end - 0.05, rail_end + 0.22, UV.x);
    float edge = smoothstep(0.35, 0.74, length(UV - vec2(0.5)));
    COLOR = vec4(0.018, 0.035, 0.045, max(rail * 0.92, edge * 0.28));
}
