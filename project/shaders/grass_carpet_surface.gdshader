shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.30, 0.45, 0.20, 1.0);
uniform float recolor : hint_range(0.0, 1.0) = 1.0;
uniform float texture_scale : hint_range(0.05, 10.0) = 1.0;
uniform vec2 tile_size = vec2(1.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.45;
uniform float contrast : hint_range(0.0, 2.0) = 0.65;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float macro_strength : hint_range(0.0, 0.5) = 0.06;
uniform float macro_scale : hint_range(0.01, 2.0) = 0.2;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = UV * texture_scale * tile_size;
    vec3 original = texture(albedo_texture, uv).rgb;
    float detail = dot(original, vec3(0.2126, 0.7152, 0.0722));
    // Normalized detail preserves authored tint rather than only darkening green.
    vec3 colored = tint.rgb * clamp(1.0 + (detail - 0.3) * contrast * 2.0, 0.3, 1.8);
    float macro = sin(world_position.x * macro_scale) * sin(world_position.z * macro_scale * 1.17);
    ALBEDO = mix(original * tint.rgb, colored, recolor) * brightness * (1.0 + macro * macro_strength);
    NORMAL_MAP = texture(normal_texture, uv).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = roughness;
    SPECULAR = 0.15;
}
