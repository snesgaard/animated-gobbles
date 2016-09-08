require "coroutine"

signal = {}

local all_connections = {}

local pendantic = false

local function fetch_connection(id)
  local id_connection = all_connections[id]
  if not id_connection then
    id_connection = {}
    all_connections[id] = id_connection
  end
  return id_connection
end

local function set_connection(id, val)
  all_connections[id] = val
end

function signal.set_pedantic(val)
  pendantic = val
end

function signal.emit(id, ...)
  local id_connection = fetch_connection(id)
  set_connection(id)
  for _, co in pairs(id_connection) do
    coroutine.resume(co, ...)
  end
end

function signal.listen(id, ...)
  local co = coroutine.running()
  local id_connection = fetch_connection(id)
  table.insert(id_connection, co)
  return coroutine.yield(...)
end

function signal.reset()
  local prev = all_connections
  all_connections = {
    update = prev.update
  }
  if pendantic then
    prev.update = nil
    local fault = ""
    local raise_error = false
    for id, connection in pairs(all_connections) do
      for _, co in pairs(connection) do
        if co then
          fault = fault .. id .. ", "
          break
        end
      end
    end
    if raise_error then
      error("Remains detected in signal " .. fault)
    end
  end
end
