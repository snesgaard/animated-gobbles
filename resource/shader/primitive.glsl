uniform bool _is_opague;
uniform bool _is_glow;
uniform bool _is_sfx;

void effects(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Here we assign the stencil
    #ifdef STENCIL
    #endif
    // THis is for drawing occluders for light rendering
    #ifdef OCCLUSION
    if (!_is_opague) discard;
    love_Canvases[0] = vec4(1.0);
    #endif

    // This is the default case, where we assign color,
    // It is assummed that the canvas are bound in following order
    // love_Canvases = {
    //      scene,
    //      color,
    //      glow,
    //      normal,
    // }
    #ifdef COLOR
    if (_is_sfx) {
        love_Canvases[0] = color;
    }
    if (_is_glow) {
        love_Canvases[2] = vec4(color.rgb, 1.0);
    }
    if (_is_opague) {
        love_Canvases[1] = color;
        love_Canvases[3] = vec4(vec2(0), vec2(1));
    }
    #endif
}
