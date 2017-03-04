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

local process_state = {}


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

local function move_cards_to_hand(id, state)
  local cards = concatenate(gamedata.deck.hand[id], state.remainder)
  table.sort(cards, function(a, b) return state.time[a] < state.time[b] end)
  --return function()
  for i, cid in pairs(cards) do
    if cid == state.selected then cards[i] = nil end
  end
  for i, cid in pairs(cards) do
    local fx, fy = hand_position(i)
    --local ix, iy = ix or state.x[cid], iy or state.y[cid]
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
--  end
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
  for _, cid in pairs(gamedata.deck.hand[userid]) do
    state.highlight[cid] = cost_hightlight(cid)
  end

  --move_cards_to_hand(userid, state)
  state.move_cards = true
end

local function initialize(userid)
  local state = {
    draw_pool = lambda_pool.new(),
    animation_pool = lambda_pool.new(),
    x = {},
    y = {},
    highlight = {},
    cards = {},
    remainder = {},
    time = {},
    selected = nil,
    reactions = {},
    scale = {},
    -- Control flags
    move_cards = false
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
      state.time[cardid] = love.timer.getTime()
      return function()
        state.highlight[cardid] = cost_hightlight(cardid)
        --move_cards_to_hand(userid, state)
        state.animation_pool:queue(cardid, function()
          state.y[cardid] = fy
          state.x[cardid] = ix
          state.scale[cardid] = 4
        end)
        state.move_cards = true
      end
    end)
  state.reactions.play = signal.merge(core.card.play)
    .filter(function(id) return id == userid end)
    .map(function(...) return state, ... end)
    .listen(_handle_card_play)
  state.reactions.discard = signal.type(core.card.discard)
    .filter(function(id) return id == userid end)
    .listen(function(id, cardid)
      state.remainder[cardid] = cardid
      state.highlight[cardid] = nil
      return function()
        state.remainder[cardid] = nil
        state.draw_pool:run(
          cardid, cards.animate_fade, cardid, DEFINE.suit, state.x[cardid],
          state.y[cardid], state.scale[cardid], text, {200, 80, 80, 255}
        )
        --move_cards_to_hand(id, state)
        state.move_cards = true
      end
    end)

  local hand = gamedata.deck.hand[userid]
  local t = love.timer.getTime()
  local dt = love.timer.getDelta()
  for i, cardid in pairs(hand) do
    state.x[cardid], state.y[cardid] = hand_position(i)
    state.time[cardid] = t + i * dt * 0.05
    state.scale[cardid] = 4
    state.highlight[cardid] = cost_hightlight(cardid)
  end

  return state
end

function process_state.default(dt, userid, state)
  state = state or initialize(userid)
  while true do
    for _, r in pairs(state.reactions) do r() end

    if state.move_cards then
      move_cards_to_hand(userid, state)
    end
    state.move_cards = false

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
    -- Draw the remainder cards
    for _, cardid in pairs(state.remainder) do
      DEFINE.suit:Button(
        cardid, {
          draw = draw_card_with_highlight,
        }, state.x[cardid], state.y[cardid],
        cards.DEFINE.WIDTH * state.scale[cardid],
        cards.DEFINE.HEIGHT * state.scale[cardid]
      )
    end
    dt = coroutine.yield(hit_card)
  end
end

return process_state.default
