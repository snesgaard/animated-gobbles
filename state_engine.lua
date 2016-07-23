-- Table holding current state
local subs = {}
-- API
state_engine = {}
-- Function which request a change to a new collection of state functions
-- Global optional arguments can be supplied
-- Changes will be handled during the next update
function state_engine.get(id, state, ...)
  local s = subs[id]
  if not s then
    s = {}
    subs[id] = nil
  end
  return s
end
-- Function which request a complete removal of state thread
-- Changes will be handled during the next update
function state_engine.clear(id)
  map(subs[id] or {}, function(s) s:unsubscribe() end)
  subs[id] = {}
end
-- Updates the states of all entities based on request
state_engine.update = rx.Subject.create()
state_engine.event = rx.Subject.create()
