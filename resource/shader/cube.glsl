uniform sampler2D normals;
uniform bool background;
uniform bool bloom;
varying float orientation;

void effects(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Write color
    vec4 tex = Texel(texture, texture_coords);
    if (tex.a < 0.1){
        discard;
    }
    if (tex.a < 0.95 || bloom) {
        love_Canvases[2] = vec4(color.rgb * tex.rgb, 1);
        //love_Canvases[0] = vec4(color.rgb, 1) * tex;
    } else {
        love_Canvases[2] = vec4(0);
    }
    if (tex.a >= 0.95) {
        love_Canvases[0] = vec4(color.rgb, 1) * tex;
        // Write normals
        //love_Canvases[1] = vec4(1);
        if (!background) {
            vec4 n = Texel(normals, texture_coords);
            if (color.a > 0.5) {
                n.r = 1 - n.r;
            }
            love_Canvases[1] = n;
        }
    }
}
