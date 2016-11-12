local data = {
  cost = 1,
  name = "Potato",
  image = "potato",
  play = {
    single = {damage = 3},
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

function data.play.text_compiler(id)
  local dmg = gamedata.effect.damage[id]
  local card = gamedata.effect.card[id]
  return string.format("A character takes %i damage. Draw %i card.", dmg, card)
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
