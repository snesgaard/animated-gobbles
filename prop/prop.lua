local fg_atlas
local bg_atlas
local anime = {}
local frame_data = {}

prop = {}

function loader.prop()
  local data_dir = "resource/sprite/prop"
  local sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  local nmap = love.graphics.newImage(data_dir .. "/normal.png")
  fg_atlas = initresource(resource.atlas, function(at, id)
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)
  bg_atlas = initresource(resource.atlas, function(at, id)
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

  --TODO make atlast drawer for background
  local _drawer = draw_engine.create_atlas(fg_atlas)
  draw_engine.foreground.prop = _drawer
  --draw_engine.foreground_draw:subscribe(_drawer.color)
  --draw_engine.foreground_stencil:subscribe(_drawer.stencil)
  --draw_engine.foreground_occlusion:subscribe(_drawer.occlusion)
end

function prop.get_resource(is_background)
  local a = is_background and bg_atlas or fg_atlas
  return a, anime, frame_data
end
