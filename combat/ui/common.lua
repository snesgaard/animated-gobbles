local common = {
  screen_suit = suit.new(),
  quad_mesh = love.graphics.newMesh(
    {
      {1, 0, 1, 0},
      {0, 0, 0, 0},
      {0, 1, 0, 1},
      {1, 1, 1, 1},
    },
    "fan"
  ),
  shader = {
    marker = loadshader("resource/shader/entity_marker.glsl")
  },
  font = {
    s20 = love.graphics.newFont(20),
    s35 = love.graphics.newFont(35)
  },
}

function common.render_marker(id, theme)
  local x, y = gamedata.spatial.x[id], gamedata.spatial.y[id]
  local ux = camera.transform(camera_id, level, x, y)
  local color = theme.normal.bg
  local r, g, b = unpack(color)
  local uw, uh = 200, 30
  local uy = 690
  common.screen_suit:Button(
    id, {draw = function(_, opt, x, y, w, h)
      gfx.setShader(common.shader.marker)
      gfx.setColor(r, g, b, 255)
      gfx.draw(common.quad_mesh, x, y, 0, w, h)
      gfx.setShader()
    end}, ux - 0.5 * uw, uy, uw, uh
  )
end

return common
