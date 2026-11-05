shader_type spatial;
// Stylized water for WaterRiver / WaterLake. Values come from a WaterStyle resource (Inspector help lives there).
// Mesh data from the generator: UV = flow space in metres (x across, y downstream; lakes: world XZ),
// TANGENT = flow direction, COLOR.r = slope (0 flat, 1 vertical), COLOR.g = foam near a slope break (lip and base of
// a waterfall), COLOR.b = distance to the ribbon edge (0 edge, 1 inside), COLOR.a = flow amount (1 river, 0 lake).
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
uniform vec4 fall_color : source_color = vec4(0.78, 0.90, 0.98, 1.0);
uniform float fall_streak_scale = 3.0;
uniform float fall_speed = 6.0;
uniform float rapids_foam = 0.6;
uniform float break_foam = 1.0;
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
// River sides fade (UV2.y): 0 outside lakes, 1 from 1.5 m past the shore.
varying float mouth_sides;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	flow_dir = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	body = COLOR;
	mouth = UV2.x;
	mouth_sides = UV2.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	float flow = body.a;
	float slope = body.r;
	float rapids = smoothstep(rapids_start, rapids_full, slope);
	float fall = smoothstep(fall_start, fall_full, slope);
	float distance_to_camera = length(VERTEX);
	float far = smoothstep(far_distance, far_distance * 1.5, distance_to_camera);

	// Flow space: rivers scroll downstream (faster in rapids and falls) and stretch along the flow.
	float speed = flow_speed * flow * (1.0 + rapids * 1.5);
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
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Scene behind the surface: vertical water depth (horizontal surfaces) or thickness along the view (falls).
	float scene_depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bed_view = vec3(VERTEX.xy / -VERTEX.z * scene_depth, -scene_depth);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float thickness = max(scene_depth + VERTEX.z, 0.0);
	float vertical = max(world_pos.y - bed_world.y, 0.0);
	float depth = mix(min(vertical, thickness), thickness, fall);

	// Refraction: bend the screen lookup with the waves, but never pick something in front of the water.
	vec2 offset = (n.xz - base_n.xz) * refraction * min(depth, 1.0) * (1.0 - far);
	vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	if (view_depth(refracted_uv, INV_PROJECTION_MATRIX) < -VERTEX.z) {
		refracted_uv = SCREEN_UV;
	}
	vec3 behind = texture(screen_texture, refracted_uv).rgb;

	// Caustics on the bed: bright moving cell edges, fading with depth.
	vec2 cp = bed_world.xz / max(caustic_scale, 0.01);
	float c1 = cells(cp, TIME * caustic_speed);
	float c2 = cells(cp * 1.37 + 3.1, TIME * caustic_speed * 1.3);
	// Depth that drives the tone: real depth, or uniform_depth everywhere (falls always keep their own thickness).
	float tone_depth = mix(mix(uniform_depth, depth, depth_tone_amount), depth, fall);
	float caustics = pow(clamp(1.0 - min(c1, c2) * 1.6, 0.0, 1.0), 3.0) * caustic_strength * exp(-tone_depth * 0.6) * (1.0 - fall);

	// Body colour: shallow to deep with depth; the bed fades out with clarity.
	float deep_amount = 1.0 - exp(-tone_depth / max(depth_scale, 0.01));
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, deep_amount);
	// Around the diving player the water is clearer and tints it less (only on calm water, not on falls).
	float visible = exp(-tone_depth / max(clarity, 0.01)) * (1.0 - far * 0.7) * (1.0 - fall * 0.85);
	// The sides of a fall thin out so the sheet does not end in a hard edge.
	visible = mix(visible, 0.85, fall * (1.0 - smoothstep(0.0, 0.35, body.b)));
	vec3 bed = (behind + caustic_color.rgb * caustics) * mix(vec3(1.0), water, bed_tint);

	// Foam: where anything crosses the surface (banks, stones, the player), plus rapids and the lip/base of falls.
	vec2 fp = UV / max(foam_noise_scale, 0.01) - scroll * wave_scale / max(foam_noise_scale, 0.01);
	float foam_noise = value_noise(fp + time * 0.5) * 0.65 + value_noise(fp * 2.3 - time * 0.3) * 0.35;
	float shore = 1.0 - smoothstep(0.0, max(foam_width, 0.001), min(vertical, thickness));
	float churn = max(rapids * rapids_foam, body.g * break_foam);
	float foam_mask = max(shore, churn) * (1.0 + foam_breakup) - foam_noise * foam_breakup;
	float foam = smoothstep(0.5 - foam_softness * 0.5, 0.5 + foam_softness * 0.5, foam_mask) * foam_strength;

	// Sparkles: stylized glints where two drifting noise fields peak together.
	vec2 sp = UV / max(sparkle_scale, 0.01) - scroll * wave_scale / max(sparkle_scale, 0.01);
	float glint = value_noise(sp + vec2(time * 0.6, 0.0)) * value_noise(sp * 1.7 + vec2(-time * 0.4, time * 0.2) + 5.0);
	glint *= 0.75 + 0.25 * sin(TIME * sparkle_twinkle + hash(floor(sp)) * 6.2831);
	float threshold = 1.0 - clamp(sparkle_amount, 0.0, 1.0);
	float sparkle = smoothstep(threshold, threshold + max(sparkle_softness, 0.001), sqrt(glint)) * sparkle_strength * (1.0 - fall);

	// Crests: the dense network of bright wavy lines that drifts with the flow, plus darker cell centres.
	vec2 scroll_m = vec2(0.0, TIME * speed);
	float crest_time = TIME * crest_speed;
	vec2 crest_a = crest_layer(UV, crest_scale, scroll_m, crest_time);
	vec2 crest_b = crest_layer(UV + 17.0, crest_scale * 0.55, scroll_m * 1.15, crest_time * 1.3);
	float crest = clamp(crest_a.x + crest_b.x * 0.8 * (1.0 - far), 0.0, 1.0) * crest_strength * (1.0 - fall) * (1.0 - foam) * (1.0 - far * 0.5);
	water *= 1.0 - trough_shade * (1.0 - smoothstep(0.2, 0.8, crest_a.y)) * (1.0 - fall);

	// Waterfall sheet: streaks falling along the flow.
	float streak = value_noise(vec2(UV.x * fall_streak_scale, (UV.y - TIME * fall_speed) * 0.15)) * 0.65
		+ value_noise(vec2(UV.x * fall_streak_scale * 2.7 + 3.0, (UV.y - TIME * fall_speed * 1.3) * 0.3)) * 0.35;
	vec3 fall_tone = fall_color.rgb * mix(0.72, 1.15, smoothstep(0.2, 0.8, streak));

	float fresnel = pow(1.0 - clamp(dot(n, normalize(CAMERA_POSITION_WORLD - world_pos)), 0.0, 1.0), max(fresnel_power, 0.1)) * fresnel_strength;

	vec3 lit = mix(water, fall_tone, fall);
	lit = mix(lit, foam_color.rgb, foam);
	float body_amount = max(1.0 - visible, foam);
	vec3 albedo = lit * body_amount * (1.0 - crest);
	ALBEDO = albedo;
	EMISSION = bed * visible * (1.0 - foam) * (1.0 - crest) + sky_color.rgb * fresnel + sparkle_color.rgb * sparkle
		+ crest_color.rgb * crest + albedo * self_light;
	SPECULAR = specular_amount;
	ROUGHNESS = roughness_amount;
	// A river entering a lake fades out over it (rivers draw after lakes), so both surfaces cross-dissolve.
	// Inside the lake its sides fade too, so it spreads as a soft plume instead of a strip with straight edges.
	float plume = mix(1.0, smoothstep(0.0, 0.85, body.b), mouth_sides);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, mouth)) * plume;

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
