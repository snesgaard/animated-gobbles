local event = require "combat/event"
local common = require "combat/ui/common"
local theme = require "combat/ui/theme"

local screen_suit = common.screen_suit

local DEFINE = {
  WAIT_TIME = 0.2,
  WIDTH = 100,
  HEIGHT = 100,
  DY = -100,
  SPEED = 100,
  ID = 1,
  THEME = {
    DAMAGE = {
      normal = {
        bg = {255, 255, 255}, fg = theme.health.low
      }
    }
  }
}

local draw = {}

function draw.damage(_, opt, x, y, w, h)
  screen_suit.theme.Label(opt.dmg, opt, x, y, w, h)
end

local function animate_icon(dt, x, y, opt)
  local dummyid = DEFINE.ID
  local state = {
    x = {[dummyid] = x},
    y = {[dummyid] = y},
    terminate = false
  }

  local mover = coroutine.wrap(function(dt)
    combat.visual.move_to(dummyid, x, y + DEFINE.DY, DEFINE.SPEED, dt, state)
    state.terminate = true
  end)
  while not state.terminate do
    screen_suit:Label(
      "smorc", opt, state.x[dummyid], state.y[dummyid], DEFINE.WIDTH, DEFINE.HEIGHT
    )
    mover(dt)
    dt = coroutine.yield()
  end
end

local function add_to_pool(dt, visual_pool, x, y, opt)
  visual_pool:run(animate_icon, x, y, opt)
  combat.visual.wait(DEFINE.WAIT_TIME, dt)
end

return function(dt)
  local handler_pool = lambda_pool.new()
  local visual_pool = lambda_pool.new()
  local tokens = {}
  tokens.damage = signal.merge(
    signal.type(event.core.character.damage)
      .map(function(id, damage)
        return id, {
          align = "center",
          draw = draw.damage,
          color = DEFINE.THEME.DAMAGE,
          dmg = damage,
          font = common.font.s35
        }
      end)
  ).listen(function(id, opt)
    return function()
      local x = gamedata.spatial.x[id]
      local y = gamedata.spatial.y[id]
      local w = gamedata.spatial.width[id]
      local h = gamedata.spatial.height[id]
      x, y = camera.transform(camera_id, level, x, y + h)
      x = x - DEFINE.WIDTH * 0.5
      y = y - DEFINE.HEIGHT * 0.75
      handler_pool:queue(id, add_to_pool, visual_pool, x, y, opt)
    end
  end)

  while true do
    for _, t in pairs(tokens) do t() end
    handler_pool:update(dt)
    visual_pool:update(dt)
    dt = coroutine.yield()
  end
end
