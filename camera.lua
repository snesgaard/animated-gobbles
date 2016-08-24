require "math"

loaders = loaders or {}

camera = {}

local gfx = love.graphics

local function normalize(x, y)
  if math.abs(x) < 1e-6 and math.abs(y) < 1e-6 then return x, y, 0 end
  local l = math.sqrt(x * x + y * y)
  local s = 1.0 / l
  return x * s, y * s, l
end

function camera.transformation(id, level)
  local cw = gamedata.spatial.width[id]
  local ch = gamedata.spatial.height[id]
  local sx = gfx.getWidth() / cw
  local sy = gfx.getHeight() / ch
  gfx.scale(sx, sy)
  ---gfx.scale(2, 2)
  local cx, cy = gamedata.spatial.x[id], gamedata.spatial.y[id]
  if level then
    cx, cy = camera.limit_map(id, level)
  end
  gfx.translate(cw * 0.5 - cx, ch * 0.5 + cy)
end

function camera.inv_transform(id, level, x, y)
  local cw = gamedata.spatial.width[id]
  local ch = gamedata.spatial.height[id]
  local sx = gfx.getWidth() / cw
  local sy = gfx.getHeight() / ch

  local cx, cy = gamedata.spatial.x[id], gamedata.spatial.y[id]
  if level then
    cx, cy = camera.limit_map(id, level)
  end
  local tx = cw * 0.5 - cx
  local ty = ch * 0.5 + cy
  return x / sx - tx , -y / sy + ty
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

function camera.follow(cam_id, target_id, level)
  local dt = signal.wait("update")
  local spa = gamedata.spatial
  local cx = spa.x[cam_id]
  local cy = spa.y[cam_id]
  local tx = spa.x[target_id]
  local ty = spa.y[target_id]
  if spa.vx[target_id] ~= 0 then
    local v = spa.vx[target_id]
    local s = v / math.abs(v)
    tx = tx + 100 * s
  end
  local dx = tx - cx
  local dy = ty - cy
  local l = 0
  dx, dy, l = normalize(dx, dy)
  local speed = math.exp(l * 0.005) - 1
  if speed > 1e-5 then
    dx = dx * speed
    dy = dy * speed
    spa.x[cam_id] = cx + dx
    spa.y[cam_id] = cy + dy
  else
    spa.x[cam_id] = tx
    spa.y[cam_id] = ty
  end
  spa.x[cam_id], spa.y[cam_id] = camera.limit_map(cam_id, level)
  return camera.follow(cam_id, target_id, level)
end
