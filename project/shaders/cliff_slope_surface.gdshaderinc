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
// Textures painted by hand in Terrain3D. The generator binds Terrain3D's own texture array and control maps through
// RenderingServer (live: painting shows at once), plus the region map and per-texture color and UV scale.
uniform bool use_painted = false;
uniform highp sampler2DArray painted_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform highp sampler2DArray painted_control : repeat_disable;
uniform int painted_region_map[1024];
uniform float painted_region_size = 256.0;
uniform vec4 painted_colors[32];
uniform float painted_uv_scales[32];
uniform float painted_fold_limit = 0.15;
// Ledges: fold faces that look up take the painted texture too (snow on shelves). Normal Y range and edge breakup.
uniform bool painted_ledges = true;
uniform float ledge_min_y = 0.707;
uniform float ledge_full_y = 0.819;
uniform float ledge_breakup = 0.15;

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

// Terrain3D UV (before texture scale): world XZ, or a vertical plane snapped to 8 directions on steep slopes.
// dx/dy: screen derivatives of world_position, taken in uniform control flow by the caller.
void terrain_uv(vec3 n, vec3 dx, vec3 dy, out vec2 uv, out vec2 uv_dx, out vec2 uv_dy) {
	uv = world_position.xz;
	uv_dx = dx.xz;
	uv_dy = dy.xz;
	if (enable_projection && n.y <= projection_threshold) {
		vec2 xz = round(normalize(-n.xz) * 1.3065629648763765);
		xz *= abs(xz.x) + abs(xz.y) > 1.5 ? 0.7071067811865475 : 1.0;
		xz = vec2(-xz.y, xz.x);
		uv = vec2(dot(world_position.xz, xz), -world_position.y);
		uv_dx = vec2(dot(dx.xz, xz), -dx.y);
		uv_dy = vec2(dot(dy.xz, xz), -dy.y);
	}
}

// Terrain3D control texel at a global vertex index; automatic (bit 0) outside any region.
uint painted_control_at(ivec2 cell) {
	int size = int(painted_region_size);
	ivec2 region = ivec2(floor(vec2(cell) / painted_region_size));
	ivec2 slot = region + 16;
	if (uint(slot.x | slot.y) >= 32u) {
		return 1u;
	}
	int layer = painted_region_map[slot.y * 32 + slot.x] - 1;
	if (layer < 0) {
		return 1u;
	}
	return floatBitsToUint(texelFetch(painted_control, ivec3(cell - region * size, layer), 0).r);
}

// Albedo of the textures painted by hand around this point, blended like Terrain3D over its four control texels
// (without per-texel rotation or detiling). rgb: color; a: share of painted texels (0 = all automatic).
// height: blended texture height (albedo alpha), used to break the ledge edge.
vec4 painted_surface_albedo(vec3 n, vec3 dx, vec3 dy, out float height) {
	height = 0.5;
	vec2 cell = world_position.xz / vertex_spacing;
	ivec2 origin = ivec2(floor(cell));
	vec2 f = fract(cell);
	vec4 corner = vec4((1.0 - f.x) * f.y, f.x * f.y, f.x * (1.0 - f.y), (1.0 - f.x) * (1.0 - f.y));
	ivec2 offsets[4] = ivec2[4](ivec2(0, 1), ivec2(1, 1), ivec2(1, 0), ivec2(0, 0));
	vec2 uv;
	vec2 uv_dx;
	vec2 uv_dy;
	terrain_uv(n, dx, dy, uv, uv_dx, uv_dy);
	float sharpness = 56.0 * blend_sharpness + 8.0;
	vec3 color = vec3(0.0);
	float heights = 0.0;
	float total = 0.0;
	float painted = 0.0;
	for (int i = 0; i < 4; i++) {
		uint c = painted_control_at(origin + offsets[i]);
		// Automatic texels keep the cliff rule. Hole texels (under the mesh) keep the texture painted on them.
		if ((c & 0x1u) != 0u) {
			continue;
		}
		painted += corner[i];
		float texel_scale = 0.9 - float(((c >> 7u & 0x7u) + 3u) % 8u + 1u) * 0.1;
		float blend = float(c >> 14u & 0xFFu) / 255.0;
		int base_id = int(c >> 27u & 0x1Fu);
		int overlay_id = int(c >> 22u & 0x1Fu);
		for (int k = 0; k < 2; k++) {
			int id = k == 0 ? base_id : overlay_id;
			float share = k == 0 ? 1.0 - blend : blend;
			if (share <= 0.0 || (k == 1 && overlay_id == base_id)) {
				continue;
			}
			float scale = painted_uv_scales[id] * texel_scale;
			vec4 alb = textureGrad(painted_albedo, vec3(uv * scale - 0.5, float(id)), uv_dx * scale, uv_dy * scale);
			float height = k == 0 ? alb.a : alb.a * clamp(n.y, 0.0, 1.0);
			// Terrain3D height blend, divided by 3^sharpness (the largest base) so it cannot overflow.
			float weight = exp2(sharpness * log2((corner[i] + share + height) / 3.0)) * corner[i];
			color += alb.rgb * painted_colors[id].rgb * weight;
			heights += alb.a * weight;
			total += weight;
		}
	}
	if (total <= 0.0) {
		return vec4(0.0);
	}
	height = heights / total;
	return vec4(color / total, painted);
}

vec3 cliff_auto_albedo() {
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
	// Auto texels use scale 0.5.
	vec2 uv;
	vec2 uv_dx;
	vec2 uv_dy;
	terrain_uv(n, dFdx(world_position), dFdy(world_position), uv, uv_dx, uv_dy);
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

vec3 cliff_surface_albedo() {
	vec3 albedo = cliff_auto_albedo();
	vec3 dx = dFdx(world_position);
	vec3 dy = dFdy(world_position);
	// Where the mesh rests on the sculpture, textures painted in Terrain3D replace the automatic rule; folds keep it.
	float reach = 1.0 - smoothstep(0.0, max(painted_fold_limit, 0.0001), surface_mask.x);
	// Ledges: fold faces looking up also take what is painted there. The texture height breaks the edge.
	vec3 lit = normalize(world_normal);
	float ledge_room = painted_ledges ? smoothstep(ledge_min_y - ledge_breakup, ledge_full_y, lit.y) : 0.0;
	if (use_painted && max(reach, ledge_room) > 0.0) {
		float height;
		// Shelves are projected from above (their own normal); the seam keeps Terrain3D's projection.
		vec4 painted = painted_surface_albedo(reach >= ledge_room ? normalize(terrain_normal) : lit, dx, dy, height);
		if (painted.a > 0.0) {
			float ledge = painted_ledges
				? smoothstep(ledge_min_y, ledge_full_y, lit.y + (height - 0.5) * 2.0 * ledge_breakup) : 0.0;
			albedo = mix(albedo, painted.rgb, painted.a * max(reach, ledge));
		}
	}
	return albedo;
}
