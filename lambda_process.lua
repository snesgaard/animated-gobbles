local named_thread = {pool_id = {}, age = {}}

local pool = createresource({
  process = {},
  age = {},
  name = {}
})

local timer = love.timer.getTime

lambda = {
  __sorted_update = {}, __sort_update_order = false
}

local function __do_sort_updates()
  lambda.__sorted_update = {}
  for id, _ in pairs(pool.process) do
    table.insert(lambda.__sorted_update, id)
  end
  table.sort(lambda.__sorted_update, function(a, b)
    local age = pool.age
    return age[a] < age[b]
  end)
end

local function _stop(id)
  if not id then return end
  local name = pool.name[id]
  if name then named_thread.pool_id[name] = nil end
  freeresource(pool, id)
  lambda.__sort_update_order = true
end

function lambda.run(...)
  local args = {...}
  local name
  local f
  if type(args[1]) ~= "function" then
    name = args[1]
    f = args[2]
    for i = 1, #args do
      args[i] = args[i + 2]
    end
    lambda.stop(name)
  else
    f = args[1]
    for i = 1, #args do
      args[i] = args[i + 1]
    end
  end
  local id = allocresource(pool)
  local co = coroutine.create(function(...)
    f(...)
    _stop(id)
  end)
  local run = function(dt)
    return coroutine.resume(co, dt, unpack(args))
  end
  pool.process[id] = run
  pool.name[id] = name
  if name then
    named_thread.pool_id[name] = id
    if not named_thread.age[name] then
      named_thread.age[name] = timer()
    end
    pool.age[id] = named_thread.age[name]
  else
    pool.age[id] = timer()
  end

  lambda.__sort_update_order = true
end

function lambda.stop(name)
  _stop(named_thread.pool_id[name])
end

function lambda.update(dt)
  if lambda.__sort_update_order then __do_sort_updates() end

  lambda.__sort_update_order = false

  for _, id in pairs(lambda.__sorted_update) do
    local run = pool.process[id]
    local r = run(dt)
    if not r then lambda.stop(id) end
  end
end

function lambda.status(id)
  return named_thread.pool_id[id]
end
