combat = combat or {}

local _visual_generator = {}
local _effect_generator = {}

function _effect_generator.damage(value)
  return function(arg)
    local id = arg.target
    gamedata.combat.damage[id] = (gamedata.combat.damage[id] or 0) + value
    return value
  end
end
function _visual_generator.damage(arg, outcome)
  local id = arg.target
  local ui_updater = combat.visual.health_ui_updater(id)
  local damage = unpack(outcome)
  return function()
    ui_updater()
    local x = gamedata.spatial.x[id]
    local y = gamedata.spatial.y[id]
    local h = gamedata.spatial.height[id] or 0
    combat.visual.damage_number(x, y + h, damage)
  end
end

function _effect_generator.heal(value)
  return function(arg)
    local id = arg.target
    if gamedata.combat.damage[id] then
      gamedata.combat.damage[id] = gamedata.combat.damage[id] - value
      return value + math.min(gamedata.combat.damage[id], 0)
    end
  end
end
function _visual_generator.heal(arg, outcome)
  local id = arg.target
  local ui_updater = combat.visual.health_ui_updater(id)
  return function()
    ui_updater()
  end
end

function _effect_generator.card(value)
  return function(arg)
    local id = arg.target
    local draw = gamedata.deck.draw
    local hand = gamedata.deck.hand
    local discard = gamedata.deck.discard
    if deck.empty(id, draw) and deck.empty(id, discard) then return 0 end

    local cards = {}
    local function _do_draw(count)
      local can_draw = math.min(count, deck.size(id, draw))
      for i = 1, can_draw do
        table.insert(cards, deck.draw(id, draw))
      end
      return can_draw
    end
    local draw_left = value
    draw_left = draw_left - _do_draw(draw_left)

    if draw_left > 0 then
      draw[id] = discard[id]
      discard[id] = {}
      deck.shuffle(id, draw)
      draw_left = draw_left - _do_draw(draw_left)
    end

    for _, c in pairs(cards) do deck.insert(id, hand, c, 1) end
    return value - draw_left, cards
  end
end

function _effect_generator.discard(value)
  return function(arg)
    local id = arg.target
    local hand = gamedata.deck.hand
    local discard = gamedata.deck.discard
    local rng = love.math.random
    local can_discard = math.min(value, deck.size(id, hand))
    local cards = {}
    for i = 1, can_discard do
      local index = rng(1, deck.size(id, hand))
      local card = deck.draw(id, hand, card)
      table.insert(cards, card)
      deck.insert(id, discard, card)
    end
    return can_discard, cards
  end
end

local function _effect_parse(effects)
  local effect_executors = {}
  for key, val in pairs(effects) do
    local generator = _effect_generator[key]
    if generator then
      effect_executors[key] = generator(val)
    else
      print(string.format("Unkown effect provided: %s", key))
    end
  end
  return effect_executors
end

local _animation_generator = {}

function _animation_generator.projectile(visual_data, arg, effect_visualizers)
  return combat.visual.projectile(
    arg.user, arg.target, effect_visualizers, visual_data
  )
end

function combat.parse_card_play(id, pile, index, data)
  data = data.play
  local ui_process

  local personal
  local single
  local all

  local all_effects = {}

  local arg = {
    user = id
  }

  local function insert_effect(arg_format, effects)
    table.insert(all_effects, {
      arg_format = arg_format, effects = effects
    })
  end

  if data.personal then
    insert_effect(
      function(arg) return {target = arg.user} end,
      _effect_parse(data.personal)
    )
  end
  if data.single then
    insert_effect(
      function(arg) return arg end,
      _effect_parse(data.single)
    )
    ui_process = function(arg)
      arg.target = combat_engine.pick_single_target()
      return arg
    end
  end
  if data.all then
    insert_effect(
      function(arg) return {target = arg.target} end, -- Return a list of targets here
      _effect_parse(data.all)
    )
  end
  ui_process = ui_process or function(arg)
    combat_engine.confirm_cast(id, pile, index)
    return arg
  end
  arg = ui_process(arg)

  signal.emit(combat_engine.events.card.play, id, pile, index)

  local viz = {}
  for _, effects in pairs(all_effects) do
    local _args = {effects.arg_format(arg)}
    for key, e in pairs(effects.effects) do
      local viz_generator = _visual_generator[key]
      for _, a in pairs(_args) do
        local outcome = {e(a)}
        if viz_generator then
          table.insert(viz, viz_generator(a, outcome))
        end
      end
    end
  end

  local effect_vis = function() for _, v in pairs(viz) do v() end end

  if not data.visual then
    effect_vis()
    return
  end
  -- Build the animation sequence
  local animation_generator = _animation_generator[data.visual.type]

  if not animation_generator then
    effect_vis()
    return
  end

  combat_engine.add_event(
    --combat.visual.melee_attack(arg.user, arg.target, visualizer)
    animation_generator(data.visual, arg, effect_vis)
  )
end
