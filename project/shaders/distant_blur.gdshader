shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float focus_distance = 18.0;
uniform float far_transition = 12.0;
uniform float blur_radius = 3.0;

float view_depth(vec2 uv, mat4 inverse_projection) {
	float depth = texture(depth_texture, uv).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 position = inverse_projection * vec4(ndc, 1.0);
	return -position.z / position.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float amount = smoothstep(focus_distance, focus_distance + far_transition, depth);
	vec2 offset = vec2(blur_radius * amount) / VIEWPORT_SIZE;
	vec3 color = texture(screen_texture, SCREEN_UV).rgb * 4.0;
	float weight = 4.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) { continue; }
			vec2 uv = clamp(SCREEN_UV + vec2(float(x), float(y)) * offset, vec2(0.0), vec2(1.0));
			// Do not smear the sharp player/foreground into distant background pixels.
			float sample_weight = smoothstep(focus_distance - 1.0, focus_distance, view_depth(uv, INV_PROJECTION_MATRIX));
			color += texture(screen_texture, uv).rgb * sample_weight;
			weight += sample_weight;
		}
	}
	ALBEDO = color / weight;
}
