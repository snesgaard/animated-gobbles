local sprite = require "sprite"

local atlas
local anime
local frame_data

function loader.testbox()
  atlas, anime = prop.get_resource()
end

function init.testbox(gd, id, x, y)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = y
  gd.spatial.width[id] = 16
  gd.spatial.height[id] = 16
  gd.spatial.vx[id] = 0
  gd.spatial.vy[id] = 0
  gd.spatial.face[id] = 1

  gd.combat.health[id] = 5
  gd.functional.portrait[id] = function() return "box" end
  --animation.play{id, atlas, anime.box, 0.75}
  gamedata.visual.idle[id] = function(dt, ...)
    return sprite.cycle(dt, atlas, anime.box, ...)
  end
end
