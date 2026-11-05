shader_type canvas_item;
render_mode unshaded;

// Both fields die away smoothly inside the sprite. No cut edge, secondary
// floating layer, or outside-texture wrapping is introduced by the motion.
uniform vec2 grip_center = vec2(0.19, 0.50);
uniform vec2 other_center = vec2(0.35, 0.62);
uniform vec2 grip_radius = vec2(0.18, 0.24);
uniform vec2 other_radius = vec2(0.15, 0.20);
uniform vec2 grip_shift = vec2(0.0);
uniform vec2 other_shift = vec2(0.0);
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

float influence(vec2 uv, vec2 center, vec2 radius) {
    float distance_from_hand = length((uv - center) / radius);
    return 1.0 - smoothstep(0.42, 1.0, distance_from_hand);
}

void fragment() {
    vec2 uv = UV;
    vec2 source_uv = uv
        - grip_shift * influence(uv, grip_center + grip_shift, grip_radius)
        - other_shift * influence(uv, other_center + other_shift, other_radius);
    if (source_uv.x < 0.0 || source_uv.y < 0.0 || source_uv.x > 1.0 || source_uv.y > 1.0) {
        COLOR = vec4(0.0);
    } else {
        COLOR = texture(TEXTURE, source_uv) * vertex_tint;
    }
}
