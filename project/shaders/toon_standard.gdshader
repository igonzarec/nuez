shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/toon_lighting.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D roughness_texture : hint_default_white;
uniform sampler2D metallic_texture : hint_default_white;
uniform sampler2D ao_texture : hint_default_white;
uniform sampler2D emission_texture : source_color, hint_default_black;
uniform vec4 roughness_channel;
uniform vec4 metallic_channel;
uniform vec4 ao_channel;
uniform vec3 emission : source_color;
uniform float emission_energy = 1.0;
uniform bool emission_multiply = false;
uniform bool use_vertex_color = false;
uniform bool use_normal = false;
uniform bool use_ao = false;
uniform bool use_uv2_ao = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float normal_strength = 1.0;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform bool banded = true;
uniform float alpha_scissor = 0.5;
uniform float ao_light_affect = 0.0;
void vertex() { UV = UV * uv_scale.xy + uv_offset.xy; }
void fragment() {
    vec4 color = texture(albedo_texture, UV) * albedo;
    if (use_vertex_color) color *= COLOR;
    ALBEDO = color.rgb;
    // ALPHA_MODE
    ROUGHNESS = roughness * dot(texture(roughness_texture, UV), roughness_channel);
    METALLIC = banded ? 0.0 : metallic * dot(texture(metallic_texture, UV), metallic_channel);
    SPECULAR = banded ? 0.0 : specular;
    if (use_normal) {
        NORMAL_MAP = texture(normal_texture, UV).rgb;
        NORMAL_MAP_DEPTH = normal_strength;
    }
    if (use_ao) {
        AO = dot(texture(ao_texture, use_uv2_ao ? UV2 : UV), ao_channel);
        AO_LIGHT_AFFECT = ao_light_affect;
    }
    vec3 e = texture(emission_texture, UV).rgb;
    EMISSION = (emission_multiply ? emission * e : emission + e) * emission_energy;
}
void light() {
    float nl = max(dot(NORMAL, LIGHT), 0.0);
    float shade = banded ? trail_toon_ramp(nl) : nl;
    DIFFUSE_LIGHT += shade * ATTENUATION * LIGHT_COLOR / PI;
    if (!banded && specular > 0.0) {
        float nh = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
        SPECULAR_LIGHT += pow(nh, mix(128.0, 4.0, roughness)) * specular * ATTENUATION * LIGHT_COLOR * nl;
    }
}
