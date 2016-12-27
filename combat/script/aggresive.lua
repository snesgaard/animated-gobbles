local control = {}
function control.confirm_cast()

end

function control.pick_single_target()
  local allies = combat_engine.data.party
  return allies[1]
end

local event = {
    finished = {}
}

local function determine_action(dt, enemies)
  if combat_engine.data.action_point <= 0 then
      signal.emit(event.finished)
      return
  end
  for _, id in pairs(enemies) do
    local hand = gamedata.deck.hand[id]
    for i, card in pairs(hand) do
      if gamedata.card.cost[card] <= combat_engine.data.action_point then
        combat.parse_card_play(id, gamedata.deck.hand, i, control)
        combat_engine.add_event(determine_action, enemies)
        return
      end
    end
  end
end

return function(dt, enemies)
  for i = 1,60 do coroutine.yield() end
  combat_engine.add_event(determine_action, enemies)
  local state = {}
  local tokens = {}
  tokens.finish = signal.type(event.finished)
    .listen(function()
        state.terminate = true
    end)
  while not state.terminate do
      for _, t in pairs(tokens) do t() end
      coroutine.yield()
  end
end
