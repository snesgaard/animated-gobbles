require "math"

ai = {}

function ai.sortclosest(gamedata, id, tofollow)
  local act = gamedata.actor
  local dist = {}
  for _, oid in pairs(tofollow) do
    dist[id] = math.abs(act.x[oid] - act.x[id])
  end
  table.sort(tofollow, function(a, b) return dist[a] < dist[b] end)
end

local function setspeed(gamedata, id, speed, cols)
  local act = gamedata.actor
  local minvx = -math.huge
  local maxvx = math.huge
  for _, oid in ipairs(cols) do
    local dx = act.x[oid] - act.x[id]
    if dx > 0 then maxvx = 0 elseif dx < 0 then minvx = 0 end
  end
  return math.min(maxvx, math.max(minvx, speed))
end

function ai.moveto(gamedata, fid, tid, speed, asid, tol)
  local dx = math.huge
  local act = gamedata.actor
  dx = act.x[tid] - act.x[fid]
  local f = dx / math.abs(dx)
  act.face[fid] = f
  if math.abs(dx) < tol then
    return true
  end
  local do_col = function(gamedata, id)
    return {asid}
  end
  local do_res = function(gamedata, id, res)
    act.vx[fid] = setspeed(gamedata, fid, speed * f, res[asid] or {})
  end
  do_action(gamedata, fid, do_col, do_res)
  --[[
  cols = coroutine.yield({asid})
  act.vx[fid] = setspeed(gamedata, fid, speed * f, cols[asid])
  ]]--
  coroutine.yield()
  return ai.moveto(gamedata, fid, tid, speed, asid, tol)
end

function ai.movefrom(gamedata, fid, tid, speed, asid, tol)
  local dx = math.huge
  local act = gamedata.actor
  dx = act.x[tid] - act.x[fid]
  local f = -dx / math.abs(dx)
  act.face[fid] = f
  local do_col = function(gamedata, id)
    return {asid}
  end
  local do_res = function(gamedata, id, res)
    act.vx[fid] = setspeed(gamedata, fid, speed * f, res[asid] or {})
  end
  do_action(gamedata, fid, do_col, do_res)
  --[[
  cols = coroutine.yield({asid})
  act.vx[fid] = setspeed(gamedata, fid, speed * f, cols[asid])
  ]]--
  coroutine.yield()
  return ai.movefrom(gamedata, fid, tid, speed, asid, tol)
end

function ai.chain(...)
  local funs = {...}
  return function(...)
    for _, f in ipairs(funs) do f(...) end
  end
end

function ai.turn(gd, id, other)
  local act = gd.actor
  if act.x[other] - act.x[id] > 0 then
    act.face[id] = 1
  else
    act.face[id] = -1
  end
end

function ai.staminaleft(gd, id)
  local act = gd.actor
  local s = act.stamina[id]
  local u = act.usedstamina[id] or 0
  return s - u
end

function ai.healthleft(gd, id)
  local act = gd.actor
  local h = act.health[id]
  local d = act.damage[id] or 0
  return h - d
end

function do_action(gamedata, id, hitbox, combat)
  local r
  if hitbox then r = hitbox(gamedata, id) end
  local res = coroutine.yield(r)
  if combat then r = combat(gamedata, id, res) else r = nil end
  return coroutine.yield(r)
end

function ai.on_ground(id)
  local buffer = 0.1 -- Add to global data if necessary
  local g = gamedata.spatial.ground[id]
  local t = system.time
  return g and t - g < buffer
end

function ai.constant_hspeed(vx)
  return coroutine.create(function(id)
    local spa = gamedata.spatial
    while true do
      spa.vx[id] = vx * spa.face[id]
      do_action()
      coroutine.yield()
    end
  end)
end

function ai.do_nothing_for(time)
  local t = system.time
  while system.time - t < time do coroutine.yield() end
end

function ai.do_for(time, f)
  local t = system.time
  while system.time - t < time do
    local args = {f()}
    coroutine.yield(unpack(args))
  end
end

function ai.do_until(condition, action)
  repeat
    local args = {action()}
    coroutine.yield(unpack(args))
  until condition()
end
