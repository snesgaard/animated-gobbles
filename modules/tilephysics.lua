require "math"
local fun = require ("modules/functional")

gravity = {}
gravity.x = 0.0
gravity.y = -350.0
--gravity.y = 0

local indexTransformNoClamp = function(x, mx, mw)
 return (x - mx) / mw
end

local indexTransformX = function(x, mx, mw)
  return math.ceil(indexTransformNoClamp(x, mx, mw))
end

local indexTransformY = function(y, my, wh)
  return math.ceil(indexTransformNoClamp(y, my, -wh))
end

local inverseIndexTransformX = function(x, mx, mw)
  return x*mw + mx
end

local inverseIndexTransformY = function(y, my, mw)
  return y*(-mw) + my
end

function print_table(t)
  for key, value in pairs(t) do
    print(key, value)
  end
end


local getTileType = function(x, y, layer_index, map)
  local layer = map.layers[layer_index]
  if layer == nil or layer.data[y] == nil or layer.data[y][x] == nil then
    return nil
  end
  local tile = layer.data[y][x]
  -- could potentially be removed
  if tile == nil then
    return nil
  end

  local tileset = map.tilesets[tile.tileset]
  -- could potentially be removed
  if tileset == nil then
    return nil
  end

  for _, itile in pairs(tileset.tiles) do
    if itile.id == tile.gid - tileset.firstgid then
      return itile
    end
  end

  return nil
end

local retrieveSlope = function(x, y, layer, map)
  local tileType = getTileType(x, y, layer, map)
  local left, right, type
  if tileType == nil then return 0, 0 end
  if not tileType.left then
    if tileType.properties.left then
      tileType.left = tonumber(tileType.properties.left)
    else
      tileType.left = 0
    end
  end
  if not tileType.right then
    if tileType.properties.right then
      tileType.right = tonumber(tileType.properties.right)
    else
      tileType.right = 0
    end
  end
  left, right = tileType.left, tileType.right
  return left, right, tileType.properties.type
end

local notEmpty = function(left, right)
  return (left > 0 or right > 0)
end


local futureXCollision = function(map, layer_index, dt, ex, ey, wx, wy, vx)
  -- Calculate map indices in y-axis which needs to be checked
  -- Add 1 to offset that lua arrays starts at 1
  local layer = map.layers[layer_index]
  local mx = map.offsetx
  local my = map.offsety
  local ly = indexTransformY(ey + wy, my, map.tileheight)
  local ty = indexTransformY(ey - wy, my, map.tileheight)
  local cx = indexTransformX(ex, mx, map.tilewidth)
  -- Check velocity and treat based
  local cleft, cright = retrieveSlope(cx, ty, layer_index, map)
  -- Check if we are standing on a slope and if it is facing our movement
  -- direction.
  if notEmpty(cleft, cright) and cleft ~= cright then
    -- In that case raise we raise the lower iterator by one so that the
    -- lower row is ignored
    ty = ty - 1
  end
  if vx > 0 then
    local tx = indexTransformX(ex + wx, mx, map.tilewidth)
    local fx = indexTransformX(ex + wx + vx * dt,
                              mx, map.tilewidth)
    for x = math.max(1, tx), math.min(fx, layer.width) do
      for y = math.max(1, ly), math.min(ty, layer.height) do
        local left, right, type = retrieveSlope(x, y, layer_index, map)
        -- Generic tile collision
        if not type and notEmpty(left, right) and (left >= right) then
          return inverseIndexTransformX(x - 1, mx, map.tilewidth)
        end
      end
    end
  elseif vx < 0 then
    local lx = indexTransformX(ex - wx, mx, map.tilewidth)
    local fx = indexTransformX(ex - wx + vx * dt, mx,
                              map.tilewidth)
    for x = math.min(lx, layer.width), math.max(1, fx), -1 do
      for y = math.max(1, ly), math.min(ty, layer.height) do
        local left, right, type = retrieveSlope(x, y, layer_index, map)
        if not type and notEmpty(left, right) and (left <= right) then
          return inverseIndexTransformX(x, mx, map.tilewidth)
        end
      end
    end
  end
  -- If we didn't find a collision point, return nil
  return nil
end

local futureYCollision = function(map, layer_index, dt, ex, ey, wx, wy, vy)
  local layer = map.layers[layer_index]
  local mx = map.offsetx
  local my = map.offsety
  local lx = indexTransformX(ex - wx, mx, map.tilewidth)
  local tx = indexTransformX(ex + wx, mx, map.tilewidth)
  local cx = indexTransformX(ex, mx, map.tilewidth)
  --print("entity", lx, cx, tx)
  if vy < 0 then
    local ty = indexTransformY(ey - wy, my, map.tileheight)
    local fy = indexTransformY(ey - wy + vy * dt, my,
                              map.tileheight)
    local dfy = -indexTransformNoClamp(ey - wy + vy * dt,
                                      my, map.tileheight)
    for y = math.max(1, ty), math.min(fy, layer.height) do
      local cy = layer.height + 1
      local cleft, cright, ctype = retrieveSlope(cx, y, layer_index, map)
      local tile_upper_y = inverseIndexTransformY(y - 1, my, map.tileheight)
      local thin_possible = tile_upper_y <= ey - wy + 1e-4
      if cleft ~= cright and notEmpty(cleft, cright) then
        -- Calculate how far the center position vertically penetrates into the
        -- slope tile, this is done in a normalized measure
        local ty = dfy + indexTransformY(ey - wy + vy * dt,
                                        my, map.tileheight) + 1
        -- Calculate how far the center position horizontally penetrates into
        -- the slope tile, this is done in a normalized measure
        local tx = indexTransformNoClamp(ex, mx, map.tilewidth)
                   - indexTransformX(ex, mx, map.tilewidth) + 1
        -- Calculate the height at which the center collision with the slope is.
        -- Again done in normalize coordinates.
        local d = 1 - (cleft*(1 - tx) + cright*tx) / map.tileheight
        -- If the entity penetrates into the slope -> collision!
        local dy = d + y - 1
        if dfy >= dy then
          return inverseIndexTransformY(d + y - 1, my, map.tileheight)
        else
          return nil
        end
      elseif
        notEmpty(cleft, cright) and
        (not ctype or thin_possible and ctype == "thin")
      then
        cy = y - 1
      end
      -- If center wasn't a slope iterate through the remaining horizontal tiles
      -- We want to find the closest collision point
      for x = math.max(1, lx), math.min(cx - 1, layer.width) do
        --print("left", x, y)
        local left, right, ctype = retrieveSlope(x, y, layer_index, map)
        sy = y - right / map.tileheight
        if
          (not ctype or thin_possible and ctype == "thin")
          and notEmpty(left, right) and left == right and dfy >= sy and cy > sy
        then
          cy = sy
        end
      end
      for x = math.max(cx + 1, lx), math.min(tx, layer.width) do
        --print("right", x, y)
        local left, right, ctype = retrieveSlope(x, y, layer_index, map)
        sy = y - left / map.tileheight
        if
          (not ctype or thin_possible and ctype == "thin")
          and notEmpty(left, right) and left == right and dfy >= sy and cy > sy
        then
          cy = sy
        end
      end
      -- If cy is within the tilegrid, then a colllision point was found
      --print("End", cy)
      if cy < layer.height + 1 then
        return inverseIndexTransformY(cy, my, map.tileheight)
      end
    end
  elseif vy > 0 then
    local ty = indexTransformY(ey + wy, my, map.tileheight)
    local fy = indexTransformY(ey + wy + vy * dt, my,
                              map.tileheight)
    for y = math.min(ty, layer.height), math.max(1, fy), -1 do
      for x = math.max(1, lx), math.min(tx, layer.width) do
        local left, right, type = retrieveSlope(x, y, layer_index, map)
        if not type and notEmpty(left, right) then
          return inverseIndexTransformY(y, my, map.tileheight)
        end
      end
    end
  end

  return nil
end

-- Function which moves an entity along a axis or stops at a collision point
-- This assumes that the entity is axis aligned
--
-- \x0 is the initial position on the axis
-- \wx is the entity's spread/width on the axis, from its position
-- \vx is the entity's velocity
-- \cx is the optional collision on the axis, if this is nil then no collision
-- occurred.
-- \dt is the timestep for the resolution
local resolveFutureX = function(x0, wx, vx, cx, dt)
  local x = x0
  if cx ~= nil then
    -- resolve x collision
    if vx > 0 then
      -- if we are moving right
      -- move entity so that right side touches collision point
      x = (cx - wx)
    elseif vx < 0 then
      -- Next is added a very small factor to ensure that we are outside of
      -- of the collision tile
      x = (cx + wx) + 0.000001
    end
  else
    -- No collison, move entity to destination
    x = x + vx * dt
  end

  return x
end

local resolveFutureY = function(y0, wy, vy, cy, dt)
  local y = y0
  if cy ~= nil then
    -- resolve y collision
    if vy > 0 then
      -- if we are moving right
      -- move entity so that right side touches collision point
      y = (cy - wy) - 0.000001
    elseif vy < 0 then
      -- Next is added a very small factor to ensure that we are outside of
      -- of the collision tile
      y = (cy + wy)
    end
  else
    -- No collison, move entity to destination
    y = y + vy * dt
  end

  return y
end

local time_scale = 1--1.5

function mapAdvanceEntity(map, layer_index, id)
  assert(
    map.layers[layer_index].type == 'tilelayer',
    "Invalid layer type: " .. map.layers[layer_index].type ..
    ". Layer must be of type: tilelayer"
  )

  local dt = system.dt

  local act = gamedata.spatial
  local x = act.x[id]
  local y = act.y[id]
  local vx = act.vx[id]
  local vy = act.vy[id]
  local wx = act.width[id]
  local wy = act.height[id]


  dt = dt * time_scale
  local cx = futureXCollision(map, layer_index, dt, x, y, wx, wy, vx)
  x = resolveFutureX(x, wx, vx, cx, dt)
  -- Resolve and advance velocities
  if cx ~= nil then
    vx = 0
  end
  -- prevent entities from leaving the map
  x = math.max(
    map.offsetx + wx,
    math.min(x, map.offsetx + map.width * map.tilewidth - wx)
  )

  local cy = futureYCollision(map, layer_index, dt, x, y, wx, wy, vy)
  y = resolveFutureY(y, wy, vy, cy, dt)
  if cy ~= nil then
    vy = 0
  end
  --if entity._do_gravity then
  vx = vx + gravity.x * dt -- Acceleration should possibly be here
  vy = vy + gravity.y * dt
  --end

  local mx = indexTransformX(x, map.offsetx, map.tilewidth)
  local my = indexTransformY(y - wy, map.offsety, map.tileheight)
  local left, right = retrieveSlope(mx, my, layer_index, map)
  -- Compensate for weak gravity if currently on a slope
  if left ~= right and notEmpty(left, right) and vy <= 0 then
    local scale = 1.01 * (left - right) / map.tilewidth
    vy = math.min(vy, -math.abs(vx * scale))
  end

  --if  (cx ~= nil or cy ~= nil) and entity.mapCollisionCallback ~= nil then
  --if entity.mapCollisionCallback then
  --  entity.mapCollisionCallback(entity, map, collisionMap, cx, cy)
  --end

  return x, y, vx, vy, cx, cy
end

--Iterates through all tilesets in a tiled map and populates them with left
--and right members if the tile properties contain these.
--They will be parse as being a number for a bit faster processing in realtime
--movement.
function generateCollisionMap(map, layer_index)
  layer = map.layers[layer_index]

  if layer == nil then
    return nil
  end

  local collisionMap = {}
  collisionMap.width = layer.width
  collisionMap.height = layer.height
  for y = 1, layer.height do
    collisionMap[y] = {}
    for x = 1, layer.width do
      collisionMap[y][x] = {}
      local left, right = retrieveSlope(x, y, layer, map)
      collisionMap[y][x].left = left
      collisionMap[y][x].right = right
    end
  end

  return collisionMap
end

local function layer_iterate(map, layer, x_low, x_up, y_low, y_up, func)
  local xl = indexTransformX(x_low, map.offsetx, map.tilewidth)
  local xu = indexTransformX(x_up, map.offsetx, map.tilewidth)
  local yl = indexTransformY(y_low, map.offsety, map.tileheight)
  local yu = indexTransformY(y_up, map.offsety, map.tileheight)

  xl = math.max(1, xl)
  xu = math.min(map.layers[layer].width, xu)
  yl = math.max(1, yl)
  yu = math.min(map.layers[layer].height, yu)

  --print(xl, xu, yl, yu)
  for x = xl, xu do
    for y = yl, yu do
      func(map, layer, x, y)
    end
  end
end

tilemap = {}
function tilemap.all_of_type(map, layer, x_low, x_up, y_low, y_up, type)
  local all_good = true
  local function f(map, layer, x, y)
    local r, l, ctype = retrieveSlope(x, y, layer, map)
    all_good = all_good and (ctype == type or not notEmpty(r, l))
  end
  layer_iterate(map, layer, x_low, x_up, y_low, y_up, f)
  return all_good
end
