local states = {}

function states.card_picked(id, pile, index)
  local next_state = {}
  local subroutines = {}

  local tokens = {
    signal.type("mousepressed")
    .filter(function(x, y, b) return b == 2 end)
    .map(function()
      return next_state, function()
        return states.action_pick(id)
      end
    end)
    .listen(table.insert),
    signal.type(combat_engine.events.card.play)
    .filter(function(cid) return cid == cardid end)
    .map(function()
      return next_state, function()
        local d = combat_engine.data.decks[id]
        return states.action_pick(id)
      end
    end)
    .listen(table.insert)
  }

  local play = gamedata.card.play[cardid]
  play = play(cardid, id)

  combat_engine.set_selected_card(id, index, cardid)
  while true do
    play()
    for _, t in pairs(tokens) do t() end
    for _, co in pairs(subroutines) do coroutine.resume(co) end
    coroutine.yield()
    if next_state[1] then
      local f = next_state[1]
      return f()
    end
  end
end

function states.action_pick(id)
  local next_state = {}

  local card_clicked = signal.type(combat_engine.events.card.clicked)
  .filter(function(index, cardid)
    return combat_engine.data.action_point >= gamedata.card.cost[cardid]
  end)
  .map(function(index, cardid)
    return next_state, function()
      return states.card_picked(id, "hand", index)
    end
  end)
  .listen(table.insert)

  combat_engine.set_available_card(id)

  while true do
    card_clicked()
    coroutine.yield()
    if next_state[1] then
      local f = next_state[1]
      return f()
    end
  end
end

function combat_engine.script.player(id)
  return states.action_pick(id)
end
