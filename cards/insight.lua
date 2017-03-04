local card_data = {
  cost = 1,
  name = "Insight",
  image = "insight",
  play = {
    personal = {card = 1}
  }
}

function card_data.play.text_compiler(data)
  return string.format("Draw %i card.", data.personal.card)
end

cards.insight = card_data
