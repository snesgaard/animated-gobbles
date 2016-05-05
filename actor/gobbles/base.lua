local weapon_path = "actor/gobbles/"
local furnace_blade = require(weapon_path .. "furnace_blade")

require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 75
local jumpspeed = 250

local atlas
local anime = {}
local hitbox = {}


local key = {
  left = "left",
  right = "right",
  down = "down",
  runtoggle = "lalt",
  jump = "space",
  attack1 = "a"
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

function control.init_run(id)
  local draw = {
    run = animation.entitydrawer(id, atlas, anime.run, 0.85),
    arial = arial_draw(),
  }
  gd.ai.action[id] = action.constant_hspeed(runspeed)
  return control.run(draw, id)
end
function control.run(draw, id)
  if input.ispressed(key.jump) and ai.on_ground(id) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    if input.isdown(key.down) and map_geometry.check_thin_platform(id) then
      gd.spatial.y[id] = gd.spatial.y[id] - 1
    else
      gd.spatial.vy[id] = jumpspeed
    end
  end
  local d = input_direction()
  if ai.on_ground(id) and d ~= 0 then
    gd.spatial.face[id] = d
  end
  -- Assign drawer
  if ai.on_ground(id) then
    gd.radiometry.draw[id] = draw.run
  else
    gd.radiometry.draw[id] = draw.arial
  end
  -- Pass to the next state
  if ai.on_ground(id) and (d == 0 or input.ispressed(key.runtoggle)) then
    input.latch(key.runtoggle)
    return control.init_movement(coroutine.yield())
  end
  return control.run(draw, coroutine.yield())
end

function control.init_movement(id)
  local co = {
    draw = {
      idle = animation.entitydrawer(id, atlas, anime.idle, 0.75),
      --idle = animation.entitydrawer(id, atlas, anime.furnace_blade_B, 0.75),
      walk = animation.entitydrawer(id, atlas, anime.walk, 1.0),
      arial = arial_draw()
    },
    act = {
      idle = action.constant_hspeed(0),
      walk = action.constant_hspeed(walkspeed),
    },
  }
  return control.movement(co, id)
end
function control.movement(co, id)
  if input.ispressed(key.attack1) and ai.on_ground(id) then
    --input.latch(key.attack1)
    furnace_blade.idle_init(id, key.attack1)
    return control.movement(co, id)
  end
  if input.ispressed(key.jump) and ai.on_ground(id) then
    input.latch(key.jump)
    gd.spatial.ground[id] = nil
    if input.isdown(key.down) and map_geometry.check_thin_platform(id) then
      gd.spatial.y[id] = gd.spatial.y[id] - 1
    else
      gd.spatial.vy[id] = jumpspeed
    end
  end
  d = input_direction()
  if d ~= 0 then
    -- set const speed walk
    gd.spatial.face[id] = d
    gd.ai.action[id] = co.act.walk
  else
    -- Set const speed 0
    gd.ai.action[id] = co.act.idle
  end
  -- Assign drawLayer
  if not ai.on_ground(id) then
    -- Set air drawer
    gd.radiometry.draw[id] = co.draw.arial
  elseif d ~= 0 then
    -- Set walk drawer
    gd.radiometry.draw[id] = co.draw.walk
  else
    -- Set idle drawer
    gd.radiometry.draw[id] = co.draw.idle
  end
  if ai.on_ground(id) and input.ispressed(key.runtoggle) then
    input.latch(key.runtoggle)
    return control.init_run(coroutine.yield())
  end
  return control.movement(co, coroutine.yield())
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
  furnace_blade.load(atlas, anime, initanime)

  --drawer.gobbles = drawing.from_atlas(atlas)
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

    --gd.ai.control[id] = coroutine.create(control.init_idle)
    gd.ai.control[id] = coroutine.create(control.init_movement)
    --gd.ai.action[id] = action.constant_hspeed(100)
    gamedata.tag.entity[id] = true
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
