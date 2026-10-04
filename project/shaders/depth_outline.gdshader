shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.2,0.3,0.35,1.0);
uniform float line_opacity : hint_range(0.0,1.0) = 0.25;
uniform float line_width : hint_range(0.5,4.0) = 1.0;
uniform float depth_threshold : hint_range(0.05,5.0) = 0.5;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
float linear_depth(vec2 uv, mat4 inverse_projection) {
 float d = texture(scene_depth, clamp(uv, vec2(0.0), vec2(1.0))).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
 #else
 vec3 ndc = vec3(uv * 2.0 - 1.0, d);
 #endif
 vec4 view = inverse_projection * vec4(ndc, 1.0);
 return -view.z / view.w;
}
void fragment() {
 vec2 offset = line_width / VIEWPORT_SIZE;
 float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
 float left = linear_depth(SCREEN_UV - vec2(offset.x,0.0), INV_PROJECTION_MATRIX);
 float right = linear_depth(SCREEN_UV + vec2(offset.x,0.0), INV_PROJECTION_MATRIX);
 float up = linear_depth(SCREEN_UV - vec2(0.0,offset.y), INV_PROJECTION_MATRIX);
 float down = linear_depth(SCREEN_UV + vec2(0.0,offset.y), INV_PROJECTION_MATRIX);
 float jump = max(left + right - 2.0 * center, up + down - 2.0 * center);
 float threshold = depth_threshold + center * 0.002;
 float edge = smoothstep(threshold, threshold * 2.0, jump);
 ALBEDO = line_color.rgb;
 ALPHA = edge * line_opacity * line_color.a;
}
