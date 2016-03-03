require "globaldata" -- THis will generate the global "data" table
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
require "trail"
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
  gamedata.system.pressed[key] = gamedata.system.time
end

function love.keyreleased(key, isrepeat)
  gamedata.system.released[key] = gamedata.system.time
end

-- Timer and break condition related functions
-- This function waits until annointed time or interrupt conditions occur
coroutine.wait = function(gamedata, duration, interrupt)
  local t = gamedata.system.time
  while gamedata.system.time - t < duration do
    if interrupt and interrupt() then return false end
    coroutine.yield()
  end
  return true
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
function on_ground(gamedata, id)
  local buffer = 0.1 -- Add to global data if necessary
  local g = gamedata.actor.ground[id]
  local t = gamedata.system.time
  return g and t - g < buffer
end

function createmapdrawer(mapkey)
  local co = coroutine.create(function(gamedata)
    while true do
      love.graphics.setBackgroundColor(70, 70, 120, 255)
      local map = gamedata.resource.tilemaps[mapkey]
      map:draw(0, 0, 0, 4, 4)
      coroutine.yield()
    end
  end)
  return co
end

function loadshader(path)
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  return love.graphics.newShader(fstring)
end

local leveldraw
function setdefaults()
  -- Some global names
  gfx = love.graphics
  -- Set filtering to nearest neighor
  local filter = "nearest"
  local s = 5
  love.graphics.setDefaultFilter(filter, filter, 0)
  gamedata.visual.scale = s
  gamedata.visual.width = love.graphics.getWidth()
  gamedata.visual.height = love.graphics.getHeight()
  gamedata.visual.aspect = gamedata.visual.width / gamedata.visual.height
  gamedata.visual.basecanvas = gfx.newCanvas(
    gamedata.visual.width, gamedata.visual.height
  )
end

colres = {}
combatreq = {}
combatres = {}

update = {}
function update.system(gamedata, dt)
  -- Check for exit
  if gamedata.system.pressed["escape"] then love.event.quit() end
  -- Update time
  gamedata.system.time = love.timer.getTime()
  gamedata.system.dt = dt
end
function update.ai_n_combat(gamedata)
  --Run game script
  -- Initiate all coroutines
  -- Gather coolision requests
  local masters = {}
  local colrequest = {}
  for id, co in pairs(gamedata.actor.action) do
    _, colrequest[id] = coroutine.resume(co, gamedata, id)
  end
  -- Flatten request table
  colres = coolision.docollisiondetections(gamedata, colrequest)
  -- Now obtain combat requests
  combatreq = {}
  for id, co in pairs(gamedata.actor.action) do
    _, combatreq[id] = coroutine.resume(co, colres)
  end
  -- TODO: Combat engine stuff
  combatres = combat.dorequests(gamedata, combatreq)
  -- Now submit combat results to control scripts
  for id, co in pairs(gamedata.actor.action) do
    coroutine.resume(co, combatres)
  end
  -- Apply the result of all results
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
  -- Do visualization
  for id, drawer in pairs(gamedata.actor.draw) do
    animation.entitydraw(gamedata, id, drawer)
  end
  if renderbox.do_it then
    _, _, _, renderbox.lx, renderbox.hx, renderbox.ly, renderbox.hy = coolision.sortcoolisiongroups(gamedata, colrequest)
  end
end
function update.movement(gamedata, map)
  -- Move all entities
  local ac = gamedata.actor
  for id, _ in pairs(ac.x) do
    local x, y, vx, vy, cx, cy = mapAdvanceEntity(map, "geometry", id, gamedata)
    ac.x[id] = x
    ac.y[id] = y
    ac.vx[id] = vx
    ac.vy[id] = vy
    if cy and cy < y then gamedata.actor.ground[id] = gamedata.system.time end
    local tco = ac.terrainco[id]
    if tco then coroutine.resume(tco, gamedata, id, cx, cy) end
  end
end


function normalrender()
  --love.graphics.scale(gamedata.visual.scale)
  local basecanvas = gamedata.visual.basecanvas
  gfx.setCanvas(basecanvas)
  --basecanvas:clear()
  gfx.clear()
  gfx.setColor(70, 70, 120)
  -- Setup camera translation
  gfx.rectangle("fill", 0, 0, gamedata.visual.width, gamedata.visual.height)
  gfx.setColor(255, 255, 255)
  local tmap = gamedata.resource.tilemaps[gamedata.global.level]
  local x, y = gamedata.visual.x, gamedata.visual.y
  love.graphics.translate(-x, y)
  love.graphics.scale(gamedata.visual.scale)

  -- Draw level tilemap
  coroutine.resume(gamedata.visual.leveldraw, gamedata, gamedata.global.level)
  -- Setup actor drawing transforms
  love.graphics.scale(1, -1)

  -- First sort all actors according to layers
  local sorted_drawers = {}
  local draworder = {}
  for id, _ in pairs(gamedata.resource.atlas) do
    table.insert(draworder, id)
  end
  local pri = gamedata.visual.draworder
  local sorter = function(a, b)
    local orda = pri[a] or 0
    local ordb = pri[b] or 0
    if orda ~= ordb then
      return orda < ordb
    else
      return a < b
    end
  end
  -- First draw the opague sprite objects
  table.sort(draworder, sorter)
  gfx.setShader(gamedata.resource.shaders.sprite)
  for k, id in ipairs(draworder) do
    gfx.stencil(function()
      gfx.setColorMask()
      gfx.draw(gamedata.resource.atlas[id], 0, 0)
    end, "replace", pri[id], true)
  end
  for _, atlas in pairs(gamedata.resource.atlas) do
    atlas:clear()
  end
  -- Now draw transparent objects
  trail.draw(gamedata)
  gfx.setShader(gamedata.resource.shaders.monosprite)
  for k, id in ipairs(draworder) do
    gfx.setStencilTest("less", pri[id])
    gfx.draw(gamedata.resource.atlas[id], 0, 0)
  end
  for _, atlas in pairs(gamedata.resource.atlas) do
    atlas:clear()
  end
  gfx.setShader()
  healthdisplay.draw(gamedata)
  love.graphics.setColor(255, 255, 255, 100)
  if renderbox.do_it then
    for bid, lx in pairs(renderbox.lx) do
      local hx = renderbox.hx[bid]
      local ly = renderbox.ly[bid]
      local hy = renderbox.hy[bid]
      gfx.rectangle("line", lx, hy, hx - lx, ly - hy)
    end
  end
  -- Reset transforms
  love.graphics.origin()
  gfx.setCanvas()
  light.draw(gamedata, basecanvas, x, y)
  -- Introduce normalize screen coordinates for UI drawing
  -- love.graphics.scale(gamedata.visual.width, gamedata.visual.width)
  love.graphics.scale(gamedata.visual.scale)
  for id, d in ipairs(gamedata.ui.draw) do
    coroutine.resume(d, gamedata, id)
  end
end

love.draw = normalrender
