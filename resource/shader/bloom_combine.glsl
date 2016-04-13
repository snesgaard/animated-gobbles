uniform sampler2D blur_tex;
uniform sampler2D bloom_tex;
uniform float exposure;

vec4 effect(vec4 color, sampler2D scene, vec2 tex_coords, vec2 pos) {
    const float gamma = 2.2;
    vec3 sceneColor = texture2D(scene, tex_coords).rgb;
    vec3 bloomColor = texture2D(bloom_tex, tex_coords).rgb;
    vec3 blurColor = texture2D(blur_tex, tex_coords).rgb;
    sceneColor += bloomColor * 0.5; // additive blending
    sceneColor += blurColor; // additive blending
    // tone mapping
    vec3 result = vec3(1.0) - exp(-sceneColor * exposure);
    // also gamma correct while we're at it
    // result = pow(result, vec3(1.0 / gamma));
    return vec4(result, 1.0f);
}
