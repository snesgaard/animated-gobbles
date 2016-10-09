local gfx = love.graphics

combat_engine = {
  script = {}, subroutines = {}, data = {}, events = {}, resource = {}
}

local combat_suit = suit.new()
local world_suit = suit.new()

combat_engine.resource = {
  turn_ui_font = gfx.newFont(50)
}

combat_engine.data = {
  party = {},
  enemy = {},
  turn_order = {},
  current_turn = 1,
  action_point = 4,
  decks = {},
  script = {},
}

combat_engine.subroutines = {
  hand, -- Event handling and ui render of current hand
  turn_order, -- Rendering of turn order_ui and handling
  turn_ui, -- Renders which turn it is and how many points said turn have left
  script, -- Script for the current entity
}

combat_engine.events = {
  card = {
    clicked = {}, request_play = {}, play = {}, discard = {}
  },
  target = {
    multi = {
      allies = {}, enemies = {}, any = {}
    },
    single = {
      allies = {}, enemies = {}, any = {}, personal = {}
    },
    random = {
      allies = {}, enemies = {}, any = {},
    }
  },
  confirm = {}
}

-- Specific functions
local subroutines_creator = {}

-- Defines
local DEFINE = {
  HIGHLIGHT = {
    PICKABLE = {0, 200, 0, 200},
    SELECTABLE = {200, 200, 0, 200},
    SELECTED = {0, 0, 100, 200},
  }
}

local function _draw_target_border(id, opt, x, y, w, h)
  gfx.stencil(function()
    gfx.rectangle("fill", x, y, w, h)
  end, "replace", 1)
  gfx.setStencilTest("equal", 0)
  gfx.setLineWidth(6)
  gfx.polygon("line", x, y, x + w * 0.1, y, x, y + h * 0.1)
  gfx.polygon("line", x + w, y + h, x + w * 0.9, y + h, x + w, y + h * 0.9)
  gfx.polygon("line", x, y + h, x + w * 0.1, y + h, x, y + h * 0.9)
  gfx.polygon("line", x + w, y, x + w * 0.9, y, x + w, y + h * 0.1)
end

function combat_engine.pick_single_target()
  local function _draw(id)
    local x, y = gamedata.spatial.x[id], gamedata.spatial.y[id]
    local w, h = gamedata.spatial.width[id], gamedata.spatial.height[id]

    local ix, iy = camera.transform(camera_id, level, x - w, y - h)
    local ex, ey = camera.transform(camera_id, level, x + w, y + h)
    return world_suit:Button(
      id, {draw = _draw_target_border} , ix, ey, ex - ix, iy - ey
    )
  end
  local function _finisher(_hit_id)
    coroutine.yield(_hit_id)
    return _finisher(_hit_id)
  end
  while true do
    --world_suit.layout:reset(0, 0)
    local pui = map(_draw, combat_engine.data.party)
    local eui = map(_draw, combat_engine.data.enemy)

    for i, ui in pairs(pui) do
      if ui.hit then return _finisher(combat_engine.data.party[i]) end
    end
    for i, ui in pairs(eui) do
      if ui.hit then return _finisher(combat_engine.data.enemy[i]) end
    end
    coroutine.yield()
  end
end

function combat_engine.set_selected_card(id, i, card_id)
  combat_engine.subroutines.hand = subroutines_creator.show_hand{
    id, true,
    highlight = function(id)
      if id == card_id then
        return DEFINE.HIGHLIGHT.SELECTED
      end
    end
  }
end

function combat_engine.set_available_card(id)
  combat_engine.subroutines.hand = subroutines_creator.show_hand{
    id, true,
    highlight = function(id)
      if gamedata.card.cost[id] <= combat_engine.data.action_point then
        return DEFINE.HIGHLIGHT.PICKABLE
      end
    end
  }
end

function combat_engine.round(c)
  local id = combat_engine.data.turn_order[c]
  local s = combat_engine.data.script[id]
  return s(id)
end

function combat_engine.next_round()
  local c = combat_engine.data.current_turn
  combat_engine.data.current_turn = c < #data.turn_order and c + 1 or 1
  return combat_engine.round(data.current_turn)
end

local function _show_hand(
  id, do_hover, highlights -- Control arguments
)
  highlights = highlights or {}
  local hand = combat_engine.data.decks[id].hand
  for i, card_id in pairs(hand) do
    gamedata.spatial.x[card_id] = 40 + (#hand + 1 - i  - 1) * 180
    gamedata.spatial.y[card_id] = 750
  end
  local _do_hover = do_hover
  for i, card_id in pairs(hand) do
    local cost = gamedata.card.cost[card_id]
    --local h = cost <= combat_engine.data.action_point and DEFINE.HIGHLIGHT.SELECTED or nil
    local h = highlights[i]
    local hit = cards.render(card_id, _do_hover, h)
    -- _do_hover = _do_hover and not card_ui.hovered
    if hit then
      signal.emit(combat_engine.events.card.clicked, i, card_id)
    end
  end
  coroutine.yield()
  return _show_hand(id, do_hover, highlights)
end

function subroutines_creator.show_hand(args)
  local id = args[1] or args.id
  local hover = args.hover or true
  local selected = args.selected
  local light_fun = args.highlight or function() end
  local highlight = map(light_fun, combat_engine.data.decks[id].hand)

  return coroutine.create(function(dt)
    return _show_hand(id, hover, highlight)
  end)
end

function subroutines_creator.show_turn(type)
  local color = {
      normal  = {bg = { 0, 0, 255}, fg = {255,255,188}},
      hovered = {bg = { 50,153,187}, fg = {0,0,255}},
      active  = {bg = {255,153,  0}, fg = {0,0,225}}
  }
  if type == "Player" then
    color.base = {80, 120, 250, 255}
  elseif type == "Enemy" then
    color.base = {200, 20, 50, 255}
  elseif type == "Neutral" then
    color.base = {20, 150, 50, 255}
  else
    error("Unknown turn type provided: " .. type)
  end
  local function corner_draw(_, opt, x, y, width, height)
    gfx.setColor(unpack(color.base))
    gfx.polygon("fill", x, y, x + width, y, x + width, y + height)
  end
  local function point_draw(_, opt, x, y, width, height)
    gfx.setColor(unpack(color.normal.fg))
    local num = opt.number
    gfx.setLineWidth(2)
    gfx.circle("line", x + width, y, width + 1, 20)
    if num <= combat_engine.data.action_point then
      local r, g, b = unpack(color.base)
      gfx.setColor(r, g, b)
      gfx.setLineWidth(1)
      gfx.circle("fill", x + width, y, width, 20)
    end
  end
  local function label_draw(text, opt, x,y,w,h)
    local r, g, b = unpack(color.base)
    gfx.setColor(r, g, b)
    --gfx.rectangle("fill", x, y, w, h)
    local margin = 20
    local poly_line = {
      x, y + h * 0.5,
      x + margin, y,
      x + w - margin, y,
      x + w, y + h * 0.5,
      x + w - margin, y + h,
      x + margin, y + h
    }
    gfx.polygon("fill", unpack(poly_line))
    suit.theme.Label(text, opt, x,y,w,h)
    gfx.polygon("line", unpack(poly_line))
  end
  local function _show_turn()
    local gfx_w = gfx:getWidth() - 50
    local w = 380
    local h = 75
    combat_suit.layout:reset(gfx_w - w, 10)
    combat_suit:Label(
      type, {
        font = combat_engine.resource.turn_ui_font, color = color, align = "center",
        draw = label_draw
      },
      combat_suit.layout:col(w, h)
    )
    --combat_suit:Button(
    --  "corner_triangle", {draw = corner_draw}, combat_suit.layout:col(100, h)
    --)
    combat_suit.layout:reset(gfx_w - w, h + 35, 25, 20)
    --combat_suit.layout:padding(10, 10)
    for i = 1,10 do
      combat_suit:Button(
        "corner_triangle", {draw = point_draw, number = i},
        combat_suit.layout:col(15, 10)
      )
    end

    coroutine.yield()
    return _show_turn()
  end
  return coroutine.create(_show_turn)
end

local function _set_selected_card(id, i, card_id)
  combat_engine.subroutines.hand = subroutines_creator.show_hand{
    id, true,
    highlight = function(id)
      if id == card_id then
        return DEFINE.HIGHLIGHT.SELECTED
      end
    end
  }
end

local function _set_available_card(id, i, card_id)
  combat_engine.subroutines.hand = subroutines_creator.show_hand{
    id, true,
    highlight = function(id)
      if gamedata.card.cost[id] <= combat_engine.data.action_point then
        return DEFINE.HIGHLIGHT.PICKABLE
      end
    end
  }
end

local function _player_turn(id)
  local queue = {}
  local token = {}
  token.click = signal.type(events.card.clicked)
    .filter(function(i, id)
      return gamedata.card.cost[id] <= combat_engine.data.action_point
    end)
    .map(function(...) return _set_selected_card, {...} end)
    .listen(queue)
  token.release = signal.type("mouse")
    .filter(function(_, _, button) return button == 2 end)
    .map(function(...) return _set_available_card, {...} end)
    .listen(queue)
  while true do
    for _, f in pairs(token) do f() end
    coroutine.yield()
    for i, pack in pairs(queue) do
      local f = pack[1]
      local arg = pack[2]
      f(id, unpack(arg))
      queue[i] = nil
    end
  end
end


function subroutines_creator.player_turn(id)
  return coroutine.create(function() _player_turn(id) end)
end

function combat_engine.begin(allies, enemies)
  -- Initialize card pool
  local all_ids = {}
  for _, id in pairs(allies) do table.insert(all_ids, id) end
  for _, id in pairs(enemies) do table.insert(all_ids, id) end

  for _, id in pairs(all_ids) do
    combat_engine.data.decks[id] = deck.create()
    local collection = gamedata.combat.collection[id] or {}
    combat_engine.data.decks[id].draw = map(function()
      return cards.init{ui_init = cards.potato}
    end,
      collection
    )
    deck.shuffle(combat_engine.data.decks[id], "draw")
    combat_engine.data.script[id] = combat_engine.player_script
    local draw_size = deck.size(combat_engine.data.decks[id], "draw")
    for i = 1, math.min(draw_size, 10) do
      local card_id = deck.draw(combat_engine.data.decks[id], "draw")
      deck.insert(combat_engine.data.decks[id], "hand", card_id)
    end
  end
  combat_engine.data.turn_order = all_ids
  combat_engine.data.current_turn = 0
  -- Hacked
  combat_engine.subroutines.hand = subroutines_creator.show_hand{
    all_ids[1], true,
    highlight = function(id)
      if gamedata.card.cost[id] <= combat_engine.data.action_point then
        return DEFINE.HIGHLIGHT.PICKABLE
      end
    end
  }
  combat_engine.subroutines.turn_ui = subroutines_creator.show_turn("Player")
  combat_engine.subroutines.script = coroutine.create(
    function()
      return combat_engine.script.player(all_ids[1])
    end
  )

  combat_engine.data.party = allies
  combat_engine.data.enemy = enemies

  draw_engine.ui.screen.combat = combat_engine.draw
  draw_engine.ui.world.combat = function()
--    world_suit:draw()
  end
end

local _event_handlers = {
  signal.type(combat_engine.events.card.play)
  --.map(function())
}

function combat_engine.handle_events()

end

function combat_engine.update(dt)
  -- Update card effects
  for _, id in pairs(combat_engine.data.party) do
    local hand = combat_engine.data.decks[id].hand
    for _, cardid in pairs(hand) do
      local effects = gamedata.card.effects[cardid]
      for _, e in pairs(effects) do e() end
    end
  end
  -- Update subroutines
  for id, co in pairs(combat_engine.subroutines) do
    if co then
      local ret, msg = coroutine.resume(co, dt)
      --print(id, ret)
      if not ret then
        subroutines[id] = nil
      end
    end
  end
end

function combat_engine.draw()
  combat_suit:draw()
  world_suit:draw()
end

require "combat/player_script"
