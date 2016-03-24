require "math"

loaders = loaders or {}

camera = {}

local gfx = love.graphics

function camera.transformation(id, level)
  local cw = gamedata.spatial.width[id]
  local ch = gamedata.spatial.height[id]
  local sx = gfx.getWidth() / cw
  local sy = gfx.getHeight() / ch
  gfx.scale(sx, sy)
  local cx, cy = gamedata.spatial.x[id], gamedata.spatial.y[id]
  if level then
    cx, cy = camera.limit_map(id, level)
  end
  gfx.translate(cw * 0.5 - cx, ch * 0.5 + cy)
end

function camera.wobble(x, y)
  local spatial = gamedata.spatial
  local function f(id)
    local t = system.time
    spatial.x[id] = x + 10 * math.cos(t)
    spatial.y[id] = y + 10 * math.sin(t)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

function camera.limit_map(id, level)
  local spatial = gamedata.spatial
  local x = spatial.x[id]
  local y = spatial.y[id]
  local w = spatial.width[id]
  local h = spatial.height[id]
  local mw = level.width * level.tilewidth
  local mh = level.height * level.tileheight
  x = math.max(x, w * 0.5 + level.tilewidth)
  x = math.min(x, mw - w * 0.5 - level.tilewidth)
  y = math.min(y, -h * 0.5 - level.tileheight)
  y = math.max(y, -mh + h * 0.5 + level.tileheight)
  return x, y
end
