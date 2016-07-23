local weapon_path = "actor/gobbles/"
--local furnace_blade = require(weapon_path .. "furnace_blade")

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
local frame_data = {}


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
local data = {}


local hitbox_seek = {
  [0xff0000] = "enemy",
}
local hitbox_hail = {
  [0xff00] = "ally",
}

local function reset(id)
  concurrent.join()
  collision_engine.stop(id)
end

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

-- APIS for weapon code
function test_state(id)
  local t = 1.5
  local type = "once"
  local function launch_seq(time, from, to)
    animation.play(id, atlas, anime.furnace_blade_A, time, type, from, to)
    entity_engine.sequence(
      id, frame_data.furnace_blade_A.width, frame_data.furnace_blade_A.height,
      frame_data.furnace_blade_A.vx, time, type, from, to
    )

    collision_engine.stop(id)
    collision_engine.sequence{
      id, frame_data.furnace_blade_A.hitbox[0xff0000], time, type = type, to = to,
      from = from
    }
    collision_engine.sequence{
      id, frame_data.furnace_blade_A.hitbox[0xff00], time, type = type, to = to,
      from = from
    }
    ai.sleep(time)
  end
  launch_seq(0.6, 1, 6)
  launch_seq(0.3, 7, 10)
  --launch_seq(0.6, 11, 15)
  return test_state_B(id)
end

function test_state_B(id)
  local t = 0.75
  local type = "once"
  local function launch_seq(time, from, to)
    animation.play(id, atlas, anime.furnace_blade_B, time, type, from, to)
    entity_engine.sequence(
      id, frame_data.furnace_blade_B.width, frame_data.furnace_blade_B.height,
      frame_data.furnace_blade_B.vx, time, type, from, to
    )

    collision_engine.stop(id)
    collision_engine.sequence{
      id, frame_data.furnace_blade_B.hitbox[0xff0000], time, type = type, to = to,
      from = from
    }
    collision_engine.sequence{
      id, frame_data.furnace_blade_B.hitbox[0xff00], time, type = type, to = to,
      from = from
    }
    ai.sleep(time)
  end
  map_geometry.diplace(id, 3, 0)
  launch_seq(t)
  return test_state(id)
end

local function ground_sequence_manager(id)
  local function launch(key, time, to, from)
    local type = "repeat"
    animation.play(id, atlas, anime[key], time, type, from, to)
    entity_engine.sequence(
      id, frame_data[key].width, frame_data[key].height,
      {}, time, type, from, to
    )
    collision_engine.stop(id)
    collision_engine.sequence{
      id, frame_data[key].hitbox[0xff00], time, type = type, to = to,
      from = from
    }
  end
  local vx = gamedata.spatial.vx
  while true do
    launch("idle", 0.75)
    while vx[id] == 0 do signal.wait("update") end
    launch("walk", 1.0)
    while vx[id] ~= 0 do signal.wait("update") end
  end
end

local function check_for_air(id)
  if not ai.on_ground(id) then
    state_engine.set(id, states.arial_control)
  else
    signal.wait("update")
    return check_for_air(id)
  end
end

local function _jump_control(id)
  if input.ispressed(key.jump) then
    gamedata.spatial.vy[id] = jumpspeed
    state_engine.set(id, states.arial_control)
    return
  end
  signal.wait("update")
  return _jump_control(id)
end

local function _run_ground_control(id)
  local d = input_direction()
  if d ~= 0 then
    gamedata.spatial.vx[id] = walkspeed * d
    gamedata.spatial.face[id] = d
  else
    gamedata.spatial.vx[id] = 0
  end
  signal.wait("update")
  return _run_ground_control(id)
end

function states.ground_control(id)
  concurrent.fork(ground_sequence_manager, id)
  concurrent.fork(_jump_control, id)
  concurrent.fork(check_for_air, id)
  return _run_ground_control(id)
end

local function arial_sequence_manager(id)
  local function launch(key, time, to, from)
    local type = "repeat"
    animation.play(id, atlas, anime[key], time, type, from, to)
    entity_engine.sequence(
      id, frame_data[key].width, frame_data[key].height,
      {}, time, type, from, to
    )
    collision_engine.stop(id)
    collision_engine.sequence{
      id, frame_data[key].hitbox[0xff00], time, type = type, to = to,
      from = from
    }
  end
  local vy = gamedata.spatial.vy
  while true do
    launch("ascend", 0.5)
    while vy[id] > 0 do signal.wait("update") end
    launch("descend", 0.5)
    while vy[id] <= 0 do signal.wait("update") end
  end
end

local function check_for_ground(id)
  if ai.on_ground(id) then
    state_engine.set(id, states.ground_control)
  else
    signal.wait("update")
    return check_for_ground(id)
  end
end

function states.arial_control(id)
  concurrent.fork(arial_sequence_manager, id)
  concurrent.fork(check_for_ground, id)
  return _run_ground_control(id)
end

local function _run_run_control(id)
  signal.wait("update")
  return _run_run_control(id)
end

function states.run_control(id)
  local function launch(key, time, to, from)
    local type = "repeat"
    animation.play(id, atlas, anime[key], time, type, from, to)
    entity_engine.sequence(
      id, frame_data[key].width, frame_data[key].height,
      {}, time, type, from, to
    )
    collision_engine.stop(id)
    collision_engine.sequence{
      id, frame_data[key].hitbox[0xff00], time, type = type, to = to,
      from = from
    }
  end
  return _run_run_control(id)
end

function loader.gobbles()
  -- Initialize animations
  local sheet = love.graphics.newImage("resource/sprite/sheet.png")
  atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage("resource/sprite/normal.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)

  local index = require "resource/sprite/info"
  frame_data = require "resource/sprite/hitbox"
  --data = data.furnace_blade_A
  --anime.furnace_blade_A = initresource(
  --  resource.animation, animation.init, sheet, index.furnace_blade_A, data, true
  --)

  table.foreach(frame_data, function(key, val)
    anime[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frame_data[key],
      true
    )
  end)

  table.foreach(frame_data, function(key, val)
    frame_data[key].hitbox = collision_engine.batch_alloc_sequence(
      frame_data[key].hitbox, hitbox_hail, hitbox_seek
    )
  end)
  -- Initialize hitboxes
  hitbox = {
    body = initresource(
      resource.hitbox, coolision.createaxisbox, -width, -height, width * 2,
      height * 2, "ally"
    )
  }
  --local fb_ground = furnace_blade.load(atlas, anime, initanime, gobbles)
  --weapon.furnace_blade = fb_ground

  -- Fork weapon setting server
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

    state_engine.set(id, states.ground_control)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
