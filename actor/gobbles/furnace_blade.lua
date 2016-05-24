-- Resources
local _hitbox = {}
local _anime -- Shared with base
local _atlas -- Shared with base
local _blast_atlas
local _blast_anime = {}
local _api

-- Defines
local time = {
  -- A
  sA_windup = 0.46,
  sA_attack = 0.3,
  sA_blast = 0.5,
  sA_recover = 0.4,
  --B
  sB_windup = 0.1,
  sB_attack = 0.3,
  sB_blast = 0.5,
  sB_recover = 0.4,
}
local gd = gamedata

local blast_a = {}

-- Logic
local action = {}
local control = {}



function slash_a(id, key)
  animation.play(
    id, _atlas, _anime.furnace_blade_A, time.sA_windup, "once", 1, 6
  )
  signal.wait("animation_done@" .. id)
  api.return2base(id)
end

local states = {
  slash_a = {slash_a}
}

-- Interface
local furnace_blade = {}
function furnace_blade.load(atlas, anime, initanime, api)
  _atlas = atlas
  _anime = anime
  _api = api
  initanime("furnace_blade_A", 15, 33, 54)
  initanime("furnace_blade_B", 7, 20, 54)
  initanime("furnace_blade_blast", 3, 13, 22)

  _blast_atlas, bindex = sfx.get_atlas_a()
  local bsheet = resource.atlas.color[_blast_atlas]:getTexture()
  local function initblastanime(key, frames, ox, oy)
    _blast_anime[key] = initresource(
      resource.animation, animation.init, bsheet, bindex[key], frames, ox, oy,
      true
    )
  end
  initblastanime("furnace_blast_A", 9, 39, 55)
  return states.slash_a
end

return furnace_blade
