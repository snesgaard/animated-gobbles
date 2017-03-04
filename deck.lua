local rng = love.math.random

gamedata.deck = {
  draw = {},
  hand = {},
  discard = {},
  burn = {},
}

deck = {}

function deck.clear()
end

function deck.create(id)
  for key, pile in pairs(gamedata.deck) do
    pile[id] = {}
  end
end

function deck.remove(id, pile, index)
  local _pool = pile[id]
  if not _pool then
    error(string.format("%i was not found in deck:", index))
  end
  if index < 1 or index > #_pool then
    error(index .. " exceeds pile " .. pile .. " with size " .. #_pool)
  end
  for i = index + 1, #_pool do
    _pool[i - 1] = _pool[i]
  end
  _pool[#_pool] = nil
end

function deck.peek(id, pile, index)
  if not index then return end
  local _pool = pile[id]
  if not _pool then
    error(pile .. " was not found in deck")
  end
  if index < 1 or index > #_pool then
    error(index .. " exceeds pile with size " .. #_pool)
  end
  return _pool[index]
end

function deck.draw(id, pile, index)
  index = index or 1
  local card_id = deck.peek(id, pile, index)
  deck.remove(id, pile, index)
  return card_id
end

function deck.insert(id, pile, card_id, index)
  local _pool = pile[id]
  if not _pool then
    error(pile .. " was not found in deck")
  end
  index = index or #_pool + 1
  if index < 1 or index > #_pool + 1 then
    error(
      index .. " cannot be placed in pile " .. pile .. " with size " .. #_pool
    )
  end
  local _move = type(card_id) == "table" and #card_id or 1
  for i = #_pool, index, -1 do
    _pool[i + _move] = _pool[i]
  end
  if type(card_id) == "table" then
    for i, id in pairs(card_id) do
      _pool[index + i - 1] = id
    end
  else
    _pool[index] = card_id
  end
  return index
end

function deck.transfer(id, src, dst, src_index, dst_index)
  src_index = src_index or 1
  if deck.size(id, src) < src_index then return end
  local card = deck.draw(id, src, src_index)
  deck.insert(id, dst, card, dst_index)
end

function deck.shuffle(id, pile)
  local _pool = pile[id]
  if not _pool then
    error(pile .. " was not found in deck")
  end
  local _order = {}
  for _, cid in pairs(_pool) do
    _order[cid] = rng()
  end
  table.sort(_pool, function(a, b) return _order[a] < _order[b] end)
end

function deck.size(id, pile)
  local _pool = pile[id]
  if not _pool then
    error(pile .. " was not found in deck")
  end
  return #_pool
end

function deck.empty(id, pile)
  return deck.size(id, pile) == 0
end

function deck.swap(id, pile_a, pile_b)
  local _pool_a = pile_a[id]
  if not _pool_a then
    error(pile_a .. " was not found in deck")
  end
  local _pool_b = pile_b[id]
  if not _pool_b then
    error(pile_b .. " was not found in deck")
  end
  _deck[pile_a] = _pool_b
  _deck[pile_b] = _pool_a
end
