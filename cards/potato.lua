
local function _play(userid, pile, index)
  local pick_coroutine = coroutine.create(combat_engine.pick_single_target)
  return signal.from_value()
  .map(pick_coroutine)
  .any()
  .fork(
    signal.from_value()
      .map(function(tid)
        local dmg = gamedata.combat.damage[tid] or 0
        dmg = dmg + 1
        gamedata.combat.damage[tid] = dmg
        return userid, tid, 1
      end)
      .map(combat.visual.melee_attack)
      .listen(combat_engine.add_event),
    signal.from_value()
      .map(function() return userid, pile, index end)
      .listen(combat_engine.events.card.play),
    signal.from_value()
      .map(function() return userid end)
      .listen(combat.mechanic.draw_card)
  )
end

function cards.potato(gd, id)
  gd.card.cost[id] = 1
  gd.card.text[id] = "Deal 1 damage to any character. Draw a card.\n\nPassive:\nAt the start of your turn, heal for 1."
  gd.card.name[id] = "Potato"
  gd.card.play[id] = _play
  gd.card.image[id] = "potato"

  local function id_filter(cardid) return cardid == id end

  local damage = 1
  local draw = 1
  gd.card.effects[id] = {
    signal.type(combat_engine.events.card.request_play)
      .filter(id_filter)
      .listen(combat_engine.events.target.single.any),
    --[[
    signal.type("play")
      .filter(id_filter)
      .map(function(cardid, userid, targetid) return userid, targetid, damage end)
      .listen(combat_engine.attack),
    signal.type("play")
      .filter(id_filter)
      .map(function(cardid, userid) return userid, draw end)
      .listen(combat_engine.draw_card)
    ]]--
  }
end
