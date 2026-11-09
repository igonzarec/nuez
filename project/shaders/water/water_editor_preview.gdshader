shader_type spatial;
// Editor stand-in for water_surface: flat colour, no motion, no screen or depth reads. Steep parts (falls) use their own colour.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 water_color : source_color = vec4(0.2, 0.55, 0.9, 0.8);
uniform vec4 fall_color : source_color = vec4(0.6, 0.85, 1.0, 0.8);

void fragment() {
	float up = abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	vec4 color = mix(fall_color, water_color, smoothstep(0.5, 0.8, up));
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
