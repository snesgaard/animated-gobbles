vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(texture, texture_coords);
    vec4 _out_color = texcolor * color;
    if (_out_color.a < 0.1) discard;
    return _out_color;
}
