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
gobbles = {}


local hitbox_seek = {
  [0xff0000] = "enemy",
}
local hitbox_hail = {
  [0xff00] = "ally",
}

local function reset(id)
  collision_engine.stop(id)
  state_engine.clear(id)
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

local function launch_seq(args)
  local type = args.type or "repeat"
  local id = args[1]
  local key = args[2]
  local time = args[3]
  local to = args.to
  local from = args.from
  local callback = args.callback
  local still = args.still
  animation.play(id, atlas, anime[key], time, type, from, to)
  local vx = not still and frame_data[key].vx or {}
  entity_engine.sequence(
    id, frame_data[key].width, frame_data[key].height, vx, time, type, from, to
  )
  collision_engine.stop(id)
  for chrom, cb in pairs(callback) do
    collision_engine.sequence{
      id, frame_data[key].hitbox[chrom], time, type = type, to = to,
      from = from, callback = callback
    }
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

local function input_direction()
  local isDown = love.keyboard.isDown
  return (isDown("right") and 1 or 0) - (isDown("left") and 1 or 0)
end

function gobbles.begin_idle_ground(id)
  reset(id)
  -- Create observer that controls jumping
  local jump = util.buffered_keypressed("space", 0.1)
    :filter(function() return ai.on_ground(id) end)
    :map(function()
      return function(id)
        gamedata.spatial.ground[id] = nil
        gamedata.spatial.vy[id] = jumpspeed
        gobbles.begin_idle_arial(id)
      end
    end)
  -- Observer that checks for ground and enters arial state
  local air = state_engine.update
    :filter(function() return not ai.on_ground(id) end)
    :map(function() return gobbles.begin_idle_arial end)
  local attack = util.buffered_keypressed("a", 0.1)
    :map(function() return gobbles.begin_furnace_blade_A end)
  -- Observer that combines and decides on the next state to execute
  local next_state = rx.Observable.merge(jump, air, attack):take(1)
  next_state:subscribe(function(f)
    f(id)
  end)

  local callback = {
    [0x00ff00] = function() end
  }
  -- Create observer that controls ground movement
  local dir = {left = -1, right = 1}
  local key_filter = util.equal(key.left, key.right)
  local isDown = love.keyboard.isDown
  gamedata.spatial.vx[id] = walkspeed * (isDown("right") and 1 or 0)
                            - walkspeed * (isDown("left") and 1 or 0)
  local move_handler = function(d)
    --print("handle", d)
    local spa = gamedata.spatial
    spa.vx[id] = spa.vx[id] + d * walkspeed
    if spa.vx[id] == 0 then
      launch_seq{id, "idle", 0.7, callback = callback}
    else
      spa.face[id] = spa.vx[id] > 0 and 1 or -1
      launch_seq{id, "walk", 0.85, callback = callback}
    end
  end
  -- Observable that handles presses
  local press = love.keypressed
    :filter(key_filter)
    :map(function(k) return dir[k] end)
  -- Observale that handles releases
  local release = love.keyreleased
    :filter(key_filter)
    :map(function(k) return -dir[k] end)
  -- Combined observable that handles movement
  -- Terminates when next state observable fires
  rx.Observable.merge(press, release)
    :takeUntil(next_state)
    :startWith(0)
    :subscribe(move_handler)
end

function gobbles.begin_idle_arial(id)
  reset(id)
  -- Observable handling ground state checking
  local ground_check = state_engine.update
    :filter(function() return ai.on_ground(id) end)
    :map(function() return gobbles.begin_idle_ground end)
  -- Observable handling jumping upon hitting a surface
  local jump = util.buffered_keypressed("space", 0.1)
      :filter(function() return ai.on_ground(id) end)
      :map(function()
        gamedata.spatial.ground[id] = nil
        gamedata.spatial.vy[id] = jumpspeed
        return gobbles.begin_idle_ground
      end)
  local next_state = rx.Observable.merge(ground_check):take(1)
  next_state:subscribe(function(f)
    f(id)
  end)

  local isDown = love.keyboard.isDown
  gamedata.spatial.vx[id] = walkspeed * (isDown("right") and 1 or 0)
                            - walkspeed * (isDown("left") and 1 or 0)
  local callback = {
    [0x00ff00] = function() end
  }
  -- Create observer that controls ground movement
  local dir = {left = -1, right = 1}
  local key_filter = util.equal(key.left, key.right)
  local move_handler = function(d)
    local spa = gamedata.spatial
    spa.vx[id] = spa.vx[id] + d * walkspeed
    if spa.vx[id] ~= 0 then spa.face[id] = d end
  end
  -- Observable handlign key pressed
  local press = love.keypressed
    :filter(key_filter)
    :map(function(k) return dir[k] end)
  -- Observable handling key releases
  local release = love.keyreleased
    :filter(key_filter)
    :map(function(k) return -dir[k] end)
  -- Combined observable that handles movement
  -- Terminates when next state observable fires
  rx.Observable.merge(press, release)
    :takeUntil(next_state)
    :subscribe(move_handler)
  -- Observer for sequence control
  state_engine.update
    :takeUntil(next_state)
    :subscribe(coroutine.wrap(function()
      local vy = gamedata.spatial.vy
      while true do
        launch_seq{id, "ascend", 0.4, callback = callback}
        while vy[id] > 0 do coroutine.yield() end
        launch_seq{id, "descend", 0.4, callback = callback}
        while vy[id] <= 0 do coroutine.yield() end
      end
    end))
end

function gobbles.begin_blast_A(id)
  reset(id)
  local callback = {
    [0x00ff00] = function() end
  }
  local t = 0.4
  launch_seq{
    id, "blast_A", t, callback = callback, type = "bounce"
  }
  gamedata.spatial.vx[id] = -gamedata.spatial.face[id] * 100
  gamedata.spatial.vy[id] = 100
  gamedata.spatial.ground[id] = nil
  state_engine.update
    :filter(function() return ai.on_ground(id) end)
    :take(1)
    :subscribe(function()
      gamedata.spatial.vx[id] = 0
      gobbles.begin_idle_ground(id)
    end)
end

local function listen_for_action_input(id, exitter, t)
  local attack_a = love.keypressed
    :filter(util.equal("a"))
    :zip(state_engine.update:skipWhile(util.time(t)))
    :map(function() return gobbles.begin_furnace_blade_A end)
  local jump = love.keypressed
    :filter(util.equal("space"))
    :filter(function() return ai.on_ground(id) end)
    :map(function()
      return function(id)
        gamedata.spatial.ground[id] = nil
        gamedata.spatial.vy[id] = jumpspeed
        gobbles.begin_idle_arial(id)
      end
    end)
  local next = rx.Observable.merge(jump, attack_a, exitter)
  next
    :take(1)
    :subscribe(function(f) return f(id) end)
end

function gobbles.begin_furnace_blade_A(id)
  reset(id)
  local callback = {
    [0x00ff00] = function() end,
    [0xff0000] = function() end
  }
  local t = 0.7
  launch_seq{
    id, "furnace_blade_A", t, callback = callback, type = "once", to = 10,
    from = 1
  }
  map_geometry.diplace(id, gamedata.spatial.face[id] * 1, 0)
  gamedata.spatial.vx[id] = 0
  local function exit(id)
    local t = 0.4
    launch_seq{
      id, "furnace_blade_A", t, callback = callback, type = "once", to = 15,
      from = 11
    }
    local exitter = state_engine.update
      :skipWhile(util.time(t))
      :map(function()
        return function(id)
          map_geometry.diplace(id, -gamedata.spatial.face[id] * 1, 0)
          gobbles.begin_idle_ground(id)
        end
      end)
    listen_for_action_input(id, exitter, t)
  end

  local default_next = love.keyreleased
    :filter(util.equal("a"))
    :zip(state_engine.update:skipWhile(util.time(t)))
    :map(function() return exit end)
  local blast_a = state_engine.update
    :skipWhile(util.time(t))
    :map(function() return gobbles.begin_blast_A end)
  local attack_b = love.keypressed
    :filter(util.equal("a"))
    :zip(state_engine.update:skipWhile(util.time(t)))
    :map(function() return gobbles.begin_furnace_blade_B end)
  local next_state = rx.Observable.merge(attack_b, default_next, blast_a)
    :take(1)
    :subscribe(function(f) f(id) end)
  local on_left = love.keypressed
    :filter(util.equal("left", "right"))
    :map(function(k)
      local t = {left = -1, right = 1}
      return t[k]
    end)
    :takeUntil(state_engine.update:skipWhile(util.time(0.3)))
    :startWith(input_direction())
    :subscribe(function(d) if d ~= 0 then gamedata.spatial.face[id] = d end end)
end

function gobbles.begin_furnace_blade_B(id)
  reset(id)
  local callback = {
    [0x00ff00] = function() end,
    [0xff0000] = function() end
  }
  local t = 0.4
  launch_seq{
    id, "furnace_blade_B", t, callback = callback, type = "once", to = 4,
    from = 1
  }

  local function exit(id)
    local t = 0.3
    launch_seq{
      id, "furnace_blade_B", t, callback = callback, type = "once", to = 7,
      from = 5
    }
    state_engine.update
      :skipWhile(util.time(t))
      :take(1)
      :subscribe(function()
        map_geometry.diplace(id, -gamedata.spatial.face[id] * 2, 0)
        gobbles.begin_idle_ground(id)
      end)
  end

  map_geometry.diplace(id, gamedata.spatial.face[id] * 3, 0)
  local default_next_down = love.keyreleased
    :filter(util.equal("a"))
    :zip(state_engine.update:skipWhile(util.time(t)))
    :map(function() return exit end)
  local default_next_up = state_engine.update
    :skipWhile(util.time(t))
    :map(function() return exit end)
  local default_next = love.keyboard.isDown("a") and default_next_down
                        or default_next_up
  local blast_a = state_engine.update
    :skipWhile(util.time(t))
    :map(function() return gobbles.begin_blast_A end)
  rx.Observable.merge(default_next, blast_a)
    :take(1)
    :subscribe(function(f) f(id) end)

  local on_left = love.keypressed
    :filter(util.equal("left", "right"))
    :map(function(k)
      local t = {left = -1, right = 1}
      return t[k]
    end)
    :takeUntil(state_engine.update:skipWhile(util.time(0.15)))
    :startWith(input_direction())
    :subscribe(function(d) if d ~= 0 then gamedata.spatial.face[id] = d end end)
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
    gobbles.begin_idle_ground(id)
    --state_engine.set(id, states.ground_control)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
