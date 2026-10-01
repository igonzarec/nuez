shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = floor(world_position * 9.0) / 9.0;
	float grain = fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	float warp = sin(p.x * 0.7 + p.z * 0.3) * 0.3;
	float strata = smoothstep(0.78, 0.96, fract((p.y + warp) * 1.5));
	float cracks = pow(0.5 + 0.5 * sin(p.x * 2.4 + p.z * 0.8 + sin(p.y * 0.6)), 24.0);
	vec3 stone = vec3(0.27, 0.25, 0.24) * (0.92 + grain * 0.18 - strata * 0.22 - cracks * 0.17);
	float snow = smoothstep(0.5, 0.8, world_normal.y) * smoothstep(39.0, 50.0, p.y);
	ALBEDO = mix(stone, vec3(0.88, 0.93, 1.0) * (0.94 + grain * 0.06), snow);
	ROUGHNESS = 1.0;
}
