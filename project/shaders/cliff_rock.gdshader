shader_type spatial;
uniform vec4 rock_color : source_color = vec4(0.18, 0.21, 0.25, 1.0);
uniform vec4 vein_color : source_color = vec4(0.08, 0.10, 0.13, 1.0);
uniform float strata_scale = 2.0;
uniform float strata_strength = 0.18;
uniform float strata_warp = 0.8;
uniform float facet_variation = 0.15;
uniform float roughness_value = 0.9;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float bend = sin(local_point.x * 0.65 + sin(local_point.y * 0.24)) * strata_warp;
	float stripe = pow(0.5 + 0.5 * sin((local_point.y + bend + local_point.x * 0.32) * strata_scale), 4.0);
	ALBEDO = mix(rock_color.rgb, vein_color.rgb, stripe * strata_strength) * mix(1.0, COLOR.r, facet_variation);
	ROUGHNESS = roughness_value;
}
