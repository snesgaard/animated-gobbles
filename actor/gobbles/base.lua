local weapon_path = "actor/gobbles/"
local furnace_blade = require(weapon_path .. "furnace_blade")

require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 90
local jumpspeed = 150
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
local gobbles = {}
local weapon = {}
local active_weapon = {}

local function weapon_server()
  local slot, wpn_id = signal.wait("set_weapon")
  local wpn = weapon[wpn_id]
  if slot < 1 or slot > 3 or not wpn then
    error("Invalid slot or key recieved", slot, wpn_id)
  end
  weapon[slot] = wpn
  print(string.format("Setting weapon <%s> to slot <%i>", wpn_id, slot))
  return weapon_server()
end

local function _jump_interrupt(id)
  signal.wait("update")
  if input.ispressed(key.jump) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = jumpspeed
    state_engine.set(id, states.arial_move)
    return
  end
  return _jump_interrupt(id)
end
local function _generic_wpn_interrupt(id)
  signal.wait("update")
  local keywpn = {
    [key.attackA] = weapon[1]
  }
  for key, wpn in pairs(keywpn) do
    if input.ispressed(key) then
      state_engine.set(id, wpn, key)
      return
    end
  end
  return _generic_wpn_interrupt(id)
end
function gobbles.fork_interrupt(id)
  concurrent.fork(_jump_interrupt, id)
  concurrent.fork(_generic_wpn_interrupt, id)
  -- Hurt interrupt
  -- Evade interrupt
end
function gobbles.goto_idle(id)
  state_engine.set(id, states.ground_move)
end
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

local function movement(id, speed)
  local d = input_direction()
  if d ~= 0 then
    gd.spatial.face[id] = d
    gd.spatial.vx[id] = speed * d
  else
    gd.spatial.vx[id] = 0
  end
  return d
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

local function jump(id)
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

local function arial2ground(id)
  if ai.on_ground(id) then
    state_engine.set(id, states.ground_move)
  end
end

local function _ground_move(id)
  signal.wait("update")
  movement(id, walkspeed)
  if not ai.on_ground(id) then return states.arial_move(id) end
  if input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    return states.ground_run(id)
  end
  if input.ispressed(key.jump) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = jumpspeed
    return states.arial_move(id)
  end
  return _ground_move(id)
end
function states.ground_move(id)
  concurrent.join()
  concurrent.fork(ground_animation, id)
  concurrent.fork(_generic_wpn_interrupt, id)
  return _ground_move(id)
end

local function _arial_move(id)
  signal.wait("update")
  movement(id, walkspeed * 1.5)
  if ai.on_ground(id) then return states.ground_move(id) end
  return _arial_move(id)
end
function states.arial_move(id)
  concurrent.join()
  concurrent.fork(arial_animation, id)
  return _arial_move(id)
end

local function _ground_run(id)
  signal.wait("update")
  -- Movement
  local d = movement(id, runspeed)
  -- Check for walk
  if d == 0 or input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    return states.ground_move(id)
  end
  if input.ispressed(key.jump) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = runjumpspeed
    return states.arial_run(id)
  end
  if not ai.on_ground(id) then return states.arial_run(id) end

  -- Repeat
  return _ground_run(id)
end
function states.ground_run(id)
  concurrent.join()
  animation.play(id, atlas, anime.run, 0.75)
  return _ground_run(id)
end

local function _arial_run(id)
  signal.wait("update")
  gd.spatial.vx[id] = gd.spatial.face[id] * runspeed
  if ai.on_ground(id) then return states.ground_run(id) end
  return _arial_run(id)
end
function states.arial_run(id)
  concurrent.join()
  concurrent.fork(arial_animation, id)
  return _arial_run(id)
end

-- APIS for weapon code


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
  local fb_ground = furnace_blade.load(atlas, anime, initanime, gobbles)
  weapon.furnace_blade = fb_ground

  -- Fork weapon setting server
  concurrent.detach(weapon_server)
  signal.send("set_weapon", 1, "furnace_blade")

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

    state_engine.set(id, states.arial_move)
    collision_engine.sequence(id, hitbox.body, 1)
    --signal.send("state@" .. id, states.ground_move)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
