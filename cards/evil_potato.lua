local card_data = {
  cost = 0,
  name = "Evil Potato",
  image = "evil_potato",
  play = {
    personal = {
      damage = 2,
      card = 2,
      action = 2,
    }
  }
}

function card_data.play.text_compiler(data)
  local card = data.personal.card
  local dmg = data.personal.damage
  local act = data.personal.action
  return string.format("Draw %i card, gain %i action and take %i damage.", card, act, dmg)
end

cards.evil_potato = card_data
