shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 cloud_color : source_color = vec4(0.98, 0.99, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.62, 0.73, 0.85, 1.0);
uniform vec3 sun_direction = vec3(0.4, 0.8, 0.3);
uniform float shading_softness : hint_range(0.05, 1.0) = 0.75;
varying vec3 world_normal;
void vertex() { world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
    float light = dot(normalize(world_normal), normalize(sun_direction));
    float shade = smoothstep(-shading_softness, shading_softness, light);
    ALBEDO = mix(shadow_color.rgb, cloud_color.rgb, shade);
    ROUGHNESS = 1.0;
}
