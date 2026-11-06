shader_type spatial;
// Vista de depuración: colorea cada píxel visible según la pendiente de la
// superficie y los umbrales de escalada del player. Reconstruye posición y
// normal desde el depth buffer (funciona en Compatibility y Forward+).
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

uniform float walkable_max_deg = 48.0;
uniform bool sustain_enabled = true;
uniform float sustain_min_deg = 40.0;
uniform float grab_min_deg = 65.0;
uniform float grab_max_deg = 89.0;

uniform vec4 walk_color : source_color = vec4(0.25, 0.55, 1.0, 0.0);
uniform vec4 slide_color : source_color = vec4(1.0, 0.5, 0.1, 0.35);
uniform vec4 sustain_color : source_color = vec4(1.0, 0.9, 0.1, 0.5);
uniform vec4 grab_color : source_color = vec4(0.1, 0.95, 0.35, 0.6);
uniform vec4 blocked_color : source_color = vec4(0.95, 0.1, 0.15, 0.6);
uniform float opacity = 1.0;
uniform float threshold_line_width_deg = 0.0;
uniform vec4 threshold_line_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);

uniform float max_distance = 60.0;
uniform float fade_distance = 15.0;
uniform vec3 ignore_center = vec3(0.0, -100000.0, 0.0);
uniform float ignore_radius = 0.0;

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

vec3 view_position(vec2 uv, mat4 inverse_projection) {
	float d = texture(scene_depth, clamp(uv, vec2(0.0), vec2(1.0))).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec3 center = view_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dist = length(center);
	if (dist > max_distance) discard;
	// Elegir el vecino más cercano en profundidad evita normales falsas en siluetas.
	vec3 left = view_position(SCREEN_UV - vec2(texel.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 right = view_position(SCREEN_UV + vec2(texel.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 down = view_position(SCREEN_UV - vec2(0.0, texel.y), INV_PROJECTION_MATRIX);
	vec3 up = view_position(SCREEN_UV + vec2(0.0, texel.y), INV_PROJECTION_MATRIX);
	vec3 dx = abs(right.z - center.z) < abs(center.z - left.z) ? right - center : center - left;
	vec3 dy = abs(up.z - center.z) < abs(center.z - down.z) ? up - center : center - down;
	vec3 view_normal = normalize(cross(dx, dy));
	if (dot(view_normal, -center) < 0.0) view_normal = -view_normal;
	vec3 normal = normalize(mat3(INV_VIEW_MATRIX) * view_normal);
	vec3 world = (INV_VIEW_MATRIX * vec4(center, 1.0)).xyz;
	if (ignore_radius > 0.0 && distance(world, ignore_center) < ignore_radius) discard;

	float slope = degrees(acos(clamp(normal.y, -1.0, 1.0)));
	vec4 color;
	if (slope <= walkable_max_deg) color = walk_color;
	else if (slope > grab_max_deg) color = blocked_color;
	else if (slope >= grab_min_deg) color = grab_color;
	else if (sustain_enabled && slope >= sustain_min_deg) color = sustain_color;
	else color = slide_color;

	if (threshold_line_width_deg > 0.0) {
		float nearest = min(min(abs(slope - walkable_max_deg), abs(slope - grab_min_deg)), abs(slope - grab_max_deg));
		if (sustain_enabled) nearest = min(nearest, abs(slope - sustain_min_deg));
		if (nearest < threshold_line_width_deg * 0.5) color = threshold_line_color;
	}

	float fade = fade_distance > 0.0 ? clamp((max_distance - dist) / fade_distance, 0.0, 1.0) : 1.0;
	ALBEDO = color.rgb;
	ALPHA = color.a * opacity * fade;
}
