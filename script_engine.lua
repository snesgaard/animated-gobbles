local queue = {["function"] = {}, table = {}}

script_engine = {}

function script_engine.set(id, updater)
  local utype = type(updater)
  local entry = queue[utype]
  if not entry then
    error(
      "Update script provided that was neither function or coroutine: ", utype
    )
  end
  -- Remove potential other updaters
  for _, entries in pairs(queue) do entries[id] = nil end
  entry[id] = updater
end

function script_engine.clear(id)
  queue["function"] = nil
  queue.coroutine = {}
end

function script_engine.update(dt)
  local fentries = queue["function"]

  for id, f in pairs(fentries) do f(id, dt) end
  for id, co in pairs(queue.coroutine) do coroutine.resume(co, id, dt) end
end
