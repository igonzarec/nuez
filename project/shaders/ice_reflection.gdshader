// Copia reflejada de un personaje bajo el hielo (IceReflection). Mezcla su
// color con la imagen ya renderizada del hielo y escribe la profundidad del
// punto del plano que atraviesa la mirada: así el reflejo se ve "pintado" sobre
// el hielo, queda tapado por lo que esté delante y nunca se suma a sí mismo.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform vec4 tint : source_color = vec4(0.55, 0.75, 0.95, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.0, 2.0) = 0.9;
uniform float opacity : hint_range(0.0, 1.0) = 0.3;
uniform float plane_height = 0.0;
uniform float fade_depth = 0.8;
uniform float depth_lift = 0.04;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float below = plane_height - world_position.y;
	if (below < -0.001) {
		discard;
	}
	vec4 color = albedo;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		color *= COLOR;
	}
	vec3 reflected = mix(color.rgb * brightness, tint.rgb, tint_amount);
	float strength = opacity * color.a * (1.0 - smoothstep(0.0, fade_depth, below));
	ALBEDO = mix(textureLod(screen_texture, SCREEN_UV, 0.0).rgb, reflected, strength);
	ALPHA = 1.0;

	// Punto del plano (algo elevado) en la línea de visión. Se retrasa un poco
	// según la profundidad real para que la parte más cercana del reflejo gane.
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = world_position - camera;
	float hit = clamp((plane_height + depth_lift - camera.y) / min(ray.y, -0.0001), 0.0, 1.0);
	float ray_length = length(ray);
	vec3 surface = camera + ray * hit;
	float behind = min(ray_length * (1.0 - hit) * 0.02, depth_lift * 0.5);
	surface += ray / max(ray_length, 0.0001) * behind;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(surface, 1.0);
	float ndc_depth = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = ndc_depth * 0.5 + 0.5;
#else
	DEPTH = ndc_depth;
#endif
}
