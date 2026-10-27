shader_type spatial;
#include "res://shaders/toon_lighting.gdshaderinc"
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 color_a : source_color = vec4(0.85,0.91,0.96,1);
uniform vec4 color_b : source_color = vec4(0.98,0.99,1,1);
uniform float color_variation = 0.08;
uniform float base_roughness = 0.95;
uniform float specular_amount = 0.12;
uniform int kind = 0;
uniform float realism = 0.85;
uniform bool toon_enabled = false;
uniform float toon_softness = 0.08;
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.0;
uniform vec2 wind_direction = vec2(1,0);
uniform vec3 camera_position = vec3(0);
uniform float draw_distance = 45.0;
uniform float fade_fraction = 0.2;
varying float variation;
varying vec3 world_position;
void vertex() {
	variation = INSTANCE_CUSTOM.x;
	if (kind == 2) {
		VERTEX.x *= mix(0.72,1.18,fract(variation*17.37));
		VERTEX.z *= mix(0.78,1.15,fract(variation*29.13));
		VERTEX.y *= 1.0 + sin(VERTEX.x*19.0+variation*31.0)*cos(VERTEX.z*17.0+variation*23.0)*realism*0.18;
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
	float fade = 1.0 - smoothstep(draw_distance * (1.0 - fade_fraction), draw_distance, distance(world.xz,camera_position.xz));
	VERTEX *= fade;
	if (kind == 3) {
		float weight = UV.y * UV.y;
		float wave = sin(TIME * wind_speed * 6.28318 + world.x * 0.8 + world.z * 0.5 + variation * 6.28);
		mat3 basis = mat3(MODEL_MATRIX);
		vec3 local_wind = transpose(basis) * vec3(wind_direction.x,0,wind_direction.y) / max(dot(basis[0],basis[0]),0.0001);
		VERTEX += local_wind * wave * wind_strength * weight * fade;
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
}
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 base = mix(color_a.rgb,color_b.rgb,variation);
	base *= 1.0 + (fract(variation * 71.43) - 0.5) * color_variation;
	if (kind == 3) base *= mix(0.68,1.05,UV.y);
	ALBEDO = base;
	ROUGHNESS = base_roughness;
	SPECULAR = toon_enabled ? 0.0 : specular_amount;
}
// Modelo local explícito: el modo global consulta este uniform sin sustituir
// el material; así Normal y Toon locales conservan su elección.
void light() {
	float nl = max(dot(NORMAL,LIGHT),0.0);
	float diffuse = nl;
	if (toon_enabled) {
		diffuse = trail_toon_ramp(diffuse);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse * ATTENUATION / PI;
	if (!toon_enabled && specular_amount > 0.0) {
		vec3 half_vector = normalize(LIGHT + VIEW);
		float power = mix(128.0,4.0,base_roughness);
		SPECULAR_LIGHT += LIGHT_COLOR * pow(max(dot(NORMAL,half_vector),0.0),power) * specular_amount * ATTENUATION * nl * 0.15;
	}
}
