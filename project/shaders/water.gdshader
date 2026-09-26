shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = floor(world_position.xz * 12.0) / 12.0;
	float ripple = sin(p.x * 5.0 + p.y * 3.0 + TIME * 1.5) + sin(p.y * 7.0 - TIME * 0.7);
	vec3 color = mix(vec3(0.12, 0.42, 0.47), vec3(0.34, 0.72, 0.73), step(1.1, ripple));
	ALBEDO = color;
	EMISSION = color * 0.12;
	ROUGHNESS = 0.8;
}
