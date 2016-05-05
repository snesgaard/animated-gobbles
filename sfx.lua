local _atlas_a
local _index_a

sfx = {}

function loader.sfx()
  local bsheet = gfx.newImage("resource/sfx/A.png")
  _atlas_a = initresource(resource.atlas, function(at, id)
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      bsheet, 200, "stream"
    )
  end)
  _index_a = require "resource/sfx/A"

  --drawer.sfx = drawing.from_atlas(_atlas_a)
  local drawer = draw_engine.create_atlas(_atlas_a)
  draw_engine.register_type("sfx", drawer)
end

function sfx.get_atlas_a()
  return _atlas_a, _index_a
end
