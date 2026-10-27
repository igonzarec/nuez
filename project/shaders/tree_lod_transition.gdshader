shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 1.0;
uniform float specular_amount = 0.1;
uniform vec3 fade_camera = vec3(0.0);
uniform bool camera_valid = false;
uniform float transition_start = 60.0;
uniform float transition_end = 90.0;
uniform bool far_mesh = false;
uniform bool smooth_transition = true;
varying flat vec3 instance_origin;

void vertex() {
	// MODEL_MATRIX includes each MultiMesh instance transform here.
	instance_origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float dist = distance(instance_origin, fade_camera);
	float blend = smoothstep(transition_start, transition_end, dist);
	if (!smooth_transition) blend = step((transition_start + transition_end) * 0.5, dist);
	if (!camera_valid) blend = 0.0;
	// Complementary masks: a pixel belongs to one representation, never two.
	float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
	if (far_mesh) {
		if (blend <= threshold) discard;
	} else {
		if (blend > threshold) discard;
	}
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ALBEDO = base_color.rgb;
	ROUGHNESS = base_roughness;
	SPECULAR = specular_amount;
}
