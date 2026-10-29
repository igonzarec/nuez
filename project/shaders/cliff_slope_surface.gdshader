shader_type spatial;
// Same lighting model as Terrain3D (burley, no specular, roughness 1) so lit tones match at the join.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/cliff_slope_surface.gdshaderinc"

void fragment() {
	ALBEDO = cliff_surface_albedo();
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
