local highlight = {}

function highlight.selected(selected_id)
  return function(cardid)
    if cardid == selected_id then return {0, 0, 100, 200} end
  end
end
function highlight.pickable(action_points)
  return function(cardid)
    local cost = gamedata.card.cost[cardid]
    if cost <= action_points then return {0, 200, 0, 200} end
  end
end

return highlight
