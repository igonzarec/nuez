shader_type spatial;
// Expanding ring on the water surface around a swimmer or a splash. PlayerSwimming drives Age (0 = born, 1 = gone) and
// scales the plane to the ring diameter. Broken into dashes so it matches the crest lines of the water style.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(0.93, 0.98, 1.0, 1.0);
uniform float age = 1.0;
uniform float opacity = 0.75;
uniform float ring_width = 0.07;
// Foam disc inside the ring (0 = only the ring). Splashes use it for the churned water at the impact.
uniform float fill = 0.0;

void fragment() {
	vec2 centered = UV - 0.5;
	float r = length(centered) * 2.0;
	float grow = 1.0 - pow(1.0 - age, 2.0);
	float radius = mix(0.12, 0.95, grow);
	float width = ring_width * mix(1.0, 2.2, age);
	float ring = 1.0 - smoothstep(0.0, width, abs(r - radius));
	// A fainter inner echo, like the second wave behind the first.
	float echo = (1.0 - smoothstep(0.0, width, abs(r - radius * 0.62))) * 0.45;
	float angle = atan(centered.y, centered.x);
	float dashes = smoothstep(-0.35, 0.4, sin(angle * 9.0 + radius * 6.0) + sin(angle * 4.0 - 1.3) * 0.6);
	float fade = (1.0 - age) * smoothstep(0.0, 0.08, age);
	float disc = (1.0 - smoothstep(radius - width * 2.0, radius, r)) * fill * smoothstep(-0.6, 0.8, sin(angle * 5.0 + r * 11.0) + sin(r * 23.0 - angle * 3.0));
	ALBEDO = ring_color.rgb;
	ALPHA = clamp(max(max(ring, echo) * mix(0.55, 1.0, dashes), disc) * fade * opacity, 0.0, 1.0);
}
