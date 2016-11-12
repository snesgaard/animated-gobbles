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

function combat.visual.move_arch(id, tx, ty, time, gravity, dt)
  local gy = gravity
  local ux = gamedata.spatial.x[id]
  local uy = gamedata.spatial.y[id]
  local vx = (tx - ux) / time
  local vy = (ty - uy) / time - time * gy * 0.5
  local t = 0
  while t + dt < time do
    t = t + dt
    gamedata.spatial.x[id] = vx * t + ux
    gamedata.spatial.y[id] = gy * t * t * 0.5 + vy * t + uy
    dt = coroutine.yield()
  end
  gamedata.spatial.x[id] = tx
  gamedata.spatial.y[id] = ty
end

function combat.visual.health_ui_updater(id)
  local health = gamedata.combat.health[id]
  local damage = gamedata.combat.damage[id]
  return function() combat_engine.update_health_ui(id, health, damage) end
end

function combat.visual.melee_attack(
  userid, targetid, effect
)
  return function(dt)
    local ux = gamedata.spatial.x[userid]
    local uy = gamedata.spatial.y[userid]
    local tx = gamedata.spatial.x[targetid]
    local ty = gamedata.spatial.y[targetid]
    -- Update animation to movement
    combat.visual.move_to(userid, tx, uy, 700, dt)
    -- Update animation to hit
    -- Display damage number
    -- Update enemy animation to hurt
    --combat_engine.update_health_ui(targetid, health, damage)
    --combat.visual.damage_number(tx, ty + th, attack)
    if effect then effect() end
    -- Update animation to back-movement
    combat.visual.move_to(userid, ux, uy, 500, dt)
  end
end

function combat.visual.projectile(
  userid, targetid, effect, visual_data
)
  return function(dt)
    local ux = gamedata.spatial.x[userid]
    local uy = gamedata.spatial.y[userid]
    local uw = gamedata.spatial.width[userid]
    local uh = gamedata.spatial.height[userid]
    local tx = gamedata.spatial.x[targetid]
    local ty = gamedata.spatial.y[targetid]
    local tw = gamedata.spatial.width[targetid]
    local th = gamedata.spatial.height[targetid]
    local pid = allocresource(gamedata)
    gamedata.spatial.x[pid] = ux + uw
    gamedata.spatial.y[pid] = uy + uh
    local pid_draw = "_projectile_draw"
    local draw_func = function()
      local x = gamedata.spatial.x[pid]
      local y = gamedata.spatial.y[pid]
      gfx.setColor(255, 255, 0)
      gfx.rectangle("fill", x, -y, 10, 10)
      gfx.setColor(255, 255, 255)
    end
    -- TODO: Play characters throw animation!
    draw_engine.foreground[pid] = draw_engine.create_primitive(
      draw_func, true, false, true
    )
    local function prehit()
      local gy = visual_data.projectile.gravity
      local time = visual_data.projectile.time
      --combat.visual.move_to(pid, tx, ty, speed, dt)
      combat.visual.move_arch(pid, tx, ty, time, gy, dt)
    end
    prehit()
    if effect then effect() end
    -- Define possible posthit behaviours
    local posthit_funcs = {}
    function posthit_funcs.bounce(visual_data)
      local time = visual_data.time
      local gy = visual_data.gravity
      -- TODO: Set potential for diffirent PDFs
      local rng = love.math.random
      local range = visual_data.range or {0, 0}
      local dx = rng() * (range[2] - range[1]) + range[1]
      -- TODO: Replace y coordinate with floor define
      combat.visual.move_arch(pid, tx + dx, ty - 20, time, gy, dt)
    end
    -- Select defined type and execute
    lambda.run(function()
      local posthit = posthit_funcs[visual_data.on_hit.type]
      if posthit then posthit(visual_data.on_hit) end
      draw_engine.foreground[pid] = nil
      freeresource(gamedata, pid)
    end)
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
