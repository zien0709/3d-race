shader_type spatial;
render_mode blend_mix;

// Gerstner wave parameters
uniform float anim_time = 0.0;
uniform float wave_speed = 0.5;
uniform float wave_height = 0.1;
uniform float wave_length = 2.0;
uniform vec2 wave_direction = vec2(1.0, 0.0);
uniform int wave_count = 3;
uniform float wave_steepness = 0.1;

// Depth fading
uniform float depth_fade_start = 5.0;
uniform float depth_fade_end = 15.0;

// Color properties
uniform vec4 water_color = vec4(0.02, 0.25, 0.5, 0.85);
uniform vec4 deep_color = vec4(0.0, 0.08, 0.2, 1.0);
uniform vec4 foam_color = vec4(0.9, 0.95, 1.0, 0.9);
uniform vec4 specular_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float reflectivity = 0.5;

varying vec3 v_world_pos;
varying vec3 v_normal;

float wave_phase(vec2 p, float t, vec2 dir) {
    float freq = 6.2831853 / wave_length;
    return dot(p, dir) * freq - t * wave_speed * freq;
}

void vertex() {
    vec3 pos = VERTEX;
    float t = anim_time;

    vec2 dirs[3];
    dirs[0] = wave_direction;
    dirs[1] = vec2(-wave_direction.y, wave_direction.x);
    dirs[2] = vec2(-wave_direction.x, -wave_direction.y) * 0.6;

    float amp = wave_height / float(wave_count);
    vec3 n = vec3(0.0, 1.0, 0.0);

    for (int i = 0; i < wave_count; i++) {
        float p = wave_phase(pos.xz, t, dirs[i]);
        pos.x += dirs[i].x * amp * wave_steepness * sin(p);
        pos.z += dirs[i].y * amp * wave_steepness * sin(p);
        pos.y += amp * cos(p);

        float wa = dirs[i].x * amp * wave_steepness;
        float wb = dirs[i].y * amp * wave_steepness;
        n.x += wa * cos(p);
        n.z += wb * cos(p);
        n.y += amp * sin(p);
    }

    VERTEX = pos;
    NORMAL = normalize(n);
    v_normal = normalize(n);
    v_world_pos = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;
}

void fragment() {
    vec3 view_dir = normalize(VIEW);
    vec3 normal = normalize(v_normal);
    float fresnel = pow(1.0 - max(dot(normal, normalize(view_dir)), 0.0), 3.0);

    // Simple distance-based depth fade toward deep color
    float depth = clamp((depth_fade_start - v_world_pos.y) / max(depth_fade_end - depth_fade_start, 0.001), 0.0, 1.0);
    vec3 base = mix(water_color.rgb, deep_color.rgb, depth);

    // Foam on wave crests
    float foam = smoothstep(0.55, 0.85, length(v_normal.xz));
    vec3 col = mix(base, foam_color.rgb, foam * foam_color.a);

    // Specular highlight
    vec3 half_vec = normalize(view_dir + normalize(VIEW));
    float spec = pow(max(dot(normal, half_vec), 0.0), 64.0) * reflectivity;
    col += specular_color.rgb * spec;

    ALBEDO = col;
    METALLIC = 0.0;
    ROUGHNESS = 0.05 + fresnel * 0.15;
    ALPHA = mix(water_color.a, 0.95, fresnel);
    SPECULAR = 1.0;
}
