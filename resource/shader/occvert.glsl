uniform vec2 inv_screen;

vec4 position( mat4 projection, vec4 vpos)
{
    vec4 pos = projection * vpos;
    if (pos.x < 0) {
        pos.x += inv_screen.x;
    }
    else if(pos.x > 0) {
        pos.x -= inv_screen.x;
    }
    if (pos.y < 0) {
        pos.y += inv_screen.y;
    }
    else if(pos.y > 0) {
        pos.y -= inv_screen.y;
    }
    return pos;
}
