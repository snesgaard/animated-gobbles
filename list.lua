require "math"


local list = {}
list.__index = list

function list.__tostring(l)
  local s = "["
  for i = 1, #l - 1 do
    s = s .. tostring(l[i]) .. ", "
  end
  s = s .. tostring(l[#l]) .. "]"
  return s
end

function list.create(...)
  return setmetatable({...}, list)
end

function list:insert(val, index)
  if not index then
    self[#self + 1] = val
  else
    local s = #self
    for i = s, index, - 1 do
      self[i + 1] = self[i]
    end
    self[index] = val
  end
end

function list:erase(index)
  index = index or #self
  local val = self[index]
  for i = index, #self do
    self[i] = self[i + 1]
  end
  return val
end

function list:size()
  return #self
end

function list:map(f)
  local ret = list.create()
  for i = 1, #self do
    ret[i] = f(self[i])
  end
  return ret
end

function list:reduce(f, seed)
  local init = seed and 1 or 2
  seed = seed or self[1]
  for i = init, #self do
    seed = f(seed, self[i])
  end
  return seed
end

function list:reverse()
  local ret = list.create()
  for i = #self, 1, -1 do
    ret[#ret + 1] = self[i]
  end
  return ret
end

function list:filter(f)
  local ret = list.create()
  for i = 1, #self do
    local val = self[i]
    ret[#ret + 1] = f(val) and val or nil
  end
  return ret
end

function list:argfilter(f)
  local ret = list.create()
  for i = 1, #self do
    local val = self[i]
    ret[#ret + 1] = f(val) and i or nil
  end
  return ret
end

function list:concat(...)
  local lists = {self, ...}
  local ret = list.create()
  for _, l in ipairs(lists) do
    for i = 1, #l do
      ret[#ret + 1] = l[i]
    end
  end
  return ret
end


function list:slice(start, stop)
  start = math.max(1, start or 1)
  stop = math.min(#self, stop or #self)
  local ret = list.create()
  for i = start, stop do
    ret[#ret + 1] = self[i]
  end
  return ret
end

function list:fill(val, start, stop)
  start = math.max(1, start or 1)
  stop = math.min(#self, stop or #self)
  local ret = list.create()
  for i = 1, start - 1 do
    ret[i] = self[i]
  end
  for i = start, stop do
    ret[i] = val
  end
  for i = stop + 1, #self do
    ret[i] = self[i]
  end
  return ret
end

function list.duplicate(val, num)
  local ret = list.create()
  for i = 1, num do
    ret[i] = val
  end
  return ret
end

function list:zip(...)
  local lists = list.create(self, ...)
  local min_size = lists:map(list.size):reduce(math.min)
  local ret = list.create()
  for i = 1, min_size do
    local sub_ret = list.create()
    for j = 1, #lists do
      sub_ret[j] = lists[j][i]
    end
    ret[i] = sub_ret
  end
  return ret
end

return list
