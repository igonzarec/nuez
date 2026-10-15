shader_type spatial;
render_mode unshaded, depth_prepass_alpha;

uniform float shape_variation : hint_range(0.0, 1.0) = 0.25;
uniform vec2 initial_size = vec2(0.04, 0.09);
uniform vec2 final_size = vec2(0.25, 0.5);
uniform vec4 light_color : source_color = vec4(0.98, 0.97, 0.94, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.62, 0.64, 0.72, 1.0);
uniform float shadow_strength = 0.75;
uniform float shadow_threshold = 0.1;
uniform float shadow_softness = 0.03;
uniform vec3 light_direction = vec3(-0.4, 1.0, 0.3);
varying vec3 world_normal;

void vertex() {
	// Angle is seeded at birth and never advances: no time-dependent wobble.
	float seed = INSTANCE_CUSTOM.x;
	vec3 stretch = vec3(1.0 + sin(seed * 3.7) * 0.3,
		1.0 + cos(seed * 2.3) * 0.25, 1.0 + sin(seed * 5.1) * 0.3);
	vec3 axes = mix(vec3(1.0), stretch, shape_variation);
	float random_size = fract(sin(seed * 17.13 + 3.1) * 43758.5453);
	float start_diameter = mix(initial_size.x, initial_size.y, random_size);
	float end_diameter = mix(final_size.x, final_size.y, random_size);
	float diameter = mix(start_diameter, end_diameter, smoothstep(0.0, 1.0, INSTANCE_CUSTOM.y));
	VERTEX *= axes * diameter;
	NORMAL = normalize(NORMAL / axes);
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float lighting = dot(normalize(world_normal), normalize(light_direction));
	float band = step(shadow_threshold, lighting);
	if (shadow_softness > 0.0001) {
		band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, lighting);
	}
	vec3 shade = mix(light_color.rgb, shadow_color.rgb, shadow_strength);
	ALBEDO = mix(shade, light_color.rgb, band) * COLOR.rgb;
	ALPHA = COLOR.a;
}
