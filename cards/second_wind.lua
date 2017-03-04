local card_data = {
  cost = 1,
  name = "Second Wind",
  image = "potato",
  play = {
    single = {
      heal = 2
    }
  }
}

function card_data.hand(cardid, userid)
  local res = {}
  res.damage = signal.type(event.core.character.damage)
    .listen(function()
      local data = gamedata.card.effect[cardid]
      data.play.single.heal = data.play.single.heal + 1
      local txt = data.play.text_compiler(data.play)
      return function()
        gamedata.card.text[cardid] = txt
      end
    end)
  return res
end

function card_data.play.text_compiler(play)
  return string.format(
    "Heal a character for %i. Potency increases everytime a character is damaged.", play.single.heal
  )
end

cards.second_wind = card_data
