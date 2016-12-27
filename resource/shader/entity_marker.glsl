vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float a = 1 - clamp(texture_coords.y, 0.0, 1.0);
    a *= a;
    return vec4(color.rgb, a * color.a);
}
