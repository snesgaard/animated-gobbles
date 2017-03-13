local _effect_generator = {}

local rng = love.math.random

-- Generators for effect executors
-- Returns a generator for effect capsulated in function f
-- The generator accepts a value or a function
local function create_generator(f)
  return function(val)
    -- The return value here is a two layered function
    -- The reason is that functional side of val needs a change to derive
    -- it's arguments
    -- Afterwards a function is returned that performs the state mutation
    if type(val) == "function" then
      return function(user, target)
        local args = {val(user, target)}
        return function() return f(user, target, unpack(args)) end
      end
    else
      return function(user, target)
        return function() return f(user, target, val) end
      end
    end
  end
end

-- This effect has the following valid arguments:
-- id -> id -> value :: Gives <id> <value> armor
-- id -> [id] -> value :: Gives all <[id]> <value> armor
-- id -> [id] -> [value] :: Gives <[id]> matching entry armor in <[value]>
_effect_generator.armor = create_generator(function(user, target, value)
  local combat = gamedata.combat
  if type(target) == "number" then
    target = {target}
  end
  if type(value) == "number" then
    value = util.duplicate(value, #target)
  end
end)

-- This effect have the following valid call arguments
-- id -> id -> value :: Heals <id> for <value>
-- id -> [id] -> value :: Heals all <[id]> for <value>
-- id -> [id] -> [value] :: Heals <[id]> for matching in <[value]>
_effect_generator.heal = create_generator(function(user, target, value)
  local combat = gamedata.combat
  if type(target) == "number" and type(value) == "number" then
    target = {target}
    value = {value}
  elseif type(target) == "table" and type(value) == "number" then
    value = util.duplicate(value, #target)
  elseif type(target) == "table" and type(value) == "table" then
  else
    error(
      string.format(
        "Unsupported combination of types: %s %s", type(target), type(value)
      )
    )
  end

  return flatten(map(function(id, heal)
    local dmg = combat.damage[id] or 0
    combat.damage[id] = dmg - heal
    if combat.damage[id] <= 0 then
      combat.damage[id] = nil
    end
    return signal.echo(event.core.character.heal, id, math.min(dmg, heal))
  end, target, value))
end)

_effect_generator.damage = create_generator(function(user, target, value)
  local combat = gamedata.combat
  target = type(target) == "table" and target or {target}
  value = type(value) == "table" and value or util.duplicate(value, #target)
  local armor = map(function(id) return combat.buff.armor[id] or 0 end, target)
  local shield = map(function(id) return combat.buff.shield[id] or 0 end, target)
  local power = combat.buff.power[user] or 0
  local charge = combat.buff.charge[user]
  -- Apply the power level
  value = map(function(value) return math.max(value + power, 0) end, value)
  -- Apply charge multiplier if present
  if charge then
    local s = charge > 0 and 2 or 0.5
    value = map(function(value) return math.round(value * s) end, value)
  end
  -- Apply armor offset
  value = map(function(arg)
    local value, armor = unpack(arg)
    return math.max(value - armor, 0)
  end, zip(value, armor))
  -- Apply shield modifier if present
  value = map(function(arg)
    local value, shield = unpack(arg)
    local s = shield > 0 and 0 or 2
    return shield == 0 and value or value * s
  end, zip(value, shield))

  -- TODO:No state updates for charge or shield yet...
  return flatten(map(function(arg)
    local id, value = unpack(arg)
    local dmg = combat.damage[id] or 0
    combat.damage[id] = dmg + value
    return signal.echo(event.core.character.damage, id, value)
  end, zip(target, value)))
end)

-- This generator can have hte following signatures
-- id -> id -> number : Discards <number> random cards from <id> hand
-- id -> [id] -> number : Foreach in <[id]> discard <number> random cards
-- id -> id -> [number] : Discards indices as given by <[number]> from id's hand
-- id -> [id] -> [[number]] : discards indices as given by [id] ' hand
_effect_generator.discard = create_generator(
function(user, target, value)
  local hand = gamedata.deck.hand
  local discard = gamedata.deck.discard
  local function pick_random(id, count)
    local indices = range(deck.size(id, hand))
    local weights = map(function() return rng() end, indices)
    table.sort(indices, function(a, b) return weights[a] < weights[b] end)
    local res = {}
    for i = 1, math.min(count, #indices) do
      res[#res + 1] = indices[i]
    end
    return res
  end
  if type(target) == "number" and type(value) == "number" then
    value = {pick_random(target, value)}
    target = {target}
  elseif type(target) == "table" and type(value) == "number" then
    value = map(function(id) return pick_random(id, value) end, target)
  elseif type(target) == "number" and type(value) == "table" then
    target = {target}
    value = {value}
  elseif type(target) == "table" and type(value) == "table" then
    -- HACK Here we kinda assumme that value is given in the [[number]] format
  else
    error(
      "Unsupported combination of target and value:", type(target), type(value)
    )
  end
  -- Arrange in descending order to prevent indice conflicts
  for _, indices in pairs(value) do
    table.sort(indices, function(a, b) return b < a end)
  end

  local cardids = map(function(arg)
    local id, indices = unpack(arg)
    return map(function(i)
      local cid = deck.peek(id, hand, i)
      deck.remove(id, hand, i)
      deck.insert(id, discard, cid)
      return cid
    end, indices)
  end, zip(target, value))

  local viz_cb = map(function(arg)
    local id, cids = unpack(arg)
    return map(function(cid)
      return signal.echo(event.core.card.discard, id, cid)
    end, cids)
  end, zip(target, cardids))

  return flatten(flatten(viz_cb))
end)

-- This generator has the following valid signatures
-- id -> id -> cardname
-- id -> id -> [cardname]
-- id -> [id] -> cardname
-- id -> [id] -> [cardname]
-- id -> [id] -> [[cardname]]
_effect_generator.summon = create_generator(
function(user, target, cardname, dst_pile)
end)

-- This generator effectively have two signatures
-- arg:= <number> -> it draws the <number> top cards from draw
-- arg:= <index> <pile> -> draws the <index> card from deck <pile>
_effect_generator.card = create_generator(
function(user, target, index, pile, src)
  local draw = gamedata.deck.draw
  local hand = gamedata.deck.hand
  local discard = gamedata.deck.discard
  target = type(target) == "table" and target or {target}
  if not pile then
    -- We assumme here that
    local count = index
    index = util.duplicate(range(count), #target)
    pile = util.duplicate(util.duplicate(draw, count), #target)
  end
  if not src then
    src = map(
      function(arg)
        local src_id, _index, _pile = unpack(arg)
        return util.duplicate(src_id, math.min(#_index, #_pile))
      end, zip(target, index, pile))
  end
  pile = type(pile) == "table" and pile or {pile}
  index = type(index) == "table" and index or {index}
  src = type(src) == "table" and src or {src}

  local cardids = map(function(arg)
    local _src, _index, _pile = unpack(arg)
    return map(function(arg)
      local s, i, p = unpack(arg)
      if deck.size(s, p) >= i then
        local cid = deck.peek(s, p, i)
        --deck.remove(s, p, i)
        return cid
      -- Exception to the rule
      else
        return -1
      end
    end, zip(_src, _index, _pile))
  end, zip(src, index, pile))
  -- Sort cards in order of table and numerical
  local pile_refs = {}
  map(function(arg)
    local _src, _index, _pile = unpack(arg)
    return map(function(arg)
      local s, i, p = unpack(arg)
      local ref = p[s]
      pile_refs[ref] = pile_refs[ref] or {}
      table.insert(pile_refs[ref], i)
    end, zip(_src, _index, _pile))
  end, zip(src, index, pile))
  -- Now sort references in descending numerical order
  -- Afterwards remove the chosen cards
  for pr, indices in pairs(pile_refs) do
    table.sort(indices, function(a, b) return b < a end)
    for _, i in pairs(indices) do
      for j = i, #pr do
        pr[j] = pr[j + 1]
      end
    end
  end

  -- TODO: CHECK FOR -1 (invalid) ids
  local draw_cb = map(function(arg)
    local tid, cardlist = unpack(arg)
    return map(function(cid)
      if cid == -1 then return end
      if deck.size(tid, hand) >= 10 then
        deck.insert(tid, discard, cid)
        return signal.echo(event.core.card.discard, tid, cid)
      else
        deck.insert(tid, hand, cid)
        return signal.echo(event.core.card.draw, tid, cid)
      end
    end, cardlist)
  end, zip(target, cardids))
  draw_cb = flatten(flatten(draw_cb))
  return draw_cb
end)
--[[
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
]]

return _effect_generator
