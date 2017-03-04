local atlas
local anime = {}
local frame_data = {}

local hitbox_seek = {
  [0xff0000] = "enemy",
}
local hitbox_hail = {
  [0xff00] = "ally",
}

function loader.witch()
  -- Initialize animations
  local data_dir = "resource/sprite/witch"
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

  table.foreach(frame_data, function(key, val)
    anime[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frame_data[key],
      true
    )
  end)
  table.foreach(frame_data, function(key, val)
    frame_data[key].hitbox = collision_engine.batch_alloc_sequence(
      frame_data[key].hitbox, hitbox_hail, hitbox_seek
    )
  end)

  local _drawer = draw_engine.create_atlas(atlas)
  draw_engine.foreground.witch = _drawer
  --draw_engine.foreground_draw:subscribe(_drawer.color)
  --draw_engine.foreground_stencil:subscribe(_drawer.stencil)
  --draw_engine.foreground_occlusion:subscribe(_drawer.occlusion)
end

function init.witch(gd, id, x, y)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = y
  gd.spatial.width[id] = 20
  gd.spatial.height[id] = 20
  gd.spatial.vx[id] = 0
  gd.spatial.vy[id] = 0
  gd.spatial.face[id] = 1

  gd.combat.health[id] = 10
  gd.functional.portrait[id] = function() return "witch" end
  --animation.play{id, atlas, anime.combat_idle, 0.75}
end
