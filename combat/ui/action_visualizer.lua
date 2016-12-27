local event = require "combat/event"
local textbox = require "combat/ui/text_box"
local theme = require "combat/ui/theme"
local common = require "combat/ui/common"

local screen_suit = common.screen_suit

local DEFINE = {
  min_card_time = 1.0
}

local function visualizer(effects)
  return function() for _, e in pairs(effects) do e() end end
end

local function show_card(user, card)
  local name = gamedata.card.name[card]
  local themes = {
    [combat_engine.DEFINE.FACTION.ENEMY] = theme.enemy,
    [combat_engine.DEFINE.FACTION.PLAYER] = theme.player,
  }
  local faction = combat_engine.faction(user)
  return function()
    screen_suit.layout:reset(800, 25)
    screen_suit:Label(
      name, {
        draw = ui.draw_text_box,
        font = combat_engine.resource.pick_font,
        color = themes[faction]
      },
      screen_suit.layout:row(300, 50)
    )
  end
end

local _animation_generator = {}
function _animation_generator.default(_, arg, all_effects)
  return function(dt)
    for name, named_effect in pairs(all_effects) do
      for _, effect in pairs(named_effect) do
        for _, e in pairs(effect.effect) do
          e()
        end
      end
    end
  end
end

function _animation_generator.projectile(visual_data, arg, all_effects)
  local projectiles = queue.new()
  local post_impact = {}

  local function create_projectile(effect)
    projectiles:push(
      combat.visual.projectile(
        arg.user, effect.target, visualizer(effect.effect), visual_data
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

function _new_effect_builder()
  return {
    effect = {},
    type = nil,
    target = nil,
  }
end

return function(dt)
  local state = {
    effect_builder = _new_effect_builder(),
    effect = {}
  }
  local tokens = {}
  -- Handler for registering completed effects
  tokens[1] = signal.merge(
    signal.type(event.core.action.start), signal.type(event.core.card.play),
    signal.type(event.core.action.stop)
  ) .filter(function()
      return #state.effect_builder.effect > 0
    end)
    .listen(function()
      local eb = state.effect_builder
      local effect_list = state.effect[eb.type] or {}
      table.insert(effect_list, eb)
      state.effect[eb.type] = effect_list
      state.effect_builder = _new_effect_builder()
    end)
  -- Registers type and target for new effect series
  tokens[2] = signal.type(event.core.action.start)
    .listen(function(name, arg)
      state.effect_builder.type = name
      state.effect_builder.target = arg.target
    end)
  -- Puts effect callback onto stack
  tokens[3] = signal.type(event.visual.effect)
    .listen(function(f)
      table.insert(state.effect_builder.effect, f)
    end)
  -- Registers card play and executes proper visualization
  tokens[4] = signal.type(event.core.card.play)
    .listen(function(userid, cardid, targetid)
      -- Fetch added play callbacks and make visualizzer function
      local all_effects = state.effect
      state.effect = {}
      -- Fetch data concerning visualization of card play
      local effects = gamedata.card.effect[cardid]
      local data = effects.play
      local animation_generator = _animation_generator.default
      if data.visual then
        local gen = _animation_generator[data.visual.animation.type]
        animation_generator = gen or animation_generator
      end
      -- Build the animation sequence

      -- If generator no available just execute the visualization
      local sf = show_card(userid, cardid)
      local seq = animation_generator(
        data.visual, {user = userid, target = targetid}, all_effects
      )
      local faction = combat_engine.faction(userid)
      if faction == "player" then
        combat_engine.add_event(function()
          local state = {terminate = false}
          lambda.run(function(dt, state)
            seq(dt)
            state.terminate = true
          end, state)
          while not state.terminate do
            sf()
            coroutine.yield()
          end
        end)
      else
        combat_engine.add_event(function(dt)
          local pool = lambda_pool.new()

          local state = {terminate = false}
          local proc = {}
          function proc.card_enter(dt)
            gamedata.spatial.x[cardid] = 850
            gamedata.spatial.y[cardid] = -325
            combat.visual.move_to(cardid, 850, 25, 1000, dt)
            return proc.seq(dt)
          end
          function proc.card_exit(dt)
            combat.visual.move_to(cardid, 850, -325, 1000, dt)
            combat.visual.wait(0.25, dt)
            state.terminate = true
          end
          function proc.seq(dt)
            local ts = love.timer.getTime()
            seq(dt)
            local te = love.timer.getTime()
            combat.visual.wait(DEFINE.min_card_time - te + ts, dt)
            return proc.card_exit(dt)
          end
          pool:run(proc.card_enter)
          pool:run(function(dt)
            local time = 1.0
            --while not state.terminate do
            repeat
              coroutine.yield()
              cards.render(cardid)
              common.render_marker(userid, theme.player)
            until state.terminate
            --end
          end)
          --while not pool:empty() do
          --  pool:update(dt)
          --  dt = coroutine.yield()
          --end
          pool:update(dt)
          repeat
            dt = coroutine.yield()
            pool:update(dt)
          until pool:empty()
        end)
      end
    end)
  tokens[5] = signal.type(event.core.action.stop)
    .listen(function(userid, visualdata, target)
      -- Fetch added play callbacks and make visualizzer function
      local all_effects = state.effect
      state.effect = {}
      -- TODO: use visual data
      local animation_generator = _animation_generator.default
      combat_engine.add_event(
        animation_generator(
          visualdata, {user = userid, target = targetid}, all_effects
        )
      )
    end)

  while true do
    for _, t in ipairs(tokens) do t() end
    coroutine.yield()
  end
end
