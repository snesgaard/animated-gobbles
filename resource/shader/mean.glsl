uniform float texeloffset;

uniform int rad;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texturecolor = vec4(0);
    for (int i = -rad; i <= rad; i++) {
        vec2 uv = texture_coords + vec2(i, 0.5) * texeloffset;
        texturecolor += Texel(texture, uv);
    }
    texturecolor /= (rad * 2 + 1);
    float d = Texel(texture, texture_coords).r;
    return vec4(d, texturecolor.xy, 1.0);
}
