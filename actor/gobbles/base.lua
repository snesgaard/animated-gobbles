local weapon_path = "actor/gobbles/"
--local furnace_blade = require(weapon_path .. "furnace_blade")

require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 25
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
  action1 = "a",
  action2 = "a",
  action3 = "a",
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



local state_select = rx.Subject.create()
local sequence_subject = rx.Subject.create()

local function reset(id)
  collision_engine.stop(id)
  state_engine.clear(id)
end

local sequence_args = {
  idle = {
    key = "idle", time = 0.7, callback = {[0xff00] = function() end}
  },
  walk = {
    key = "walk", time = 0.8, callback = {[0xff00] = function() end}
  },
  ascend = {
    key = "ascend", time = 0.35, callback = {[0xff00] = function() end}
  },
  descend = {
    key = "descend", time = 0.35, callback = {[0xff00] = function() end}
  },
  pre_furnace_A = {
    key = "furnace_blade_A", time = 0.8, from = 1, to = 10, type = "once",
    callback = {
      [0xff00] = function() end,
      [0xff0000] = function() end,
    },
  },
  post_furnace_A = {
    key = "furnace_blade_A", time = 0.5, from = 11, to = 15, type = "once",
    callback = {
      [0xff00] = function() end,
      [0xff0000] = function() end,
    },
  },
}

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

function gobbles.begin_idle(id)
  -- Animation controller
  gobbles.enable_movement(id)
end

function gobbles.furnace_blade_A(id)
  gobbles.disable_movement(id)
  gamedata.spatial.vx[id] = 0
  --gobbles.disable_action(id)
  local done_event = entity_engine.event
    :filter(function(e)
      local b_id = e.id == id
      local b_type = e.type == entity_engine.event_types.done
      return b_id and b_type
    end)
  local seq = done_event
    :take(2)
    :startWith(1)
    :map(coroutine.wrap(function()
      local pre_A = sequence_args.pre_furnace_A
      coroutine.yield(pre_A)
      local post_A = sequence_args.post_furnace_A
      coroutine.yield(post_A)
      local idle = sequence_args.idle
      coroutine.yield(idle)
    end))
  sequence_subject:subscribe(print)
  sequence_subject:onNext(seq)
  --sequence_subject:subscribe(print)
  done_event
    :take(1)
    :subscribe(function()
      local t = 0.2
      gobbles.enable_action(id, t)
      gobbles.enable_movement(id, true, t)
    end)
end

local function is_move_key(k)
  return k == key.left or k == key.right
end
local move_stream = {
  move = rx.Observable.merge(
    love.keypressed
      :filter(is_move_key)
      :map(function(k) return k == "left" and -1 or 1 end),
    love.keyreleased
      :filter(is_move_key)
      :map(function(k) return k == "left" and 1 or -1 end)
  ),
  jump = love.keypressed
    :filter(function(k) return k == key.jump end),
  sequence = state_engine.update
    :map(function()
      local vx, vy = gamedata.spatial.vx, gamedata.spatial.vy
      if ai.on_ground(id) then
        if vx[id] == 0 then
          return sequence_args.idle
        else
          return sequence_args.walk
        end
      else
        if vy[id] > 0 then
          return sequence_args.ascend
        else
          return sequence_args.descend
        end
      end
    end)
    :startWith(sequence_args.idle),
  cancel = rx.Subject.create(),
  enable = rx.Subject.create()
}
local action_stream = {
  action1_key = love.keypressed
    :filter(function(k) return key.action1 == k end),
  action2_key = love.keypressed
    :filter(function(k) return key.action2 == k end),
  action3_key = love.keypressed
    :filter(function(k) return key.action3 == k end),
  cancel = rx.Subject.create(),
}

function gobbles.enable_action(id, delay)
  local delay_trigger = function() return util.wait(delay or 0) end
  action_stream.action1_key
    :takeUntil(action_stream.cancel)
    :zip(delay_trigger())
    :take(1)
    :subscribe(function() gobbles.furnace_blade_A(id) end)
end
function gobbles.disable_action(id)
  action_stream.cancel:onNext(true)
end

function gobbles.enable_movement(id, trigger_start, delay)
  local delay_trigger = function() return util.wait(delay or 0) end
  -- First disble movement if any should happen to be enabled
  gobbles.disable_movement()
  -- Investigate the current keyboard state and see if any happens to be pressed
  local isDown = love.keyboard.isDown
  local init_d = (
    (isDown(key.left) and -1 or 0) + (isDown(key.right) and 1 or 0)
  )
  -- This stream analyses the revelant keyboard inputs and aggregates into a
  -- direction variable
  local tmp_stream = move_stream.move
    :takeUntil(move_stream.cancel)
    :scan(function(a, b) return a + b end, init_d)
    :startWith(init_d)
    :zip(delay_trigger())
  -- If any keys where pressed, this stream should start with the revelant
  -- direction as the initial value
  -- Subscriber that sets face and velocity according to the aggregated value
  tmp_stream:subscribe(function(d)
    gamedata.spatial.vx[id] = d * walkspeed
    if d ~= 0 then gamedata.spatial.face[id] = d end
  end)
  -- Stream that handles buffered inputs for jumping
  -- Upon trigger it creates a temporary stream that checks for ground state for
  -- 150ms. If a trigger happens a jump is executed
  move_stream.jump
    :takeUntil(move_stream.cancel)
    :zip(delay_trigger())
    :subscribe(function()
      love.update
        :takeWhile(coroutine.wrap(function(dt)
          local t = 0.15
          while true do
            t = t - dt
            dt = coroutine.yield(t > 0)
          end
        end))
        :filter(function() return ai.on_ground(id) end)
        :take(1)
        :subscribe(function()
          gamedata.spatial.ground[id] = nil
          gamedata.spatial.vy[id] = jumpspeed
        end)
    end)
  local function sample_velocity()
    local vx = gamedata.spatial.vx[id]
    local vy = gamedata.spatial.vy[id]
    local g = ai.on_ground(id)
    return g, vx, vy
  end
  local function __filter_ground(g, vx, vy)
    local prev_vx = 0
    while g do
      local r = prev_vx ~= vx and prev_vx * vx == 0
      prev_vx = vx
      g, vx, vy = coroutine.yield(r)
    end
    return g, vx, vy
  end
  local function __filter_air(g, vx, vy)
    local prev_vy = vy
    while not g do
      local r = prev_vy ~= vy and prev_vy * vy <= 0
      prev_vy = vy
      g, vx, vy = coroutine.yield(r)
    end
    return g, vx, vy
  end
  local seq_manager = state_engine.update
    :map(sample_velocity)
    :filter(coroutine.wrap(function(g, vx, vy)
      g, vx, vy = coroutine.yield(true)
      while true do
        g, vx, vy = __filter_ground(g, vx, vy)
        coroutine.yield(true)
        g, vx, vy = __filter_air(g, vx, vy)
        coroutine.yield(true)
      end
    end))
    :map(function(g, vx, vy)
      local ground_seq = vx ~= 0 and sequence_args.walk or sequence_args.idle
      local air_seq = vy >= 0 and sequence_args.ascend or sequence_args.descend
      return g and ground_seq or air_seq
    end)
  local isDown = love.keyboard.isDown
  if not trigger_start or init_d ~= 0 then
    delay_trigger()
      :take(1)
      :subscribe(function()
        sequence_subject:onNext(seq_manager)
      end)
  else
    local g_stream = state_engine.update
      :filter(function() return not ai.on_ground(id) end)
    local kp_stream = love.keypressed
      :filter(function(k)
        return k == key.left or k == key.right or k == key.jump
      end)
    local kr_stream = love.keyreleased
      :filter(function(k)
        return k == key.left or k == key.right
      end)
    rx.Observable.merge(g_stream, kp_stream, kr_stream)
      :takeUntil(move_stream.cancel)
      :zip(delay_trigger())
      :take(1)
      :subscribe(function()
        sequence_subject:onNext(seq_manager)
      end)
  end
end
function gobbles.disable_movement()
  move_stream.cancel:onNext(true)
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
  --local fb_ground = furnace_blade.load(atlas, anime, initanime, gobbles)
  --weapon.furnace_blade = fb_ground

  -- Fork weapon setting server

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
    sequence_subject
      :switch()
      :subscribe(function(arg)
        arg[1] = id
        arg[2] = arg.key
        arg[3] = arg.time
        entity_engine.sequence_sync
          :take(1)
          :map(function() return arg end)
          :subscribe(launch_seq)
       end)
    gobbles.enable_movement(id)
--    gobbles.enable_action(id)

    --state_engine.set(id, states.ground_control)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
