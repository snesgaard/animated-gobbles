local carddata = {
  cost = 0,
  name = "Potion of Forgetfulness",
  image = "potion",
  play = {
    personal = {
      discard = function(user, target)
        return #gamedata.deck.hand[user]
      end,
      card = function(user, target)
        return #gamedata.deck.hand[user]
      end
    }
  }
}

function carddata.play.text_compiler(play)
  return string.format("Discard you hand. Draw cards equal to the number you discarded")
end

cards.potion_of_forgetfulness = carddata
