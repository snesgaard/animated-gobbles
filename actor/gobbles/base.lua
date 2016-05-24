local weapon_path = "actor/gobbles/"
local furnace_blade = require(weapon_path .. "furnace_blade")

require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 90
local jumpspeed = 250
local runjumpspeed = 150

local atlas
local anime = {}
local hitbox = {}


local key = {
  left = "left",
  right = "right",
  down = "down",
  runtoggle = "lalt",
  jump = "space",
  attackA= "a"
}

local gd = gamedata

local action = {}
local control = {}
local states = {}
local api = {}
-- Parse inputs and returns the newest direction pressed
-- Right = 1
-- Left = -1
-- Nothing = 0
local function input_direction()
  local l = input.isdown(key.left)
  local r = input.isdown(key.right)
  local pl = system.pressed[key.left] or 0
  local pr = system.pressed[key.right] or 0
  local lgr = pl > pr

  if l and (not r or lgr) then
    return -1
  elseif r and (not l or not lgr) then
    return 1
  end
  return 0
end

local function movement(id)
  signal.wait("update")
  local d = input_direction()
  if d ~= 0 then
    gd.spatial.face[id] = d
    gd.spatial.vx[id] = walkspeed * d
  else
    gd.spatial.vx[id] = 0
  end
  return movement(id)
end

local function run(id)
  signal.wait("update")
  local d = input_direction()
  if d ~= 0 then
    gd.spatial.face[id] = d
    gd.spatial.vx[id] = runspeed * d
  else
    signal.send("state@" .. id, states.ground_move)
    return
  end
  return run(id)
end
local function run_begin(id)
  animation.play(id, atlas, anime.run, 0.75)
  return run(id)
end


local function run_toggle(id)
  signal.wait("update")
  if input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    if math.abs(gd.spatial.vx[id]) == runspeed then
      signal.send("state@" .. id, states.ground_move)
    else
      signal.send("state@" .. id, states.ground_run)
    end
    return
  end
  return run_toggle(id)
end

local function ground_animation(id)
  animation.play(id, atlas, anime.idle, 0.75)
  while gd.spatial.vx[id] == 0 do signal.wait("update") end
  animation.play(id, atlas, anime.walk, 1.0)
  while gd.spatial.vx[id] ~= 0 do signal.wait("update") end
  return ground_animation(id)
end

local function arial_animation(id)
  animation.play(id, atlas, anime.ascend, 0.3)
  while gd.spatial.vy[id] > 0 do signal.wait("update") end
  animation.play(id, atlas, anime.descend, 0.3)
  while gd.spatial.vy[id] <= 0 do signal.wait("update") end
  return arial_animation(id)
end

function api.ground2arial(id)
  signal.wait("update")
  if not ai.on_ground(id) then
    if math.abs(gd.spatial.vx[id]) == runspeed then
      signal.send("state@" .. id, states.arial_run)
    else
      signal.send("state@" .. id, states.arial_move)
    end
    return
  end
  return api.ground2arial(id)
end

function api.arial2ground(id)
  signal.wait("update")
  if ai.on_ground(id) then
    if math.abs(gd.spatial.vx[id]) == runspeed then
      signal.send("state@" .. id, states.ground_run)
    else
      signal.send("state@" .. id, states.ground_move)
    end
    return
  end
  return api.arial2ground(id)
end

function api.jump(id)
  signal.wait("update")
  if input.ispressed(key.jump) then
    input.latch(key.jump)
    -- Clear ground variable to avoid multiple jumps
    gd.spatial.ground[id] = nil
    if math.abs(gd.spatial.vx[id]) < 0.5 * (runspeed + walkspeed) then
      gd.spatial.vy[id] = jumpspeed
    else
      gd.spatial.vy[id] = runjumpspeed
    end
  end
  return api.jump(id)
end

function api.get_default_keys()
  local k = {}
  k[key.attackA] = key.attackA
  return k
end

function api.fork_interrupt(id)
  concurrent.fork(api.jump, id)
  concurrent.fork(api.ground2arial, id)
end

local wpn_states = {}

local function wpn_state_listener(id, keys)
  signal.wait("update")
  local f
  for _, key in pairs(keys) do
    if input.ispressed(key) then
      local state = wpn_states[key]
      local function init(id)
        return state(id, key)
      end
      f = init and state or nil
      break
    end
  end
  if f then signal.send("state@" .. id, f) end
  return wpn_state_listener(id, keys)
end

function api.wpn_state_listener_init(id, ...)
  local banned = {...}
  local keys = api.get_default_keys()
  for _, key in pairs(banned) do keys[key] = nil end
  return wpn_state_listener(id, keys)
end

function api.return2base(id)
  local next = states.ground_move and ai.on_ground(id) or states.arial_move
  signal.send("state@" .. id, next)
end

states = {
  ground_move = {
    api.ground2arial, run_toggle, movement, api.jump, ground_animation,
    api.wpn_state_listener_init
    --function(id) return wpn_state_listener(id, api.get_default_keys()) end
  },
  ground_run = {api.ground2arial, run_toggle, run_begin, api.jump},
  arial_move = {api.arial2ground, movement, arial_animation},
  arial_run = {api.arial2ground, arial_animation},
}

local function state_machine(id)
  local next_state = signal.wait("state@" .. id)
  concurrent.join()
  if next_state == nil then return end
  map(function(f) concurrent.fork(f, id) end, next_state)
  return state_machine(id)
end

function loader.gobbles()
  -- Initialize animations
  local sheet = love.graphics.newImage("resource/sheet/gobbles.png")
  atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage("resource/sheet/gobbles_nmap.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)

  local index = require "resource/sheet/gobbles"
  local function initanime(key, frames, ox, oy)
    anime[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frames, ox, oy,
      true
    )
  end
  initanime("idle", 4, 15, 22)
  initanime("walk", 10, 16, 22)
  initanime("run", 8, 17, 22)
  initanime("descend", 4, 15, 21)
  initanime("ascend", 4, 15, 22)
  -- Load normal map
  --nmap:setFilter("linear", "linear")
  -- Initialize hitboxes
  hitbox = {
    body = initresource(
      resource.hitbox, coolision.createaxisbox, -width, -height, width * 2,
      height * 2, "ally"
    )
  }
  local fb_ground = furnace_blade.load(atlas, anime, initanime, api)
  wpn_states[key.attackA] = fb_ground

  -- HACK
  goobles_drawing_stuff = draw_engine.create_atlas(atlas)
end

function init.gobbles(gd, id, x, y)
    gd.spatial.x[id] = x
    gd.spatial.y[id] = y
    gd.spatial.width[id] = width
    gd.spatial.height[id] = height
    gd.spatial.vx[id] = 0
    gd.spatial.vy[id] = 0
    gd.spatial.face[id] = 1

    gamedata.tag.entity[id] = true

    concurrent.detach(state_machine, id, states)
    signal.send("state@" .. id, states.ground_move)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
