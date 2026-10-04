shader_type spatial;
render_mode diffuse_burley;

uniform vec4 snow_color : source_color = vec4(0.88, 0.94, 0.98, 1.0);
uniform vec4 rock_color : source_color = vec4(0.29, 0.32, 0.34, 1.0);
// 0 = reflejo más definido/húmedo; 1 = luz muy dispersa, nieve mate y seca.
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
// Apaga únicamente el patrón de grano fino; conserva color, brillo y detalle medio.
uniform bool grain_enabled = true;
uniform float grain_scale : hint_range(0.1, 40.0) = 12.0;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.07;
// 1 conserva el antialias actual; 0 conserva el grano incluso a distancia.
uniform float grain_distance_fade : hint_range(0.0, 1.0) = 1.0;
// Intensidad de microrelieve de iluminación; no desplaza la malla.
uniform float micro_relief : hint_range(0.0, 0.3) = 0.045;
uniform float shading_softness : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_point;
varying float surface_up;
uniform float flat_detail_strength : hint_range(0.0, 1.0) = 0.0;
// Frecuencia independiente del detalle mediano de las superficies planas.
uniform float flat_detail_scale : hint_range(0.1, 20.0) = 2.0;
uniform float snow_brightness : hint_range(0.1, 1.5) = 1.0;
uniform float flat_brightness : hint_range(0.1, 1.5) = 1.0;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; surface_up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y; }
void fragment() {
	float snow = COLOR.r;
	// Fade subpixel grain to avoid shimmering when viewing the whole mountain.
	float frequency = grain_scale;
	float footprint = max(length(dFdx(world_point)), length(dFdy(world_point))) * frequency;
	float anti_shimmer = 1.0 - smoothstep(0.25, 1.2, footprint);
	float detail = mix(1.0, anti_shimmer, grain_distance_fade);
	float grain = (noise3(world_point * frequency) - 0.5) * detail;
	if (!grain_enabled) { grain = 0.0; }
	float broad = noise3(world_point * 0.35) - 0.5;
	ALBEDO = mix(rock_color.rgb * (0.94 + broad * 0.16), snow_color.rgb * (1.0 + grain * grain_strength + broad * 0.035), snow);
	float medium_footprint = max(length(dFdx(world_point)), length(dFdy(world_point))) * flat_detail_scale;
	float medium = (noise3(world_point * flat_detail_scale) - 0.5) * (1.0 - smoothstep(0.25, 1.2, medium_footprint));
	ALBEDO *= mix(1.0, (1.0 + medium * flat_detail_strength) * snow_brightness * mix(1.0, flat_brightness, smoothstep(0.65, 0.98, surface_up)), snow);
	ROUGHNESS = mix(0.97, roughness, snow);
	SPECULAR = 0.22;
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(flat_normal, NORMAL) < 0.0) { flat_normal = -flat_normal; }
	vec3 base_normal = normalize(mix(flat_normal, NORMAL, shading_softness));
	vec3 bump = vec3(grain, broad * detail, -grain) * micro_relief * snow;
	NORMAL = normalize(base_normal + bump);
}
