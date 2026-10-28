shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 cliff_tint : source_color = vec4(1.0);
uniform float grass_scale = 0.1;
uniform float cliff_scale = 0.1;
uniform float slope_start = 45.0;
uniform float slope_width = 10.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

vec3 project_texture(sampler2D tex, vec3 position, vec3 weights, float scale) {
	return texture(tex, position.zy * scale).rgb * weights.x
		+ texture(tex, position.xz * scale).rgb * weights.y
		+ texture(tex, position.xy * scale).rgb * weights.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	float angle = degrees(acos(clamp(n.y, -1.0, 1.0)));
	float rock = smoothstep(slope_start, slope_start + slope_width, angle);
	vec3 grass = project_texture(grass_texture, world_position, weights, grass_scale) * grass_tint.rgb;
	vec3 cliff = project_texture(cliff_texture, world_position, weights, cliff_scale) * cliff_tint.rgb;
	ALBEDO = mix(grass, cliff, rock);
	ROUGHNESS = 1.0;
}
