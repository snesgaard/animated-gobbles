-- Resources
local _hitbox = {}
local _anime -- Shared with base
local _atlas -- Shared with base
local _blast_atlas
local _blast_anime = {}

-- Defines
local time = {
  sA_windup = 0.46,
  sA_attack = 0.3,
  sA_blast = 0.5,
  sA_recover = 0.4,
}
local gd = gamedata

local blast_a = {}

-- Logic
local action = {}
local control = {}
local draw = {}

function control.slash_A(id, key)
  map_geometry.diplace(id, 3 * gd.spatial.face[id], 0)
  gd.ai.action[id] = ai.constant_hspeed(0)
  gd.radiometry.draw[id] = draw.slash_A()
  local pressed = true
  ai.do_for(time.sA_windup, function()
    pressed = input.isdown(key) and pressed
  end)
  --gd.ai.action[id] = ai.constant_hspeed(10 / time.sA_attack)
  map_geometry.diplace(id, 8 * gd.spatial.face[id], 0)
  local do_blast = false
  ai.do_for(time.sA_attack, function()
    do_blast = (pressed and not input.isdown(key)) or do_blast
  end)
  if do_blast then
    return control.blast_a(id)
  end
--  gd.ai.action[id] = ai.constant_hspeed(-11 / time.sA_recover)
  ai.do_nothing_for(time.sA_recover)
  map_geometry.diplace(id, -3 * gd.spatial.face[id], 0)
  --ai.do_nothing_for(10000)
end

function control.blast_a(id)
  gd.radiometry.draw[id] = animation.entitydrawer(
    id, _atlas, _anime.furnace_blade_blast, 0.2, "bounce"
  )
  blast_a.spawn(id)
  local f = gd.spatial.face[id]
  gd.spatial.ground[id] = nil
  gd.spatial.vy[id] = 50
  gd.ai.action[id] = ai.constant_hspeed(-100)
  while not ai.on_ground(id) do
    coroutine.yield()
  end
end

function blast_a.spawn(id)
  local f = gd.spatial.face[id]
  local x = gd.spatial.x[id]
  local y = gd.spatial.y[id]
  return initresource(gamedata, blast_a.init, x + f * 30, y, f)
end
function blast_a.run(id)
  local co = animation.entitydrawer(
    id, _blast_atlas, _blast_anime.furnace_blast_A, time.sA_blast, "once"
  )
  ai.do_for(time.sA_blast, function()
    coroutine.resume(co, id)
  end)
  -- Release resource
  freegamedata(id)
end
function blast_a.init(gd, id, x, y, f)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = y
  gd.spatial.face[id] = f

  gd.radiometry.draw[id] = coroutine.create(blast_a.run)

  gamedata.tag.sfx[id] = true
end


function draw.slash_A()
  --local t = time.sA_windup + time.sA_attack
  --local co = animation.entitydrawer(id, _atlas, _anime.furnace_blade_A, t, "once")
  local windup_co = animation.entitydrawer(
    id, _atlas, _anime.furnace_blade_A, time.sA_windup, "once", 1, 6
  )
  local attack_co = animation.entitydrawer(
    id, _atlas, _anime.furnace_blade_A, time.sA_attack, "once", 7, 11
  )
  local recov_co = animation.entitydrawer(
    id, _atlas, _anime.furnace_blade_A, time.sA_recover, "once", 12, 15
  )
  local drawer = function(id)
    ai.do_for(time.sA_windup, function()
      coroutine.resume(windup_co, id)
    end)
    ai.do_for(time.sA_attack, function()
      coroutine.resume(attack_co, id)
    end)
    while true do
      coroutine.resume(recov_co, id)
      coroutine.yield()
    end
  end
  return coroutine.create(drawer)
end

-- Interface
local furnace_blade = {}
function furnace_blade.load(atlas, anime, initanime)
  _atlas = atlas
  _anime = anime
  initanime("furnace_blade_A", 15, 33, 54)
  initanime("furnace_blade_A_blast", 12, 10, 54)
  initanime("furnace_blade_blast", 3, 13, 22)

  _blast_atlas, bindex = sfx.get_atlas_a()
  print(_blast_atlas)
  local bsheet = resource.atlas.color[_blast_atlas]:getTexture()
  local function initblastanime(key, frames, ox, oy)
    _blast_anime[key] = initresource(
      resource.animation, animation.init, bsheet, bindex[key], frames, ox, oy,
      true
    )
  end
  initblastanime("furnace_blast_A", 9, 39, 55)
end

function furnace_blade.idle_init(id, key)
  return control.slash_A(id, key)
end

return furnace_blade
