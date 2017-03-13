local card_data = {
  cost = 1,
  name = "Potato",
  image = "potato",
  play = {
    single = {
      damage = 1
    },
    personal = {
      card = 1,
    },
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
  }
}

function card_data.play.text_compiler(data)
  local dmg = data.single.damage
  local card = data.personal.card
  return string.format("A character takes %i damage. Draw %i card.", dmg, card)
end

cards.potato = card_data
