local card_data = {
  cost = 1,
  name = "Bulwark",
  image = "bulwark",
  play = {
    personal = {
      armor = 2,
      shield = 1
    }
  }
}

function card_data.play.text_compiler(play)
  return string.format(
    "Gain %i armor and %i shield.", play.personal.armor, play.personal.shield
  )
end

cards.bulwark = card_data
