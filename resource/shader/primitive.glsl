uniform bool background;
uniform bool bloom;

void effects(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Write color
    vec4 tex = color;
    if (tex.a < 0.1){
        discard;
    }
    if (tex.a < 0.95 || bloom) {
        love_Canvases[2] = vec4(tex.rgb, 1);
    } else {
        love_Canvases[2] = vec4(vec3(0), 1);
    }
    if (tex.a >= 0.75) {
        love_Canvases[0] = vec4(tex.rgb, 1);
        // Write normals
        //love_Canvases[1] = vec4(1);
        if (!background) {
            love_Canvases[1] = vec4(0, 0, 0, 1);
        }
    }
}
