vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 tex = Texel(texture, texture_coords);
    if (tex.a > 0.1) {
        return vec4(1);
    }
    return tex;
}
