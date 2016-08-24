local rng = love.math.random

deck = {}

function deck.create()
  return {
    draw = {},
    hand = {},
    discard = {},
    burn = {},
  }
end

function deck.remove(pool, index)
  for i = index + 1, #pool do
    pool[i - 1] = pool[i]
  end
  pool[#pool] = nil
end

function deck.peek(pool, index)
  return pool[index]
end

function deck.draw(pool, index)
  local card = deck.peek(pool, index)
  deck.remove(pool, index)
  return card
end

function deck.insert(pool, card)
  table.insert(pool, card)
end

function deck.move(from, to, index)
  local card = deck.draw(from, index)
  deck.insert(to, card)
  return card
end

function deck.move_random(from, to)
  return deck.move(from, to, rng(#from))
end

function deck.filter(f, pool)
  local res = {}
  for _, card in pairs(pool) do
    if f(card) then table.insert(res, card) end
  end
  return res
end
