uniform vec2 texeloffset;

uniform int rad;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = vec4(0);
    for (int i = -rad; i <= rad; i++) {
        for (int j = -rad; j <= rad; j++) {
            vec2 uv = texture_coords + vec2(i, j) * texeloffset;
            texturecolor += Texel(texture, uv);
        }
    }
    texturecolor /= (rad * 2 + 1) * (rad * 2 + 1);
    return texturecolor * color;
}
