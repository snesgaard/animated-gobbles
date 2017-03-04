local resource = {}


local seed = {}
local available_id = {}
function resource.create(res)
  --resource.__seed__ = 1
  --resource.__available_id__ = {}
  seed[res] = 1
  available_id[res] = {}
  return res
end
function resource.alloc(res)
  local sub_available_id = available_id[res]
  local id = sub_available_id[#sub_available_id]
  if id then
    sub_available_id[#sub_available_id] = nil
    return id
  end
  local s = seed[res]
  seed[res] = s + 1
  return s
end
function resource.free(res, id)
  if type(id) ~= "number" then
    error(string.format("Unsupported id type: %s", type(id)))
  end
  table.insert(available_id[res], id)
  local function _erase(t, id)
    t[id] = nil
    for _, sub in pairs(t) do
      if type(sub) == "table" then _erase(sub, id) end
    end
  end
  _erase(res, id)
end
function resource.init(res, f, ...)
  local id = resource.alloc(res)
  f(res, id, ...)
  return id
end

return resource
