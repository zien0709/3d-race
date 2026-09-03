shader_type canvas_item;

// Glassmorphism / Frosted Glass Shader for Godot 4.x
// Based on: https://godotshaders.com/shader/frosted-glass-2/
// Enhanced with: tint, rim light, noise, chromatic aberration

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Blur intensity (0.0 - 0.5). Higher = more blur, but more expensive.
uniform float blur_intensity: hint_range(0.0, 0.5) = 0.08;

// Base tint color (RGB) with alpha for opacity
uniform vec4 tint_color: source_color = vec4(0.06, 0.08, 0.12, 0.6);

// How much the tint affects the result (0.0 - 1.0)
uniform float tint_amount: hint_range(0.0, 1.0) = 0.4;

// Rim light intensity at edges (0.0 - 1.0)
uniform float rim_intensity: hint_range(0.0, 1.0) = 0.3;

// Rim light color
uniform vec3 rim_color: source_color = vec3(0.22, 0.74, 0.97);

// Noise texture for subtle grain/speckle
uniform sampler2D noise_texture: hint_default_white, repeat_enable, filter_linear_mipmap;

// Noise intensity (0.0 - 0.1)
uniform float noise_amount: hint_range(0.0, 0.1) = 0.02;

// Chromatic aberration strength (0.0 - 0.02)
uniform float chromatic_aberration: hint_range(0.0, 0.02) = 0.002;

// Edge fade - makes corners more transparent
uniform float edge_fade: hint_range(0.0, 1.0) = 0.15;

// ----------------------------------------------------------------
// Helper: Sample screen texture with mipmap-based blur
// ----------------------------------------------------------------
vec4 sample_blurred(vec2 uv, float lod) {
    return textureLod(screen_texture, uv, lod);
}

// ----------------------------------------------------------------
void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Calculate blur LOD based on intensity
    // intensity 0.08 -> LOD ~0.64, intensity 0.3 -> LOD ~2.4
    float lod = blur_intensity * 8.0;
    
    // Base blurred background
    vec4 bg = sample_blurred(uv, lod);
    
    // Chromatic aberration: sample R/G/B at slightly different UVs
    vec2 ca_offset = (uv - 0.5) * chromatic_aberration;
    float r = sample_blurred(uv + ca_offset, lod).r;
    float g = bg.g;
    float b = sample_blurred(uv - ca_offset, lod).b;
    vec3 chromatic_rgb = vec3(r, g, b);
    
    // Apply tint
    vec3 tinted = mix(chromatic_rgb, tint_color.rgb, tint_amount);
    
    // Rim light at edges
    float dist_from_center = length(uv - 0.5) * 2.0;
    float rim = smoothstep(0.7, 1.0, dist_from_center);
    vec3 rim_light = rim_color * rim * rim_intensity;
    
    // Noise/grain
    vec4 noise = texture(noise_texture, uv * 50.0);
    float grain = (noise.r - 0.5) * noise_amount;
    
    // Combine everything
    vec3 result = tinted + rim_light + vec3(grain);
    
    // Edge fade for rounded corners compatibility
    float edge = 1.0 - smoothstep(0.5 - edge_fade, 0.5, dist_from_center);
    float alpha = tint_color.a * edge;
    
    COLOR = vec4(result, alpha);
}
