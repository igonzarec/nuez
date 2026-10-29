shader_type spatial;
// Seam band of the cliff mesh: rests on the sculpture and fades into Terrain3D (opacity in UV2.y).
// Dithered discard instead of blending keeps it in the opaque pass, so screen effects that only read
// opaque geometry (the player camera's distant blur) treat it exactly like the terrain around it.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/cliff_slope_surface.gdshaderinc"

void fragment() {
	// Interleaved gradient noise: an even screen-space threshold without a visible pattern.
	float threshold = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (surface_mask.y <= threshold) {
		discard;
	}
	ALBEDO = cliff_surface_albedo();
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
