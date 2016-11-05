combat = combat or {}
combat.mechanic = {}

function combat.mechanic.draw_card(id)
  local hand = gamedata.deck.hand
  local draw = gamedata.deck.draw
  local discard = gamedata.deck.discard

  if deck.size(id, discard) == 0 and deck.size(id, draw) == 0 then
    return
  end

  if deck.size(id, draw) == 0 then
    local discard = gamedata.deck.discard
    draw[id] = discard[id]
    discard[id] = {}
    deck.shuffle(id, draw)
  end

  local cardid = deck.draw(id, draw)
  local index = deck.insert(id, hand, cardid, 1)
  signal.emit(combat_engine.events.card.draw, id, hand, index)
end
