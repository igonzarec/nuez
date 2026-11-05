shader_type spatial;
// Cartoon foam lumps and droplets at the base of a fall (WaterRiver › Cascada · efectos): two flat tones (light and
// shadow) from a fixed light, a soft rim, and a gentle pulse per lump (INSTANCE_CUSTOM.x = phase, .y = speed).
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled, fog_disabled;

uniform vec4 light_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.6, 0.8, 0.96, 1.0);
// 0-1: how much each lump swells and settles.
uniform float pulse = 0.35;
// 0-1: lumps slightly translucent, the water behind shows through.
uniform float opacity = 0.85;
uniform vec3 light_direction = vec3(-0.45, 0.7, 0.55);
// 0-1: how much of the shadow tone shows (0 = flat light colour, no shadow side).
uniform float shading = 1.0;
// Life cycle: each lump grows from nothing, shrinks away and comes back somewhere else with another size.
uniform bool life_enabled = true;
// Cycles per second (average).
uniform float life_speed = 0.45;
// 0-1: how much the rhythm differs between lumps.
uniform float life_speed_variation = 0.6;
// 0-1: how much the size changes from one appearance to the next.
uniform float life_size_variation = 0.5;
// How far (in lump radii) a lump moves between appearances.
uniform float wander = 0.8;
// 0-1: smallest size during the cycle (0 = it vanishes completely).
uniform float min_size = 0.0;
// 0-1: share of the cycle spent fully grown (0 = always growing or shrinking).
uniform float hold = 0.3;

varying vec3 world_normal;

float hash1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float speed = max(INSTANCE_CUSTOM.y, 0.1);
	float beat = sin(TIME * 3.2 * speed + phase);
	// Swell and settle, a little higher when big: boiling foam.
	// Lumpy, not a perfect ball: bumps that roll slowly around each lump.
	float bumps = sin(VERTEX.x * 3.1 + phase + TIME * 1.3) * sin(VERTEX.z * 2.7 - phase * 0.7 + TIME) * sin(VERTEX.y * 3.4 + phase * 1.3);
	VERTEX += NORMAL * bumps * 0.16;
	VERTEX *= 1.0 + beat * 0.18 * pulse;
	if (life_enabled) {
		float id = float(INSTANCE_ID);
		float rate = max(life_speed * (1.0 + (hash1(id * 1.7) - 0.5) * 2.0 * life_speed_variation), 0.01);
		float t = TIME * rate + hash1(id * 3.1);
		float cycle = floor(t);
		float life = fract(t);
		// Grow, hold, shrink: a rounded bump with a flat top of Hold.
		float edge = (1.0 - clamp(hold, 0.0, 0.95)) * 0.5;
		float grow = smoothstep(0.0, edge, life) * (1.0 - smoothstep(1.0 - edge, 1.0, life));
		float size = max(1.0 + (hash1(cycle * 7.3 + id * 1.9) - 0.5) * 2.0 * life_size_variation, 0.1);
		VERTEX *= mix(min_size, 1.0, grow) * size;
		// A new spot for every appearance, and a little rise while it grows.
		VERTEX += vec3(hash1(cycle * 5.1 + id * 2.3) - 0.5, 0.0, hash1(cycle * 9.7 + id * 4.1) - 0.5) * 2.0 * wander;
		VERTEX.y += grow * 0.15;
	}
	VERTEX.y += max(beat, 0.0) * 0.25 * pulse;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float lit = dot(normalize(world_normal), normalize(light_direction));
	// Two tones with a short soft step, like the rest of the water's flat shading.
	float tone = smoothstep(0.42, 0.52, lit);
	vec3 colour = mix(light_color.rgb, mix(shadow_color.rgb, light_color.rgb, tone), shading);
	// Thin brighter rim facing the camera's edge.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(colour, light_color.rgb, rim * 0.35);
	// Thinner (more see-through) towards the silhouette.
	ALPHA = opacity * mix(1.0, 0.75, rim);
}
