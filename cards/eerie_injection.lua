local card_data = {
  cost = 2,
  name = "Eerie Injection",
  image = "eerie_injection", --TODO Replace with proper graphics
  description = [[
    Creation of the Holy Ridenberg Company. Invigorates the user with liquidated lifeforce, granted with some side-effects.
  ]],
  play = {
    single = {
      heal = 8,
      regen = -3,
    }
  }
}

function card_data.play.text_compiler(data)
  return string.format(
    "Heal a character for %i and grant %i poison.", data.single.heal,
    -data.single.regen
  )
end

cards.eerie_injection = card_data
