require "util"

local spatial = gamedata.spatial

combat = combat or {}
combat.visual = {}


function combat.visual.move_to(id, x, y, speed, dt)
  dt = dt or 0
  local dx = x - spatial.x[id]
  local dy = y - spatial.y[id]
  local l = math.sqrt(dx * dx + dy * dy)
  if l < 1e-5 then
    spatial.x[id] = x
    spatial.y[id] = y
    return
  end
  dx = dx / l
  dy = dy / l
  local function terminate()
    local d1 = math.dot(dx, dy, x, y)
    local d2 = math.dot(dx, dy, spatial.x[id], spatial.y[id])
    return d1 <= d2
  end
  spatial.x[id] = spatial.x[id] + dx * speed * dt
  spatial.y[id] = spatial.y[id] + dy * speed * dt
  while not terminate() do
    dt = coroutine.yield()
    spatial.x[id] = spatial.x[id] + dx * speed * dt
    spatial.y[id] = spatial.y[id] + dy * speed * dt
  end
  spatial.x[id] = x
  spatial.y[id] = y
end

function combat.visual.health_ui_updater(id)
  local health = gamedata.combat.health[id]
  local damage = gamedata.combat.damage[id]
  return function() combat_engine.update_health_ui(id, health, damage) end
end

function combat.visual.melee_attack(
  userid, targetid, attack
)
  local health = gamedata.combat.health[targetid]
  local damage = gamedata.combat.damage[targetid] or 0
  return function(dt)
    local ux = gamedata.spatial.x[userid]
    local uy = gamedata.spatial.y[userid]
    local tx = gamedata.spatial.x[targetid]
    local ty = gamedata.spatial.y[targetid]
    local th = gamedata.spatial.height[targetid]
    -- Update animation to movement
    combat.visual.move_to(userid, tx, uy, 700, dt)
    -- Update animation to hit
    -- Display damage number
    -- Update enemy animation to hurt
    combat_engine.update_health_ui(targetid, health, damage)
    combat.visual.damage_number(tx, ty + th, attack)
    -- Update animation to back-movement
    combat.visual.move_to(userid, ux, uy, 500, dt)
  end
end

function combat.visual.damage_number(x, y, damage)
  local suit = combat_engine.resource.suit.world
  local str = "" .. damage
  local opt = {
    font = combat_engine.resource.pick_font,
    color = {
      normal = {
        bg = {255, 255, 255}, fg = combat_engine.resource.theme.health.low
      }
    }
  }
  local id = allocresource(gamedata)
  x, y = camera.transform(camera_id, level, x, y)
  gamedata.spatial.x[id] = x
  gamedata.spatial.y[id] = y
  local token = {}
  local function _movement(dt)
    combat.visual.move_to(id, x, y - 100, 100, dt)
    token.terminate = true
    freeresource(gamedata, id)
  end
  local function _run(dt, str, opt)
    if token.terminate then return end
    local x = spatial.x[id]
    local y = spatial.y[id]
    local w = 100
    local h = 100
    suit:Label(str, opt, x - w / 2, y - h / 2, 100, 100)
    return _run(coroutine.yield())
  end
  lambda.run(_run, str, opt)
  lambda.run(_movement)
end
