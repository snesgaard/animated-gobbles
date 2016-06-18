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
    next[id] = "blast"
    return
  end
  input.latch(key)
  while not input.ispressed(key) do signal.wait("update") end
  -- Set attack action
  next[id] = "next"
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
  collision_engine.sequence(id, _hitbox.slash_a, time.sA_attack)
  ai.sleep(time.sA_attack)
  animation.play(
    id, _atlas, _anime.furnace_blade_A, time.sA_recover, "once", 12, 15
  )
  if next[id] == "blast" then
    return states.blast_a(id)
  elseif next[id] == "next" then
    return states.slash_b(id, key)
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

function states.slash_b(id, key)
  gd.spatial.vx[id] = 0
  concurrent.join()
  concurrent.fork(_monitor_blast, id, time.sB_windup, key)
  map_geometry.diplace(id, 3 * gd.spatial.face[id], 0)
  animation.play(
    id, _atlas, _anime.furnace_blade_B, time.sB_windup, "once", 1, 2
  )
  ai.sleep(time.sB_windup)
  map_geometry.diplace(id, 6 * gd.spatial.face[id], 0)
  animation.play(
    id, _atlas, _anime.furnace_blade_B, time.sB_attack, "once", 3, 5
  )
  collision_engine.sequence(id, _hitbox.slash_b, time.sB_attack)
  ai.sleep(time.sB_attack)
  if next[id] == "blast" then
    return states.blast_a(id)
  end
  animation.play(
    id, _atlas, _anime.furnace_blade_B, time.sB_recover, "once", 5, 7
  )
  _gobbles.fork_interrupt(id)
  ai.sleep(time.sB_recover)
  map_geometry.diplace(id, -4 * gd.spatial.face[id], 0)
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

  local function make_init_hurt_box(ox, oy)
    return function(xl, yl, xh, yh)
      local w = xh - xl
      local h = yh - yl
      return initresource(
        resource.hitbox, coolision.createaxisbox, xl - ox + 1, oy - yh, w,
        h, nil, "enemy"
      )
    end
  end
  local slash_a_hurt_box = make_init_hurt_box(33, 54)
  local slash_b_hurt_box = make_init_hurt_box(20, 54)
  _hitbox = {
    slash_a = {
      slash_a_hurt_box(25, 28, 54, 46),
      slash_a_hurt_box(34, 31, 57, 62),
      slash_a_hurt_box(37, 46, 53, 62),
      collision_engine.empty_box(),
      collision_engine.empty_box(),
    },
    slash_b = {
      slash_b_hurt_box(17, 51, 46, 61),
      slash_b_hurt_box(17, 51, 46, 61),
      collision_engine.empty_box(),
    }
  }

  return states.slash_a
end

return furnace_blade
