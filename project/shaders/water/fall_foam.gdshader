shader_type spatial;
// Foam on the water at the base of a fall, cartoon style: a soft white patch right under the foam lumps and curved white
// lines that spread outward from the impact and break into dashes. Created by WaterRiver (Cascada · efectos) on a plane
// lying on the water; local -Z points downstream.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float opacity = 0.85;
// Metres per foam detail.
uniform float noise_scale = 0.6;
uniform float drift_speed = 0.6;
// Radius of the solid white patch under the lumps (fraction of the plane).
uniform float patch_size = 0.19;
// Lines per unit of distance from the impact (more = closer lines).
uniform float rings = 5.0;
// How fast the lines move outward.
uniform float ring_speed = 1.2;
// 0-1: thickness of each line (fraction of the gap between lines).
uniform float line_width = 0.16;
// 0-1: how broken into dashes the lines are (0 = whole rings).
uniform float dashes = 0.5;
// How far out the lines reach before fading (fraction of the plane).
uniform float reach = 0.62;
// Waviness of the patch and the lines.
uniform float wobble = 0.06;

// Integer hash (PCG2D), same as water_surface: the sin() hash drew square cuts under Vulkan.
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

void fragment() {
	// Impact near the upstream edge of the plane (UV.y grows upstream, +Z); the foam fans out downstream.
	vec2 centered = (UV - vec2(0.5, 0.88)) * vec2(1.0, 1.25);
	float r = length(centered);
	float angle = atan(centered.x, -centered.y);
	float t = TIME * drift_speed;
	float wave = value_noise(vec2(angle * 3.0, t * 0.5)) * wobble;
	// Soft white patch right under the lumps.
	float patch = 1.0 - smoothstep(patch_size * 0.85, patch_size * 1.15, r + wave);
	// Curved lines moving outward, broken into dashes that drift sideways.
	float ring = fract((r + wave) * rings - t * ring_speed);
	float line = smoothstep(0.0, 0.05, ring) * (1.0 - smoothstep(line_width, line_width + 0.06, ring));
	float cut = mix(-0.1, 0.6, dashes);
	float dash = smoothstep(cut, cut + 0.2, value_noise(vec2(angle * 5.0 + t * 0.3, r * 3.0 - t)));
	float fade = 1.0 - smoothstep(reach * 0.5, reach, r);
	float foam = max(patch, line * dash * fade);
	ALBEDO = foam_color.rgb;
	ALPHA = clamp(foam * opacity, 0.0, 1.0);
}
