local anime = {}
local atlas
local frame_data
local sheet
local card_frame

local card_suit = suit.new()

cards = {}

function loader.cards()
  -- Initialize animations
  local data_dir = "resource/sprite/card"
  sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  atlas = initresource(resource.atlas, function(at, id)
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 20, "stream"
    )
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
  local ox, oy = cards.anime_offset()
  for _, id in pairs(anime) do
    local x = resource.animation.x[id]
    for i, _ in pairs(x) do x[i] = ox end
    local y = resource.animation.y[id]
    for i, _ in pairs(y) do y[i] = oy end
  end

  draw_engine.ui.screen.card = cards.draw
end

function cards.anime_offset()
  return -25 * 8 * 0.5 * 0.2 / 5, -35 * (1 - 0.2) * 0.25 * 0.75
end
function cards.get_gfx()
  return atlas, anime
end

function cards.init(init_tab, ...)
  init_tab = init_tab or {}
  local _spec_args = {...}
  local _ui_init = function(gd, id)
    gd.spatial.x[id] = 0
    gd.spatial.y[id] = 0
    gd.spatial.width[id] = 25
    gd.spatial.height[id] = 35
    gd.spatial.face[id] = 5
    gd.spatial.flip[id] = 5
    if init_tab.ui_init then init_tab.ui_init(gd, id, unpack(_spec_args)) end
  end
  return initresource(gamedata, _ui_init)
end

function cards.render(id)
  local x = gamedata.spatial.x[id]
  local y = gamedata.spatial.y[id]
  local w = gamedata.spatial.width[id]
  local h = gamedata.spatial.height[id]
  return card_suit:Button("" .. id, x, y, w, h)
end

function cards.draw()
  card_suit:draw()
end
