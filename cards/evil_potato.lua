local function _play(userid, pile, index)
  local co = coroutine.create(combat_engine.confirm_cast)
  return signal.from_value()
    .map(function() return userid, pile, index end)
    .map(co).any()
    .fork(
      signal.from_value()
        .map(function() return userid, pile, index end)
        .listen(combat_engine.events.card.play),
      signal.from_value()
        .map(function() return userid end)
        .listen(combat.mechanic.draw_card),
      signal.from_value()
        .map(function()
          local pow = 2
          local dmg = gamedata.combat.damage[userid] or 0
          dmg = dmg + pow
          gamedata.combat.damage[userid] = dmg
          return userid, userid, pow
        end)
        .map(combat.visual.melee_attack)
        .listen(combat_engine.add_event)
    )
end

function cards.evil_potato(gd, id)
  gd.card.cost[id] = 0
  gd.card.text[id] = "Deal 2 damage to self. Draw a card."
  gd.card.name[id] = "Evil Potato"
  gd.card.play[id] = _play
  gd.card.image[id] = "evil_potato"

  local function id_filter(cardid) return cardid == id end

  local damage = 1
  local draw = 1
  gd.card.effects[id] = {}
end
