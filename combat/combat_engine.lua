require "ui"
require "deck"
require "combat/visual"
require "combat/mechanic"
require "combat/parser"

local gfx = love.graphics

combat_engine = {
  script = {}, subroutines = {}, data = {}, events = {}, resource = {}
}

combat_engine.DEFINE = {
  FACTION = {PLAYER = "player", ENEMY = "enemy"}
}

local combat_suit = suit.new()
local world_suit = suit.new()

combat_engine.resource = {
  turn_ui_font = gfx.newFont(50),
  pick_font = gfx.newFont(35),
  health_font = gfx.newFont(20),
  theme = {
    player = {
      normal = {bg = {255, 255, 255}, fg = {80, 80, 200}}
    },
    enemy = {
      normal = {bg = {255, 255, 255}, fg = {200, 20, 50}}
    },
    health = {
      high = {0, 255, 0}, medium = {255, 255, 0}, low = {255, 0, 0}
    }
  },
  lambda_token = {
    entity_marker = {}, event_queue = {}
  },
  shader = {},
  mesh = {},
  suit = {world = world_suit}
}

combat_engine.data = {
  party = {},
  enemy = {},
  faction = {},
  turn_order = {},
  current_turn = 1,
  action_point = 4,
  decks = {},
  script = {},
  event_queue = {}
}

combat_engine.ui = {
  health = {}, draw = {}, discard = {}
}

function loader.combat_engine()
  combat_engine.resource.shader.entity_marker = loadshader(
    "resource/shader/entity_marker.glsl"
  )
  local vert = {
    {1, 0, 1, 0},
    {0, 0, 0, 0},
    {0, 1, 0, 1},
    {1, 1, 1, 1},
  }
  combat_engine.resource.mesh.quad = gfx.newMesh(vert, "fan")
end

local function _get_uid(tab, id)
  local _uid = tab[id]
  if not _uid then
    _uid = {}
    tab[id] = _uid
  end
  return _uid
end

combat_engine.subroutines = {
  hand, -- Event handling and ui render of current hand
  turn_order, -- Rendering of turn order_ui and handling
  turn_ui, -- Renders which turn it is and how many points said turn have left
  script, -- Script for the current entity
}

combat_engine.events = {
  card = {
    clicked = {}, request_play = {}, play = {}, discard = {}, draw = {}
  },
  target = {
    multi = {
      player = {}, enemy = {}, any = {}
    },
    single = {
      player = {}, enemy = {}, any = {},
    },
    random = {
      player = {}, enemy = {}, any = {},
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

function combat_engine.play_card(userid, pile, index)
  local card_data = {
    cost = 1,
    name = "Potato",
    image = "potato",
    play = {
      single = {damage = 2},
      personal = {card = 1},
      visual = {
        type = "projectile",
        projectile = {
          sprite = "potato",
          gravity = -1000,
          time = 0.65,
        },
        on_hit = {
          type = "bounce",
          sprite = "potato",
          gravity = -1000,
          time = 0.65,
          distribution = "uniform",
          range = {-50, 50},
        }
      }
    }
  }
  local sig = {}
  local play = coroutine.wrap(function()
    combat.parse_card_play(userid, pile, index, card_data)
  end)
  local abort = signal.merge(
    signal.type("mousepressed")
      .filter(function(x, y, b) return b == 2 end),
    signal.type("keypressed")
      .filter(function(key) return key == "escape" end),
    signal.type(combat_engine.events.card.play)
      .filter(function(_userid, _pile, _index)
        return userid == _userid and pile == _pile and index == _index
      end)
  ).listen(function() table.insert(sig, 1) end)

  while true do
    play()
    abort()
    coroutine.yield()
    if sig[1] then return end
  end
end

function combat_engine.add_event(f)
  table.insert(combat_engine.data.event_queue, f)
end

function combat_engine.handle_event_queue()
  local queue = combat_engine.data.event_queue
  if #queue <= 0 then
    return combat_engine.handle_event_queue(coroutine.yield())
  end
  local f = queue[1]
  for i = 1, #queue do queue[i] = queue[i + 1] end
  local sub_token = {}
  lambda.run(sub_token, f)
  while lambda.status(sub_token) do coroutine.yield() end

  return combat_engine.handle_event_queue()
end

function combat_engine.entity_marker(id)
  if not id then
    lambda.stop(combat_engine.subroutines.entity_marker)
    return
  end
  local shader = combat_engine.resource.shader.entity_marker
  local quad = combat_engine.resource.mesh.quad
  local function _run(dt, id)
    local x, y = gamedata.spatial.x[id], gamedata.spatial.y[id]
    --local w, h = gamedata.spatial.width[id], gamedata.spatial.height[id]

    --local ix, iy = camera.transform(camera_id, level, x - w, y - h)
    --local ex, ey = camera.transform(camera_id, level, x + w, y + h)
    local ux = camera.transform(camera_id, level, x, y)
    local theme = combat_engine.resource.theme.player.normal.bg
    local r, g, b = unpack(theme)
    local uw, uh = 200, 30
    local uy = 690
    world_suit:Button(
      id, {draw = function(_, opt, x, y, w, h)
        gfx.setShader(shader)
        gfx.setColor(r, g, b, 255)
        gfx.draw(quad, x, y, 0, w, h)
        gfx.setShader()
      end}, ux - 0.5 * uw, uy, uw, uh
    )
    return _run(coroutine.yield())
  end
  lambda.run(combat_engine.resource.lambda_token.entity_marker, _run, id)
end

function _show_card_pile(dt, pile, parent_uid, x, y, opt)
  local count = #pile
  local width = 100
  local height = 20
  local xmargin = 5
  local ymargin = 0

  local block_height = (count) * height + math.max(0, (ymargin ) * (count + 1))

  opt = opt or {}
  local align = opt.align or "left"
  local fx
  if align == "left" then
    fx = x
  elseif align == "center" then
    fx = x - width * 0.5
  elseif align == "right" then
    fx = x - width
  else
    error("Unknown alignment provided " .. align)
  end
  local fy
  local valign = opt.valign or "middle"
  if valign == "top" then
    fy = y
  elseif valign == "middle" then
    fy = y - block_height / 2
  elseif valign == "bottom" then
    fy = y - block_height
  else
    error("Unkown vertical alignment provided " .. valign)
  end
  world_suit.layout:reset(fx, fy, 2, 2)
  local bg_state = world_suit:Button(
    parent_uid, world_suit.layout:row(width + xmargin * 2, block_height)
  )
  world_suit.layout:reset(fx + xmargin, fy + ymargin, xmargin, ymargin)
  local _ui_states = {}
  for _, cid in pairs(pile) do
    local name = gamedata.card.name[cid]
    local function _draw(text, opt, ...)
      suit.theme.Button(opt.name, opt, ...)
    end
    _ui_states[cid] = world_suit:Button(
      cid, {draw = _draw, name = name}, world_suit.layout:row(width, height)
    )
  end

  for cid, state in pairs(_ui_states) do
    if state.hovered then
      gamedata.spatial.x[cid] = fx + width + xmargin
      gamedata.spatial.y[cid] = fy + block_height * 0.25
      cards.render(cid, false)
      break
    end
  end

  if not bg_state.hovered then return end
  return _show_card_pile(coroutine.yield())
end

function combat_engine.update_health_ui(id, health, damage)
  health = health or gamedata.combat.health[id]
  damage = damage or (gamedata.combat.damage[id] or 0)

  local uid = combat_engine.ui.health[id]
  if not uid then
    uid = {}
    combat_engine.ui.health[id] = uid
  end
  local pick_theme = {
    [combat_engine.DEFINE.FACTION.PLAYER] = combat_engine.resource.theme.player,
    [combat_engine.DEFINE.FACTION.ENEMY] = combat_engine.resource.theme.enemy,
  }
  local theme = pick_theme[combat_engine.faction(id)]
  if not theme then error("Faction not defined for id = " .. id) end
  --local health = gamedata.combat.health[id]
  --local damage = gamedata.combat.damage[id] or 0
  local function _draw(dt, id, uid)
    local x = gamedata.spatial.x[id]
    local y = gamedata.spatial.y[id]
    local h = gamedata.spatial.height[id]
    local sc_x, _ = camera.transform(camera_id, level, x, y + h)
    local sc_y = 300
    local sc_w = 150
    local sc_h = 23
    local font = combat_engine.resource.health_font
    --local theme =  combat_engine.resource.theme.player or combat_engine.resource.theme.enemy
    local margin = 5
    world_suit.layout:reset(sc_x - sc_w * 0.5, sc_y, margin, margin)
    local function _text_box_draw(_, opt, x, y, w, h)
      local theme = opt.color.normal
      gfx.setColor(unpack(theme.fg))
      gfx.setLineWidth(5)
      local mx = 10
      local my = 2
      gfx.rectangle("fill", x - mx, y - my, w + 2 * mx, h + 2 * my, 15)
      gfx.setColor(unpack(theme.bg))
      gfx.rectangle("fill", x, y, w, h, 25)
    end
    world_suit:Button(
      uid, {draw = _text_box_draw, color =  theme}, world_suit.layout:row(sc_w, sc_h)
    )
    local function _bar_draw(_, opt, x, y, w, h)
      gfx.stencil(function()
        gfx.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 5)
      end, "replace", 1)
      gfx.setStencilTest("equal", 0)
      gfx.setColor(unpack(opt.color.normal.fg))
      gfx.rectangle("fill", x, y, w, h)
      gfx.setStencilTest("equal", 1)
      local hp = opt.health
      local dmg = opt.damage
      local r = (hp - dmg) / hp
      local hp_theme = opt.hp_color
      if r > 0.5 then
        gfx.setColor(unpack(hp_theme.high))
      elseif r > 0.25 then
        gfx.setColor(unpack(hp_theme.medium))
      else
        gfx.setColor(unpack(hp_theme.low))
      end
      gfx.rectangle("fill", x, y, w * r, h)
      gfx.setStencilTest()
    end
    local hp_theme = combat_engine.resource.theme.health
    world_suit:Button(
      uid, {draw = _bar_draw, hp_color = hp_theme, health = health, damage = damage, color = theme},
      world_suit.layout:row(sc_w, sc_h * 0.5)
    )
    world_suit.layout:push(world_suit.layout:row())
    local ui_deck_w = 65
    local ui_deck_aspect = 1.4
    local deck_margin = sc_w - 2 * ui_deck_w
    world_suit.layout:padding(deck_margin, deck_margin)
    local _discard_uid = _get_uid(combat_engine.ui.discard, id)
    local _discard_state = world_suit:Button(
      _discard_uid,
       world_suit.layout:col(ui_deck_w, ui_deck_w * ui_deck_aspect)
    )
    local _draw_uid = _get_uid(combat_engine.ui.draw, id)
    local _draw_state = world_suit:Button(
      _draw_uid, world_suit.layout:col(ui_deck_w, ui_deck_w * ui_deck_aspect)
    )
    world_suit.layout:pop()
    if _draw_state.entered and not lambda.status(_draw_uid) and deck.size(id, gamedata.deck.draw) > 0 then
      local x, y = world_suit.layout:col()
      local pile = gamedata.deck.draw[id]
      lambda.run(
        _draw_uid, _show_card_pile, pile, _draw_uid, x - deck_margin,
        y + ui_deck_aspect * ui_deck_w * 0.5
      )
    end
    if _discard_state.entered and not lambda.status(_discard_uid) and deck.size(id, gamedata.deck.discard) > 0 then
      local x, y = world_suit.layout:col()
      local pile = gamedata.deck.discard[id]
      lambda.run(
        _discard_uid, _show_card_pile, pile, _discard_uid, sc_x - sc_w * 0.5,
        y + ui_deck_aspect * ui_deck_w * 0.5, {align = "right"}
      )
    end
    --world_suit.layout:push(world_suit.layout:row())
    --world_suit.layout:pop()
    local hh = (sc_w - 30) * 0.5
    world_suit.layout:reset(sc_x - sc_w * 0.5, sc_y, 5, 5)
    world_suit:Label(
      "" .. (health - damage), {align = "right", font = font, color = theme},
      world_suit.layout:col(hh, sc_h)
    )
    world_suit:Label(
      "/", {font = font, color = theme}, world_suit.layout:col(20, sc_h)
    )
    world_suit:Label(
      "" .. health, {align = "left", font = font, color = theme},
      world_suit.layout:col(hh, sc_h)
    )

    return _draw(coroutine.yield())
  end
  lambda.run(uid, _draw, id, uid)
end

local function _draw_target_border(id, opt, x, y, w, h)
  gfx.stencil(function()
    gfx.rectangle("fill", x, y, w, h)
  end, "replace", 1)
  gfx.setStencilTest("equal", 0)
  gfx.setLineWidth(6)
  gfx.setColor(255, 255, 255)
  gfx.polygon("line", x, y, x + w * 0.1, y, x, y + h * 0.1)
  gfx.polygon("line", x + w, y + h, x + w * 0.9, y + h, x + w, y + h * 0.9)
  gfx.polygon("line", x, y + h, x + w * 0.1, y + h, x, y + h * 0.9)
  gfx.polygon("line", x + w, y, x + w * 0.9, y, x + w, y + h * 0.1)
  gfx.setStencilTest()
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
    world_suit.layout:reset(800, 25)
    world_suit:Label(
      "Select Target",
      {
        draw = ui.draw_text_box,
        font = combat_engine.resource.pick_font,
        color = combat_engine.resource.theme.player
      },
      world_suit.layout:row(300, 50)
    )
    local pui = map(_draw, combat_engine.data.party)
    local eui = map(_draw, combat_engine.data.enemy)


    for i, ui in pairs(pui) do
      if ui.hit then
        --return _finisher(combat_engine.data.party[i]
        return combat_engine.data.party[i]
      end
    end
    for i, ui in pairs(eui) do
      if ui.hit then
        --return _finisher(combat_engine.data.enemy[i])
        return combat_engine.data.enemy[i]
      end
    end
    coroutine.yield()
  end
end

function combat_engine.confirm_cast(id, pile, index)
  local registered = {}
  local token = signal.type(combat_engine.events.card.clicked)
    .filter(function(_id, _pile, _index)
      return id == _id and pile == _pile and index == _index
    end)
    .map(function(v) return registered, v end)
    .listen(table.insert)
  while true do
    world_suit.layout:reset(800, 25)
    world_suit:Label(
      "Press to Confirm",
      {
        draw = ui.draw_text_box,
        font = combat_engine.resource.pick_font,
        color = combat_engine.resource.theme.player
      },
      world_suit.layout:row(300, 50)
    )
    if registered[1] then return end
    token()
  end
end

function combat_engine.entity_mouse()
  local function _draw(id)
    local x, y = gamedata.spatial.x[id], gamedata.spatial.y[id]
    local w, h = gamedata.spatial.width[id], gamedata.spatial.height[id]

    local ix, iy = camera.transform(camera_id, level, x - w, y - h)
    local ex, ey = camera.transform(camera_id, level, x + w, y + h)
    return world_suit:Button(
      id, {draw = function() end} , ix, ey, ex - ix, iy - ey
    )
  end

  local pui = map(_draw, combat_engine.data.party)
  local eui = map(_draw, combat_engine.data.enemy)

  for i, ui in pairs(pui) do
    if ui.hit then
      signal.emit(combat_engine.events.target.single, combat_engine.data.party[i])
    end
  end
  for i, ui in pairs(eui) do
    if ui.hit then
      signal.emit(combat_engine.events.target.single, combat_engine.data.enemy[i])
    end
  end
  return combat_engine.entity_mouse(coroutine.yield())
end

function combat_engine.set_selected_card(id, card_id)
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
  local hand = gamedata.deck.hand[id]
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
      signal.emit(combat_engine.events.card.clicked, id, gamedata.deck.hand, i)
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
  local highlight = map(light_fun, gamedata.deck.hand[id])

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

function combat_engine.faction(id)
  local f = combat_engine.data.faction[id]
  if f then return f() end
end

function combat_engine.begin(allies, enemies)
  -- Initialize card pool
  local all_ids = {}
  for _, id in pairs(allies) do
    combat_engine.data.faction[id] = function()
      return combat_engine.DEFINE.FACTION.PLAYER
    end
    table.insert(all_ids, id)
  end
  for _, id in pairs(enemies) do
    combat_engine.data.faction[id] = function()
      return combat_engine.DEFINE.FACTION.ENEMY
    end
    table.insert(all_ids, id)
  end

  for _, id in pairs(all_ids) do
    deck.create(id)
    local collection = gamedata.combat.collection[id] or {}
    gamedata.deck.draw[id] = map(function(c)
      return cards.init{ui_init = c}
    end,
      collection
    )
    deck.shuffle(id, gamedata.deck.draw)
    combat_engine.data.script[id] = combat_engine.player_script
    local draw_size = deck.size(id, gamedata.deck.draw)
    for i = 1, math.min(draw_size, 10) do
      local card_id = deck.draw(id, gamedata.deck.draw)
      deck.insert(id, gamedata.deck.hand, card_id)
    end
    -- Init ui
    combat_engine.update_health_ui(id)
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
  combat_engine.subroutines.entity_mouse = coroutine.create(combat_engine.entity_mouse)

  combat_engine.data.party = allies
  combat_engine.data.enemy = enemies

  draw_engine.ui.screen.combat = combat_engine.draw
  draw_engine.ui.world.combat = function()
--    world_suit:draw()
  end

  lambda.run(
    combat_engine.resource.lambda_token.event_queue,
    combat_engine.handle_event_queue
  )
end

local _event_handlers = {
  signal.type(combat_engine.events.card.play)
    .filter(function(id, pile, index) return pile == gamedata.deck.hand end)
    .map(function(id, pile, index)
      local cardid = deck.peek(id, pile, index)
      return gamedata.card.cost[cardid]
    end)
    .listen(function(cost)
      local a = combat_engine.data.action_point
      combat_engine.data.action_point = math.max(0, a - cost)
    end),
  signal.type(combat_engine.events.card.play)
    .filter(function(id, pile, index) return pile == gamedata.deck.hand end)
    .map(function(id, pile, index)
      return id, gamedata.deck.discard, deck.draw(id, pile, index)
    end)
    .listen(deck.insert),
}

function combat_engine.update(dt)
  --Setup event handlers
  for _, f in pairs(_event_handlers) do f() end
  -- Update card effects
  for _, id in pairs(combat_engine.data.party) do
    local hand = gamedata.deck.hand[id]
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
