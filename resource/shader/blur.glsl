const float kernel[5] = float[](
    0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162
);

#ifdef HORIZONTAL
uniform float inv_x;
#endif
#ifdef VERTICAL
uniform float inv_y;
#endif

vec4 effect(vec4 color, sampler2D tex, vec2 tex_coords, vec2 pos) {
    color = texture2D(tex, tex_coords) * kernel[0];
    for(int i = 1; i < 5; i++) {
        #ifdef HORIZONTAL
        vec4 f = texture2D(tex, vec2(tex_coords.x + i * inv_x, tex_coords.y));
        vec4 b = texture2D(tex, vec2(tex_coords.x - i * inv_x, tex_coords.y));
        #endif
        #ifdef VERTICAL
        vec4 f = texture2D(tex, vec2(tex_coords.x, tex_coords.y + i * inv_y));
        vec4 b = texture2D(tex, vec2(tex_coords.x, tex_coords.y - i * inv_y));
        #endif
        color += f * kernel[i];
        color += b * kernel[i];
    }
    return vec4(color.rgb, 1.0);
}
