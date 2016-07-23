require "math"

collision_engine = {}

-- This hers be a list of lists of hitbox requests
-- It contains entity IDs at top level and boxids at bottom level
local _collision_requests = {}
-- Marks a hitbox as being active for a given entity
-- By only supplying id and seq_id the current active box will be released
local function _set_request(id, box_id)
  local sub_req = _collision_requests[id]
  if not sub_req then
    sub_req = {}
    _collision_requests[id] = sub_req
  end
  if box_id ~= collision_engine.empty_box() then
    sub_req[box_id] = box_id
  end
end

local function _fetch_result(res, id, boxid)
  local sub_res = res[id]
  if not sub_res then return end
  return sub_res[boxid]
end

-- Sequence iterator
-- Argument in order
local function create_sequence(args)
  local id = args[1]
  local seq = args[2]
  local time = args[3]
  local cb  = args.callback
  local to = args.to or #seq
  local from = args.from or 1
  local type = args.type or "repeat"
  local ft
  local dir = 1
  local border
  if type == "repeat" then
    border = function(i, dir)
      return from, 1
    end
    ft = time / (to - from + 1)
  elseif type == "bounce" then
    border = function(i, dir)
      if dir == 1 then
        return math.max(from, to - 1), -1
      else
        return math.min(from + 1, to), 1
      end
    end
    ft = time / (to - from) * 0.5
  elseif type == "once" then
    border = function(i, dir)
      return to, 0
    end
    ft = time / (to - from + 1)
  end
  local function f(dt)
    local t = ft
    local i = from
    while true do
      local boxid = seq[i]
      while t > 0 do
        t = t - dt
        _set_request(id, boxid)
        local col_res = coroutine.yield()
        local sub_res = _fetch_result(col_res, id, boxid)
        if cb and sub_res then map(cb, sub_res) end
        dt = coroutine.yield()
      end
      t = ft + t
      i = i + dir
      if i > to or i < from then i, dir = border(i, dir) end
    end
  end
  return coroutine.wrap(f)
end

local master_sequence = {}

local function _create_boundry_draw(col_req)
  return function()
    local _, _, _, xlow, xup, ylow, yup = coolision.sortcoolisiongroups(
      gamedata, col_req
    )
    gfx.setColor(255, 255, 255, 100)
    gfx.setBlendMode("alpha")
    for id, xl in pairs(xlow) do
      local xu = xup[id]
      local yl = ylow[id]
      local yu = yup[id]
      gfx.rectangle("line", xl, -yl, xu - xl, yl - yu)
    end
  end
end

function collision_engine.update(dt)
  -- Update all sequences temporally
  for id, sequences in pairs(master_sequence) do
    for _, seq in pairs(sequences) do
      seq(dt)
    end
  end
  local col_req = _collision_requests
  _collision_requests = {}
  collision_engine.draw_boundries = _create_boundry_draw(col_req)
  -- Run collision detection on all registered hitboxes
  local results = coolision.docollisiondetections(gamedata, col_req)
  -- Submit results to all sequences
  for id, sequences in pairs(master_sequence) do
    for _, seq in pairs(sequences) do
      seq(results)
    end
  end
  return col_req
end

function collision_engine.sequence(args)
  local id = args[1]
  local sequences = master_sequence[id]
  if not sequences then
    sequences = {}
    master_sequence[id] = sequences
  end
  local seq_id = #sequences + 1
  sequences[seq_id] = create_sequence(args)
  return seq_id
end

function collision_engine.stop(id, seq_id)
  local sequences = master_sequence[id]
  if not sequences then return end
  if seq_id then
    sequences[seq_id] = nil
  else
    master_sequence[id] = {}
  end
end

function collision_engine.empty_box()
  return -1
end

function collision_engine.alloc_sequence(seq, hail, seek)
  local f = function(h)
    if #h == 0 then
      return collision_engine.empty_box()
    else
      return initresource(
        resource.hitbox, coolision.createaxisbox, h[1], h[2], h[3], h[4], hail,
        seek
      )
    end
  end
  return map(f, seq)
end

function collision_engine.batch_alloc_sequence(seq_map, hail_map, seek_map)
  local res = {}
  for key, seq in pairs(seq_map) do
    res[key] = collision_engine.alloc_sequence(
      seq, hail_map[key], seek_map[key]
    )
  end
  return res
end

function collision_engine.draw_boundries() end
