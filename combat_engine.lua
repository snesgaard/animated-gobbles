combat_engine = {}

local data = {
  turn_order = {},
  current_turn = 1,
  action_point = {},
  decks = {},
  script = {},
}

function combat_engine.round(c)
  local id = data.turn_order[c]
  local s = data.script[id]
  print(id, s, c)
  return s(id)
end

function combat_engine.next_round()
  local c = data.current_turn
  data.current_turn = c < #data.turn_order and c + 1 or 1
  return combat_engine.round(data.current_turn)
end

function pick_card_from_hand(id)
  local hand = data.decks[id].hand
  local card_activated
  for i, card_id in pairs(hand) do
    local x = 1000 - i * 100
    gamedata.spatial.x[card_id] = x
    gamedata.spatial.y[card_id] = 720
    local card_ui = cards.render(card_id)
    if card_ui.hit then
      print("spoof")
      --card_activated = card_activated or card_id
    end
  end
  return card_activated
end


function combat_engine.player_script(id)
  local card_id = pick_card_from_hand(id)
  if card_id then
    combat_engine.activate_card(card_id)
    combat_engine.discard(card_id, id)
  end
  --local end_turn = turn_ended(id)
  if end_turn then return combat_engine.next_round() end
  signal.listen("update")
  --coroutine.yield()
  return combat_engine.player_script(id)
end

function combat_engine.begin(allies, enemies)
  -- Initialize card pool
  local all_ids = {}
  for _, id in pairs(allies) do table.insert(all_ids, id) end
  for _, id in pairs(enemies) do table.insert(all_ids, id) end

  for _, id in pairs(all_ids) do
    data.decks[id] = deck.create()
    local collection = gamedata.combat.collection[id] or {}
    data.decks[id].draw = map(function() return cards.init() end, collection)
    deck.shuffle(data.decks[id], "draw")
    data.script[id] = combat_engine.player_script
    for i = 1, deck.size(data.decks[id], "draw") do
      local card_id = deck.draw(data.decks[id], "draw")
      deck.insert(data.decks[id], "hand", card_id)
    end
  end
  data.turn_order = all_ids
  data.current_turn = 0
  -- Hacked
  local co = coroutine.create(combat_engine.next_round)
  coroutine.resume(co)
end
