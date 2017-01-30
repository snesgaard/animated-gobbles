local event = require "combat/event"
local animation_builder = require "combat/ui/animation_builder"
local card_seq = require "combat/ui/card_play_seq"

combat = combat or {}

local _visual_generator = {}
local _effect_generator = require "combat/effect"


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
    local ui_process
    local personal
    local single
    local all

    local all_effects = {}

    local arg = {
      user = id
    }

    local function insert_effect(name, arg_format, effects)
      all_effects[name] = {
        arg_format = arg_format, effects = effects
      }
    end

    if data.personal then
      insert_effect(
        "personal", function(arg) return {target = arg.user} end,
        _effect_parse(data.personal)
      )
    end
    if data.single then
      insert_effect(
        "single", function(arg) return arg end,
        _effect_parse(data.single)
      )
      ui_process = function(arg)
        --combat_engine.set_selected_card(id, cardid)
        arg.target = control.pick_single_target()
        return arg
      end
    end
    if data.all then
      insert_effect(
        "all", function(arg) return {target = arg.target} end, -- Return a list of targets here
        _effect_parse(data.all)
      )
    end
    if data.random then
      insert_effect(
        "random",
        function(arg)
          local output = {}
          local reps = data.random.rep or 1
          local rng = love.math.random
          local user_faction = combat_engine.faction(arg.user)
          local friends  = {
            [combat_engine.DEFINE.FACTION.PLAYER] = combat_engine.data.party,
            [combat_engine.DEFINE.FACTION.ENEMY] = combat_engine.data.enemy
          }
          local opponents = {
            [combat_engine.DEFINE.FACTION.PLAYER] = combat_engine.data.enemy,
            [combat_engine.DEFINE.FACTION.ENEMY] = combat_engine.data.party
          }
          local target_faction = data.random.faction
          local target_pool
          if target_faction == "opponent" then
            target_pool = opponents[user_faction]
          elseif target_faction == "friend" then
            target_pool = friends[user_faction]
          else
            target_pool = concatenate(
              opponents[user_faction], friends[user_faction]
            )
          end
          for i = 1, reps do
            local _arg = {
              target = target_pool[rng(#target_pool)],
              user = arg.user
            }
            table.insert(output, _arg)
          end
          return unpack(output)
        end,
        _effect_parse(data.random)
      )
    end
    ui_process = ui_process or function(arg)
      --combat_engine.set_selected_card(id, cardid)
      control.confirm_cast()
      return arg
    end
    arg = ui_process(arg)
    return arg, all_effects
end

local function execute_play(arg, all_effects)
  local all_vis = {}
  for name, effects in pairs(all_effects) do
    local vis = {}
    local _args = {effects.arg_format(arg)}
    for _, a in pairs(_args) do
      local m = map(function(e) return e(a) end, effects.effects)
      local arg_vis = flatten(m)
      table.insert(vis, {effect = arg_vis, arg = a})
    end
    all_vis[name] = vis
  end
  return all_vis
end

function combat.parse_card_play(id, pile, index, control)
  local cardid = deck.peek(id, pile, index)
  local effects = gamedata.card.effect[cardid]
  local data = effects.play
  if not combat_engine.can_play(cardid) then
    return
  end

  local representation = cards.create_representation(cardid)

  local arg, all_effects = parse_play(id, data, control)

  deck.remove(id, pile, index)
  deck.insert(id, gamedata.deck.discard, cardid)
  -- Remove callbacks from hand
  map(function(r) r(true) end, gamedata.card.react.hand[cardid] or {})
  -- Add callbacks from discard
  map(function(r) r() end, gamedata.card.react.discard[cardid] or {})
  local cost = gamedata.card.cost[cardid]
  combat_engine.data.action_point = combat_engine.data.action_point - cost
  --signal.echo(event.core.card.begin, id, cardid)

  local all_viz = execute_play(arg, all_effects)

  all_viz.play = {
    {
      effect = signal.echo(event.core.card.play, id, cardid, arg.target, representation),
      arg = {user = id, target = id}
    }
  }

  local anime = animation_builder(id, data.visual, all_viz)
  combat_engine.add_event(card_seq, representation, anime)
end

function combat.parse_play(id, data, control)
  local arg, all_effects = parse_play(id, data, control)
  local cost = data.cost or 0
  combat_engine.data.action_point = combat_engine.data.action_point - cost

  local all_viz = execute_play(arg, all_effects)

  local anime = animation_builder(id, data.visual, all_viz)
  combat_engine.add_event(anime)
end
