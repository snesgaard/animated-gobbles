local list = {}
list.__index = list

function list.new()
  return setmetatable({
    __list = {}
  }, list)
end

function list:insert(val, index)
  if not index then
    table.insert(self.__list, val)
  else
    for i = #self.__list, index, -1 do
      self.__list[i + 1] = self.__list[i]
    end
    self.__list[index] = val
  end
end

function list:erase(index)
  local val = self.__list[index]
  for i = index + 1, #self.__list do
    self.__list[i] = self.__list[i + 1]
  end
  return val
end

function list:size()
  return #self.__list
end

function list:clear()
  self.__list = {}
end

return list
