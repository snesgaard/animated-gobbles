local named_pool = {}
local unnamed_pool = {}

tscript = {}

function tscript.run(...)
  local args = {...}
  if type(args[1]) == "function" then
    local f = args[1]
    for i = 1, #args do
      args[i] = args[i + 1]
    end
    local co = coroutine.create(function(dt)
      f(dt, unpack(args))
    end)
    table.insert(unnamed_pool, co)
  else
    local id = args[1]
    local f = args[2]
    for i = 1, #args do
      args[i] = args[i + 2]
    end
    local co = coroutine.create(function(dt)
      f(dt, unpack(args))
    end)
    named_pool[id] = co
  end
end

function tscript.stop(id)
  named_pool[id] = nil
end

function tscript.update(dt)
  for id, co in pairs(named_pool) do
    local r = coroutine.resume(co, dt)
    if not r then named_pool[id] = nil end
  end
  for id, co in pairs(unnamed_pool) do
    local r = coroutine.resume(co, dt)
    if not r then unnamed_pool[id] = nil end
  end
end
