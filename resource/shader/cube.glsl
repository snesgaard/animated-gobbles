uniform sampler2D normals;
varying float orientation;

void effects(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Write color
    vec4 tex = Texel(texture, texture_coords);
    if (tex.a < 0.1) {
        discard;
    }
    love_Canvases[0] = vec4(color.rgb, 1) * tex;
    // Write normals
    //love_Canvases[1] = vec4(1);
    vec4 n = Texel(normals, texture_coords);
    if (color.a > 0.5) {
        n.r = 1 - n.r;
    }
    love_Canvases[1] = n;
}
