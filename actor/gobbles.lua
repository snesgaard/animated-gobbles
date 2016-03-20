require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 75
local jumpspeed = 100

local anime = {}
local hitbox = {}

local key = {
  left = "left",
  right = "right",
  runtoggle = "lalt",
  jump = "space"
}

local _do_action = do_action
local do_action = function(gd, id, col, com)
  local supercol
  if col then
    supercol = function(gd, id)
      local r = col(gd, id)
      table.insert(r, hitbox.body)
      return r
    end
  else
    supercol = function(gd, id)
      return {hitbox.body}
    end
  end
  _do_action(gd, id, supercol, com)
end


local action = {}
local control = {}

function action.idle(gamedata, id)
  while true do
    gamedata.actor.draw[id] = animation.draw(
      gamedata, "gobbles", anime.idle, 0.75, "repeat"
    )
    while math.abs(gamedata.actor.vx[id]) < 1 do
      do_action(gamedata, id)
      coroutine.yield()
    end
    local select_draw = coroutine.create(function(vx)
      while true do
        gamedata.actor.draw[id] = animation.draw(
          gamedata, "gobbles", anime.walk, 1.0, "repeat"
        )
        while vx == walkspeed do
          vx = coroutine.yield()
        end
        gamedata.actor.draw[id] = animation.draw(
          gamedata, "gobbles", anime.run, 0.75, "repeat"
        )
        while vx == runspeed do
          vx = coroutine.yield()
        end
      end
    end)
    while math.abs(gamedata.actor.vx[id]) > 1 do
      coroutine.resume(select_draw, math.abs(gamedata.actor.vx[id]))
      do_action(gamedata, id)
      coroutine.yield()
    end
  end
end

function action.airidle(gamedata, id)
  while true do
    gamedata.actor.draw[id] = animation.draw(
      gamedata, "gobbles", anime.ascend, 0.3, "repeat"
    )
    while gamedata.actor.vy[id] >= 0 do
      do_action(gamedata, id)
      coroutine.yield()
    end
    gamedata.actor.draw[id] = animation.draw(
      gamedata, "gobbles", anime.descend, 0.3, "repeat"
    )
    while gamedata.actor.vy[id] < 0 do
      do_action(gamedata, id)
      coroutine.yield()
    end
  end
end

function control.idle(gd, id, fd)
  gd.actor.action[id] = coroutine.create(action.idle)
  local speed = walkspeed
  while on_ground(gd, id) do
    -- Check for jump
    local j = input.isdown(gd, key.jump)
    if j then
      input.latch(gd, key.jump)
      gd.actor.ground[id] = nil
      gd.actor.vy[id] = jumpspeed
      return control.arial(gd, id ,fd)
    end
    -- Normal movement control
    local rd = input.isdown(gd, key.right)
    local ld = input.isdown(gd, key.left)
    local p = gd.system.pressed
    local gr = (p[key.right] or 0) > (p[key.left] or 0)
    local rt = input.ispressed(gd, key.runtoggle)
    if rt and (rd or ld) then
      input.latch(gd, key.runtoggle)
      if speed > walkspeed then
        speed = walkspeed
      else
        speed = runspeed
      end
    end
    if not rd and not ld then
      gd.actor.vx[id] = 0
      speed = walkspeed
    elseif rd and (not ld or gr) then
      gd.actor.face[id] = 1
      gd.actor.vx[id] = speed
    elseif ld then
      gd.actor.face[id] = -1
      gd.actor.vx[id] = -speed
    end
    gd, id, fd = coroutine.yield()
  end
  return control.arial(gd, id, fd)
end

function control.arial(gd, id, fd)
  gd.actor.action[id] = coroutine.create(action.airidle)
  while not on_ground(gd, id) do
    gd, id, fd = coroutine.yield()
  end
  return control.idle(gd, id, fd)
end

function loader.gobbles(gamedata)
  -- Initialize animations
  local sheet = love.graphics.newImage("resource/sheet/gobbles.png")
  gamedata.resource.atlas.gobbles = love.graphics.newSpriteBatch(
    sheet, 200, "stream"
  )
  local index = require "resource/sheet/gobbles"
  local function initanime(key, frames, ox, oy)
    anime[key] = initresource(
      gamedata.animations, animation.init, sheet, index[key], frames, ox, oy,
      true
    )
  end
  initanime("idle", 4, 15, 22)
  initanime("walk", 10, 16, 22)
  initanime("run", 8, 17, 22)
  initanime("descend", 4, 15, 21)
  initanime("ascend", 4, 15, 22)
  -- Load normal map
  local nmap = love.graphics.newImage("resource/sheet/gobbles_nmap.png")
  gamedata.resource.images.gobbles_normals = nmap
  --nmap:setFilter("linear", "linear")
  -- Initialize hitboxes
  hitbox = {
    body = initresource(
      gamedata.hitbox, coolision.createaxisbox, -width, -height, width * 2,
      height * 2, gamedata.hitboxtypes.allybody
    )
  }
end

function actor.gobbles(gamedata, x, y)
  local id = initresource(gamedata.actor, function(act, id)
    act.x[id] = x
    act.y[id] = y
    act.width[id] = width
    act.height[id] = height
    act.vx[id] = 0
    act.vy[id] = 0
    act.face[id] = 1

    act.control[id] = coroutine.create(control.idle)
    act.action[id] = coroutine.create(action.idle)
  end)
  return id
end
