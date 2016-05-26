-- Resources
local _hitbox = {}
local _anime -- Shared with base
local _atlas -- Shared with base
local _blast_atlas
local _blast_anime = {}
local _gobbles

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
local next = {}

local states = {}

local function _monitor_blast(id, windup_time, key)
  local dt = 0
  next[id] = nil
  while input.isdown(key) do dt = dt + signal.wait("update") end
  if dt >= windup_time then
    next[id] = states.blast_a
    return
  end
  while not input.ispressed(key) do signal.wait("update") end
  -- Set attack action
end

function states.slash_a(id, key)
  gd.spatial.vx[id] = 0
  concurrent.join()
  concurrent.fork(_monitor_blast, id, time.sA_windup, key)
  map_geometry.diplace(id, 3 * gd.spatial.face[id], 0)
  animation.play(
    id, _atlas, _anime.furnace_blade_A, time.sA_windup, "once", 1, 6
  )
  ai.sleep(time.sA_windup)
  map_geometry.diplace(id, 8 * gd.spatial.face[id], 0)
  animation.play(
    id, _atlas, _anime.furnace_blade_A, time.sA_attack, "once", 7, 11
  )
  ai.sleep(time.sA_attack)
  animation.play(
    id, _atlas, _anime.furnace_blade_A, time.sA_recover, "once", 12, 15
  )
  if next[id] then
    return next[id](id, key)
  end
  _gobbles.fork_interrupt(id)
  ai.sleep(time.sA_recover)
  map_geometry.diplace(id, -3 * gd.spatial.face[id], 0)
  _gobbles.goto_idle(id)
end

function states.blast_a(id)
  gd.spatial.vy[id] = 100
  gd.spatial.vx[id] = -gd.spatial.face[id] * 100
  gd.spatial.ground[id] = nil
  animation.play(id, _atlas, _anime.furnace_blade_blast, 0.2, "bounce")
  while not ai.on_ground(id) do signal.wait("update") end
  _gobbles.goto_idle(id)
end

-- Interface
local furnace_blade = {}
function furnace_blade.load(atlas, anime, initanime, gobbles)
  _atlas = atlas
  _anime = anime
  _gobbles = gobbles
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
