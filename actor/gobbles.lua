require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 75
local jumpspeed = 120

local atlas
local anime = {}
local hitbox = {}

local key = {
  left = "left",
  right = "right",
  runtoggle = "lalt",
  jump = "space"
}

--[[
local _do_action = do_action
local do_action = function(gd, id, col, com)
  local supercol
  if col then
    supercol = function(gd, id)
      local r = col(gd, id)
      table.insert(r, hitbox.body)
      return r
    end
  else
    supercol = function(gd, id)
      return {hitbox.body}
    end
  end
  _do_action(gd, id, supercol, com)
end
]]--

local gd = gamedata

local action = {}
local control = {}

local function no_action(id)
  do_action()
  return no_action(coroutine.yield())
end

function action.constant_hspeed(vx)
  return coroutine.create(function(id)
    while true do
      gd.spatial.vx[id] = vx * gd.spatial.face[id]
      do_action()
      coroutine.yield()
    end
  end)
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

local function arial_draw()
  local time = 0.4
  local ascend = animation.draw(atlas, anime.ascend, time)
  local descend = animation.draw(atlas, anime.descend, time)
  local function f(id)
    local co = ascend
    if gd.spatial.vy[id] < 0 then co = descend end
    animation.entitydraw(id, co)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

function control.init_run_jump(id)
  gd.radiometry.draw[id] = arial_draw()
  gd.ai.action[id] = action.constant_hspeed(runspeed)
  return control.run_jump(id)
end
function control.run_jump(id)
  if ai.on_ground(id) then
    if input.isdown(key.left) or input.isdown(key.right) then
      return control.init_run(id)
    else
      return control.init_idle(id)
    end
  end
  return control.run_jump(coroutine.yield())
end

function control.init_arial(id)
  gd.radiometry.draw[id] = arial_draw()
  return control.init_arial_idle(id)
end
function control.init_arial_move(id)
  gd.ai.action[id] = action.constant_hspeed(walkspeed)
  return control.arial_move(id)
end
function control.arial_move(id)
  if ai.on_ground(id) then
    return control.init_walk(id)
  end
  local d = input_direction()
  if d == 0 then
    return control.init_arial_idle(id)
  else
    gamedata.spatial.face[id] = d
  end
  return control.arial_move(coroutine.yield())
end

function control.init_arial_idle(id)
  gd.ai.action[id] = action.constant_hspeed(0)
  return control.arial_idle(coroutine.yield())
end
function control.arial_idle(id)
  if ai.on_ground(id) then
    return control.init_idle(id)
  end
  local d = input_direction()
  if d ~= 0 then
    return control.init_arial_move(id)
  end
  return control.arial_idle(coroutine.yield())
end

function control.init_run(id)
  gd.ai.action[id] = action.constant_hspeed(runspeed)
  gd.radiometry.draw[id] = animation.entitydrawer(id, atlas, anime.run, 0.85)
  return control.run(id)
end
function control.run(id)
  if input.ispressed(key.jump) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = jumpspeed
    return control.init_run_jump(id)
  end
  local d = input_direction()
  if d == 0 then
    return control.init_idle(id)
  elseif input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    return control.init_walk(id)
  else
    gamedata.spatial.face[id] = d
  end

  return control.run(coroutine.yield())
end

function control.init_walk(id)
  gd.ai.action[id] = action.constant_hspeed(walkspeed)
  gd.radiometry.draw[id] = animation.entitydrawer(id, atlas, anime.walk, 1.0)
  return control.walk(id)
end
function control.walk(id)
  if input.ispressed(key.jump) then
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = jumpspeed
    return control.init_arial(id)
  elseif not ai.on_ground(id) then
    return control.init_arial(id)
  end

  local d = input_direction()
  if d == 0 then
    return control.init_idle(id)
  elseif input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    return control.init_run(id)
  else
    gamedata.spatial.face[id] = d
  end
  return control.walk(coroutine.yield())
end

function control.init_idle(id)
  gd.ai.action[id] = action.constant_hspeed(0)
  gd.radiometry.draw[id] = animation.entitydrawer(id, atlas, anime.idle, 0.75)
  return control.idle(coroutine.yield())
end
function control.idle(id)
  if input.ispressed(key.jump) then
    gd.spatial.ground[id] = nil
    gd.spatial.vy[id] = jumpspeed
    return control.init_arial(id)
  elseif not ai.on_ground(id) then
    return control.init_arial(id)
  end
  local d = input_direction()
  if d ~= 0 then
    return control.init_walk(id)
  end
  return control.idle(coroutine.yield())
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
end

function init.gobbles(gd, id, x, y)
    gd.spatial.x[id] = x
    gd.spatial.y[id] = y
    gd.spatial.width[id] = width
    gd.spatial.height[id] = height
    gd.spatial.vx[id] = 0
    gd.spatial.vy[id] = 0
    gd.spatial.face[id] = 1

    gd.ai.control[id] = coroutine.create(control.init_idle)
    --gd.ai.action[id] = action.constant_hspeed(100)

    tag.entity[id] = true
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
