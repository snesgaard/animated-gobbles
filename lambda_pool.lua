local queue = require "queue"

local timer = love.timer.getTime

local pool = {}

pool.__index = pool

function pool.new()
  return setmetatable(
    {
      named_thread = {
        pool_id = {},
        age = {},
        queue = {},
      },
      resource = createresource({
        process = {},
        age = {},
        name = {},
      }),
      __sorted_update = {},
      __sort_update_order = {},
    },
    pool
  )
end

function pool:__named_handle_run(dt, name, f)
  f(dt)
  local q = self.named_thread.queue[name]
  if not q or q:empty() then
    self:stop(name)
  else
    return self:__named_handle_run(dt, name, q:pop())
  end
end

function pool:__unnamed_handle_run(dt, pid, f)
  f(dt)
  self:__stop(pid)
end

function pool:__do_sort_updates()
  self.__sorted_update = {}
  for id, _ in pairs(self.resource.process) do
    table.insert(self.__sorted_update, id)
  end
  table.sort(self.__sorted_update, function(a, b)
    local age = self.resource.age
    return age[a] < age[b]
  end)
end

function pool:__stop(id)
  if not id then return end
  local name = self.resource.name[id]
  if name then self.named_thread.pool_id[name] = nil end
  freeresource(self.resource, id)
  self.__sort_update_order = true
end

function pool:run(...)
  local args = {...}
  local name
  local f
  if type(args[1]) ~= "function" then
    name = args[1]
    f = args[2]
    for i = 1, #args do
      args[i] = args[i + 2]
    end
    self:stop(name)
  else
    f = args[1]
    for i = 1, #args do
      args[i] = args[i + 1]
    end
  end
  if not f then return end

  local shroud_f = function(dt)
    return f(dt, unpack(args))
  end
  local id = allocresource(self.resource)
  local run = coroutine.wrap(function(dt)
    if name then
      return self:__named_handle_run(dt, name, shroud_f)
    else
      return self:__unnamed_handle_run(dt, id, shroud_f)
    end
  end)
  --print("running", name, run)
  self.resource.process[id] = run
  self.resource.name[id] = name
  if name then
    local q = self.named_thread.queue[name]
    if q then
      q:clear()
    else
      self.named_thread.queue[name] = queue.new()
    end
    self.named_thread.pool_id[name] = id
    if not self.named_thread.age[name] then
      self.named_thread.age[name] = timer()
    end
    self.resource.age[id] = self.named_thread.age[name]
  else
    self.resource.age[id] = timer()
  end

  self.__sort_update_order = true
end

function pool:queue(name, f, ...)
  if not f then return end
  if not self:status(name) then return self:run(name, f, ...) end
  local args = {...}
  local q = self.named_thread.queue[name]
  q:push(function(dt) return f(dt, unpack(args)) end)
end

function pool:stop(name)
  local q = self.named_thread.queue[name]
  if q then q:clear() end
  self:__stop(self.named_thread.pool_id[name])
end

function pool:update(dt)
  if self.__sort_update_order then self:__do_sort_updates() end

  self.__sort_update_order = false

  for _, id in pairs(self.__sorted_update) do
    local run = self.resource.process[id]
    local r = run(dt)
    --if not r then self:stop(id) end
  end
end

function pool:status(id)
  return self.named_thread.pool_id[id]
end

function pool:empty()
  local res = self.resource
  for _,_ in pairs(res.process) do return false end
  return true
end

return pool
