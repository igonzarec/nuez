shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform vec4 color_a : source_color;
uniform vec4 color_b : source_color;
uniform float color_variation = 0.22;
uniform float base_roughness = 1.0;
uniform float specular_amount = 0.0;
uniform bool toon_enabled = false;
uniform float toon_softness = 0.08;
uniform float wind_strength = 0.012;
uniform float wind_speed = 1.0;
uniform vec2 wind_direction = vec2(1,0);
uniform vec3 camera_position = vec3(0);
uniform float draw_distance = 40.0;
uniform float fade_fraction = 0.25;
varying float variation;
varying vec3 world_position;
varying float pixel_fade;

void vertex() {
	variation = INSTANCE_CUSTOM.x;
	VERTEX.x *= mix(0.6,1.2,fract(variation*19.7));
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
	float scale = max(length(MODEL_MATRIX[1].xyz),0.0001);
	float wave = sin(TIME*wind_speed*6.28318 + dot(world.xz,wind_direction)*0.8 + variation*6.28);
	// La hoja se levanta desde su apoyo; no oscila a través del suelo.
	VERTEX.y += (0.5+0.5*wave) * wind_strength / scale * abs(UV.x-0.5);
	world_position = (MODEL_MATRIX * vec4(VERTEX,1)).xyz;
	float view_depth = max(0.01,-(VIEW_MATRIX*vec4(world_position,1)).z);
	float pixels = scale * abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y / (2.0*view_depth);
	pixel_fade = smoothstep(1.5,4.0,pixels);
}
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 base = mix(color_a.rgb,color_b.rgb,variation);
	base *= 1.0 + (fract(variation*71.43)-0.5)*color_variation;
	float vein = 1.0-smoothstep(0.015,0.045,abs(UV.x-0.5));
	ALBEDO = base * (1.0-0.13*vein);
	ROUGHNESS = base_roughness;
	SPECULAR = specular_amount;
	ALPHA = pixel_fade * (1.0-smoothstep(draw_distance*(1.0-fade_fraction),draw_distance,distance(world_position.xz,camera_position.xz)));
}
void light() {
	float nl = max(dot(NORMAL,LIGHT),0.0);
	float diffuse = nl;
	if (toon_enabled) {
		float width = max(0.001,toon_softness*0.5);
		diffuse = smoothstep(0.5-width,0.5+width,nl);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse * ATTENUATION / PI;
	if (!toon_enabled && specular_amount > 0.0) {
		float nh = max(dot(NORMAL,normalize(LIGHT+VIEW)),0.0);
		SPECULAR_LIGHT += LIGHT_COLOR * pow(nh,mix(128.0,4.0,base_roughness))*specular_amount*ATTENUATION*nl*0.15;
	}
}
