local core = event.core
local visual = event.visual
local highlight = require "combat/ui/highlight"

local DEFINE = {
  DRAW_SPEED = 3000,
  PLAY_SPEED = 1000,
}

local function render_hand(
  userid, hand, highlights, active  -- Control arguments
)
  highlights = highlights or {}
  active = active or {}
  local state = {}
  for i, card_id in pairs(hand) do
    local cost = gamedata.card.cost[card_id]
    local h = highlights[card_id]
    state[card_id] = cards.render(card_id, h)
    -- TODO: Add a card state checler, so e.g. discarded cards can't be clicked
    --if hit and active[card_id] then
      --signal.emit(visual.card.clicked, userid, card_id)
    --end
  end
  return state
end

local function sort_render_cards(cards)
  local x = gamedata.spatial.x
  local render_order = util.deep_copy(cards)
  table.sort(render_order, function(ida, idb)
    return x[ida] > x[idb]
  end)
  return render_order
end

local function create_default_tokens(userid, state)

end

local function create_select_tokens(userid, state)

end

local function hand_position(index)
  return 100 + index * 150, 750
end

local function initialize(userid)
  local pool = lambda_pool.new()
  local state = {
    discarded_cards = {},
    action_build = nil,
    future_actions = queue.new(),
    render_order = {},
    can_click = {},
    highlight = {},
    highlight_func = highlight.pickable(combat_engine.data.action_point),
    render = true,
    pool = lambda_pool.new(),
  }

  local hand = gamedata.deck.hand[userid]
  for i, card in ipairs(hand) do
    local x, y = hand_position(i)
    gamedata.spatial.x[card] = x
    gamedata.spatial.y[card] = y
    --state.highlight[card] = state.highlight_func(card)
  end
  state.render_order = sort_render_cards(hand)

  return state
end

local process_state = {}

function process_state.default(dt, userid, state)
  local function is_user(id) return userid == id end

  state = state or initialize(userid)

  state.highlight_func = highlight.pickable(combat_engine.data.action_point)
  state.highlight = {}
  local hand = gamedata.deck.hand[userid]
  for _, cid in pairs(hand) do
    state.highlight[cid] = state.highlight_func(cid)
  end

  local tokens = {}
  tokens.draw = signal.type(core.card.draw)
    .filter(is_user)
    .listen(function(user, cardid)
      local hand = gamedata.deck.hand[user]
      local x, y = hand_position(#hand)
      state.highlight[cardid] = state.highlight_func(cardid)
      gamedata.spatial.x[cardid] = 2000 + x * 0.25
      gamedata.spatial.y[cardid] = 750
      state.pool:queue(cardid, function(dt, x, y)
        combat.visual.move_to(cardid, x, y, DEFINE.DRAW_SPEED, dt)
      end, x, y)
      state.render_order = sort_render_cards(
        concatenate(hand, state.discarded_cards)
      )
    end)

  while true do
    for _, t in pairs(tokens) do t() end
    state.pool:update(dt)
    local cardstate = render_hand(
      state.user, state.render_order, state.highlight, state.can_click
    )
    local hand = gamedata.deck.hand[userid]
    local selected_card
    for i = #hand, 1, -1 do
      local card = hand[i]
      if cardstate[card] and gamedata.card.cost[card] <= combat_engine.data.action_point then
        selected_card = selected_card or i
      end
      -- Emit clicked signal
    end
    dt = coroutine.yield(selected_card)
    if selected_card then
      local cardid = hand[selected_card]
      return process_state.selected(dt, userid, cardid, state)
    end
  end
end

function process_state.selected(dt, userid, card, state)
  local function is_user(id) return userid == id end

  state.highlight_func = highlight.selected(card)
  state.highlight = {}
  for _, cid in pairs(state.render_order) do
    state.highlight[cid] = state.highlight_func(cid)
  end
  local flags = {}
  local tokens = {}
  tokens.exit = signal.merge(
    signal.type("mousepressed").filter(function(_, _, b) return b == 2 end),
    signal.type(event.core.card.play)
      .filter(is_user)
      .filter(function(user, _card)
        return card == _card
      end)
  ) .listen(function()
    flags.terminate = true
  end)
  tokens.play = signal.type(core.card.play)
    .filter(is_user)
    .listen(function(user, cardid)
      local hand = gamedata.deck.hand[user]
      state.discarded_cards[cardid] = cardid
      for i, card in pairs(hand) do
        state.pool:queue(card, function(dt)
          local x, y = hand_position(i)
          combat.visual.move_to(card, x, y, DEFINE.PLAY_SPEED, dt)
        end)
      end
      state.pool:queue(cardid, function()
        local x = gamedata.spatial.x[cardid]
        local y = gamedata.spatial.y[cardid]
        combat.visual.move_to(cardid, x, y - 100, 250, dt)
        state.discarded_cards[cardid] = nil
        state.render_order = sort_render_cards(
          concatenate(hand, state.discarded_cards)
        )
      end)
      state.render_order = sort_render_cards(
        concatenate(hand, state.discarded_cards)
      )
    end)
  tokens.draw = signal.type(core.card.draw)
    .filter(is_user)
    .listen(function(user, cardid)
      local hand = gamedata.deck.hand[user]
      local x, y = hand_position(#hand)
      gamedata.spatial.x[cardid] = 2000 + x * 0.25
      gamedata.spatial.y[cardid] = 750
      state.pool:queue(cardid, function(dt, x, y)
        combat.visual.move_to(cardid, x, y, DEFINE.DRAW_SPEED, dt)
      end, x, y)
      state.render_order = sort_render_cards(
        concatenate(hand, state.discarded_cards)
      )
    end)


  while true do
    for _, t in pairs(tokens) do t() end
    state.pool:update(dt)
    render_hand(
      state.user, state.render_order, state.highlight, state.can_click
    )
    dt = coroutine.yield()
    if flags.terminate then
      return process_state.default(dt, userid, state)
    end
  end
end

return process_state.default
