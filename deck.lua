local rng = love.math.random

deck = {}

function deck.create()
  local _deck =  {
    draw = {},
    hand = {},
    discard = {},
    burn = {},
  }
  return _deck
end

function deck.remove(_deck, _pile, _card)
  local _pool = _deck[_pile]
  if not _pool then
    error(_pile .. " was not found in deck")
  end
  if _card < 1 or _card > #_pool then
    error(_card .. " exceeds pile " .. _pile .. " with size " .. #_pool)
  end
  for i = _card + 1, #_pool do
    _pool[i - 1] = _pool[i]
  end
  _pool[#_pool] = nil
end

function deck.peek(_deck, _pile, _card)
  local _pool = _deck[_pile]
  if not _pool then
    error(_pile .. " was not found in deck")
  end
  if _card < 1 or _card > #_pool then
    error(_card .. " exceeds pile <" .. _pile .. "> with size " .. #_pool)
  end
  return _pool[_card]
end

function deck.draw(_deck, _pile, _card)
  _card = _card or 1
  local id = deck.peek(_deck, _pile, _card)
  deck.remove(_deck, _pile, _card)
  return id
end

function deck.insert(_deck, _pile, _id, _index)
  local _pool = _deck[_pile]
  if not _pool then
    error(_pile .. " was not found in deck")
  end
  _index = _index or #_pool + 1
  if _index < 1 or _index > #_pool + 1 then
    error(
      _card .. " cannot be placed in pile " .. _pile .. " with size " .. #_pool
    )
  end
  local _move = type(_id) == "table" and #_id or 1
  for i = #_pool, _index, -1 do
    _pool[i] = _pool[i + _move]
  end
  if type(_id) == "table" then
    for i, id in pairs(_id) do
      _pool[_index + i - 1] = id
    end
  else
    _pool[_index] = _id
  end
end

function deck.shuffle(_deck, _pile)
  local _pool = _deck[_pile]
  if not _pool then
    error(_pile .. " was not found in deck")
  end
  local _order = {}
  for _, id in pairs(_pool) do
    _order[id] = rng()
  end
  table.sort(_pool, function(a, b) return _order[a] < _order[b] end)
end

function deck.size(_deck, _pile)
  local _pool = _deck[_pile]
  if not _pool then
    error(_pile .. " was not found in deck")
  end
  return #_pool
end

function deck.swap(_deck, _pile_a, _pile_b)
  local _pool_a = _deck[_pile_a]
  if not _pool_a then
    error(_pile_a .. " was not found in deck")
  end
  local _pool_b = _deck[_pile_b]
  if not _pool_b then
    error(_pile_b .. " was not found in deck")
  end
  _deck[_pile_a] = _pool_b
  _deck[_pile_b] = _pool_a
end
