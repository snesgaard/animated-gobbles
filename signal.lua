local _MAGIC_NUMBER = 0xDEADBABE

local function _filter(condition)
  return function(next)
    return function(...) if condition(...) then return next(...) end end
  end
end

local function _any()
  return _filter(function(...)
    local arg = {...}
    return #arg > 0
  end)
end

local function _none()
  return _filter(function(...)
    local arg = {...}
    return #arg == 0
  end)
end

local function _map(M)
  return function(next)
    local t = type(M)
    if t == "function" then
      return function(...) return next(M(...)) end
    elseif t == "thread" then
      return function(...)
        local arg = {coroutine.resume(M, ...)}
        for i, v in pairs(arg) do arg[i] = arg[i + 1] end
        return next(unpack(arg))
      end
    end
  end
end

local function _sequence()
  return function(next)
    return function(t)
      local res = {}
      for key, val in pairs(t) do res[key] = {next(val)} end
      for key, val in pairs(res) do
        if #val == 1 then res[key] = val[1] end
      end
      return res
    end
  end
end

local function _flatten()
  return function(next)
    return function(t)
      local res = {}
      for _, subtab in pairs(t) do
        for _, val in pairs(subtab) do
          table.insert(res, val)
        end
      end
      return next(res)
    end
  end
end

local function _future(f)
  return function(next)
    return function(...)
      local co = coroutine.create(f(...))
      local function _future_run(dt)
        local arg = coroutine.resume(co, dt)
        if not arg[1] then return end
        for i, val in ipairs(arg) do
          arg[i] = arg[i + 1]
        end
        if #arg > 0 then return next(unpack(arg)) end
        return _future_run(coroutine.yield())
      end
      lambda.run(_future_run)
    end
  end
end

local function _compile(agg)
  local init_fun = agg[#agg]
  agg[#agg] = nil
  for i = #agg, 1, -1  do
    local _partial_compiler = agg[i]
    init_fun = _partial_compiler(init_fun)
  end
  return init_fun
end

local _branch

local function _leaf(f, builders)
  return function(...)
    table.insert(builders, f(...))
    return _branch(builders)
  end
end

_branch = function(builders)
  return {
    _magic_number = _MAGIC_NUMBER, -- Replace with metatable
    filter = _leaf(_filter, builders),
    map = _leaf(_map, builders),
    future = _leaf(_future, builders),
    any = _leaf(_any, builders),
    none = _leaf(_none, builders),
    listen = function(f)
      local tf = type(f)
      if tf == "function" then
        table.insert(builders, f)
      elseif tf == "string" or tf == "number" or tf == "table" then
        table.insert(builders, function(...) signal.emit(f, ...) end)
      else
        error("Unsupported type: " .. tf)
      end
      local token = _compile(builders)
      -- return token
      return token
    end,
    fork = function(...)
      local branches = {...}
      for i, b in pairs(branches) do
        local t = type(b)
        if t == "function" then
          -- Do nothing
        elseif t == "string" or t == "number" or t == "table" then
          branches[i] = function(...) signal.emit(b, ...) end
        else
          error("Unsupported type: " .. t)
        end
      end
      table.insert(builders, function(...)
        for _, b in ipairs(branches) do b(...) end
      end)
      return _compile(builders)
    end,
  }
end

local id_cache = {}
local val_cache = {}

local sig_table = {}
local token_table = {}
local sig_buffer = {}
local token_buffer = {}

local function fetch_entry(tab, id)
  local entry = tab[id]
  if not entry then
    entry = {}
    tab[id] = entry
  end
  return entry
end

signal = {}

function signal.type(id)
  local builders = {}
  table.insert(builders, function(next)
    local token = {}
    return function()
      local sig_entry = fetch_entry(sig_table, id)
      local sig_buf = fetch_entry(sig_buffer, id)
      local token_buf = fetch_entry(token_buffer, id)
      --local cache = fetch_cache(id)
      --local ub = upper_bracket[id] or {}
      --ub[token] = next
      --upper_bracket[id] = ub
      if not token_table[token] then
        token_table[token] = true
        table.insert(sig_entry, next)
      end
      table.insert(sig_buf, next)
      table.insert(token_buf, token)
      --for _, sig in pairs(cache) do
      --  next(unpack(sig))
      --end
      --table.insert(entry, next)
    end
  end)
  return _branch(builders)
end

function signal.from_value()
  local builders = {}
  table.insert(builders, function(next)
    return function(...) return next(...) end
  end)
  return _branch(builders)
end

function signal.from_table()
  local builders = {}
  table.insert(builders, function(next)
    return function(t)
      if type(t) ~= "table" then error("Table expected, got " .. type(t)) end
      for val, key in pairs(t) do
        return next(val, key)
      end
    end
  end)
  return _branch(builders)
end

function signal.merge(...)
  local builders = {}
  local parents = {...}
  table.insert(builders, function(next)
    local tokens = map(function(p)
      local t = type(p)
      if t == "table" and p._magic_number == _MAGIC_NUMBER then
        return p.listen(next)
      elseif t == "table" or t == "number" or t == "string" then
        return signal.type(p).listen(next)
      else
        error("Unsupported type:", t)
      end
    end, parents)
    return function()
      for _, t in pairs(tokens) do t() end
    end
  end)
  return _branch(builders)
end

function signal.zip(...)
  local builders = {}
  local parents = {...}
  local values = {}
  for i, _ in ipairs(parents) do values[i] = {} end
  local function do_emit()
    for i, v in ipairs(values) do
      if #v == 0 then return false end
    end
    return true
  end
  local function create_branch(i, next)
    return function(...)
      table.insert(values[i], {...})
      --TODO INVOKE NEXT IF ALL OF VALUE IS FILLED
      while do_emit() do
        local res = {}
        for i, val in ipairs(values) do
          for _, v in ipairs(val[1]) do
            table.insert(res, v)
          end
          for i, v in pairs(val) do
            val[i] = val[i + 1]
          end
        end
        next(unpack(res))
      end
    end
  end
  table.insert(builders, function(next)
    local tokens = {}
    for i, p in ipairs(parents) do
      local br = create_branch(i, next)
      local t = type(p)
      if t == "table" and p._magic_number == _MAGIC_NUMBER then
        tokens[i] = p.listen(br)
      elseif t == "table" or t == "number" or t == "string" then
        tokens[i] = signal.type(p).listen(br)
      else
        error("Unsupported type:", t)
      end
    end
    return function()
      for i, t in pairs(tokens) do
        print("token", i)
        t()
      end
    end
  end)
  return _branch(builders)
end

function signal.emit(id, ...)
  local entries = fetch_entry(sig_table, id)
  for _, react in pairs(entries) do react(...) end
end

-- Basically the same as emit
-- Except that it gathers the return values of signal listeners
function signal.echo(id, ...)
  local entries = fetch_entry(sig_table, id)
  local val = {}
  for _, react in pairs(entries) do
    local r = {react(...)}
    if r[1] ~= nil then table.insert(val, r) end
  end
  return val
end

function signal.update()
  sig_table = {}
  token_table = {}

  for id, sig_buf in pairs(sig_buffer) do
    local entry = fetch_entry(sig_table, id)
    for _, s in pairs(sig_buf) do
      table.insert(entry, s)
    end
  end
  for id, tok_buf in pairs(token_buffer) do
    for _, t in pairs(tok_buf) do
      token_table[t] = true
    end
  end
  sig_buffer = {}
  token_buffer = {}
end
