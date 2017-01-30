local core = event.core
local visual = event.visual
local highlight = require "combat/ui/highlight"
local common = require "combat/ui/common"
local x_suit = require "combat/ui/x_suit"

local DEFINE = {
  DRAW_SPEED = 3000,
  PLAY_SPEED = 1000,
  PLAY_X = 800,
  PLAY_Y = 150,
  PLAY_SCALE = 6,
  SHOW_TIME = 0.2,
  suit = x_suit()
}

function draw_engine.ui.screen.hand()
  DEFINE.suit:draw()
end

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
    DEFINE.suit:Button("eh", 0, 0, 10, 10)
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

local function draw_card_with_highlight(cardid, opt, x, y, w, h)
  if opt.highlight then
    gfx.setColor(unpack(opt.highlight))
    cards.suit_highlight(cardid, opt, x, y, w, h)
  end
  gfx.setColor(255, 255, 255)
  cards.suit_draw(cardid, opt, x, y, w, h)
end

local function cost_hightlight(cardid)
  if gamedata.card.cost[cardid] <= combat_engine.data.action_point then
    return {0, 255, 0, 200}
  end
end

local function _handle_card_play(state, userid, cardid, target, representation)
  local x = state.x[cardid]
  local y = state.y[cardid]
  local s = state.scale[cardid]
  local text = gamedata.card.text[cardid]
  state.scale[cardid] = nil
  state.selected = nil
  state.draw_pool:run(
    cardid, cards.animate_fade, representation or cardid, DEFINE.suit, x, y, s,
    text
  )

  local hand = gamedata.deck.hand[userid]
  for i, cid in pairs(hand) do
    local fx, fy = hand_position(i)
    local ix, iy = state.x[cid] or fx, state.y[cid] or fy
    state.highlight[cid] = cost_hightlight(cid)
    local function f(t)
      local ix, iy = state.x[cid] or fx, state.y[cid] or fy
      while true do
        state.x[cid] = fx * t + ix * (1 - t)
        state.y[cid] = fy * t + iy * (1 - t)
        t = coroutine.yield()
      end
    end
    state.animation_pool:queue(cid, util.gerp, 0.2, coroutine.wrap(f))
  end
end

local function initialize(userid)
  local state = {
    draw_pool = lambda_pool.new(),
    animation_pool = lambda_pool.new(),
    x = {},
    y = {},
    highlight = {},
    card = {},
    selected = nil,
    reactions = {},
    scale = {},
  }

  state.reactions.cancel = signal.type("mousepressed")
    .filter(function(_, _, b)
      return state.selected and b == 2
    end)
    .listen(function()
      state.selected = nil
      state.highlight = {}
      local hand = gamedata.deck.hand[userid]
      for i, cardid in pairs(hand) do
        local ix, iy, is = state.x[cardid], state.y[cardid], state.scale[cardid]
        local fx, fy = hand_position(i)
        local fs = 4
        state.highlight[cardid] = cost_hightlight(cardid)
        local function f(t)
          local ix, iy, is = state.x[cardid], state.y[cardid], state.scale[cardid]
          while true do
            state.x[cardid] = fx * t + ix * (1 - t)
            state.y[cardid] = fy * t + iy * (1 - t)
            if is then
              state.scale[cardid] = fs * t + is * (1 - t)
            end
            t = coroutine.yield()
          end
        end
        state.animation_pool:queue(cardid, util.gerp, 0.2, coroutine.wrap(f))
      end
    end)
  state.reactions.draw = signal.type(core.card.draw)
    .filter(function(id) return id == userid end)
    .listen(function(userid, cardid)
      local deck_size = deck.size(userid, gamedata.deck.hand)
      local fx, fy = hand_position(deck_size)
      local ix = 2000
      return function()
        state.y[cardid] = fy
        state.scale[cardid] = 4
        if not state.selected then
          state.highlight[cardid] = cost_hightlight(cardid)
        end
        local function f(t)
          fx = state.x[cardid] or fx
          while true do
            state.x[cardid] = fx * t + ix * (1 - t)
            t = coroutine.yield()
          end
        end
        state.animation_pool:queue(cardid, util.gerp, 0.2, coroutine.wrap(f))
      end
    end)
  state.reactions.play = signal.type(core.card.play)
    .filter(function(id) return id == userid end)
    .map(function(...) return state, ... end)
    .listen(_handle_card_play)

  local hand = gamedata.deck.hand[userid]
  for i, cardid in pairs(hand) do
    state.x[cardid], state.y[cardid] = hand_position(i)
    state.scale[cardid] = 4
    state.highlight[cardid] = cost_hightlight(cardid)
  end

  return state
end

function process_state.default(dt, userid, state)
  state = state or initialize(userid)
  while true do
    for _, r in pairs(state.reactions) do r() end
    state.animation_pool:update(dt)
    state.draw_pool:update(dt)
    local hand = gamedata.deck.hand[userid]
    local cardstate = map(
      function(cardid)
        if state.scale[cardid] then
          return DEFINE.suit:Button(
            cardid, {
              draw = draw_card_with_highlight,
              highlight = state.highlight[cardid],
            }, state.x[cardid], state.y[cardid],
            cards.DEFINE.WIDTH * state.scale[cardid],
            cards.DEFINE.HEIGHT * state.scale[cardid]
          )
        else
          return {}
        end
      end,
      gamedata.deck.hand[userid]
    )
    local function search_for_hit(cardstate)
      for i = #cardstate, 1, -1 do
        if cardstate[i].hit then return i end
      end
    end
    local hit_card = search_for_hit(cardstate)
    if hit_card and not state.selected then
      state.selected = hit_card
      local cardid = deck.peek(userid, gamedata.deck.hand, hit_card)
      state.highlight = {[cardid] = {0, 0, 255, 200}}
      local ix, iy, is = state.x[cardid], state.y[cardid], state.scale[cardid]
      local fx, fy, fs = DEFINE.PLAY_X, DEFINE.PLAY_Y, DEFINE.PLAY_SCALE
      state.animation_pool:run(cardid, util.gerp, 0.2, function(t)
        state.x[cardid] = fx * t + ix * (1 - t)
        state.y[cardid] = fy * t + iy * (1 - t)
        state.scale[cardid] = fs * t + is * (1 - t)
      end)
    else
      hit_card = nil
    end
    dt = coroutine.yield(hit_card)
  end
end

return process_state.default
