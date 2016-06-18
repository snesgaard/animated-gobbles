require "math"

local _collision_requests = {}
-- Marks a hitbox as being active for a given entity
-- By only supplying id and seq_id the current active box will be released
local function _set_request(id, seq_id, box_id)
  local sub_req = _collision_requests[id]
  if not sub_req then
    sub_req = {}
    _collision_requests[id] = sub_req
  end
  if box_id ~= collision_engine.empty_box() then
    sub_req[seq_id] = box_id
  else
    sub_req[seq_id] = nil
  end
end

local function _fetch_result(res, id, boxid)
  local sub_res = res[id]
  if not sub_res then return end
  return sub_res[boxid]
end

local function _run_sequence(id, seq_id, seq, time, callback)
  local i = 1
  local l = #seq
  local ft = time / l
  for i = 1, l do
      -- Register id in engine
      local t = 0
      local box_id = seq[i]
      _set_request(id, seq_id, box_id)
      while t < ft do
        local dt, res = coroutine.yield()
        t = t + dt
        local sub_res = _fetch_result(res, id, boxid)
        if sub_res and callback then map(callback, sub_res) end
      end
  end
  _set_request(id, seq_id)
  return true
end

local active_sequence = createresource({
  sequence = {},
  owner = {},
})
collision_engine = {}
-- This creates a sequence play back, where a list of hitboxes is traverse in
-- the given time. If a box collides the provided callback function will be
-- triggered. If no callback is desired simply set it to nil
function collision_engine.sequence(id, seq, time, callback)
  if type(seq) ~= "table" then seq = {seq} end
  local seq_id = allocresource(active_sequence)
  local co = concurrent.detach(_run_sequence, id, seq_id, seq, time, callback)
  active_sequence.sequence[seq_id] = co
  active_sequence.owner[seq_id] = id
  return seq_id
end

function collision_engine.stop(seq_id)
  local id = active_sequence.owner[seq_id]
  _set_request(id, seq_id)
  active_sequence.sequence[seq_id] = nil
  active_sequence.owner[seq_id] = nil
  freeresource(active_sequence, seq_id)
end

-- Fake id that symbolizes an empty collision box
function collision_engine.empty_box()
  return -1
end

function collision_engine.update(dt)
  -- Acquire all submitted collision states
  local collision_results = coolision.docollisiondetections(
    gamedata, _collision_requests
  )
  -- Update all active sequence with results and time
  for seq_id, seq_co in pairs(active_sequence.sequence) do
    local stat, ret = coroutine.resume(seq_co, dt, collision_results)
    if ret then collision_engine.stop(seq_id) end
  end
end

function collision_engine.get_boundries()
  local _, _, _, xlow, xup, ylow, yup = coolision.sortcoolisiongroups(
    gamedata, _collision_requests
  )
  return xlow, xup, ylow, yup
end
