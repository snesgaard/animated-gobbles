
local portait = {
  atlas,
  anime = {},
}

shared_actor = {}

function loader.shared()
  local data_dir = "resource/sprite/portrait"
  local sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  portait.atlas = initresource(resource.atlas, function(at, id)
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
  end)

  local index = require (data_dir .. "/info")
  frame_data = require (data_dir .. "/hitbox")

  table.foreach(frame_data, function(key, val)
    portait.anime[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frame_data[key],
      true
    )
  end)

  --TODO make atlast drawer for background
end

function shared_actor.get_portait()
  return portait.atlas, portait.anime
end
