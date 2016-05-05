bool is_none(float alpha) {
    return alpha < 0.1;
}
bool is_sfx(float alpha) {
    return 0.1 <= alpha && alpha < 0.5;
}
bool is_opague(float alpha) {
    return 0.6 <= alpha;
}
bool is_glow(float alpha) {
    return 0.2 <= alpha && alpha <= 0.7;
}

uniform bool _do_opague;
uniform bool _do_sfx;
uniform sampler2D normals;

void effects(
    vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords
) {
    vec4 tex = Texel(texture, texture_coords);
    if (is_none(tex.a)) discard;

    // This for when we want to build our stencil buffer from sprite alphas
    #ifdef STENCIL
    bool opague = _do_opague && is_opague(tex.a);
    bool sfx = _do_sfx && is_sfx(tex.a);
    if (!opague && !sfx) discard;
    #endif

    // This for when we want to render our sprite as a light occluder
    #ifdef OCCLUSION
    if (!is_opague(tex.a)) discard;
    love_Canvases[0] = vec4(1);
    #endif

    // This is the default case, where we assign color,
    // It is assummed that the canvas are bound in following order
    // love_Canvases = {
    //      scene,
    //      color,
    //      glow,
    //      normal,,
    // }
    #ifdef COLOR
    bool opague = is_opague(tex.a) && _do_opague;
    bool sfx = is_sfx(tex.a) && _do_sfx;
    bool glow = is_glow(tex.a);
    if (sfx) {
        love_Canvases[0] = vec4(color.rgb * tex.rgb, 1.0);
    }
    if (glow) {
        love_Canvases[2] = vec4(color.rgb * tex.rgb, 1.0);
    }
    if (opague) {
        vec4 n = Texel(normals, texture_coords);
        n = color.a > 0.5 ? vec4(1 - n.r, n.gba) : n;
        love_Canvases[1] = vec4(color.rgb * tex.rgb, 1.0);
        love_Canvases[3] = n;
    }
    //love_Canvases[0] = vec4(float(glow), float(opague), float(sfx), 1.0);
    #endif
}
