return {
  core = {
    card = {
      draw = {}, discard = {}, play = {}, begin = {}
    },
    character = {
      damage = {}, heal = {}, select = {},
      -- BUFFS
      power = {}, -- Modifies damage
      armor = {}, -- Modifies taken damage
      regen = {}, -- Heals/damage at the end of your turn
      bleed = {}, -- Heals/damage everytime you take an action
      charge = {}, -- Deals 2.5 damage on next action
      shield = {}, -- Blocks or doubles an attack
      crit = {},
    },
    action = {
      start = {}, stop = {},
    }
  },
  visual = {
    card = {
      clicked = {}, discard = {}, draw = {}, highlight = {}
    },
    character = {
      clicked = {}, damage = {}, heal = {}
    },
    effect = {}
  },
  hitbox = {
    appear = {}
  }
}
