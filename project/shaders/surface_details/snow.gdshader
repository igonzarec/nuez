shader_type spatial;
#include "res://shaders/toon_lighting.gdshaderinc"
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 color_a : source_color = vec4(0.85,0.91,0.96,1);
uniform vec4 color_b : source_color = vec4(0.98,0.99,1,1);
uniform float color_variation = 0.08;
uniform float base_roughness = 0.95;
uniform float specular_amount = 0.12;
uniform float grain_strength = 0.25;
uniform float snow_grain_size = 0.025;
uniform float snow_scatter = 0.25;
uniform float snow_sparkle = 0.06;
uniform float snow_albedo_gain = 0.75;
uniform bool snow_stylized = true;
uniform float snow_surface_scale = 0.32;
uniform float snow_surface_strength = 0.13;
uniform float snow_surface_contrast = 0.10;
uniform sampler2D footprint_mask : filter_linear, repeat_disable;
uniform vec2 tile_origin = vec2(0);
uniform float footprint_clock = 0.0;
uniform float footprint_lifetime = 120.0;
uniform bool toon_enabled = false;
uniform float toon_softness = 0.08;
uniform vec3 camera_position = vec3(0);
uniform float draw_distance = 40.0;
uniform float fade_fraction = 0.25;
varying vec3 world_position;
varying float sparkle;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float soft_snow(vec2 p) {
	vec2 warp = vec2(noise2(p*0.43+vec2(8,2)),noise2(p*0.43+vec2(2,9)));
	p += (warp-0.5)*1.4;
	return noise2(p)*0.7 + noise2(p*2.13+vec2(12,7))*0.3;
}
float footprint(vec2 uv) {
	vec2 data = texture(footprint_mask,uv).rg;
	float born = data.g / max(data.r,0.000001);
	return data.r * (1.0-smoothstep(footprint_lifetime*0.65,footprint_lifetime,footprint_clock-born));
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
}
void fragment() {
	float distance_fade = 1.0 - smoothstep(draw_distance*(1.0-fade_fraction), draw_distance, distance(world_position.xz,camera_position.xz));
	ALPHA = smoothstep(0.0,0.65,COLOR.a) * distance_fade;
	float broad = noise2(world_position.xz * 0.65);
	vec3 base = mix(color_a.rgb,color_b.rgb,0.78 + 0.15*broad) * snow_albedo_gain;
	base *= 1.0 + (broad-0.5)*color_variation*0.3;
	vec2 surface_uv = world_position.xz / max(snow_surface_scale,0.1);
	float surface_filter = 1.0-smoothstep(0.15,0.65,max(length(dFdx(surface_uv)),length(dFdy(surface_uv))));
	float mound = soft_snow(surface_uv);
	vec2 gradient = vec2(soft_snow(surface_uv+vec2(0.04,0))-soft_snow(surface_uv-vec2(0.04,0)),soft_snow(surface_uv+vec2(0,0.04))-soft_snow(surface_uv-vec2(0,0.04)))/0.08;
	vec3 relief_normal = (VIEW_MATRIX*vec4(-gradient.x,0,-gradient.y,0)).xyz;
	NORMAL = normalize(NORMAL+relief_normal*snow_surface_strength*surface_filter);
	float hollow = (1.0-smoothstep(0.2,0.8,mound))*snow_surface_contrast*surface_filter;
	base *= vec3(1.0-hollow,1.0-hollow*0.85,1.0-hollow*0.6);
	vec2 grain_uv = world_position.xz / max(snow_grain_size,0.005);
	// Retirar frecuencias antes del límite de Nyquist; nunca usar ruido temporal.
	float grain_footprint = max(length(dFdx(grain_uv)),length(dFdy(grain_uv)));
	float detail = 1.0 - smoothstep(0.2,0.65,grain_footprint);
	float grain = noise2(grain_uv);
	float micro_weight = snow_stylized ? 0.25 : 1.0;
	base *= 1.0 + (grain-0.5)*grain_strength*0.08*detail*micro_weight;
	vec3 perturb = vec3(noise2(grain_uv+vec2(8,3))-0.5,0,noise2(grain_uv+vec2(3,9))-0.5);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(perturb,0)).xyz * grain_strength * detail * 0.18 * micro_weight);
	sparkle = snow_stylized ? 0.0 : smoothstep(0.85,0.98,grain) * detail * snow_sparkle;
	vec2 print_uv = (world_position.xz-tile_origin)/16.0;
	float dent = footprint(print_uv);
	float texel = 1.0/512.0;
	vec2 dent_gradient = vec2(footprint(print_uv+vec2(texel,0))-footprint(print_uv-vec2(texel,0)),footprint(print_uv+vec2(0,texel))-footprint(print_uv-vec2(0,texel)))/(32.0*texel);
	NORMAL = normalize(NORMAL+(VIEW_MATRIX*vec4(dent_gradient.x,0,dent_gradient.y,0)).xyz);
	float compression = smoothstep(0.0,0.06,dent);
	base *= mix(vec3(1),vec3(0.58,0.68,0.8),compression);
	ALBEDO = base;
	ROUGHNESS = base_roughness;
	SPECULAR = specular_amount;
}
void light() {
	float nl = dot(NORMAL,LIGHT);
	float diffuse = max((nl + snow_scatter)/(1.0+snow_scatter),0.0);
	if (toon_enabled) {
		diffuse = trail_toon_ramp(diffuse);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse * ATTENUATION / PI;
	if (!toon_enabled) {
		float nh = max(dot(NORMAL,normalize(LIGHT+VIEW)),0.0);
		float broad = pow(nh,mix(64.0,8.0,base_roughness))*specular_amount*(snow_stylized ? 0.02 : 0.08);
		SPECULAR_LIGHT += LIGHT_COLOR * (broad + pow(nh,48.0)*sparkle) * ATTENUATION * max(nl,0.0);
	}
}
