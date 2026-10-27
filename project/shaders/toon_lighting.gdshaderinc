// Shared direct-light ramp. Ambient light and shadow filtering remain independent.
uniform int trail_toon_bands = 3;
uniform float trail_toon_softness = 0.08;
uniform float trail_toon_offset = 0.0;
uniform float trail_toon_contrast = 1.0;
float trail_toon_ramp(float nl) {
    float intervals = float(max(trail_toon_bands - 1, 1));
    float x = clamp((nl - 0.5) * trail_toon_contrast + 0.5 + trail_toon_offset, 0.0, 1.0);
    float width = max(0.0001, trail_toon_softness * 0.5 / intervals);
    float result = 0.0;
    for (int i = 1; i < 6; i++) {
        if (i < trail_toon_bands) {
            float edge = (float(i) - 0.5) / intervals;
            result += smoothstep(edge - width, edge + width, x);
        }
    }
    return result / intervals;
}
