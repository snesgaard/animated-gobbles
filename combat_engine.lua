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

local function pick_card_from_hand(id, hovered)
  local hand = data.decks[id].hand
  local card_activated
  for i, card_id in pairs(hand) do
    gamedata.spatial.x[card_id] = 40 + (#hand + 1 - i  - 1) * 180
    gamedata.spatial.y[card_id] = 750
  end
  --local hand_ui = cards.batch_render(hand, 40, 750)
  local next_hovered
  for i, card_id in pairs(hand) do
    local card_ui = cards.render(card_id, card_id == hovered)
    next_hovered = (card_ui.hovered and not next_hovered) and card_id or next_hovered
  end
  coroutine.yield()
  return pick_card_from_hand(id, next_hovered)
end


local function _run_player_script(id, card_picker)
  local card_id = card_picker(id)
  if card_id then
    combat_engine.activate_card(card_id)
    combat_engine.discard(card_id, id)
  end
  --local end_turn = turn_ended(id)
  if end_turn then return combat_engine.next_round() end
  signal.listen("update")
  --coroutine.yield()
  return _run_player_script(id, card_picker)
end

function combat_engine.player_script(id)
  local card_picker = coroutine.wrap(pick_card_from_hand)
  return _run_player_script(id, card_picker)
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
    local draw_size = deck.size(data.decks[id], "draw")
    for i = 1, math.min(draw_size, 10) do
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
