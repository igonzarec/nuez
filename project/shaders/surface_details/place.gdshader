shader_type particles;
render_mode disable_force, disable_velocity;
uniform sampler2D positions : filter_nearest;
uniform sampler2D orientations : filter_nearest;
uniform int data_width = 256;
void start() {
	ivec2 pixel = ivec2(int(INDEX) % data_width, int(INDEX) / data_width);
	vec4 p = texelFetch(positions, pixel, 0);
	vec4 o = texelFetch(orientations, pixel, 0);
	vec3 up = normalize(o.xyz);
	vec3 reference = abs(up.z) < 0.99 ? vec3(0,0,1) : vec3(1,0,0);
	vec3 right = normalize(cross(up, reference));
	vec3 back = cross(right, up);
	float angle = o.a * 6.2831853;
	mat3 rotate_y = mat3(vec3(cos(angle),0,-sin(angle)), vec3(0,1,0), vec3(sin(angle),0,cos(angle)));
	mat3 basis = mat3(right, up, back) * rotate_y;
	TRANSFORM = mat4(vec4(basis[0] * p.a,0), vec4(basis[1] * p.a,0), vec4(basis[2] * p.a,0), vec4(p.xyz,1));
	CUSTOM = vec4(o.a, fract(o.a * 37.79), 0, 1);
	COLOR = vec4(1);
}
void process() { }
