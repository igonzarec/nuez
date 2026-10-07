shader_type spatial;
render_mode cull_disabled;

uniform vec4 palette[32] : source_color;
uniform int palette_count = 3;
uniform vec4 root_tint : source_color = vec4(0.55, 0.64, 0.45, 1.0);
uniform vec4 tip_tint : source_color = vec4(1.0);
uniform float color_variation : hint_range(0.0, 0.5) = 0.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float normal_up : hint_range(0.0, 1.0) = 0.7;
uniform float backlight : hint_range(0.0, 1.0) = 0.2;
uniform bool wind_enabled = false;
uniform float wind_strength : hint_range(0.0, 0.3) = 0.04;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float fade_start = 28.0;
uniform float fade_end = 40.0;
varying vec3 blade_color;

void vertex() {
    int index = min(int(INSTANCE_CUSTOM.r * float(palette_count)), palette_count - 1);
    blade_color = palette[index].rgb * mix(1.0 - color_variation, 1.0 + color_variation, INSTANCE_CUSTOM.g);
    vec3 world_base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float distance_to_camera = distance(world_base, CAMERA_POSITION_WORLD);
    float fade = 1.0 - smoothstep(fade_start, max(fade_start + 0.01, fade_end), distance_to_camera);
    VERTEX *= fade;
    if (wind_enabled) {
        float wave = sin(TIME * wind_speed + world_base.x * 0.8 + world_base.z * 0.6);
        VERTEX.xz += wind_direction * wave * wind_strength * UV.y * UV.y * fade;
    }
    NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_up));
}

void fragment() {
    vec3 world_up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
    if (dot(NORMAL, world_up_view) < 0.0) { NORMAL = -NORMAL; }
    ALBEDO = blade_color * mix(root_tint.rgb, tip_tint.rgb, UV.y);
    ROUGHNESS = roughness;
    SPECULAR = 0.15;
    BACKLIGHT = ALBEDO * backlight;
}
