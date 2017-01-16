local event = require "combat/event"



local card_data = {
  cost = 1,
  name = "Fury",
  image = "fury",
  play = {
    single = {damage = 1},
    visual = {
      animation = {
        type = "projectile",
        sprite = "potato",
        gravity = -1000,
        time = 0.65,
      },
      on_hit = {
        type = "bounce",
        sprite = "potato",
        gravity = -1000,
        time = 0.65,
        distribution = "uniform",
        range = {-50, 50},
      }
    }
  },
}

function card_data.react(cardid, userid)
  local res = {}
  res.damage = signal.type(event.core.character.damage)
    .listen(function()
      local data = gamedata.card.effect[cardid]
      data.play.single.damage = data.play.single.damage + 1
      local txt = data.play.text_compiler(data.play)
      return function()
        gamedata.card.text[cardid] = txt
      end
    end)
  res.reset = signal.merge(event.core.card.play,event.core.card.draw)
    .filter(function(_userid, _cardid) return _cardid == cardid end)
    .listen(function()
      local data = gamedata.card.effect[cardid]
      data.play.single.damage = 1
      local txt = data.play.text_compiler(data.play)
      gamedata.card.text[cardid] = txt
    end)
  return res
end

function card_data.play.text_compiler(data)
  local dmg = data.single.damage
  return string.format("A character takes %i damage.\nWhenever a character is damaged, potency is increased.", dmg)
end

cards.fury = card_data
