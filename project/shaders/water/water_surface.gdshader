shader_type spatial;
// Stylized water for WaterRiver / WaterLake. Values come from a WaterStyle resource (Inspector help lives there).
// Mesh data from the generator: UV = flow space in metres (x across, y downstream; lakes: world XZ),
// TANGENT = flow direction, COLOR.r = slope (0 flat, 1 vertical), COLOR.g is unused,// COLOR.b = distance to the ribbon edge (0 edge, 1 inside), COLOR.a = flow amount (1 river, 0 lake).
// The scene behind is read from the screen and depth textures: the bed shows through shallow water and foam
// appears where anything crosses the surface. Drawn at render priority 0, after the camera's distant blur (-128).
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

group_uniforms color;
uniform vec4 shallow_color : source_color = vec4(0.40, 0.70, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.13, 0.38, 0.75, 1.0);
uniform float depth_scale = 1.2;
// 0 = every body of water takes the tone of uniform_depth; 1 = tone follows the real depth.
uniform float depth_tone_amount = 1.0;
uniform float uniform_depth = 1.2;
uniform float clarity = 0.55;
uniform float bed_tint = 0.6;
uniform float self_light = 0.25;
group_uniforms surface;
uniform float wave_scale = 2.0;
uniform float wave_strength = 0.35;
uniform float wave_speed = 0.4;
uniform float refraction = 0.03;
uniform float flow_speed = 1.2;
uniform float flow_stretch = 1.8;
group_uniforms sparkles;
uniform vec4 sparkle_color : source_color = vec4(1.0);
uniform float sparkle_scale = 0.7;
uniform float sparkle_amount = 0.12;
uniform float sparkle_softness = 0.06;
uniform float sparkle_strength = 1.0;
uniform float sparkle_twinkle = 1.5;
group_uniforms crests;
uniform vec4 crest_color : source_color = vec4(0.82, 0.93, 1.0, 1.0);
uniform float crest_scale = 0.9;
uniform float crest_width = 0.035;
uniform float crest_softness = 0.04;
uniform float crest_amount = 0.75;
uniform float crest_strength = 0.9;
uniform float crest_stretch = 1.8;
uniform float crest_wobble = 0.6;
uniform float crest_speed = 0.6;
uniform float trough_shade = 0.35;
group_uniforms foam;
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float foam_width = 0.25;
uniform float foam_softness = 0.5;
uniform float foam_noise_scale = 0.6;
uniform float foam_breakup = 0.65;
uniform float foam_strength = 0.7;
group_uniforms falls;
uniform float rapids_start = 0.04;
uniform float rapids_full = 0.17;
uniform float fall_start = 0.39;
uniform float fall_full = 0.67;
uniform vec4 fall_color : source_color = vec4(0.45, 0.67, 0.88, 1.0);
uniform vec4 fall_streak_color : source_color = vec4(0.86, 0.94, 1.0, 1.0);
uniform vec4 fall_shadow_color : source_color = vec4(0.3, 0.52, 0.78, 1.0);
uniform float fall_streak_length = 0.07;
uniform float fall_transparency = 0.3;
uniform float fall_reflection = 1.0;
uniform float fall_foot_band = 0.85;
uniform float fall_foot_band_transparency = 0.0;
uniform float fall_foot_band_offset = 0.0;
uniform vec4 fall_foot_band_color : source_color = vec4(0.86, 0.94, 1.0, 1.0);
uniform float fall_foot_band_softness = 0.3;
uniform float fall_foot_band_ragged_scale = 1.0;
uniform float fall_foot_band_pulse = 0.25;
uniform float fall_foot_band_speed = 0.8;
uniform float fall_foot_band_up = 1.8;
uniform float fall_foot_top_ragged = 0.6;
uniform int fall_foot_top_shape = 1;
uniform float fall_foot_top_amount = 0.8;
uniform float fall_foot_top_size = 1.8;
uniform float fall_foot_top_width = 0.45;
uniform float fall_foot_band_down = 0.3;
uniform float fall_foot_bottom_ragged = 0.6;
uniform int fall_foot_bottom_shape = 0;
uniform float fall_foot_bottom_amount = 0.0;
uniform float fall_foot_bottom_size = 0.5;
uniform float fall_foot_bottom_width = 0.4;
uniform float fall_lip_band = 0.85;
// Set per river by WaterRiver (Fall Lip Band Offset), not by the style.
uniform float fall_lip_band_offset = 0.0;
uniform float fall_lip_band_transparency = 0.0;
uniform float fall_lip_opaque = 1.5;
uniform vec4 fall_lip_band_color : source_color = vec4(0.86, 0.94, 1.0, 1.0);
uniform float fall_lip_band_softness = 0.3;
uniform float fall_lip_band_ragged_scale = 1.0;
uniform float fall_lip_band_pulse = 0.25;
uniform float fall_lip_band_speed = 0.8;
uniform float fall_lip_band_height = 1.2;
uniform int fall_lip_bottom_shape = 0;
uniform float fall_lip_bottom_amount = 0.5;
uniform float fall_lip_bottom_size = 0.9;
uniform float fall_lip_bottom_width = 0.4;
uniform int fall_lip_top_shape = 1;
uniform float fall_lip_top_amount = 0.6;
uniform float fall_lip_top_size = 0.8;
uniform float fall_lip_top_width = 0.45;
uniform float fall_lip_band_ragged = 0.6;
uniform float fall_lip_band_up = 0.25;
uniform float fall_lip_top_ragged = 0.6;
uniform float fall_marks_light = 1.15;
uniform float fall_streak_shimmer = 0.25;
uniform float fall_streak_seed = 0.0;
uniform float fall_color_mix = 0.25;
uniform float fall_crests = 0.6;
uniform float river_edge_light = 0.35;
uniform float shore_line_strength = 0.7;
uniform float shore_line_depth = 0.35;
uniform float shore_line_width = 0.05;
uniform float fall_streak_wave = 0.3;
uniform float fall_streak_softness = 0.35;
uniform float fall_streak_scale = 1.5;
uniform float fall_speed = 6.0;
uniform float rapids_foam = 0.2;
group_uniforms reflection;
uniform vec4 sky_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float fresnel_strength = 0.2;
uniform float fresnel_power = 4.0;
uniform float specular_amount = 0.5;
uniform float roughness_amount = 0.08;
group_uniforms caustics;
uniform vec4 caustic_color : source_color = vec4(0.85, 1.0, 1.0, 1.0);
uniform float caustic_scale = 1.2;
uniform float caustic_speed = 0.6;
uniform float caustic_strength = 0.35;
group_uniforms distance;
uniform float far_distance = 40.0;
// Fade caustics, sparkles and the second crest layer out up to 1.5 x far_distance and skip them (plus refraction and
// player waves) beyond it.
uniform bool far_simplify = true;
// Far from the camera Terrain3D is a coarse mesh whose triangles zigzag across the water plane. From shore_lod_start on the
// shoreline comes from the real heightmap instead: the water ignores the coarse mesh (drawn shore_lod_bias metres closer,
// only over shallow water) and cuts itself where the real terrain rises above it.
uniform bool shore_mask_style = true;
uniform float shore_lod_bias = 3.0;
uniform float shore_lod_start = 12.0;
uniform float shore_object_tolerance = 0.35;
group_uniforms terrain_link;
// Terrain3D height data, set by WaterBody once it finds the terrain.
uniform bool shore_mask_ready = false;
uniform highp sampler2DArray terrain_heights : repeat_disable;
uniform int terrain_region_map[1024];
uniform float terrain_region_size = 1024.0;
uniform float terrain_density = 1.0;
group_uniforms surface_motion;
uniform bool motion_enabled = false;
uniform float swell_height = 0.1;
uniform float swell_scale = 4.0;
uniform float swell_speed = 0.25;
// Seconds, from WaterBody (shared with the CPU so floating matches the swell).
uniform float motion_time = 0.0;
uniform float pw_height = 0.14;
group_uniforms player_waves;
// Wave sources from WaterBody.add_wave: xyz = point on the surface, w = strength; ages in seconds.
uniform int wave_count = 0;
uniform vec4 wave_points[16];
uniform float wave_ages[16];
uniform float pw_length = 0.45;
uniform float pw_speed = 1.4;
uniform float pw_strength = 1.8;
uniform float pw_rings = 1.6;
uniform float pw_damping = 0.9;
uniform float pw_falloff = 0.25;
uniform float pw_highlight = 0.5;
group_uniforms underwater;
uniform vec4 under_surface_color : source_color = vec4(0.30, 0.62, 0.80, 1.0);
uniform float under_window = 0.6;
group_uniforms;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 flow_dir;
varying vec4 body;
// River mouth fade (UV2.x): 0 = opaque, 1 = gone. Lakes leave it at 0.
varying float mouth;
// Metres to the lip of a fall: 0 on the curtain, up to 6 on the river just above it, large elsewhere.
// Signed metres across the lip of a fall: negative up the river, positive down the curtain surface. lip_valid is 1 where
// that distance is known (near a lip), so interpolation with unmarked rows never draws a false band.
varying float lip_s;
// Signed metres from the foot of a fall (> 0 up the curtain, < 0 out over the water below); foot_valid 1 where known.
varying float foot_s;
varying float foot_valid;
varying float lip_valid;
// River sides fade (UV2.y > 0): 0 outside lakes, 1 from 1.5 m past the shore. Negative UV2.y marks the lip of a fall.
varying float mouth_sides;
varying float lip;
// 1 on the curtain rows of a fall (from the lip down), 0 elsewhere.
varying float curtain;

// Background swell: three crossing sine swells in world space (same for rivers and lakes, so their surfaces meet at the
// mouths). WaterBody.swell_at() computes the same height on the CPU so the swimmer floats on it. xyz = height and slope.
vec3 swell_at(vec2 xz, float time) {
	vec2 dirs[3] = vec2[3](normalize(vec2(1.0, 0.3)), normalize(vec2(-0.45, 1.0)), normalize(vec2(0.8, -0.7)));
	float sizes[3] = float[3](1.0, 0.63, 0.41);
	float weights[3] = float[3](0.5, 0.3, 0.2);
	float speeds[3] = float[3](1.0, 1.27, 1.61);
	vec3 result = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float k = 6.2831 / max(swell_scale * sizes[i], 0.05);
		float phase = dot(xz, dirs[i]) * k + time * speeds[i] * 6.2831;
		result.x += sin(phase) * weights[i];
		result.yz += dirs[i] * cos(phase) * k * weights[i];
	}
	return result;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Moving surface: lift the vertex with the swell and the player waves (not on falls).
	float vertex_fall = smoothstep(fall_start, fall_full, COLOR.r);
	if (motion_enabled && vertex_fall < 0.99) {
		float lift = swell_at(world_pos.xz, motion_time * swell_speed).x * swell_height;
		if (wave_count > 0) {
			float k = 6.2831 / max(pw_length, 0.02);
			float packet = max(pw_length * pw_rings, 0.02);
			for (int i = 0; i < wave_count; i++) {
				vec4 source = wave_points[i];
				if (abs(world_pos.y - source.y) > 0.75) {
					continue;
				}
				float r = length(world_pos.xz - source.xz);
				float x = r - wave_ages[i] * pw_speed;
				float env = source.w * exp(-wave_ages[i] * pw_damping) * exp(-(x * x) / (packet * packet)) / (1.0 + r * pw_falloff);
				lift += sin(k * x) * env * pw_height;
			}
		}
		lift *= 1.0 - vertex_fall;
		world_pos.y += lift;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
	}
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	flow_dir = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	body = COLOR;
	mouth = max(UV2.x, 0.0);
	foot_s = CUSTOM0.x;
	foot_valid = CUSTOM0.z;
	float across_code = -UV2.x;
	lip_valid = across_code >= 0.5 ? 1.0 : 0.0;
	lip_s = across_code >= 100.5 ? across_code - 101.0 : (across_code >= 0.5 ? 1.0 - across_code : 0.0);
	mouth_sides = max(UV2.y, 0.0);
	// UV2.y <= -2 marks a curtain row (lip = -UV2.y - 2 there); between 0 and -1 it is the highlight just above a lip.
	float lip_code = max(-UV2.y, 0.0);
	curtain = lip_code >= 1.5 ? 1.0 : 0.0;
	lip = lip_code >= 1.5 ? lip_code - 2.0 : lip_code;
}

// Integer hash (PCG2D). The usual fract(sin(...) * 43758.5) amplifies rounding differences: under Vulkan two neighbouring
// noise cells stopped agreeing on their shared edge, which drew hard square cuts. Integers give the same bits every time.
float hash(vec2 p) {
	uvec2 v = uvec2(ivec2(floor(p))) * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> uvec2(16u));
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> uvec2(16u));
	return float(v.x) / 4294967295.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance to the nearest of a jittered grid of moving points (cellular noise, F1).
float cells(vec2 p, float time) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = vec2(float(x), float(y));
			float h = hash(i + cell);
			vec2 point = 0.5 + 0.4 * sin(time + 6.2831 * vec2(h, fract(h * 7.31)));
			nearest = min(nearest, length(cell + point - f));
		}
	}
	return nearest;
}

// Nearest and second nearest distances to the moving cell points (F1, F2): F2 - F1 is small along cell borders.
vec2 cells2(vec2 p, float time) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = vec2(float(x), float(y));
			float h = hash(i + cell);
			vec2 point = 0.5 + 0.4 * sin(time + 6.2831 * vec2(h, fract(h * 7.31)));
			float d = length(cell + point - f);
			second = d < first ? first : min(second, d);
			first = min(first, d);
		}
	}
	return vec2(first, second);
}

// Crest lines: contour lines of a warped, drifting noise field (wavy strokes without junctions), broken into patches
// and dashes. x: line, y: field height (low = trough).
vec2 crest_layer(vec2 uv, float scale, vec2 scroll_m, float time) {
	vec2 p = (uv - scroll_m) / max(scale, 0.01);
	p.x /= max(crest_stretch, 0.1);
	p += (vec2(value_noise(p * 0.6 + time * 0.25), value_noise(p * 0.6 + 7.0 - time * 0.25)) - 0.5) * crest_wobble * 2.0;
	float h = value_noise(p + vec2(0.0, time * 0.4)) * 0.6 + value_noise(p * 2.03 - vec2(time * 0.3, 0.0)) * 0.3
		+ value_noise(p * 4.1 + time * 0.5) * 0.1;
	float contour = abs(fract(h * 4.0) - 0.5);
	float line = 1.0 - smoothstep(crest_width, crest_width + max(crest_softness, 0.001), contour);
	float patches = smoothstep(0.85 - crest_amount, 1.15 - crest_amount, value_noise(p * 0.45 + 13.0 + time * 0.2));
	float dashes = smoothstep(0.3, 0.6, value_noise(p * 1.7 + vec2(time * 0.5, 31.0)));
	return vec2(line * patches * dashes, h);
}

// Wave height in flow space: two layers drifting at different speeds and directions.
float waves(vec2 p, float time) {
	return value_noise(p + vec2(0.0, -time)) * 0.6 + value_noise(p * 2.1 + vec2(time * 0.37, -time * 1.3)) * 0.4;
}

// Real terrain height at one heightmap vertex, or -1e6 where there is no region.
float terrain_vertex(ivec2 vertex) {
	vec2 region = floor(vec2(vertex) / terrain_region_size);
	ivec2 cell = ivec2(region) + 16;
	if (uint(cell.x | cell.y) >= 32u) {
		return -1e6;
	}
	int layer = terrain_region_map[cell.y * 32 + cell.x] - 1;
	if (layer < 0) {
		return -1e6;
	}
	return texelFetch(terrain_heights, ivec3(vertex - ivec2(region * terrain_region_size), layer), 0).r;
}

float terrain_height(vec2 xz) {
	vec2 p = xz * terrain_density;
	ivec2 a = ivec2(floor(p));
	vec2 f = fract(p);
	return mix(mix(terrain_vertex(a), terrain_vertex(a + ivec2(1, 0)), f.x),
		mix(terrain_vertex(a + ivec2(0, 1)), terrain_vertex(a + ivec2(1, 1)), f.x), f.y);
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

// Height of one edge of the lip band at x: Base metres or fraction, uneven across the width at two scales and breathing
// over time.
float lip_edge(float x, float base, float ragged, float bt, float seed_off, float ragged_scale, float pulse) {
	float sx = x * ragged_scale;
	float h = base * (1.0 + (value_noise(vec2(sx * 1.3 + seed_off, bt)) - 0.5) * 1.6 * ragged);
	h *= 1.0 + (value_noise(vec2(sx * 4.0 + seed_off + 5.0, bt * 1.7 + 3.0)) - 0.5) * 0.6 * ragged;
	h *= 1.0 + pulse * 0.5 * sin(bt * 1.3 + sx * 0.7 + seed_off);
	return max(h, 0.0);
}

// Pointed shapes on one edge of the lip band, all with the same look and motion: dist is the distance from that edge
// (into the band for notches, out of it for spikes), size the mean length in metres.
float lip_points(float x, float dist, float size, float amount, float width, float seed_off, float bt, float softness) {
	float result = 0.0;
	float density = 1.0 / max(width * 2.5, 0.05);
	float base_cell = floor(x * density);
	for (int k = -1; k <= 1; k++) {
		float cell = base_cell + float(k);
		vec2 s = vec2(cell, fall_streak_seed + seed_off);
		if (hash(s) >= amount) {
			continue;
		}
		float phase = hash(s + 3.7) * 6.2831;
		float len = size * (0.45 + 0.55 * hash(s + 1.1)) * (1.0 + 0.35 * sin(bt * 2.0 + phase));
		float r = dist / max(len, 0.0005);
		if (r < 0.0 || r > 1.0) {
			continue;
		}
		// Each point stays inside its own cell (base at most 90 % of it), so neighbours never overlap.
		float cell_w = 1.0 / density;
		float base_w = min(0.5 * width * (0.6 + 0.8 * hash(s + 4.4)), 0.45 * cell_w);
		float centre = (cell + 0.5) * cell_w + (hash(s + 2.9) - 0.5) * (cell_w - 2.0 * base_w);
		float w = base_w * (1.0 - r);
		float soft = max(w * (0.15 + softness), 0.004);
		result = max(result, 1.0 - smoothstep(w - soft, w, abs(x - centre)));
	}
	return result;
}

// One edge of the lip band at signed distance out (beyond the edge: > 0, inside the band: < 0): the plain edge, then
// notches cut into it or spikes added out of it.
float lip_band_edge(float x, float out_dist, float edge_h, int shape, float amount, float size, float width, float seed_off,
		float bt, float softness) {
	float soft = max(edge_h * (0.05 + softness * 0.4), 0.01);
	float inside = 1.0 - smoothstep(-soft, 0.0, out_dist);
	if (amount <= 0.0 || size <= 0.0) {
		return inside;
	}
	if (shape == 0) {
		return inside * (1.0 - lip_points(x, -out_dist, min(size, edge_h), amount, width, seed_off, bt, softness));
	}
	// Spikes start inside the band's soft edge, so band and spike merge with no lighter or darker line at the base.
	return max(inside, lip_points(x, out_dist + soft, size + soft, amount, width, seed_off, bt, softness));
}

void fragment() {
	float flow = body.a;
	float slope = body.r;
	float rapids = smoothstep(rapids_start, rapids_full, slope);
	float fall = smoothstep(fall_start, fall_full, slope);
	float distance_to_camera = length(VERTEX);
	float far = smoothstep(far_distance, far_distance * 1.5, distance_to_camera);
	// Distance optimisation: detail fades with far and the costly blocks are skipped once it is gone. Whole screen regions
	// take the same branch (far water is far everywhere around it), so the skipped work is really saved.
	float detail = far_simplify ? 1.0 - far : 1.0;
	bool skip_detail = detail <= 0.001;
	// Beyond shore_lod_start the shoreline follows the real heightmap, not the coarse terrain mesh.
	float shore_ramp = 0.0;
	float real_ground = -1e6;
	if (shore_mask_style && shore_mask_ready && fall < 0.5 && CAMERA_POSITION_WORLD.y >= world_pos.y) {
		shore_ramp = smoothstep(shore_lod_start, shore_lod_start * 2.0, distance_to_camera);
		if (shore_ramp > 0.0) {
			real_ground = terrain_height(world_pos.xz);
			if (real_ground > world_pos.y) {
				discard;
			}
		}
	}

	// Flow space: rivers scroll downstream and stretch along the flow. Rapids and falls run faster through their UV.y, which
	// the mesh squeezes there (same scroll everywhere, so no shear stripes where the slope changes).
	float speed = flow_speed * flow;
	vec2 p = UV / max(wave_scale, 0.01);
	p.y /= mix(1.0, max(flow_stretch, 0.1), flow);
	float time = TIME * wave_speed;
	vec2 scroll = vec2(0.0, TIME * speed / max(wave_scale, 0.01));

	// Normal from the wave height, mapped back to world space through the flow frame.
	float e = 0.15;
	float h = waves(p - scroll, time);
	float hx = waves(p - scroll + vec2(e, 0.0), time);
	float hy = waves(p - scroll + vec2(0.0, e), time);
	// Normal toward the camera side, whatever the winding of the mesh (lake triangles face down; FRONT_FACING would flip
	// their up normal and max out the sky reflection).
	vec3 base_n = normalize(world_normal);
	if (dot(base_n, CAMERA_POSITION_WORLD - world_pos) < 0.0) {
		base_n = -base_n;
	}
	vec3 along = normalize(flow_dir - base_n * dot(flow_dir, base_n));
	vec3 across = cross(along, base_n);
	float strength = wave_strength * (1.0 + rapids) * (1.0 - far * 0.6);
	vec3 n = normalize(base_n - (across * (hx - h) + along * (hy - h)) / e * strength * 0.25);
	// The swell tilts the surface too, so its slopes catch the light and read as moving water.
	if (motion_enabled && fall < 0.5) {
		vec2 slope = swell_at(world_pos.xz, motion_time * swell_speed).yz * swell_height;
		n = normalize(n - vec3(slope.x, 0.0, slope.y) * (1.0 - fall) * (1.0 - far * 0.7));
	}
	// Player waves: expanding ring trains (a Gaussian packet of sine ripples) that fade with age and distance.
	float wave_height = 0.0;
	if (wave_count > 0 && fall < 0.5 && !skip_detail) {
		vec2 grad = vec2(0.0);
		float k = 6.2831 / max(pw_length, 0.02);
		float packet = max(pw_length * pw_rings, 0.02);
		for (int i = 0; i < wave_count; i++) {
			vec4 source = wave_points[i];
			if (abs(world_pos.y - source.y) > 0.75) {
				continue;
			}
			vec2 d = world_pos.xz - source.xz;
			float r = length(d);
			float x = r - wave_ages[i] * pw_speed;
			float env = source.w * exp(-wave_ages[i] * pw_damping) * exp(-(x * x) / (packet * packet)) / (1.0 + r * pw_falloff);
			float phase = k * x;
			wave_height += sin(phase) * env;
			grad += (d / max(r, 0.001)) * cos(phase) * env;
		}
		n = normalize(n - vec3(grad.x, 0.0, grad.y) * pw_strength * 0.35 * (1.0 - fall) * (1.0 - far));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Scene behind the surface: vertical water depth (horizontal surfaces) or thickness along the view (falls).
	float scene_depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bed_view = vec3(VERTEX.xy / -VERTEX.z * scene_depth, -scene_depth);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float thickness = max(scene_depth + VERTEX.z, 0.0);
	float vertical = max(world_pos.y - bed_world.y, 0.0);
	// The shore foam follows the real shoreline too, not the triangles of the coarse mesh.
	if (shore_ramp > 0.0 && real_ground > -1e5) {
		vertical = mix(vertical, world_pos.y - real_ground, shore_ramp);
	}
	float depth = mix(min(vertical, thickness), thickness, fall);

	// Refraction: bend the screen lookup with the waves, but never pick something in front of the water.
	vec2 offset = (n.xz - base_n.xz) * refraction * min(depth, 1.0) * (1.0 - far);
	vec2 refracted_uv = SCREEN_UV;
	if (!skip_detail) {
		refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
		if (view_depth(refracted_uv, INV_PROJECTION_MATRIX) < -VERTEX.z) {
			refracted_uv = SCREEN_UV;
		}
	}
	vec3 behind = texture(screen_texture, refracted_uv).rgb;

	// Caustics on the bed: bright moving cell edges, fading with depth.
	// Depth that drives the tone: real depth, or uniform_depth everywhere (falls always keep their own thickness).
	float tone_depth = mix(mix(uniform_depth, depth, depth_tone_amount), depth, fall);
	float caustics = 0.0;
	if (!skip_detail && caustic_strength > 0.0 && fall < 0.999) {
		vec2 cp = bed_world.xz / max(caustic_scale, 0.01);
		float c1 = cells(cp, TIME * caustic_speed);
		float c2 = cells(cp * 1.37 + 3.1, TIME * caustic_speed * 1.3);
		caustics = pow(clamp(1.0 - min(c1, c2) * 1.6, 0.0, 1.0), 3.0) * caustic_strength * exp(-tone_depth * 0.6) * (1.0 - fall)
			* detail;
	}

	// Body colour: shallow to deep with depth; the bed fades out with clarity.
	float deep_amount = 1.0 - exp(-tone_depth / max(depth_scale, 0.01));
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, deep_amount);
	// Rivers: lighter towards the banks, bluer in the middle of the channel (flow = 1 on rivers, 0 on lakes).
	water = mix(water, shallow_color.rgb * 1.08, (1.0 - smoothstep(0.0, 0.7, body.b)) * river_edge_light * flow * (1.0 - fall));
	// Around the diving player the water is clearer and tints it less (only on calm water, not on falls).
	float visible = exp(-tone_depth / max(clarity, 0.01)) * (1.0 - far * 0.7) * (1.0 - fall * 0.85);
	// A fall is a curtain: the cliff behind shows a little when seen face on, tinted by the falling water; at grazing
	// angles (the rounded sides, a side view) it turns solid, so the far side never shows through as a second sheet.
	float facing = abs(dot(n, normalize(CAMERA_POSITION_WORLD - world_pos)));
	visible = mix(visible, fall_transparency * smoothstep(0.35, 0.8, facing), fall);
	// Just before a lip the water turns opaque (fast, full of air), so the cliff edge under it never shows as a dark line.
	if (lip_valid > 0.999 && lip_s < 0.0) {
		visible *= smoothstep(0.0, max(fall_lip_opaque, 0.001), -lip_s);
	}
	vec3 bed = (behind + caustic_color.rgb * caustics) * mix(vec3(1.0), water, bed_tint);

	// Foam: where anything crosses the surface (banks, stones, the player), plus rapids.
	vec2 fp = UV / max(foam_noise_scale, 0.01) - scroll * wave_scale / max(foam_noise_scale, 0.01);
	float foam_noise = value_noise(fp + time * 0.5) * 0.65 + value_noise(fp * 2.3 - time * 0.3) * 0.35;
	// Not on falls: the cliff right behind the curtain would read as a shore everywhere and paint it white.
	float shore = (1.0 - smoothstep(0.0, max(foam_width, 0.001), min(vertical, thickness))) * (1.0 - fall);
	// Rapids foam stops where the slope becomes a fall: the curtain has its own streaks.
	// Not on the lip of a fall: there the river just bends over, without a strip of rapids foam.
	float churn = rapids * (1.0 - fall) * rapids_foam * (1.0 - smoothstep(0.05, 0.3, lip));
	float foam_mask = max(shore, churn) * (1.0 + foam_breakup) - foam_noise * foam_breakup;
	float foam = smoothstep(0.5 - foam_softness * 0.5, 0.5 + foam_softness * 0.5, foam_mask) * foam_strength;
	// A second thin dashed line a little further into the water, like the reference's bank lines.
	float shore_depth = min(vertical, thickness);
	float second_line = (1.0 - smoothstep(0.0, max(shore_line_width, 0.001), abs(shore_depth - shore_line_depth)))
		* smoothstep(0.35, 0.6, foam_noise) * shore_line_strength * (1.0 - fall);
	foam = max(foam, second_line * foam_strength);

	// Sparkles: stylized glints where two drifting noise fields peak together.
	float sparkle = 0.0;
	if (!skip_detail && sparkle_strength > 0.0) {
		vec2 sp = UV / max(sparkle_scale, 0.01) - scroll * wave_scale / max(sparkle_scale, 0.01);
		float glint = value_noise(sp + vec2(time * 0.6, 0.0)) * value_noise(sp * 1.7 + vec2(-time * 0.4, time * 0.2) + 5.0);
		glint *= 0.75 + 0.25 * sin(TIME * sparkle_twinkle + hash(floor(sp)) * 6.2831);
		float threshold = 1.0 - clamp(sparkle_amount, 0.0, 1.0);
		sparkle = smoothstep(threshold, threshold + max(sparkle_softness, 0.001), sqrt(glint)) * sparkle_strength * (1.0 - fall)
			* detail;
	}

	// Crests: the dense network of bright wavy lines that drifts with the flow, plus darker cell centres.
	vec2 scroll_m = vec2(0.0, TIME * speed);
	float crest_time = TIME * crest_speed;
	vec2 crest_a = crest_layer(UV, crest_scale, scroll_m, crest_time);
	// The second, finer layer already fades with far; it is not computed once gone (far = 1 without far_simplify too).
	float crest_b = 0.0;
	if (far < 0.999) {
		crest_b = crest_layer(UV + 17.0, crest_scale * 0.55, scroll_m * 1.15, crest_time * 1.3).x;
	}
	float crest = clamp(crest_a.x + crest_b * 0.8 * (1.0 - far), 0.0, 1.0) * crest_strength * (1.0 - fall) * (1.0 - foam) * (1.0 - far * 0.5);
	// Light on the crests of the player waves.
	crest = clamp(crest + smoothstep(0.15, 0.6, wave_height) * pw_highlight, 0.0, 1.0);
	water *= 1.0 - trough_shade * (1.0 - smoothstep(0.2, 0.8, crest_a.y)) * (1.0 - fall);

	// Waterfall sheet, cartoon style: long vertical streaks in flat tones (light, base, dark) falling with the water, and
	// darker towards the sides so the curtain reads rounded.
	// Streaks wobble sideways and bend into Vs (flames pointing up), like water sheeting over a rounded lip.
	float fall_y = UV.y - TIME * fall_speed;
	float chevron = abs(fract(UV.x * fall_streak_scale * 0.35) - 0.5) * 2.0;
	vec2 fall_p = vec2(UV.x * fall_streak_scale + sin(UV.y * 0.9 + value_noise(vec2(UV.x * 0.7, fall_y * 0.05)) * 4.0) * 0.35 * fall_streak_wave,
		(fall_y + chevron * 1.6 * fall_streak_wave) * fall_streak_length);
	float streak = value_noise(fall_p) * 0.6 + value_noise(fall_p * vec2(2.3, 1.6) + 3.0) * 0.4;
	float soft = 0.02 + fall_streak_softness * 0.2;
	float dark_band = 1.0 - smoothstep(0.24 - soft * 0.5, 0.24 + soft * 0.5, streak);
	// The curtain is the river's own water falling: its colours, darker lower down, and its crests stretched by the drop.
	float progress = 1.0 - sqrt(clamp(lip, 0.0, 1.0));
	// Water running through the lip and foot bands while they stay in place.
	float shimmer = 1.0 - fall_streak_shimmer * value_noise(vec2(UV.x * 3.0, (UV.y - TIME * fall_speed) * 0.8));
	vec3 river_tone = mix(shallow_color.rgb, deep_color.rgb, 0.35 + 0.4 * progress);
	vec3 fall_tone = mix(river_tone, fall_color.rgb, fall_color_mix);
	fall_tone = mix(fall_tone, fall_shadow_color.rgb, dark_band * 0.3);
	// Right below the lip it is the river's own crest pattern, which stretches into the falling one lower down. Only
	// computed on falls (elsewhere fall_tone is not used).
	float curtain_crest = crest_a.x;
	if (fall > 0.001) {
		vec2 falling_crest = crest_layer(UV * vec2(1.0, 0.3), crest_scale, vec2(0.0, TIME * fall_speed * 0.3), crest_time);
		curtain_crest = mix(crest_a.x, falling_crest.x, smoothstep(0.15, 0.7, progress));
	}
	fall_tone = mix(fall_tone, crest_color.rgb, clamp(curtain_crest * fall_crests, 0.0, 1.0));
	fall_tone = mix(fall_shadow_color.rgb, fall_tone, 0.55 + 0.45 * smoothstep(0.0, 0.4, body.b));
	// Light lines on top of the side shading, so they stay white up to the edges.
	// Soft horizontal ripples sliding down the curtain.
	fall_tone *= 0.94 + 0.06 * sin(fall_y * 2.2 + value_noise(vec2(UV.x * 1.3, fall_y * 0.4)) * 3.0);
	// A lighter translucent rim right at the sides.
	fall_tone = mix(fall_tone, fall_streak_color.rgb, (1.0 - smoothstep(0.0, 0.12, body.b)) * 0.35);

	float fresnel = pow(1.0 - clamp(dot(n, normalize(CAMERA_POSITION_WORLD - world_pos)), 0.0, 1.0), max(fresnel_power, 0.1)) * fresnel_strength;
	// Just before a lip (and on the band) the fast water shows its own colour instead of mirroring the sky, so the band's
	// spikes over the river read as clearly as its notches over the curtain.
	if (lip_valid > 0.999) {
		fresnel *= lip_s < 0.0 ? smoothstep(0.0, max(fall_lip_opaque, 0.001), -lip_s) : 1.0;
	}
	// On the curtain the sky reflection is its own amount (it shows as a glossy sheen just below the lip, where the
	// curtain is still nearly flat and seen at a grazing angle).
	fresnel *= mix(1.0, fall_reflection, fall);

	vec3 lit = mix(water, fall_tone, fall);
	lit = mix(lit, foam_color.rgb, foam);
	// The lip band: one strip across the lip, measured in one signed distance (up the river < 0 < down the curtain), so it
	// has no seam at the fold. Each edge is uneven (same noise, pulse and speed) and carries notches or spikes.
	float band_mark = 0.0;
	if (fall_lip_band > 0.0 && lip_valid > 0.999) {
		float bt = TIME * fall_lip_band_speed;
		float down_h = lip_edge(UV.x, fall_lip_band_height, fall_lip_band_ragged, bt, fall_streak_seed, fall_lip_band_ragged_scale,
			fall_lip_band_pulse);
		float up_h = lip_edge(UV.x, fall_lip_band_up, fall_lip_top_ragged, bt, fall_streak_seed + 7.0, fall_lip_band_ragged_scale,
			fall_lip_band_pulse);
		// Band Offset slides the whole band along the surface: down the curtain (> 0) or up the river (< 0).
		float band_s = lip_s - fall_lip_band_offset;
		float lower = lip_band_edge(UV.x, band_s - down_h, down_h, fall_lip_bottom_shape, fall_lip_bottom_amount,
			fall_lip_bottom_size, fall_lip_bottom_width, 31.0, bt, fall_lip_band_softness);
		float upper = lip_band_edge(UV.x, -band_s - up_h, up_h, fall_lip_top_shape, fall_lip_top_amount, fall_lip_top_size,
			fall_lip_top_width, 47.0, bt, fall_lip_band_softness);
		band_mark = min(lower, upper);
	}
	// The foot band: the same band anchored at the foot of the fall (up the curtain > 0 > out over the water below).
	float foot_mark = 0.0;
	if (fall_foot_band > 0.0 && foot_valid > 0.999) {
		float ft = TIME * fall_foot_band_speed;
		float up_h = lip_edge(UV.x, fall_foot_band_up, fall_foot_top_ragged, ft, fall_streak_seed + 61.0,
			fall_foot_band_ragged_scale, fall_foot_band_pulse);
		float down_h = lip_edge(UV.x, fall_foot_band_down, fall_foot_bottom_ragged, ft, fall_streak_seed + 67.0,
			fall_foot_band_ragged_scale, fall_foot_band_pulse);
		float fs = foot_s - fall_foot_band_offset;
		float top_edge = lip_band_edge(UV.x, fs - up_h, up_h, fall_foot_top_shape, fall_foot_top_amount, fall_foot_top_size,
			fall_foot_top_width, 71.0, ft, fall_foot_band_softness);
		float bottom_edge = lip_band_edge(UV.x, -fs - down_h, down_h, fall_foot_bottom_shape, fall_foot_bottom_amount,
			fall_foot_bottom_size, fall_foot_bottom_width, 73.0, ft, fall_foot_band_softness);
		foot_mark = min(top_edge, bottom_edge);
	}
	// Band Transparency lets the real water show through the band (its crests and motion), unlike Fall Lip Band.
	float lip_share = band_mark * (1.0 - fall_lip_band_transparency);
	float foot_share = foot_mark * (1.0 - fall_foot_band_transparency);
	float flat_amount = max(lip_share, foot_share);
	// The band is see-through (Fall Lip Band < 1) onto one even colour (Fall Color), not onto the water under it, which
	// differs on each side of the fold and would show the fold as a line through the band.
	vec3 lip_colour = mix(fall_color.rgb, fall_lip_band_color.rgb, fall_lip_band * shimmer);
	vec3 foot_colour = mix(fall_color.rgb, fall_foot_band_color.rgb, fall_foot_band * shimmer);
	vec3 band_colour = (lip_colour * lip_share + foot_colour * foot_share) / max(lip_share + foot_share, 0.001);
	vec3 flat_colour = band_colour;
	// The marks are opaque like foam, however see-through the curtain is.
	float body_amount = max(1.0 - visible, foam);
	vec3 albedo = lit * body_amount * (1.0 - crest);
	// The lip band and curtain strokes are flat colour, like drawn foam: no light, sky reflection or highlight on them, so
	// the band looks the same on the river side and the curtain side of the lip fold.
	float flat_marks = clamp(flat_amount, 0.0, 1.0);
	ALBEDO = albedo * (1.0 - flat_marks);
	// The water underneath is faded once (by flat_marks below), not twice: a double fade left a dark outline round the band.
	EMISSION = (bed * visible * (1.0 - foam) * (1.0 - crest) + sky_color.rgb * fresnel + sparkle_color.rgb * sparkle
		+ crest_color.rgb * crest + albedo * self_light) * (1.0 - flat_marks) + flat_colour * fall_marks_light * flat_marks;
	SPECULAR = specular_amount * (1.0 - flat_marks) * mix(1.0, fall_reflection, fall);
	ROUGHNESS = roughness_amount;
	// A river entering a lake fades out over it (rivers draw after lakes), so both surfaces cross-dissolve.
	// Inside the lake its sides fade too, so it spreads as a soft plume instead of a strip with straight edges.
	float plume = mix(1.0, smoothstep(0.0, 0.85, body.b), mouth_sides);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, mouth)) * plume;
	// Falls: solid sides with a crisp edge at the width of the water (the extra mesh under the banks is cut off). The
	// sides wave in the vertex shader (Fall Edge Waves), never dissolve.
	if (fall > 0.01) {
		ALPHA *= mix(1.0, smoothstep(0.0, 0.015, body.b), fall);
	}

	// Moved closer only to beat the coarse terrain: something in front whose real ground is under the water and that lies on
	// that ground. A real bank (real ground above the water) or an object (well above its ground) keeps hiding the water.
	float lod_bias = 0.0;
	if (shore_ramp > 0.0 && scene_depth < -VERTEX.z) {
		float occluder_ground = terrain_height(bed_world.xz);
		if (occluder_ground <= world_pos.y && bed_world.y - occluder_ground < shore_object_tolerance) {
			lod_bias = shore_lod_bias * shore_ramp * (1.0 - smoothstep(1.0, 2.0, world_pos.y - real_ground));
		}
	}
	vec4 biased_clip = PROJECTION_MATRIX * vec4(VERTEX * max(1.0 - lod_bias / max(distance_to_camera, 0.001), 0.01), 1.0);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = biased_clip.z / biased_clip.w * 0.5 + 0.5;
	#else
	DEPTH = biased_clip.z / biased_clip.w;
	#endif

	// Seen from below (diving): a bright ceiling with the sky only inside a cone looking up (Snell's window).
	// The camera height decides the side: the winding of lakes and rivers is not reliable for FRONT_FACING.
	if (CAMERA_POSITION_WORLD.y < world_pos.y && fall < 0.5) {
		vec3 view_dir = normalize(world_pos - CAMERA_POSITION_WORLD);
		float window = smoothstep(under_window, min(under_window + 0.25, 1.0), view_dir.y);
		vec2 wobble = (n.xz - base_n.xz) * 0.08;
		vec3 sky_through = texture(screen_texture, clamp(SCREEN_UV + wobble, vec2(0.001), vec2(0.999))).rgb;
		vec3 ceiling = mix(under_surface_color.rgb, sky_through * mix(vec3(1.0), shallow_color.rgb, 0.35), window);
		ALBEDO = vec3(0.0);
		EMISSION = ceiling * (1.0 - trough_shade * 0.3 * (1.0 - smoothstep(0.2, 0.8, crest_a.y))) + crest_color.rgb * crest * 0.2;
		SPECULAR = 0.0;
	}
}
