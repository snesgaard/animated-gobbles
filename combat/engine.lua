require "deck"
local pool = require "lambda_pool"
local sprite = require "sprite"
local ui = {
  stat = require "combat/ui/character_stat",
  player = require "combat/ui/player",
  turn = require "combat/ui/turn",
  popup = require "combat/ui/icon_popup"
}
local common = require "combat/ui/common"

function draw_engine.ui.screen.ui_suit()
  common.screen_suit:draw()
end

local DEFINE = {
  STARTING_CARDS = 5,
  ACTION_PR_TURN = 4,
  FACTION = {PLAYER = "player", ENEMY = "enemy"}
}

local engine = {}


local function create_faction_handle(party, enemies)
  local e2f = {}
  for _, id in pairs(party) do e2f[id] = DEFINE.FACTION.PLAYER end
  for _, id in pairs(enemies) do e2f[id] = DEFINE.FACTION.ENEMY end
  return function(id)
    return type(id) == "number" and e2f[id] or id
  end
end

local function turn(dt, state, characters, action)
  engine.pool.ui:run()
end

local function handle_play(
  dt, handle, party, party_script, enemies, enemy_script
)
  local turn_start_data = {
    personal = {card = 1}
  }
  local turn_start_control = {
    confirm_cast = function(arg) return arg end
  }
  while true do
    handle.change_action(DEFINE.FACTION.PLAYER, DEFINE.ACTION_PR_TURN)
    handle.add_battle_event(function()
      for _, id in pairs(party) do
        local seq = combat.parse_play(
          handle, id, turn_start_data, turn_start_control
        )
        handle.add_visual_seq(seq)
      end
    end)
    handle.pool.ui:run(
      "turn_pane", ui.turn, handle, DEFINE.FACTION.PLAYER, DEFINE.FACTION.ENEMY
    )
    party_script(dt, handle, party, enemies)
  end
end

local function initialize(party, enemies)
  local _all = concatenate(party, enemies)
  map(function(id)
    gamedata.deck.hand[id] = {}
    gamedata.deck.discard[id] = {}

    gamedata.deck.draw[id] = map(function(card_data)
      return initresource(gamedata, cards.init, card_data)
    end, gamedata.combat.collection[id] or {})

    deck.shuffle(id, gamedata.deck.draw)
    for i = 1, DEFINE.STARTING_CARDS do
      deck.transfer(id, gamedata.deck.draw, gamedata.deck.hand)
    end
    gamedata.combat.damage[id] = nil
  end, _all)

  local state = {
    actor = {party = party, enemies = enemies},
  }

  local handle = {
    action_point = {[DEFINE.FACTION.PLAYER] = 0, [DEFINE.FACTION.ENEMY] = 0}
  }
  function handle.get_action(id)
    return handle.action_point[handle.faction(id)]
  end
  function handle.set_action(id, val)
    handle.action_point[handle.faction(id)] = val
  end
  function handle.change_action(id, val)
    local f = handle.faction(id)
    local a = handle.action_point[f]
    handle.action_point[f] = math.max(a + val, 0)
  end
  function handle.can_play(id, cardid)
    local a = handle.get_action(id)
    local c = gamedata.card.cost[cardid]
    -- TODO: Possibly add card-based conditionals
    return a >= c
  end

  handle.faction = create_faction_handle(party, enemies)
  function handle.add_visual_seq(seq)
    handle.pool.visual:queue("seq", seq)
  end
  function handle.add_battle_event(e, ...)
    handle.pool.battle:queue("event", e, ...)
  end
  handle.pool = {
    visual = pool.new(),
    battle = pool.new(),
    sprite = pool.new(),
    ui = pool.new(),
  }
  handle.DEFINE = DEFINE

  -- Now start the various routines
  for _, id in pairs(_all) do
    handle.pool.sprite:queue(id, gamedata.visual.idle[id], sprite.entity_center(id))
  end
  --state.pool.ui:run("turn_script", ui.player, party)
  -- Start all related UI
  for _, id in pairs(_all) do
    handle.pool.ui:run(id, ui.stat, handle, id)
  end
  handle.pool.ui:run("popup", ui.popup)
  handle.pool.battle:run("turn", handle_play, handle, party, ui.player, enemies)

  return state, handle
end

function engine.battle(dt, party, enemies)

  local state, handle = initialize(party, enemies)

  while true do
    for _, key in pairs({"battle", "visual", "sprite", "ui"}) do
      handle.pool[key]:update(dt)
    end
    dt = coroutine.yield()
  end
end

return engine
