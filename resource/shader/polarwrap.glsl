#define M_PI 3.1415926535897932384626433832795

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    float t = texture_coords.x * M_PI * 2;
    float r = texture_coords.y;
    vec2 s = vec2(r * cos(t), r * sin(t));
    s = (s + vec2(1)) * 0.5;
    return Texel(texture, s);
}
