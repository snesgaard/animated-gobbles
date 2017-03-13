local event = require "combat/event"
local lambda_pool = require "lambda_pool"
local sprite = require "sprite"
local proj = require "combat/animation/projectile"

local card_data = {
  cost = 1,
  name = "Potion",
  image = "potion",
  play = {
    single = {
      heal = 4
    }
  }
}

function card_data.play.text_compiler(data)
  return string.format("Heal a character for %i.", data.single.heal)
end

local function projectile(dt, ix, iy, fx, fy, time, on_impact)
  local state = {x = ix, y = iy, r = 0}
  local pool = lambda_pool.new()

  local ty = -100
  local deg = {
    a = 2 * iy + 2 * fy - 4 * ty,
    b = -3 * iy - fy + 4 * ty,
    c = iy,
  }
  pool:run("move", util.lerp, time, function(t)
    state.x = ix * (1 - t) + fx * t
    state.y = deg.a * t * t + deg.b * t + deg.c
    state.r = t * 10
  end)
  -- HACK: Temporary effect
  local sheet, anime = prop.get_resource()
  pool:run(
    sprite.cycle, {suit = sprite.suit.projectile}, sheet, anime.potion_red,
    function() return state.x, state.y, state.r end
  )
  
  while pool:status("move") do
    pool:update(dt)
--    print(state.x, state.y)
    dt = coroutine.yield()
  end
  on_impact()
end

function card_data.play.animate(dt, engine, cb_effects)
  local user = cb_effects.single[1].user
  local target = cb_effects.single[1].target
  local pool = lambda_pool.new()

  local idle_anime = gamedata.visual.idle[user]
  local throw_anime = gamedata.visual.throw[user]

  local sheet, anime = prop.get_resource()

  local token = signal.type(event.hitbox.appear)
    .filter(function(id) return id == 0xff0000 end)
    .listen(function(_, x, y, w, h)
      pool:run(
        function(...)
          proj.ballistic(...)
          for _, effect_list in pairs(cb_effects) do
            for _, effect in pairs(effect_list) do
              effect.callbacks()
            end
          end
        end,
        x, y, gamedata.spatial.x[target], gamedata.spatial.y[target], 0.5,
        sheet, anime.potion_red
      )
    end)

  engine.pool.sprite:run(user, function(dt)
    local s = sprite.entity_center(user)
    dt = throw_anime(dt, s)
    idle_anime(dt, s)
  end)

  while pool:empty() do
    token()
    pool:update(dt)
    dt = coroutine.yield()
  end
  while not pool:empty() do
    pool:update(dt)
    dt = coroutine.yield()
  end
  return dt
end

cards.potion = card_data
