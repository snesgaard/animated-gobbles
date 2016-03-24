local gfx = love.graphics

local atlas
local animid

lantern_A = {}

function lantern_A.flicker(id, freq, phase)
  local function f(id)
    local p = freq * system.time + phase
    local sinp = math.sin(p)
    local cosp = math.cos(p)
    gamedata.spatial.width[id] = 100 + sinp * 7
    cosp = math.abs(cosp)
    sinp = math.abs(sinp)
    local s = cosp + sinp
    gamedata.radiometry.color[id] = {
      (243 * cosp + sinp * 195) / s,
      (156 * cosp + sinp * 119) / s,
      (31 * cosp + sinp * 10) / s,
    }
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

function lantern_A.draw()
  local anime = animation.draw(atlas, animid, 0.75)
  local spatial = gamedata.spatial
  local function f(id)
    animation.entitydraw(id, anime)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

function loader.lantern_A()
  local im = gfx.newImage("resource/sheet/lantern.png")
  atlas = initresource(resource.atlas, function(at, id)
    at.color[id] = gfx.newSpriteBatch(im, 200, "stream")
  end)
  local index = {x = 0, y = 0, w = im:getWidth(), h = im:getHeight()}
  animid = initresource(
    resource.animation, animation.init, im, index, 5, 8, 11
  )
end

function init.lantern_A(gd, id, x, y)
  local spatial = gd.spatial
  spatial.x[id] = x
  spatial.y[id] = y
  spatial.width[id] = 100

  local rng = love.math.random
  gd.ai.control[id] = lantern_A.flicker(id, rng() + 1, rng() * math.pi * 0.5)

  local radiometry = gd.radiometry
  radiometry.color[id] = {243, 156, 31}
  radiometry.draw[id] = lantern_A.draw()

  tag.point_light[id] = true
  tag.background[id] = true
end

function parser.lantern_A(obj)
  local x = math.floor(obj.x + obj.width * 0.5)
  local y = math.floor(-obj.y + obj.height * 0.5)
  return x, y
end
