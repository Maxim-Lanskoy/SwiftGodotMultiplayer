shader_type spatial;

// The main palette texture
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

// Target hue to SET for all colored pixels (-1 = no change, 0.0 = red, 0.33 = green, 0.58 = blue, 0.15 = yellow)
uniform float target_hue : hint_range(-1.0, 1.0) = -1.0;

// Saturation threshold - pixels with saturation above this are considered "colored"
uniform float saturation_threshold : hint_range(0.0, 1.0) = 0.15;

// Standard material properties
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Convert RGB to HSV
vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB
vec3 hsv_to_rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 albedo_color = texture(albedo_texture, UV);
    vec3 final_color = albedo_color.rgb;

    // Only apply hue modification if target_hue is non-negative
    if (target_hue >= 0.0) {
        vec3 hsv = rgb_to_hsv(albedo_color.rgb);

        // Set hue to target for colored pixels (saturation above threshold)
        // This makes all colored areas the same color (team color)
        if (hsv.y > saturation_threshold) {
            hsv.x = target_hue;
        }

        final_color = hsv_to_rgb(hsv);
    }

    ALBEDO = final_color;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
