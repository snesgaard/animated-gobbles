
local queue = {}

script_engine = {}

function script_engine.queue(id, f)
  local q = queue[id] or {}
  table.insert(q, coroutine.create(f))
  queue[id] = q
end

function script_engine.clear(id)
  queue[id] = nil
end

local function update(dt)
  local function _update(q)
    local co = q[1]
    if not co then return end
    if coroutine.status(co) == "dead" then
      for i = 1, #q do q[i] = q[i + 1] end
      return _update(q)
    else
      coroutine.resume(co, dt)
      return q
    end
  end
  for id, q in pairs(queue) do
    queue[id] = _update(q)
  end
end

love.update:subscribe(update)
