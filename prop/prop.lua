local sprite = require "sprite"

local fg_atlas
local bg_atlas
local anime = {}
local frame_data = {}

prop = {}

function loader.prop()
  fg_atlas, anime = sprite.load("resource/sprite/prop")
end

function prop.get_resource(is_background)
  local a = is_background and bg_atlas or fg_atlas
  return a, anime, frame_data
end
