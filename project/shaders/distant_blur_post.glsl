#[versions]

copy = "#define MODE_COPY";
blur = "";

#[compute]
#version 450

// Distant blur as a post effect (Forward+), run by DistantBlurEffect after the transparent pass, so water, snow and
// particles blur like everything else. Same kernel as distant_blur.gdshader (the Compatibility version): a 3 x 3
// cross of samples whose spacing grows with depth, leaving out the sharp foreground so it never smears outward.
// "copy" copies the colour into a scratch texture; "blur" reads that copy (filtered) and writes back into the colour.

VERSION_DEFINES

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
#ifdef MODE_COPY
layout(rgba16f, set = 0, binding = 1) uniform image2D copy_image;
#else
layout(set = 0, binding = 1) uniform sampler2D copy_texture;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;
#endif

layout(push_constant, std430) uniform Params {
	mat4 inv_projection;
	vec2 size;
	float focus_distance;
	float far_transition;
	float blur_radius;
	float pad0;
	float pad1;
	float pad2;
} params;

#ifndef MODE_COPY
float view_depth(vec2 uv) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 position = params.inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -position.z / position.w;
}
#endif

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (pixel.x >= int(params.size.x) || pixel.y >= int(params.size.y)) {
		return;
	}
#ifdef MODE_COPY
	imageStore(copy_image, pixel, imageLoad(color_image, pixel));
#else
	vec2 uv = (vec2(pixel) + 0.5) / params.size;
	float amount = smoothstep(params.focus_distance, params.focus_distance + params.far_transition, view_depth(uv));
	if (amount <= 0.0) {
		return;
	}
	vec4 centre = textureLod(copy_texture, uv, 0.0);
	vec3 color = centre.rgb * 4.0;
	float weight = 4.0;
	vec2 offset = vec2(params.blur_radius * amount) / params.size;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			vec2 sample_uv = clamp(uv + vec2(float(x), float(y)) * offset, vec2(0.0), vec2(1.0));
			// Do not smear the sharp player/foreground into distant background pixels.
			float sample_weight = smoothstep(params.focus_distance - 1.0, params.focus_distance, view_depth(sample_uv));
			color += textureLod(copy_texture, sample_uv, 0.0).rgb * sample_weight;
			weight += sample_weight;
		}
	}
	imageStore(color_image, pixel, vec4(color / weight, centre.a));
#endif
}
