local sprite = require "sprite"

local atlas
local anime = {}
local frame_data = {}

local hitbox_seek = {
  [0xff0000] = "enemy",
}
local hitbox_hail = {
  [0xff00] = "ally",
}

local sheet

function loader.engineer()
  -- Initialize animations
  local data_dir = "resource/sprite/gungoblin"
  local sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage(data_dir .. "/normal.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)

  local index = require (data_dir .. "/info")
  frame_data = require (data_dir .. "/hitbox")



  draw_engine.foreground.engineer = draw_engine.create_atlas(atlas)

  atlas, anime = sprite.load("resource/sprite/gungoblin")


end

function init.engineer(gd, id, x, y)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = y
  gd.spatial.width[id] = 20
  gd.spatial.height[id] = 20
  gd.spatial.vx[id] = 0
  gd.spatial.vy[id] = 0
  gd.spatial.face[id] = 1

  gd.combat.health[id] = 20

  gd.combat.damage[id] = 5
  gd.functional.portrait[id] = function() return "engineer" end
  --lambda.run(sprite.cycle, atlas, anime.idle, sprite.entity_center(id))
  --animation.play{id, atlas, anime.idle, 1.0}
  gamedata.visual.idle[id] = function(dt, ...)
    return sprite.cycle(dt, atlas, anime.idle, ...)
  end
  gamedata.visual.throw[id] = function(dt, ...)
    return sprite.once(dt, atlas, anime.throw, ...)
  end
end
