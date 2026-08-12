shader_type spatial;

uniform float anim_time = 0.0;
uniform float grass_height = 0.5;
uniform float wind_strength = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
uniform float wind_speed = 1.0;
uniform float interaction_radius = 3.0;
uniform float interaction_strength = 1.0;
uniform vec3 vehicle_position = vec3(0.0, 0.0, 0.0);

varying vec3 v_world_pos;
varying float v_grass_uv_y;

void vertex() {
    vec3 pos = VERTEX;
    vec3 world_pos = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;
    v_world_pos = world_pos;
    v_grass_uv_y = clamp(pos.y / max(grass_height, 0.001), 0.0, 1.0);

    // Wind sway - stronger toward the blade tip
    float sway = pow(v_grass_uv_y, 1.5);
    float phase = anim_time * wind_speed + world_pos.x * 0.5 + world_pos.z * 0.3;
    vec3 wind_offset = wind_direction * sin(phase) * wind_strength * sway * 0.15;
    pos.x += wind_offset.x;
    pos.z += wind_offset.z;

    // Vehicle interaction - bend blades away and down near the car
    vec3 to_vehicle = vehicle_position - world_pos;
    float dist = length(to_vehicle.xz);
    if (dist < interaction_radius && dist > 0.01) {
        float influence = pow(1.0 - (dist / interaction_radius), 2.0) * interaction_strength;
        vec3 push_dir = normalize(vec3(to_vehicle.x, 0.0, to_vehicle.z));
        pos.x -= push_dir.x * influence * sway * 0.6;
        pos.z -= push_dir.z * influence * sway * 0.6;
        pos.y -= influence * sway * 0.3;
    }

    VERTEX = pos;
    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    vec3 root = vec3(0.06, 0.2, 0.05);
    vec3 tip = vec3(0.25, 0.55, 0.15);
    vec3 col = mix(root, tip, v_grass_uv_y);
    // Slight per-blade variation
    col *= 0.9 + 0.2 * sin(v_world_pos.x * 13.0 + v_world_pos.z * 17.0 + floor(v_world_pos.y * 50.0));
    ALBEDO = col;
    ROUGHNESS = 1.0;
}
