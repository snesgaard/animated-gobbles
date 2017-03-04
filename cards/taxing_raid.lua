local card_data = {
  name = "Taxing Raid",
  cost = 1,
  image = "potato",
  play = {
    single = {
      damage = function(user, target)
        return #gamedata.deck.hand[target]
      end
    }
  }
}

function card_data.play.text_compiler(play)
  return "Deal damage to a character equal to the number of cards in their hand."
end

cards.taxing_raid = card_data
