local states = {}

local card_data = {
  cost = 1,
  name = "Potato",
  image = "potato",
  play = {
    single = {damage = 1},
    personal = {card = 1},
    visual = {
      type = "projectile",
      projectile = {
        sprite = "potato",
        speed = 500
      },
      on_hit = {
        sprite = "potato",
        behavior = "bounce",
      }
    }
  }
}

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
    .filter(function(_id) return id == _id end)
    .map(function()
      return next_state, function()
        return states.action_pick(id)
      end
    end)
    .listen(table.insert)
  }

  local cardid = deck.peek(id, pile, index)
  local play = gamedata.card.play[cardid]
  play = play(id, pile, index)

  combat_engine.set_selected_card(id, cardid)
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
  .filter(function(_id, _pile, _index)
    return _id == id
  end)
  .filter(function(_id, _pile)
    return _pile == gamedata.deck.hand
  end)
  .filter(function(id, pile, index)
    local cardid = deck.peek(id, pile, index)
    return combat_engine.data.action_point >= gamedata.card.cost[cardid]
  end)
  .map(function(id, pile, index)
    return next_state, function ()
      combat_engine.play_card(id, pile, index)
      return states.action_pick(id)
    end
  end)
  .listen(table.insert)

  local player_clicked = signal.type(combat_engine.events.target.single)
  .filter(function(eid) return eid ~= id end)
  .filter(function(eid)
    return combat_engine.faction(eid) == combat_engine.DEFINE.FACTION.PLAYER
  end)
  .map(function(eid)
    return next_state, function()
      return states.action_pick(eid)
    end
  end)
  .listen(table.insert)

  combat_engine.set_available_card(id)
  combat_engine.entity_marker(id)

  while true do
    card_clicked()
    player_clicked()
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
