shader_type canvas_item;
// A subtle UV deformation of the actual still-pose pixels, not invented frames.
// Opposite hands/feet counter-swing as the actor walks. The material is unique
// per rig, so guards don't move in mechanical lockstep with the player.
uniform float phase = 0.0;
uniform float amount = 0.0;
uniform float guard_pose = 0.0;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

float region(vec2 uv, vec2 center, vec2 radius) {
    vec2 q = (uv - center) / radius;
    return 1.0 - smoothstep(0.05, 1.0, dot(q, q));
}

void fragment() {
    vec2 uv = UV;
    float step_wave = sin(phase) * amount;
    if (guard_pose < 0.5) {
        // Original assassins are left-facing: hand groups around the head,
        // with boots at the right. Opposing movement keeps the torso stable.
        float hand_top = region(uv, vec2(0.30, 0.25), vec2(0.26, 0.30));
        float hand_bottom = region(uv, vec2(0.34, 0.78), vec2(0.27, 0.27));
        float boot_top = region(uv, vec2(0.86, 0.32), vec2(0.18, 0.25));
        float boot_bottom = region(uv, vec2(0.86, 0.70), vec2(0.18, 0.25));
        uv.x += step_wave * (0.034 * (hand_top - hand_bottom) + 0.025 * (boot_bottom - boot_top));
        uv.y += step_wave * 0.016 * (hand_bottom - hand_top);
    } else {
        // Guard stills face upward; animate each hand/boot in counterphase.
        float hand_left = region(uv, vec2(0.25, 0.40), vec2(0.28, 0.33));
        float hand_right = region(uv, vec2(0.76, 0.40), vec2(0.28, 0.33));
        float boot_left = region(uv, vec2(0.32, 0.79), vec2(0.25, 0.24));
        float boot_right = region(uv, vec2(0.68, 0.79), vec2(0.25, 0.24));
        uv.y += step_wave * (0.045 * (hand_left - hand_right) + 0.032 * (boot_right - boot_left));
        uv.x += step_wave * 0.010 * (hand_left + hand_right);
    }
    COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * vertex_tint;
}
