//#define L 600
//#define STEP 1.0/L
uniform float STEP;
uniform int L;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    //vec2 s = vec2(texture_coords.x, 0);
    for (int y = 0; y < L; y++) {
        vec2 s = vec2(texture_coords.x, (y + 0.5) * STEP);
        vec4 t = Texel(texture, s);
        if (t.r > 0) {
            return vec4(s.y, s.y * s.y, 0.0, 1.0);
        }
    }
    /*
    bool tag = false;
    for (int y = 0; y < L; y++) {
        vec2 s = vec2(texture_coords.x, (y + 0.5) * STEP);
        vec4 t = Texel(texture, s);
        if (t.r > 0 && !tag) {
            tag = true;
        } else if(t.r == 0 && tag) {
            return vec4(s.y, s.y * s.y, 0.0, 1.0);
        }
    }
    */
    return vec4(1);
}
