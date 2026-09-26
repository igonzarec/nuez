shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D trail_mask : filter_linear, repeat_disable;
uniform vec4 trail_color : source_color = vec4(0.62, 0.36, 0.16, 1.0);
uniform vec4 grass_color : source_color = vec4(0.40, 0.48, 0.17, 1.0);
uniform vec4 snow_color : source_color = vec4(0.72, 0.77, 0.94, 1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = floor(world_position.xz * 12.0) / 12.0;
	float dist = texture(trail_mask, (p + vec2(38.0, 40.0)) / vec2(76.0, 78.0)).r * 6.0;
	float patches = noise(p * 0.35);
	float grass_tone = floor(noise(p * 0.8) * 4.0) / 4.0;
	float snow = step(0.76 - smoothstep(4.0, 15.5, world_position.y) * 0.61, patches);
	vec3 base = mix(grass_color.rgb * (0.86 + grass_tone * 0.24), snow_color.rgb, snow);
	float edge = 1.7 + (noise(p * 1.6) - 0.5) * 0.65;
	float path = 1.0 - smoothstep(edge, edge + 0.12, dist);
	base = mix(base, trail_color.rgb * (0.95 + floor(patches * 3.0) * 0.07), path);
	float grain = hash(floor(p * 14.0));
	float speckle = step(0.975, hash(floor(p * vec2(7.0, 4.0))));
	base *= 0.97 + floor(grain * 3.0) * 0.02;
	base = mix(base, base * 0.7, speckle * 0.55);
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
