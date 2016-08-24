#define M_PI 3.1415926535897932384626433832795
#define M_PI_2 M_PI*0.5

uniform Image normalmap;
uniform Image shadowmap;
uniform vec2 inv_screen;
uniform float amplitude;

vec2 cart2polar(vec2 c) {
    float r = sqrt(c.x * c.x + c.y * c.y);
    float t = atan(c.y / c.x);
    if (c.x < 0 && c.y >= 0) {
        t = t + M_PI;
    }
    else if (c.x < 0 && c.y < 0) {
        t = t + M_PI;
    }
    else if (c.x >= 0 && c.y < 0) {
        t = t + 2 * M_PI;
    }
    return vec2(t, r);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    float amp = amplitude;
    vec4 cm = Texel(texture, screen_coords * inv_screen);
    vec4 nm = Texel(normalmap, (screen_coords) * inv_screen);
    vec2 polar = cart2polar((texture_coords - vec2(0.5)) * 2);
    // If color alpha is too faint there is nothign there and we discard
    if (cm.a < 0.1) discard;
    #ifdef SHADOWMAP
    vec2 blur = vec2(inv_screen.y  * smoothstep(0., 1., polar.y), 0);
    //now we use a simple gaussian blur
    float sum = 0.0;
    vec2 centeruv = vec2(polar.x / M_PI * 0.5, 0.5);
    float bias = -0.006;
    //float bias = -0.002;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv - 4.0 * blur).r) * 0.05;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv - 3.0 * blur).r) * 0.09;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv - 2.0 * blur).r) * 0.12;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv - 1.0 * blur).r) * 0.15;

    sum += step(polar.y + bias, Texel(shadowmap, centeruv).r) * 0.16;

    sum += step(polar.y + bias, Texel(shadowmap, centeruv + 1.0 * blur).r) * 0.15;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv + 2.0 * blur).r) * 0.12;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv + 3.0 * blur).r) * 0.09;
    sum += step(polar.y + bias, Texel(shadowmap, centeruv + 4.0 * blur).r) * 0.05;

    amp *= sum;
    #endif
    // If blue is not 255, we assume that the normal is valid
    // Proceed with diffuse shading
    if (nm.b != 1.0) {
        vec2 normal = 2 * vec2(nm.x - 0.5, nm.y - 0.5);
        vec2 l = -normalize(
            vec2(texture_coords.x - 0.5, 0.5 - texture_coords.y)
        );
        //float dot_prod = max(0, dot(normal, l));
        float dot_prod = 0.0;
        if (dot(normal, l) > 0.4) dot_prod = 1;
        else if (dot(normal, l) > 0.25) dot_prod = 0.75;
        else if(dot(normal, l) > 0) dot_prod = 0.25;
        amp *= 0.3 + 0.7 * dot_prod;
    }
    // Calculate attenuation based on the distance to the light source
    float att = clamp(1.0 - polar.y, 0.0, 1.0);
    amp *= att * att;

    return color * vec4(cm.rgb, amp);
}
