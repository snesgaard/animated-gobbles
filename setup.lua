require "gamedata" -- THis will generate the global "data" table
require "input"
require "coroutine"
require "combat"
require ("modules/tilephysics")
require ("modules/coolision")
misc = require ("modules/misc")
sti = require ("modules/sti")
require "statsui"
require ("modules/functional")
require "light"
require "animation"
require "camera"
fun = require "modules/functional"


renderbox = {
  lx = {},
  hx = {},
  ly = {},
  hy = {},
  do_it = true
}


function love.keypressed(key, isrepeat)
  system.pressed[key] = system.time
end

function love.keyreleased(key, isrepeat)
  system.released[key] = system.time
end

-- redefine coroutine resume to be a bit more verbose
_coroutine_resume = coroutine.resume
function coroutine.resume(...)
	local result = {_coroutine_resume(...)}
  local state = result[1]
	if not state then
		error( tostring(result[2]), 2 )	-- Output error message
	end

	return unpack(result)
end

-- Utility
-- TODO FInd more suitable location for this function
function on_ground(id)
  local buffer = 0.1 -- Add to global data if necessary
  local g = gamedata.spatial.ground[id]
  local t = system.time
  return g and t - g < buffer
end

function loadshader(path, path2)
  --path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()

  if path2 == nil then
    return love.graphics.newShader(fstring)
  else
    --path2 = "resource/shader/" .. path2
    local f2 = io.open(path2, "rb")
    local fstring2 = f2:read("*all")
    f2:close()
    return love.graphics.newShader(fstring, fstring2)
  end
end

local leveldraw
function setdefaults()
  -- Some global names
  gfx = love.graphics
  -- Set filtering to nearest neighor
  local filter = "nearest"
  local s = 5
  love.graphics.setDefaultFilter(filter, filter, 0)
  -- Setup camera
  local camera = allocresource(gamedata)
  local spatial = gamedata.spatial
  spatial.width[camera] = gfx.getWidth() / s
  spatial.height[camera] = gfx.getHeight() / s
  spatial.x[camera] = 100
  spatial.y[camera] = -100
  return camera
end

colres = {}
combatreq = {}
combatres = {}

update = {}
function update.system(dt)
  -- Check for exit
  if system.pressed["escape"] then love.event.quit() end
  -- Update time
  system.time = love.timer.getTime()
  system.dt = dt
end
function update.action()
  --Run game script
  -- Initiate all coroutines
  -- Gather coolision requests
  local masters = {}
  local colrequest = {}
  for id, co in pairs(gamedata.ai.action) do
    _, colrequest[id] = coroutine.resume(co, id)
  end
  -- Flatten request table
  colres = coolision.docollisiondetections(gamedata, colrequest)
  -- Now obtain combat requests
  combatreq = {}
  for id, co in pairs(gamedata.ai.action) do
    _, combatreq[id] = coroutine.resume(co, colres)
  end
  -- TODO: Combat engine stuff
  combatres = combat.dorequests(gamedata, combatreq)
  -- Now submit combat results to control scripts
  for id, co in pairs(gamedata.ai.action) do
    coroutine.resume(co, combatres)
  end
  -- Apply the result of all results
  --[[
  local act = gamedata.actor
  for id, res in pairs(combatres) do
    local d = act.damage[id] or 0
    for _, r in pairs(res) do
       d = d + r.dmg
    end
    if d > 0 then
      act.damage[id] = d
    end
  end
  ]]--
  -- Do visualization
  if renderbox.do_it then
    _, _, _, renderbox.lx, renderbox.hx, renderbox.ly, renderbox.hy = coolision.sortcoolisiongroups(gamedata, colrequest)
  end
end
function update.movement(gamedata, map)
  -- Move all entities
  --local ac = gamedata.actor
  for id, _ in pairs(gamedata.tag.entity) do
    --local x, y, vx, vy, cx, cy = mapAdvanceEntity(map, "geometry", id)
    --gamedata.spatial.x[id] = x
    --gamedata.spatial.y[id] = y
    --gamedata.spatial.vx[id] = vx
    --gamedata.spatial.vy[id] = vy
    --if cy and cy < y then gamedata.spatial.ground[id] = system.time end
    physics.update_entity(map, "geometry", id)
  end
end
