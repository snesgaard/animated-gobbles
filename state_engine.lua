-- Table holding current state
local states = {}
-- Table holding future changes in state
-- This includes setting, removal and optional arguments
local pending = {
  states = {},
  args = {},
  removal = {},
}
-- API
state_engine = {}
-- Function which request a change to a new collection of state functions
-- Global optional arguments can be supplied
-- Changes will be handled during the next update
function state_engine.set(id, state, ...)
  pending.states[id] = state
  pending.args[id] = {...}
end
-- Function which request a complete removal of state thread
-- Changes will be handled during the next update
function state_engine.remove(id)
  table.insert(pending.removal, id)
end
-- Updates the states of all entities based on request
function state_engine.update()
  -- First collect and clear request tables
  local ps = pending.states
  pending.states = {}
  local pa = pending.args
  pending.args = {}
  local pe = pending.removal
  pending.removal = {}
  -- Iterate through all change request
  for id, state in pairs(ps) do
    -- Check previous state, if there is something, join it and erase
    local prev = states[id]
    if prev then
      signal.send("interrupt@" .. id)
      concurrent.join(prev)
    end
    -- Fork new thread with supplied arguments
    local args = pa[id] or {}
    if state then
      states[id] = concurrent.fork(state, id, unpack(args))
    else
      states[id] = nil
    end
  end
end
