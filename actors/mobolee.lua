actor = actor or {}
loaders = loaders or {}

local ims = {
  hit = "res/mobolee/hit.png",
  idle = "res/mobolee/idle.png",
  prehit = "res/mobolee/prehit.png",
  walk = "res/mobolee/walk.png",
}

local w = 6
local h = 12

local walkspeed = 25
local prehittime = 0.4
local hittime = 0.2
local hitframes = 4
local hitframetime = hittime / hitframes

local psearch = {
  w = 300, h = 200
}
local followthreshold = 2
local phit = {
  w = 30, h = 30
}

loaders.mobolee = function(gamedata)
  for _, path in pairs(ims) do
    gamedata.visual.images[path] = loadspriteimage(path)
  end
end

local createidledrawer = function(gamedata)
  local im = gamedata.visual.images[ims.idle]
  return misc.createrepeatdrawer(
    newAnimation(im, 48, 48, 0.4, 2)
  )
end
local createwalkdrawer = function(gamedata)
  local im = gamedata.visual.images[ims.walk]
  return misc.createrepeatdrawer(
    newAnimation(im, 48, 48, 0.2, 0)
  )
end
local createprehitdrawer = function(gamedata)
  local im = gamedata.visual.images[ims.prehit]
  local frames = 4
  local frametime = prehittime / frames
  return misc.createoneshotdrawer(
    newAnimation(im, 48, 48, frametime, frames)
  )
end
local createhitdrawer = function(gamedata)
  local im = gamedata.visual.images[ims.hit]
  return misc.createoneshotdrawer(
    newAnimation(im, 48, 48, hitframetime, hitframes)
  )
end

-- Control states
local idle = {}
local hit = {}
local follow = {}

idle.begin = function(gamedata, id)
  gamedata.visual.drawers[id] = createidledrawer(gamedata)
  local entity = gamedata.entity[id]
  entity.vx = 0
  return idle.run(gamedata, id)
end

idle.run = function(gamedata, id)
  coroutine.yield()
  local t = gamedata.target[id]
  local h = gamedata.message[id].hit
  if h then
    if hit.ready(gamedata, id) then return hit.run(gamedata, id) end
    gamedata.message[id].hit = nil
  end
  if t and not h then return follow.begin(gamedata, id) end
  return idle.run(gamedata, id)
end

follow.begin = function(gamedata, id)
  gamedata.visual.drawers[id] = createwalkdrawer(gamedata)
  return follow.run(gamedata, id)
end

follow.run = function(gamedata, id)
  local h = gamedata.message[id].hit
  if h then
    if hit.ready(gamedata, id) then return hit.run(gamedata, id) end
    gamedata.message[id].hit = nil
    return idle.begin(gamedata, id)
  end
  local t = gamedata.target[id]
  if not t then return idle.begin(gamedata, id) end
  gamedata.target[id] = nil
  local entity = gamedata.entity[id]
  local s = t.x - entity.x
  if s < 0 then
    gamedata.face[id] = "left"
    entity.vx = -walkspeed
  else
    gamedata.face[id] = "right"
    entity.vx = walkspeed
  end
  coroutine.yield()
  return follow.run(gamedata, id)
end

hit.ready = function(gamedata, id)
  local ustam = gamedata.usedstamina[id] or 0
  local mstam = gamedata.stamina[id]
  return math.ceil(ustam) < mstam
end

hit.run = function(gamedata, id)
  local entity = gamedata.entity[id]
  entity.vx = 0
  local h = gamedata.message[id].hit
  if h.x - entity.x > 0 then
    gamedata.face[id] = "right"
  else
    gamedata.face[id] = "left"
  end
  gamedata.visual.drawers[id] = createprehitdrawer(gamedata)
  local prehittimer = misc.createtimer(gamedata.system.time, prehittime)
  while prehittimer(gamedata.system.time) do
    coroutine.yield()
  end
  gamedata.visual.drawers[id] = createhitdrawer(gamedata)
  local passivetimer = misc.createtimer(
    gamedata.system.time, hitframetime * 2
  )
  while passivetimer(gamedata.system.time) do
    coroutine.yield()
  end
  local dmgfunc = combat.singledamagecall(
    function(this, other)
      if other.applydamage then other.applydamage(this.id, 0, 0, 1) end
      return this, other
    end
  )
  gamedata.hitbox[id].hit = coolision.newAxisBox(
    id, 0, 0, 14, 24, nil, gamedata.hitboxtypes.allybody,
    dmgfunc
  )
  gamedata.hitboxsync[id].hit = {x = 2, y = 14}
  local activetimer = misc.createtimer(
    gamedata.system.time, hitframetime * 2
  )
  while activetimer(gamedata.system.time) do
    coroutine.yield()
  end
  gamedata.hitbox[id].hit = nil
  gamedata.hitboxsync[id].hit = nil
  gamedata.message[id].hit = nil
  gamedata.usedstamina[id] = (gamedata.usedstamina[id] or 0) + 1
  return idle.begin(gamedata, id)
end

local init = function(gamedata)
  return idle.begin
end

actor.mobolee = function(gamedata, id, x, y)
  gamedata.actor[id] = "mobolee"
  gamedata.entity[id] = newEntity(x, y, w, h)
  gamedata.face[id] = "right"
  gamedata.control[id] = coroutine.create(init(gamedata))
  gamedata.message[id] = {}
  gamedata.stamina[id] = 1
  gamedata.hitbox[id] = {
    playersearch = coolision.newAxisBox(
      id, x - psearch.w, y + psearch.h, psearch.w,
      psearch.h, nil, gamedata.hitboxtypes.allybody,
      function(this, other)
        gamedata.target[id] = {
          x = other.x + other.w * 0.5, y = other.y - other.h * 0.5
        }
      end
    ),
    playerhit = coolision.newAxisBox(
      id, x, y, phit.w, phit.h, nil, gamedata.hitboxtypes.allybody,
      function(this, other)
        gamedata.message[id].hit = {
          x = other.x + other.w * 0.5, y = other.y - other.h * 0.5
        }
      end
    ),
    body = coolision.newAxisBox(
      id, x, y, w * 2, h * 2, gamedata.hitboxtypes.enemybody
    )
  }
  gamedata.hitboxsync[id] = {
    playersearch = {x = -psearch.w * 0.5, y = psearch.h * 0.5},
    playerhit = {x = -phit.w * 0.5, y = phit.h * 0.5}
  }
end