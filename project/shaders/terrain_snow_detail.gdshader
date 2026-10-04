shader_type spatial;
render_mode diffuse_burley;
uniform vec4 snow_color : source_color = vec4(0.88, 0.94, 0.98, 1.0);
uniform vec4 rock_color : source_color = vec4(0.29, 0.32, 0.34, 1.0);
// 0 = reflejo más definido/húmedo; 1 = luz muy dispersa, nieve mate y seca.
uniform float roughness : hint_range(0.0, 1.0) = 0.95;
// Apaga únicamente el patrón de grano fino; conserva las variaciones amplias y medias.
uniform bool grain_enabled = true;
uniform float grain_scale : hint_range(0.1, 40.0) = 8.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
// 1 conserva el antialias actual; 0 conserva el grano incluso a distancia.
uniform float grain_distance_fade : hint_range(0.0, 1.0) = 1.0;
uniform float broad_scale : hint_range(0.01, 5.0) = 0.65;
uniform float broad_strength : hint_range(0.0, 1.0) = 0.1;
// Intensidad de microrelieve de iluminación; no desplaza la malla.
uniform float micro_relief : hint_range(0.0, 1.0) = 0.08;
uniform float shading_softness : hint_range(0.0, 1.0) = 1.0;
uniform float flat_detail_strength : hint_range(0.0, 1.0) = 0.25;
// Frecuencia independiente del detalle mediano de las superficies planas.
uniform float flat_detail_scale : hint_range(0.1, 20.0) = 2.0;
varying vec3 world_point;
varying float surface_up;
uniform float snow_brightness : hint_range(0.1, 1.5) = 1.0;
uniform float flat_brightness : hint_range(0.1, 1.5) = 1.0;
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; surface_up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y; }
void fragment() {
 float snow = COLOR.r;
 float pixel_size = max(length(dFdx(world_point)), length(dFdy(world_point)));
 float anti_shimmer = 1.0 - smoothstep(0.25, 1.2, pixel_size * grain_scale);
 float fine_fade = mix(1.0, anti_shimmer, grain_distance_fade);
 float grain = (noise3(world_point * grain_scale) - 0.5) * fine_fade;
 if (!grain_enabled) { grain = 0.0; }
 float broad = (noise3(world_point * broad_scale) - 0.5) * (1.0 - smoothstep(0.25,1.2,pixel_size * broad_scale));
 float medium = (noise3(world_point * flat_detail_scale) - 0.5) * (1.0 - smoothstep(0.25,1.2,pixel_size * flat_detail_scale));
 // Color contrast remains visible on flat ground even with frontal illumination.
 vec3 snowy = snow_color.rgb * (1.0 + grain * grain_strength + broad * broad_strength + medium * flat_detail_strength);
 ALBEDO = mix(rock_color.rgb * (0.95 + broad * 0.15), snowy, snow);
 ALBEDO *= mix(1.0, snow_brightness * mix(1.0, flat_brightness, smoothstep(0.65, 0.98, surface_up)), snow);
 ROUGHNESS = mix(0.97, roughness, snow);
 SPECULAR = 0.18;
 vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
 if(dot(flat_normal,NORMAL)<0.0) flat_normal = -flat_normal;
 NORMAL = normalize(mix(flat_normal,NORMAL,shading_softness) + vec3(grain,0.0,-grain) * micro_relief * snow);
}
