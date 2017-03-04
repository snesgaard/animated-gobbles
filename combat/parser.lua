local event = require "combat/event"
local animation_builder = require "combat/ui/animation_builder"
local card_seq = require "combat/ui/card_play_seq"

combat = combat or {}

local _visual_generator = {}
local _effect_generator = require "combat/effect"

local DEFINE = {
  EFFECT_ORDER = {
    "heal", "damage", "discard", "card", "action"
  },
  TARGET_ORDER = {
    "single", "all", "random", "personal"
  }
}

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


function _visual_generator.heal(arg, outcome)
  local id = arg.target
  local ui_updater = combat.visual.health_ui_updater(id)
  return function()
    ui_updater()
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

local function parse_play(id, data, control)
  local arg = {
    user = id
  }

  local function default(arg)
    control.confirm_cast()
    return arg
  end
  local function single(arg)
    arg.target = control.pick_single_target()
    return arg
  end
  local ui_process = data.single and single or default
  arg = ui_process(arg)
  return arg
end

local function callback_activator(callbacks)
  return function()
    for _, cb in pairs(callbacks) do cb() end
  end
end


local function execute_play(arg, data)
  local function get_faction_targets(user, faction)
    local p = combat_engine.DEFINE.FACTION.PLAYER
    local e = combat_engine.DEFINE.FACTION.ENEMY
    local user_faction = combat_engine.faction(user)
    local enemy_faction = user_faction == p and e or p

    local allies = combat_engine.faction_members(user_faction)
    local enemies = combat_engine.faction_members(enemy_faction)
    local all = concatenate(allies, enemies)
    local select = {
      allies = allies,
      opponents = enemies,
      default = all
    }
    return select[faction]
  end

  local rng = love.math.random
  -- TODO FINISH THIS STUFF
  local get_target = {}
  function get_target.personal(arg)
    return arg.user
  end
  function get_target.single(arg)
    return arg.target
  end
  function get_target.all(arg)
    return get_faction_targets(arg.user, data.all.faction or "default")
  end
  function get_target.random(arg)
    local targets = get_faction_targets(data.random.faction or "default")
    return targets[rng(1, #targets)]
  end

  local visualizer_cbs = {}
  -- ITerate over the different targeting paradigms
  for _, targetid in pairs(DEFINE.TARGET_ORDER) do
    -- Create stub if not available
    local effect_data = data[targetid] or {}
    -- Function for obtaining target for functions
    local target_selector = get_target[targetid]
    -- This is an aggregator list, which collects a list of lists of effectors
    local effects_list = {}
    -- This function probes the effect_data table for a given effect
    -- If it exists, it creates and returns a list of the corresponding generators
    local function add_effect(effect_id)
      local effect = effect_data[effect_id]
      if not effect then return end
      local gen = _effect_generator[effect_id]
      if not gen then
        print("unknown effect:", effect_id)
        return
      end
      effect = type(effect) == "table" and effect or {effect}
      return map(gen, effect)
    end
    -- Iterate effect ids in order and add to the effect table
    for _, effect_id in pairs(DEFINE.EFFECT_ORDER) do
      effects_list[#effects_list + 1] = add_effect(effect_id)
    end
    -- Zip the list of lists
    -- As such repitions of various types are properly grouped together
    effects_list = zip(unpack(effects_list))
    -- ITerate throuth the zipped effector table
    visualizer_cbs[targetid] = map(function(effects)
      local target = target_selector(arg)
      -- TODO: A flatten might be neceassary here, don't quite recall
      local final_exes = map(function(e)
        return e(arg.user, target)
      end, effects)
      local cbs = flatten(map(function(f) return f() end, final_exes))
      cbs = flatten(cbs)
      return {callbacks = callback_activator(cbs), user = arg.user, target = target}
    end, effects_list)
  end
  return visualizer_cbs
end

function combat.parse_card_play(engine, id, pile, index, control)
  local cardid = deck.peek(id, pile, index)
  local effects = gamedata.card.effect[cardid]
  local data = effects.play
  if not engine.can_play(id, cardid) then
    return
  end

  local representation = cards.create_representation(cardid)

  local arg = parse_play(id, data, control)

  deck.remove(id, pile, index)
  deck.insert(id, gamedata.deck.discard, cardid)
  -- Remove callbacks from hand
  map(function(r) r(true) end, gamedata.card.react.hand[cardid] or {})
  -- Add callbacks from discard
  map(function(r) r() end, gamedata.card.react.discard[cardid] or {})
  local cost = gamedata.card.cost[cardid]
  --combat_engine.data.action_point = combat_engine.data.action_point - cost
  engine.change_action(id, -cost)
  --signal.echo(event.core.card.begin, id, cardid)

  local all_viz = execute_play(arg, data)

  all_viz.play = {
    {
      callbacks = signal.echo(
        event.core.card.play, id, cardid, arg.target, representation
      ),
      user = id,
      target = id,
    }
  }
  -- TODO: Remove this when appropriate
  local anime = animation_builder(id, data.visual, all_viz, engine)
  local n_anime = gamedata.card.animate[cardid]
  return function(dt)
    card_seq(dt, representation, n_anime or anime, engine, all_viz)
  end
  --combat_engine.add_event(card_seq, representation, anime)
end

function combat.parse_play(engine, id, data, control)
  local arg = parse_play(id, data, control)
  local cost = data.cost or 0
  --combat_engine.data.action_point = combat_engine.data.action_point - cost
  engine.change_action(id, -cost)

  local all_viz = execute_play(arg, data)
  local anime = animation_builder(id, data.visual, all_viz, engine)
  return anime
end
