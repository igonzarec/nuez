shader_type spatial;
// Shows the diving player through the water surface, and only the player. TrailCamera puts it as material_overlay on the
// player's meshes while they dive. It draws after the water (render priority 2) and repaints the player's own pixels
// with the scene as it was before the water (screen texture), tinted by the water above it. An opaque thing in front of
// the player (a rock, the bank) still hides it: the depth texture is checked against the fragment.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// 0-1 fade driven by TrailCamera (Reveal Swimmer Fade).
uniform float weight = 0.0;
uniform float surface_height = 0.0;
// Metres of water through which the player still reads clearly (WaterStyle Swimmer Clarity).
uniform float clarity = 8.0;
// 0-1: how much of the water colour the player takes (WaterStyle Swimmer Tint).
uniform float tint = 0.4;
uniform vec4 shallow_color : source_color = vec4(0.40, 0.70, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.13, 0.38, 0.75, 1.0);
uniform float depth_scale = 1.2;
// Screen-space wobble of the refracted image, like the waves bending it.
uniform float wobble = 0.006;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

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

void fragment() {
	float below = surface_height - world_pos.y;
	// Something opaque is in front of this part of the player: keep it hidden.
	if (view_depth(SCREEN_UV, INV_PROJECTION_MATRIX) < -VERTEX.z - 0.06 || below <= 0.0) {
		discard;
	}
	vec2 bend = vec2(sin(TIME * 2.1 + world_pos.x * 5.0 + world_pos.y * 3.0), cos(TIME * 1.7 + world_pos.z * 5.0)) * wobble;
	vec3 body = texture(screen_texture, clamp(SCREEN_UV + bend, vec2(0.001), vec2(0.999))).rgb;
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, 1.0 - exp(-below / max(depth_scale, 0.01)));
	// The water colour veils the player a little more the deeper it is, keeping its own colours readable.
	ALBEDO = mix(body, water, clamp(tint * (0.6 + 0.4 * (1.0 - exp(-below / 3.0))), 0.0, 1.0));
	ALPHA = weight * exp(-below / max(clarity, 0.01)) * smoothstep(0.0, 0.08, below);
}
