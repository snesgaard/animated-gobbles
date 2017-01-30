local _effect_generator = {}

local rng = love.math.random

function _effect_generator.damage(value)
  return function(arg)
    local res = {}
    local target = arg.target
    local user = arg.user
    local power = gamedata.combat.buff.power[user] or 0
    local armor = gamedata.combat.buff.armor[target] or 0
    local charge = gamedata.combat.buff.charge[user]
    local shield = gamedata.combat.buff.shield[target]
    local crit = gamedata.combat.buff.crit[user]

    value = value + power
    if charge then
      local ds = charge > 0 and -1 or 1
      local s = charge > 0 and 2 or 0.5
      value = math.floor(value * s)
      charge = charge + ds
      if charge == 0 then charge = nil end
      gamedata.combat.buff.charge[user] = charge
      res = concatenate(res, signal.echo(event.core.character.charge, user, ds))
    end
    if crit then
      local s = crit > 0 and 2 or 0
      test = crit > 0 and crit * 10 or -crit * 10
      if test > rng(100) then
        value = value * s
      end
    end
    value = value - armor
    if shield then
      local ds = shield > 0 and -1 or 1
      local s = shield > 0 and 0 or 2
      value = value * s
      shield = shield + ds
      if shield == 0 then shield = nil end
      gamedata.combat.buff.shield[target] = shield
      res = concatenate(res, signal.echo(event.core.character.shield, target, ds))
    end
    value = math.max(0, value)
    --print("dealt damage to", value, id)
    gamedata.combat.damage[target] = (gamedata.combat.damage[target] or 0) + value
    res = concatenate(res, signal.echo(event.core.character.damage, target, value))
    return res
  end
end

-- TODO: Refactor when each faction get their own action pool
function _effect_generator.action(value)
  return function(arg)
    --local id = arg.target
    combat_engine.data.action_point = combat_engine.data.action_point + value
  end
end

function _effect_generator.heal(value)
  return function(arg)
    local id = arg.target
    local dmg = gamedata.combat.damage[id]
    if not dmg then return end
    if dmg <= value then
      gamedata.combat.damage[id] = nil
      value = dmg
    else
      gamedata.combat.damage[id] = dmg - value
    end
    return signal.echo(event.core.character.heal, id,  value)
  end
end

function _effect_generator.regen(value)
  return function(arg)
    local id = arg.target
    local regen = (gamedata.combat.buff.regen[id] or 0) + value
    if regen == 0 then
      gamedata.combat.buff.regen[id] = nil
    else
      gamedata.combat.buff.regen[id] = regen
    end
    return signal.echo(event.core.character.regen, id, value)
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

    --for _, c in pairs(cards) do
    --  deck.insert(id, hand, c)
    --  signal.emit(event.core.card.draw, id, c)
    --end
    return flatten(map(function(card)
      deck.insert(id, hand, card)
      return signal.echo(event.core.card.draw, id, card)
    end, cards))
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


return _effect_generator
