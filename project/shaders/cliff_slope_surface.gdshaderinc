// Shared by the cliff mesh and its seam fade band (cliff_slope_surface / cliff_slope_fade).
// With match_terrain it reproduces the Terrain3D 1.0 auto shader: same textures, UV scale, vertical
// projection and height blend, driven by the sculpted normal stored in UV. The mesh then shades like
// the terrain wherever it rests on it, so the join has nothing to show.
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 cliff_tint : source_color = vec4(1.0);
uniform float grass_scale = 0.1;
uniform float cliff_scale = 0.1;
// Legacy blend, used only when match_terrain is off.
uniform float slope_start = 45.0;
uniform float slope_width = 10.0;
uniform bool match_terrain = true;
// Copied from the Terrain3D material by the generator.
uniform float auto_slope = 1.0;
// Rock by angle: same rule the generator writes into the Terrain3D override.
uniform bool rock_by_angle = false;
uniform float rock_angle_start = 58.0;
uniform float rock_angle_full = 66.0;
uniform float rock_height_reduction = 0.0;
uniform float auto_height_reduction = 0.1;
uniform float blend_sharpness = 0.5;
uniform bool enable_projection = true;
uniform float projection_threshold = 0.8;
uniform float vertex_spacing = 1.0;
uniform float fold_triplanar = 1.0;
uniform float clean_rock_edge = 1.0;
uniform float depth_offset = 0.002;
uniform float fade_far_distance = 24.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 terrain_normal;
varying vec2 surface_mask;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	terrain_normal = vec3(UV.x, sqrt(max(1.0 - dot(UV, UV), 0.0)), UV.y);
	surface_mask = UV2;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Slide along the view ray: same pixel, slightly nearer, so the mesh wins where it coincides with the terrain.
	if (PROJECTION_MATRIX[3][3] == 0.0) {
		view.xyz *= 1.0 - depth_offset;
	}
	POSITION = PROJECTION_MATRIX * view;
}

vec3 triplanar(sampler2D tex, vec3 position, vec3 weights, float scale) {
	return texture(tex, position.zy * scale).rgb * weights.x
		+ texture(tex, position.xz * scale).rgb * weights.y
		+ texture(tex, position.xy * scale).rgb * weights.z;
}

vec3 cliff_surface_albedo() {
	vec3 lit = normalize(world_normal);
	vec3 weights = pow(abs(lit), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	if (!match_terrain) {
		float angle = degrees(acos(clamp(lit.y, -1.0, 1.0)));
		float rock = smoothstep(slope_start, slope_start + slope_width, angle);
		// Clean rock edge: fold faces gentler than Rock Start Angle would paint grass teeth up the wall.
		rock = max(rock, clean_rock_edge * surface_mask.y * smoothstep(0.0, 0.15, surface_mask.x));
		vec3 grass = triplanar(grass_texture, world_position, weights, grass_scale) * grass_tint.rgb;
		vec3 cliff = triplanar(cliff_texture, world_position, weights, cliff_scale) * cliff_tint.rgb;
		return mix(grass, cliff, rock);
	}
	vec3 n = normalize(terrain_normal);
	float grass_rule = rock_by_angle
		? 1.0 - smoothstep(rock_angle_start, rock_angle_full, degrees(acos(clamp(n.y, -1.0, 1.0))))
		: auto_slope * 2.0 * (n.y - 1.0) + 1.0;
	float height_reduction = rock_by_angle ? rock_height_reduction : auto_height_reduction;
	// Clean rock edge: the sculpted foot crosses the rock angles over almost a metre and the height blend draws grass teeth
	// up the rock. Inside the mesh (the terrain under it is hidden) the transition narrows and folds are always rock; the seam
	// band keeps the terrain's exact rule (weight = seam opacity), so the join still matches.
	float edge = clean_rock_edge * surface_mask.y;
	float rule = clamp(grass_rule, 0.0, 1.0);
	float narrow = mix(0.5, 0.03, edge);
	rule = mix(rule, smoothstep(0.5 - narrow, 0.5 + narrow, rule), edge);
	grass_rule = min(rule, 1.0 - edge * smoothstep(0.0, 0.15, surface_mask.x));
	float blend = clamp(grass_rule - height_reduction * 0.01 * world_position.y, 0.0, 1.0);
	// Terrain3D UV: world XZ, or a vertical plane snapped to 8 directions on steep slopes; auto texels use scale 0.5.
	vec3 dx = dFdx(world_position);
	vec3 dy = dFdy(world_position);
	vec2 uv = world_position.xz;
	vec2 uv_dx = dx.xz;
	vec2 uv_dy = dy.xz;
	if (enable_projection && n.y <= projection_threshold) {
		vec2 xz = round(normalize(-n.xz) * 1.3065629648763765);
		xz *= abs(xz.x) + abs(xz.y) > 1.5 ? 0.7071067811865475 : 1.0;
		xz = vec2(-xz.y, xz.x);
		uv = vec2(dot(world_position.xz, xz), -world_position.y);
		uv_dx = vec2(dot(dx.xz, xz), -dx.y);
		uv_dy = vec2(dot(dy.xz, xz), -dy.y);
	}
	uv *= 0.5;
	uv_dx *= 0.5;
	uv_dy *= 0.5;
	vec4 rock = textureGrad(cliff_texture, uv * cliff_scale - 0.5, uv_dx * cliff_scale, uv_dy * cliff_scale);
	vec4 grass = textureGrad(grass_texture, uv * grass_scale - 0.5, uv_dx * grass_scale, uv_dy * grass_scale);
	// Height blend accumulated over the four control texels, as Terrain3D does.
	float sharpness = 56.0 * blend_sharpness + 8.0;
	vec2 f = fract(world_position.xz / vertex_spacing);
	vec4 corner = vec4((1.0 - f.x) * f.y, f.x * f.y, f.x * (1.0 - f.y), (1.0 - f.x) * (1.0 - f.y));
	float rock_weight = 0.0;
	float grass_weight = 0.0;
	for (int i = 0; i < 4; i++) {
		if (blend < 1.0) {
			rock_weight += exp2(sharpness * log2(corner[i] + 1.0 - blend + rock.a)) * corner[i];
		}
		if (blend > 0.0) {
			grass_weight += exp2(sharpness * log2(corner[i] + blend + grass.a * n.y)) * corner[i];
		}
	}
	float grass_amount = grass_weight / max(rock_weight + grass_weight, 1e-20);
	vec3 terrain_like = mix(rock.rgb * cliff_tint.rgb, grass.rgb * grass_tint.rgb, grass_amount);
	// Deep folds stretch a planar projection: blend to triplanar only where relief exists.
	vec3 folded = mix(
		triplanar(cliff_texture, world_position * 0.5, weights, cliff_scale) * cliff_tint.rgb,
		triplanar(grass_texture, world_position * 0.5, weights, grass_scale) * grass_tint.rgb,
		grass_amount);
	return mix(terrain_like, folded, clamp(surface_mask.x * fold_triplanar, 0.0, 1.0));
}
