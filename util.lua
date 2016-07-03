require "math"

function map(f, t)
  local r = {}
  for key, val in pairs(t) do
    r[key] = f(val)
  end
  return r
end

function duplicate(val, n)
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
