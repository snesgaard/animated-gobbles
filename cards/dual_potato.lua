local card_data = {
  cost = 2,
  name = "Potato Swarm",
  image = "dualpotato",
  play = {
    --personal = {card = 3},
    random = {
      faction = "opponent",
      damage = 1,
      rep = 4,
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
        gravity = -3000,
        time = 0.65,
        distribution = "uniform",
        range = {-500, 500},
      }
    }
  }
}

function card_data.play.text_compiler(data)
  local rep = data.random.rep
  local dmg = data.random.damage
  return string.format("%i random opponents takes %i damage.", rep, dmg)
end

cards.dualpotato = card_data
