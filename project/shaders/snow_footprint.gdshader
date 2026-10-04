shader_type spatial;
render_mode depth_draw_never, cull_disabled;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 print_color : source_color = vec4(0.49, 0.64, 0.72, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float edge = 1.0 - smoothstep(0.65, 0.98, d);
	float lip = smoothstep(0.5, 0.72, d);
	ALBEDO = mix(print_color.rgb, vec3(0.9,0.95,1.0), lip);
	ROUGHNESS = 1.0;
	ALPHA = edge * fade * 0.65;
}
