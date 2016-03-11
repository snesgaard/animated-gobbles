#define M_PI 3.1415926535897932384626433832795
#define M_PI_2 M_PI*0.5

uniform Image colormap;
uniform Image normalmap;
uniform vec2 inv_screen;

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
    vec2 polar = cart2polar((texture_coords - vec2(0.5)) * 2);

    vec2 blur = vec2((1./800.0)  * smoothstep(0., 1., polar.y), 0);

    //now we use a simple gaussian blur
    float sum = 0.0;
    vec2 centeruv = vec2(polar.x / M_PI * 0.5, 0.5);
    float bias = 0.0015 + 4 * blur.x;
    sum += step(polar.y + bias, Texel(texture, centeruv - 4.0 * blur).r) * 0.05;
    sum += step(polar.y + bias, Texel(texture, centeruv - 3.0 * blur).r) * 0.09;
    sum += step(polar.y + bias, Texel(texture, centeruv - 2.0 * blur).r) * 0.12;
    sum += step(polar.y + bias, Texel(texture, centeruv - 1.0 * blur).r) * 0.15;

    sum += step(polar.y + bias, Texel(texture, centeruv).r) * 0.16;

    sum += step(polar.y + bias, Texel(texture, centeruv + 1.0 * blur).r) * 0.15;
    sum += step(polar.y + bias, Texel(texture, centeruv + 2.0 * blur).r) * 0.12;
    sum += step(polar.y + bias, Texel(texture, centeruv + 3.0 * blur).r) * 0.09;
    sum += step(polar.y + bias, Texel(texture, centeruv + 4.0 * blur).r) * 0.05;

    //sum of 1.0 -> in light, 0.0 -> in shadow

    //multiply the summed amount by our distance, which gives us a radial falloff
    //then multiply by vertex (light) color
    float att = clamp(1.0 - polar.y, 0.0, 1.0);
    att *= att;

    vec3 cm = Texel(colormap, screen_coords * inv_screen).rgb;
    vec4 nm = Texel(normalmap, screen_coords * inv_screen);
    vec2 normal = normalize(vec2(nm.x - 0.5, nm.y - 0.5));
    float diffuse;
    if (nm.a == 0) {
        diffuse = 1;
    } else {
        vec2 l = -normalize(
                    vec2(texture_coords.x - 0.5, 0.5 - texture_coords.y)
                    );
        diffuse = dot(normal, l);
        sum = 1;
    }

    return color * vec4(cm, diffuse * att * sum * 0.8);
}
