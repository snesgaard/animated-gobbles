require "coroutine"

local function map(f, t)
  local r = {}
  for key, val in pairs(t) do
    r[key] = f(val)
  end
  return r
end

local _waiting_list = {}
local _active_list = {} -- List conatining the currently executing signals
local _co_list = {}

signal = {}
-- Function that waits for a given signal
function signal.wait(key, ...)
  -- Retrieve calling thread
  local co = coroutine.running()
  -- Check for validity
  assert(co ~= nil, "Main thread cannot wait")
  -- Insert into relevant list of waiters
  local sub_list = _waiting_list[key] or {}
  sub_list[co] = co
  _co_list[co] = key
  _waiting_list[key] = sub_list
  --_onhold[co] = true
  -- Yield and wait for signal
  return coroutine.yield(...)
end

-- Function that triggers a signal to given pool of threads
function signal.send(key, ...)
  -- Find waiters and check for existance
  local sub_list = _waiting_list[key]
  if not sub_list then return end
  -- Clear list and resume waiting threads
  _waiting_list[key] = nil
  -- Set reference to the executing coroutines, so that they may be removed
  -- This may not be the cleanest of solutions :(
  _active_list[key] = sub_list
  for _, co in pairs(sub_list) do
    _co_list[co] = nil
    coroutine.resume(co, ...)
    -- If the coroutine was removed from the active list by another
    -- In this case, reclear the coroutine so it is removed from
    -- any waiting position
    -- TODO: This currently does not seem to work :(
    if not sub_list[co] then signal.clear(co) end
  end
  _active_list[key] = nil
end

function signal.clear(co)
  local key = _co_list[co]
  _co_list[co] = nil
  local sub_list = _waiting_list[key] or {}
  sub_list[co] = nil
  local a_list = _active_list[key] or {}
  a_list[co] = nil
end

-- Table for concurrency and heredity
concurrent = {}
-- Contains reference to coroutines that has been spawned by a given parent
local children = {}

-- Used to create a new coroutine and put it in reletion to the spawning routine
-- It is important that whenever a fork is happening, join must be called later
-- Other the resources will never be released
function concurrent.fork(f, ...)
  local current = coroutine.running() or "main"
  local co = coroutine.create(f)
  coroutine.resume(co, ...)
  local c = children[current] or {}
  --table.insert(c, co)
  c[co] = co
  children[current] = c
  return co
end

-- Used to join a parent with all it's descendents
-- This will clear them from all waiting signals and event
-- NOTE: Maybe add a check when joining a specific routine, to ensure that it
--        is a child routine
function concurrent.join(co)
  co = co or coroutine.running() or "main"
  local call_co = coroutine.running() or "main"
  -- Check if we are dealing with a sub coroutine
  -- In that case, clear it from the masters table
  if co ~= call_co then
    local super_children = children[call_co] or {}
    super_children[co] = nil
  end
  local function subjoin(co)
    local c = children[co] or {}
    children[co] = nil
    signal.clear(co)
    map(concurrent.join, c)
  end
  subjoin(co)
end

-- A simple wrapper around coroutine create and first resume
-- Intended to launch an independent thread
function concurrent.detach(f, ...)
  local co = coroutine.create(f)
  coroutine.resume(co, ...)
  return co
end
