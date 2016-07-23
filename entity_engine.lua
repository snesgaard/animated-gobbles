require "math"

local function sequence(id, width, height, vx, time, type, from, to)
  local frames = math.min(#width, #height)
  vx = vx or {}
  type = type or "repeat"
  from = from or 1
  to = to or frames
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
    local spatial = gamedata.spatial
    while true do
      local prev_h = spatial.height[id]
      spatial.width[id] = width[i]
      local dy = prev_h - height[i]
      if dy < 0 then
        map_geometry.diplace(id, 0, -dy)
        spatial.height[id] = height[i]
      else
        spatial.height[id] = height[i]
        map_geometry.diplace(id, 0, -dy)
      end
      map_geometry.diplace(id, spatial.face[id] * (vx[i - 1] or 0), 0)
      while t > 0 do
        t = t - dt
        dt = coroutine.yield()
      end
      t = ft + t
      i = i + dir
      if i > to or i < from then i, dir = border(i, dir) end
      while dir == 0 do coroutine.yield() end
    end
  end
  return f
end

local _sequences = {}
entity_engine = {}
function entity_engine.sequence(id, ...)
  _sequences[id] = coroutine.create(sequence(id, ...))
end
function entity_engine.stop(id)
  _sequences[id] = nil
end
function entity_engine.update(dt)
  for id, co in pairs(_sequences) do coroutine.resume(co, dt) end
end
