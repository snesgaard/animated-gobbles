void effects(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Write color
    love_Canvases[0] = Texel(texture, texture_coords);
    // Write normals
    love_Canvases[1] = vec4(
        vec2(texture_coords.x, 1.0 - texture_coords.y), 0, 1.0

    );
}
