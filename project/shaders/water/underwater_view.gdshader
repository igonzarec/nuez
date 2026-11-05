shader_type spatial;
// Full-screen fog drawn by TrailCamera while the camera is under a WaterRiver / WaterLake. Colours and distance come from
// the WaterStyle of that water (group "Bajo el agua"). Looking up, the fog only counts the water up to the surface, so the
// bright ceiling (water_surface seen from below) stays readable.
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.10, 0.33, 0.55, 1.0);
uniform vec4 light_color : source_color = vec4(0.42, 0.74, 0.90, 1.0);
uniform float fog_distance = 14.0;
uniform float min_tint = 0.12;
uniform float max_fog = 0.92;
uniform float surface_height = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(scene_depth, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, d) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 ray = world - CAMERA_POSITION_WORLD;
	float dist = length(ray);
	vec3 dir = ray / max(dist, 0.0001);
	// Only the water between the camera and the surface fogs what lies above it.
	if (dir.y > 0.001) {
		dist = min(dist, (surface_height - CAMERA_POSITION_WORLD.y) / dir.y);
	}
	// Quadratic: what is near (the swimmer) stays readable, the distance closes in quickly.
	float ratio = max(dist, 0.0) / max(fog_distance, 0.01);
	float fog = 1.0 - exp(-3.0 * ratio * ratio);
	float depth_below = max(surface_height - CAMERA_POSITION_WORLD.y, 0.0);
	vec3 colour = mix(fog_color.rgb, light_color.rgb, smoothstep(-0.35, 0.85, dir.y));
	colour *= mix(1.0, 0.55, 1.0 - exp(-depth_below / max(fog_distance, 0.01)));
	ALBEDO = colour;
	ALPHA = clamp(mix(min_tint, max_fog, fog), 0.0, 1.0);
}
