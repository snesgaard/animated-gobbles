local _effect_generator = {}

function _effect_generator.damage(value)
  return function(arg)
    local id = arg.target
    --print("dealt damage to", value, id)
    gamedata.combat.damage[id] = (gamedata.combat.damage[id] or 0) + value
    return signal.echo(event.core.character.damage, id, value)
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
