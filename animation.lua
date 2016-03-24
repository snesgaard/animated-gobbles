require "math"

animation = {}

function animation.init(anime, id, im, index, frames, ox, oy, normal_hack)
  anime.quads[id] = {}
  local x = index.x
  local y = index.y
  local w = index.w
  local h = index.h
  local fw = w / frames
  for i = 1, frames do
    local q = love.graphics.newQuad(
      x + fw * (i - 1), y, fw, h, im:getDimensions()
    )
    table.insert(anime.quads[id], q)
  end
  anime.width[id] = fw
  anime.height[id] = h
  anime.x[id] = ox or 0
  anime.y[id] = oy or 0
  anime.normals[id] = normal_hack or false
end

function animation.draw(atid, anid, time, type, from, to)
  local atlas = resource.atlas.color[atid]
  local anime = resource.animation

  type = type or "repeat"
  from = from or 1
  to = to or #anime.quads[anid]
  local ox = anime.x[anid]
  local oy = anime.y[anid]
  local nh = anime.normals[anid]

  local i = from
  local dir = 1
  local border
  local ft
  if type == "repeat" then
    border = function(i, dir)
      return from, 1
    end
    ft = time / (to - from + 1)
  elseif type == "bounce" then
    border = function(i, dir)
      if dir == 1 then
        return math.max(from, to - 1), -1
      else
        return math.min(from + 1, to), 1
      end
    end
    ft = time / (to - from) * 0.5
  elseif type == "once" then
    border = function(i, dir)
      return to, 0
    end
    ft = time / (to - from + 1)
  end

  local f = function(dt, x, y, r, sx, sy)
    local t = ft
    while true do
      while t > 0 do
        t = t - dt
        --x = math.floor(x - sx * ox)
        --y = math.floor(y - sy * oy)
        x = x - sx * ox
        y = y - sy * oy
        -- HACK
        local a = (sx > 0 or not nh) and 1 or -1
        atlas:setColor(255, 255, 255, 255 * a)
        atlas:add(anime.quads[anid][i], x, y, r, sx, sy)
        dt, x, y, r, sx, sy = coroutine.yield()
      end
      t = ft + t
      i = i + dir
      if i > to or i < from then
         i, dir = border(i, dir)
      end
    end
  end
  return coroutine.create(f)
end

function animation.entitydraw(id, co)
  local act = gamedata.spatial
  local x = act.x[id]
  local y = act.y[id]
  local f = act.face[id] or 1
  return coroutine.resume(co, system.dt, x, -y, 0, f, 1)
end

function animation.entitydrawer(id, ...)
  local anime = animation.draw(...)
  local function f(id)
    animation.entitydraw(id, anime)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

return animation
