local card_data = {
  cost = 2,
  name = "Invasive Surgery",
  image = "invasive_surgery", -- TODO Replace with graphics
  play = {
    single = {
      damage = 5,
      regen = 3,
    }
  }
}

function card_data.play.text_compiler(data)
  local damage = data.single.damage
  local regen = data.single.regen
  return string.format(
    "Deal %i damage and grant %i regen to a character.", damage, regen
  )
end

cards.invasive_surgery = card_data
