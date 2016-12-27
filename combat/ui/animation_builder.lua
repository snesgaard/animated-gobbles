local function visualizer(effects)
  return function()
    map(function(e) map(function(f) f() end, e) end, effects)
  end
end

local _animation_generator = {}
function _animation_generator.default(_, _, all_effects)
  return function(dt)
    for name, named_effect in pairs(all_effects) do
      for _, effect in pairs(named_effect) do
        print(effect, effect.effect, name)
        for _, e in pairs(effect.effect) do
          map(function(f) return f() end, e)
        end
      end
    end
  end
end

function _animation_generator.projectile(user, visual_data, all_effects)
  local projectiles = queue.new()
  local post_impact = {}

  local function create_projectile(effect)
    projectiles:push(
      combat.visual.projectile(
        user, effect.arg.target, visualizer(effect.effect),
        visual_data
      )
    )
  end
  local function create_post(effect)
    table.insert(post_impact, visualizer(effect.effect))
  end

  local projectile_handlers = {
    random = create_projectile,
    single = create_projectile,
    all = create_projectile,
    personal = create_post,
  }

  for name, named_effect in pairs(all_effects) do
    local h = projectile_handlers[name]
    if h then
      for _, effect in pairs(named_effect) do h(effect) end
    end
  end
  return function(dt)
    local pool = lambda_pool.new()
    repeat
      local next = projectiles:pop()
      pool:run(next)
      local time = 0.25
      while time > 0 do
        pool:update(dt)
        time = time - dt
        dt = coroutine.yield()
      end
    until projectiles:empty()
    while not pool:empty() do
      pool:update(dt)
      dt = coroutine.yield()
    end
    for _, p in pairs(post_impact) do p() end
  end
  --return combat.visual.projectile(
  --  arg.user, arg.target, effect_visualizers, visual_data
  --)
end

return function(userid, visual_data, effects)
  local key = nil
  if not visual_data or not visual_data.animation then
    key = "default"
  end
  local type = key or visual_data.animation.type
  local gen = _animation_generator[type or "default"]
  local play = effects.play or {}
  effects.play = nil
  local anime = gen(userid, visual_data, effects)
  return function(dt)
    for _, effect in pairs(play) do
      for _, e in pairs(effect.effect) do
        map(function(f) return f() end, e)
      end
    end
    anime(dt)
  end
end
