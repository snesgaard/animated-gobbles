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
  blast_A = {
    key = "blast_A", time = 0.4, type = "bounce",
    callback = {
      [0xff00] = function() end,
    },
  },
  pre_furnace_B = {
    key = "furnace_blade_B", time = 0.4, from = 1, to = 4, type = "once",
    callback = {
      [0xff00] = function() end,
      [0xff0000] = function() end,
    },
  },
  post_furnace_B = {
    key = "furnace_blade_B", time = 0.3, from = 5, to = 7, type = "once",
    callback = {
      [0xff00] = function() end,
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
  local callback = args.callback or {}
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

local subject = {
  -- Attributes
  face = rx.Subject.create(),
  horizontal_speed = rx.Subject.create(),
  vertical_speed = rx.Subject.create(),
  sequence = rx.Subject.create(),
  state = rx.Subject.create(),
  -- Sequences
  idle_seq = rx.BehaviorSubject.create(sequence_args.idle),
  air_seq = rx.BehaviorSubject.create(sequence_args.ascend),
}

local input = {
  direction = rx.BehaviorSubject.create(0),
  jump = rx.BehaviorSubject.create(),
  action1 = rx.BehaviorSubject.create(),
}

rx.Observable.merge(
  love.keypressed
    :filter(function(k) return k == key.left or k == key.right end)
    :map(function(k) return k == key.left and -1 or 1 end),
  love.keyreleased
    :filter(function(k) return k == key.left or k == key.right end)
    :map(function(k) return k == key.left and 1 or -1 end)
) :scan(function(a, b) return a + b end, 0)
  :subscribe(input.direction)

love.keypressed
  :filter(function(k) return k == key.jump end)
  :map(function(k) return k, love.timer.getTime() end)
  :subscribe(input.jump)

love.keypressed
  :filter(function(k) return k == key.action1 end)
  :map(function(k) return k, love.timer.getTime() end)
  :subscribe(input.action1)

function gobbles.idle(id)
  subject.horizontal_speed:onNext(
    input.direction:map(function(d) return d * walkspeed end)
  )
  subject.face:onNext(input.direction)
  local jump_buffer = 0.2
  subject.vertical_speed:onNext(
    input.jump
      :filter(function(k, t) return love.timer.getTime() -t < jump_buffer end)
      :flatMapLatest(function()
        return state_engine.update
          :takeUntil(util.wait(jump_buffer))
          :filter(function() return ai.on_ground(id) end)
          :take(1)
          :map(function() return jumpspeed end)
      end)
  )

  subject.sequence:onNext(
    state_engine.update
      :map(function() return ai.on_ground(id) end)
      :filter(coroutine.wrap(function(g)
        local prev_g = not g
        while true do
          local r = prev_g ~= g
          prev_g = g
          g = coroutine.yield(r)
        end
      end))
      :flatMapLatest(function(g)
        return g and subject.idle_seq or subject.air_seq
      end)
  )
  subject.state:onNext(
    input.action1
      :filter(function(k, t) return love.timer.getTime() - t < 0.15 end)
      :flatMapLatest(function()
        return state_engine.update:takeUntil(util.wait(0.15))
      end)
      :filter(function() return ai.on_ground(id) end)
      :take(1)
      :map(function() return gobbles.furnace_blade_A end)
  )
end

function gobbles.furnace_blade_A(id)
  subject.horizontal_speed:onNext(rx.Observable.fromValue(0))
  subject.face:onNext(
    input.direction:takeUntil(util.wait(0.3))
  )
  subject.vertical_speed:onNext(rx.Observable.fromValue(0))
  subject.sequence:onNext(
    entity_engine.event
      :filter(function(e)
        return e.id == id and e.type == entity_engine.event_types.done
      end)
      :take(1)
      :startWith(1)
      :map(coroutine.wrap(function()
        coroutine.yield(sequence_args.pre_furnace_A)
        coroutine.yield(sequence_args.post_furnace_A)
      end))
  )
  local cancel_blast = rx.BehaviorSubject.create(
    not love.keyboard.isDown(key.action1)
  )
  rx.Observable.merge(love.keypressed, love.keyreleased)
    :filter(function(k) return k == key.action1 end)
    :take(1)
    :map(function() return true end)
    :subscribe(cancel_blast)
  local next_stuff = rx.Observable.merge(
    input.jump
      :filter(function(k, t) return love.timer.getTime() - t < 0.2 end)
      :map(function() return gobbles.idle end),
    input.action1
      :filter(function(k, t) return love.timer.getTime() - t < 0.5 end)
      :filter(function() return ai.on_ground(id) end)
      :take(1)
      :map(function() return gobbles.furnace_blade_B end),
    rx.Observable.fromValue(gobbles.blast_A)
      :zip(cancel_blast)
      :filter(function(f, c) return not c end),
    subject.done_stream
      :map(function() return gobbles.idle end)
    --input.direction
    --  :filter(function(d) return d ~= 0 end)
    --  :map(function() return gobbles.idle end)
  )
  subject.state:onNext(
    subject.done_stream
      :flatMapLatest(function() return next_stuff end)
      :take(1)
  )
end

function gobbles.furnace_blade_B(id)
  subject.horizontal_speed:onNext(rx.Observable.fromValue(0))
  subject.face:onNext(input.direction:take(1))
  input.direction
    :take(1)
    :map(function(d) return d ~= 0 and d or gamedata.spatial.face[id] end)
    :subscribe(function(d)
      map_geometry.diplace(id, d * 3, 0)
    end)

  subject.vertical_speed:onNext(rx.Observable.fromValue(0))
  subject.sequence:onNext(
    entity_engine.event
      :filter(function(e)
        return e.id == id and e.type == entity_engine.event_types.done
      end)
      :take(1)
      :startWith(1)
      :map(coroutine.wrap(function()
        coroutine.yield(sequence_args.pre_furnace_B)
        coroutine.yield(sequence_args.post_furnace_B)
      end))
  )
  local cancel_blast = rx.BehaviorSubject.create(
    not love.keyboard.isDown(key.action1)
  )
  rx.Observable.merge(love.keypressed, love.keyreleased)
    :filter(function(k) return k == key.action1 end)
    :take(1)
    :map(function() return true end)
    :subscribe(cancel_blast)
  local next_stuff = rx.Observable.merge(
    input.jump
      :filter(function(k, t) return love.timer.getTime() - t < 0.2 end)
      :map(function() return gobbles.idle end),
    rx.Observable.fromValue(gobbles.blast_A)
      :zip(cancel_blast)
      :filter(function(f, c) return not c end),
    subject.done_stream
      :map(function() return
        function(id)
          local f = gamedata.spatial.face[id]
          map_geometry.diplace(id, -2 * f, 0)
          gobbles.idle(id)
        end
      end)
    --input.direction
    --  :filter(function(d) return d ~= 0 end)
    --  :map(function() return gobbles.idle end)
  )
  subject.state:onNext(
    subject.done_stream
      :flatMapLatest(function() return next_stuff end)
      :take(1)
  )
end

function gobbles.blast_A(id)
  local f = gamedata.spatial.face[id]
  subject.horizontal_speed:onNext(rx.Observable.fromValue(-f * 50))
  subject.vertical_speed:onNext(rx.Observable.fromValue(130))
  subject.face:onNext(rx.Observable.fromValue(f))
  subject.sequence:onNext(rx.Observable.fromValue(sequence_args.blast_A))
  subject.state:onNext(
    state_engine.update
      :map(function() return ai.on_ground(id) end)
      :filter(function(g) return g end)
      :take(1)
      :map(function() return gobbles.idle end)
  )
end

function loader.gobbles()
  -- Initialize animations
  local data_dir = "resource/sprite/gobbles"
  local sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage(data_dir .. "/normal.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)

  local index = require (data_dir .. "/info")
  frame_data = require (data_dir .. "/hitbox")
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

  --launch_seq{id, "walk", 0.9}

  subject.horizontal_speed
    :switch()
    :subscribe(function(vx)
      gamedata.spatial.vx[id] = vx
    end)
  subject.vertical_speed
    :switch()
    :subscribe(function(vy)
      if vy > 0 then
        gamedata.spatial.ground[id] = nil
      end
      gamedata.spatial.vy[id] = vy
    end)
  subject.face
    :switch()
    :filter(function(f) return f == -1 or f == 1 end)
    :subscribe(function(f)
      gamedata.spatial.face[id] = f
    end)

  subject.sequence
    :switch()
    :subscribe(function(seq)
      seq[1] = id
      seq[2] = seq.key
      seq[3] = seq.time
      entity_engine.sequence_sync
        :take(1)
        :subscribe(function() launch_seq(seq) end)
    end)
  subject.state
    :switch()
    :subscribe(function(f)
      love.update
        :take(1)
        :map(function() return id end)
        :subscribe(f)
    end)

  input.direction
    :map(function(d)
      return d ~= 0 and sequence_args.walk or sequence_args.idle
    end)
    :subscribe(subject.idle_seq)
  state_engine.update
    :map(function() return gamedata.spatial.vy[id] end)
    :filter(coroutine.wrap(function(vy)
      local prev_vy = -vy * math.huge
      while true do
        local r = prev_vy * vy <= 0 and prev_vy ~= vy
        prev_vy = vy
        vy = coroutine.yield(r)
      end
    end))
    :map(function(vy)
      return vy >= 0 and sequence_args.ascend or sequence_args.descend
    end)
    :subscribe(subject.air_seq)
  subject.done_stream = entity_engine.event
    :filter(function(e)
      return e.id == id and e.type == entity_engine.event_types.done
    end)

  gobbles.idle(id)

  gamedata.tag.entity[id] = true
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
