local gfx = love.graphics
local hand_ui = require "combat/ui/hand"
local theme = require "combat/ui/theme"
local common = require "combat/ui/common"
local menu = require "combat/ui/menu"

local player_suit = common.screen_suit

local marker_shader = common.marker_shader
local marker_quad = common.quad_mesh

local render_marker = common.render_marker

local function click_detect(x, y, player_list)
  local function hit_detect(id)
    local px, py = gamedata.spatial.x[id], gamedata.spatial.y[id]
    local pw, ph = gamedata.spatial.width[id], gamedata.spatial.height[id]

    local ix, ey = camera.transform(camera_id, level, px - pw, py - ph)
    local ex, iy = camera.transform(camera_id, level, px + pw, py + ph)

    return x > ix and y > iy and x < ex and y < ey
  end
  local pui = map(hit_detect, player_list)
  for i, hit in pairs(pui) do
    if hit then return player_list[i] end
  end
end

local function initialize(player_list)
  return {
    selected_player = player_list[1],
    card_co = coroutine.create(hand_ui),
    card_play_co = {}
  }
end

local function draw()
  player_suit:draw()
end

return function(dt, player_list, state)
  state = state or initialize(player_list)
  --draw_engine.ui.screen.player_ui = draw
  local tokens = {}
  tokens.mouse_left = signal.type("mousepressed")
    .filter(function(_, _, b) return b == 1 end)
    .filter(function()
      return not lambda.status(state.card_play_co)
    end)
    .map(function(x, y)
      return click_detect(x, y, player_list)
    end)
    .any()
    .listen(function(selected_id)
      state.selected_player = selected_id
      state.card_co = coroutine.create(hand_ui)
    end)
  tokens.cancel = signal.type("mousepressed")
    .filter(function(_, _, b) return b == 2 end)
    .listen(function()
      lambda.stop(state.card_play_co)
    end)
  while not state.terminate do
    for _, t in pairs(tokens) do t() end
    local menu_state = menu(
      {"Attack", "Defend", "End Turn"}, 20, 750, 200, 40
    )
    render_marker(state.selected_player, theme.player)
    _, card = coroutine.resume(state.card_co, dt, state.selected_player)
    if card and not lambda.status(state.card_play_co) then
      local function f(dt, id, pile, index)
        local control = {
          confirm_cast = function()
            combat_engine.confirm_cast(id, pile, index)
          end,
          pick_single_target = combat_engine.pick_single_target
        }
        combat.parse_card_play(id, pile, index, control)
      end
      lambda.run(
        state.card_play_co, f, state.selected_player, gamedata.deck.hand, card
      )
    end
    dt = coroutine.yield()
    if menu_state["End Turn"].hit and not lambda.status(state.card_play_co) then
      --combat_engine.data.action_point = 0
      state.terminate = true
    end
  end
end
