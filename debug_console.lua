require "modules/LOVEDEBUG/lovedebug"
local fun = require "modules/functional"

local gd = gamedata
local gfx = love.graphics

debug = {
  buffer_view = false,
  draw_hitbox = false,
  draw_entity = false,
}

function debug.view_scene()
  debug.buffer_view = false
end

function debug.view_buffer()
  debug.buffer_view = true
end

function debug.toggle_hitbox_render()
  debug.draw_hitbox = not debug.draw_hitbox
end
