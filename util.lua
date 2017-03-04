require "math"

local DEFINE = {
  E = math.exp(1)
}

util = {}
function map(f, ...)
  local r = {}

  local t = zip(...)
  for key, val in pairs(t) do
    r[key] = f(unpack(val))
  end
  return r
end

function filter(f, list)
  local res = {}
  for key, val in pairs(list) do
    if f(val) then res[key] = val end
  end
  return res
end

function range(min, max)
  if not max then
    return range(1, min)
  end
  local r = {}
  for i = min, max do table.insert(r, i) end
  return r
end

function util.duplicate(val, n)
  local t = {}
  for i = 1, n do
    t[i] = val
  end
  return t
end

function util.deep_copy(src, dst)
  dst = dst or {}
  for key, val in pairs(src) do
    if type(val) == "table" then
      dst[key] = util.deep_copy(val)
    else
      dst[key] = val
    end
  end
  return dst
end

function concatenate(...)
  local lists = {...}
  local aggr = {}
  for _, list in pairs(lists) do
    for _, val in pairs(list) do
      table.insert(aggr, val)
    end
  end
  return aggr
end

function flatten(listoflists)
  local res = {}
  for _, list in pairs(listoflists) do
    for _, val in pairs(list) do
      table.insert(res, val)
    end
  end
  return res
end

function zip(...)
  local lists = {...}
  if #lists == 0 then return {} end
  local sizes = {}
  for i, l in pairs(lists) do
    sizes[i] = #l
  end
  --local sizes = map(function(t) return #t end, lists)
  local zipped = {}
  local min_size = math.min(unpack(sizes))
  for i = 1, min_size do
    local entry = {}
    for _, l in pairs(lists) do
      table.insert(entry, l[i])
    end
    table.insert(zipped, entry)
  end
  return zipped
end

function fold(f, l, init)
  if #l == 0 then
    if not init then
      error("fold was called with empty list and no initializer")
    else
      return init
    end
  end
  if #l == 1 and init == nil then return l[1] end
  local j = 1
  if init == nil then
    init = f(l[1], l[2])
    j = 3
  end
  for i = j, #l do init = f(init, l[i]) end
  return init
end

function flip(t)
  local res = {}
  for k, v in pairs(t) do res[v] = k end
  return res
end

-- Linear interpolant
function util.lerp(dt, time, f)
  local t = time
  while t > 0 do
    f(1 - t / time) -- Call with interpolant
    dt = coroutine.yield()
    t = t - dt
  end
  -- Call to signal end of lerp
  f(1)
end
-- Exponential interpolant
function util.xerp(dt, time, f)
  local _min = 2
  local _max = 7
  local min = math.exp(_min)
  local max = math.exp(_max)
  local s = 1.0 / (max - min)
  local function g(t)
    return f((math.exp(_max * t + _min * (1 - t)) - min) * s)
  end
  return util.lerp(dt, time, g)
end
-- Logarithmic interpolation
function util.gerp(dt, time, f)
  local _min = 1
  local _max = 30
  local min = math.log(_min)
  local max = math.log(_max)
  local s = 1.0 / (max - min)
  local function g(t)
    return f((math.log(_max * t + _min * (1 - t)) - min) * s)
  end
  return util.lerp(dt, time, g)
end

function util.equal(...)
  local args = {...}
  return function(c)
    local val = false
    for _, k in pairs(args) do
      val = val or c == k
    end
    return val
  end
end
function util.time(t)
  return function(dt)
    t = t - dt
    return t > 0
  end
end

function math.dot(x1, y1, x2, y2)
  return x1 * x2 + y1 * y2
end

function print_table(t)
  for key, val in pairs(t) do print(key, val) end
end
