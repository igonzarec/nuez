shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 4.0) = 2.0;
void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 grid = floor(SCREEN_UV * resolution / pixel_size);
	vec2 uv = (grid + 0.5) * pixel_size / resolution;
	vec3 color = texture(screen_texture, uv).rgb;
	float ordered = mod(grid.x + mod(grid.y, 2.0) * 2.0, 4.0) / 4.0 - 0.375;
	color = floor(clamp(color + ordered / 80.0, 0.0, 1.0) * 40.0 + 0.5) / 40.0;
	COLOR = vec4(color, 1.0);
}
