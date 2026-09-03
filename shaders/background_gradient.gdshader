shader_type canvas_item;

uniform float time = 0.0;
uniform vec2 resolution = vec2(1280.0, 720.0);

// Color palette
vec3 color1 = vec3(0.06, 0.08, 0.12);  // Deep blue
vec3 color2 = vec3(0.10, 0.12, 0.16);  // Dark blue
vec3 color3 = vec3(0.15, 0.18, 0.22);  // Medium blue
vec3 color4 = vec3(0.08, 0.10, 0.14);  // Darker blue

// Accent colors
vec3 accent1 = vec3(0.22, 0.74, 0.97);  // Cyan
vec3 accent2 = vec3(0.30, 0.85, 0.45);  // Green

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec3 palette(float t) {
    // Color palette interpolation
    vec3 a = color1;
    vec3 b = color2;
    vec3 c = color3;
    vec3 d = color4;
    
    if (t < 0.25) {
        return mix(a, b, t * 4.0);
    } else if (t < 0.5) {
        return mix(b, c, (t - 0.25) * 4.0);
    } else if (t < 0.75) {
        return mix(c, d, (t - 0.5) * 4.0);
    } else {
        return mix(d, a, (t - 0.75) * 4.0);
    }
}

void fragment() {
    vec2 uv = FRAGCOORD.xy / resolution;
    vec2 uv_centered = uv - 0.5;
    
    // Time-based animation
    float t = time * 0.1;
    
    // Base gradient
    vec3 base_color = mix(color1, color2, uv.y);
    
    // Add animated noise
    float n = fbm(uv * 3.0 + vec2(t * 0.5, t * 0.3));
    float n2 = fbm(uv * 6.0 + vec2(t * 0.2, -t * 0.4));
    
    // Radial gradient from center
    float dist = length(uv_centered * 2.0);
    float radial = 1.0 - smoothstep(0.0, 1.5, dist);
    
    // Combine
    vec3 color = base_color;
    color += radial * vec3(0.05, 0.05, 0.1) * (1.0 + n * 0.5);
    color += vec3(0.02, 0.02, 0.03) * n2;
    
    // Subtle accent glow at center
    float glow = smoothstep(1.0, 0.3, dist) * 0.15;
    color += vec3(0.22, 0.74, 0.97) * glow * (0.5 + 0.5 * sin(time * 2.0));
    
    // Subtle scanline effect
    float scanline = sin(uv.y * resolution.y * 0.5 + time * 10.0) * 0.01;
    color += scanline;
    
    // Vignette
    float vignette = 1.0 - smoothstep(0.5, 1.5, dist);
    color *= vignette;
    
    COLOR = vec4(color, 1.0);
}
