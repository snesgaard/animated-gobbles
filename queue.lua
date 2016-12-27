local queue = {}
queue.__index = queue

function queue.new()
  return setmetatable({
    __queue = {}
  }, queue)
end

function queue:push(val)
  table.insert(self.__queue, val)
end

function queue:peek()
  return self.__queue[1]
end

function queue:pop()
  local val = self:peek()
  for i = 1, #self.__queue do
    self.__queue[i] = self.__queue[i + 1]
  end
  return val
end

function queue:size()
  return #self.__queue
end

function queue:empty()
  for k, v in pairs(self.__queue) do
    return false
  end
  return true
end

function queue:clear()
  self.__queue = {}
end

return queue
