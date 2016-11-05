require "math"

util = {}
function map(f, t)
  local r = {}
  for key, val in pairs(t) do
    r[key] = f(val)
  end
  return r
end

function util.duplicate(val, n)
  local t = {}
  for i = 1, n do
    t[i] = val
  end
  return t
end

function concatenate(...)
  local lists = {...}
  local aggr = {}
  for _, list in ipairs(lists) do
    for _, val in ipairs(list) do
      table.insert(aggr, val)
    end
  end
  return aggr
end

function zip(...)
  local lists = {...}
  local sizes = map(function(t) return #t end, lists)
  local zipped = {}
  local min_size = math.min(unpack(sizes))
  for i = 1, min_size do
    local entry = {}
    for _, l in pairs(lists) do
      table.insert(entry, l[i])
    end
    table.insert(zipped, lists)
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
