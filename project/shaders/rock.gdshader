shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 rock_color : source_color = vec4(0.45, 0.36, 0.42, 1.0);
uniform vec4 snow_color : source_color = vec4(0.75, 0.78, 0.9, 1.0);
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = floor(world_position * 10.0) / 10.0;
	float warp = sin(p.x * 1.8 + p.z * 0.8) * 0.12 + sin(p.z * 4.0) * 0.06;
	float band = fract((p.y + warp) * 2.8);
	float grain = hash(floor(p.xz * 12.0));
	float strata = step(0.78, band) * 0.18 - step(band, 0.14) * 0.09;
	vec3 stone = rock_color.rgb * (1.0 - strata + (grain - 0.5) * 0.14);
	float snow = smoothstep(0.52, 0.72, world_normal.y + grain * 0.12);
	ALBEDO = mix(stone, snow_color.rgb * (0.94 + grain * 0.06), snow);
	ROUGHNESS = 1.0;
}
