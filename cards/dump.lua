cards = cards or {}

local function activate(id, userid)
  local activate_stream = combat_engine.state.card.selected
    :filter(function(cid) return cid == id end)

  activate_stream
    :map(function(id, userid, pile, card)
      local _deck = combat_engine.state.decks[userid]
      return userid, deck.draw(_deck, "draw")
    end)
    :subscribe(combat_engine.event.card.draw)
  activate_stream
    :subscribe(function(...) combat_engine.event.card.play:onNext(...) end)
  --activate_stream
  --  :subscribe(function(_, userid)
  --    combat_engine.event.general.turn_start:onNext(userid)
  --  end)

  -- Display text "Select target"
end

function cards.dump(gd, id, userid)
  cards.generic_init(gd, id)
  local str = ""
  str = str .. "Draw 3 cards.\n"
  gamedata.card.text[id] = str
  local atlas, anime = cards.get_gfx()
  gamedata.card.image[id] = function() return anime.potato end
  gamedata.card.activate[id] = activate
  gamedata.card.name[id] = "Recycle"
  gamedata.card.cost[id] = 0
  activate(id, userid)
end
