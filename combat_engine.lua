require "deck"

local gfx = love.graphics

combat_engine = {}

local all_decks = {}
local actions = {}

local turn_type = {ally = 1, enemy = 2, neutral = 3}
local turn_type_ui_data = {
  [turn_type.ally] = {color = {0, 80, 220}, text = "Player"},
  [turn_type.enemy] = {color = {220, 0, 0}, text = "Enemy"},
  [turn_type.neutral] = {color = {0, 220, 80}, text = "Neutral"},
}

local state = {
  card = {
    selectable = rx.BehaviorSubject.create({}),
    render = {},
    selected = rx .BehaviorSubject.create(-1),
  },
  actions = {},
  decks = {},
  turn_script = {},
  turn_order = rx.BehaviorSubject.create({}),
  current_turn = rx.BehaviorSubject.create(1),
  ui = {
    turn_order = rx.BehaviorSubject.create({}),
    action = -1,
    turn_type = rx.Subject.create()
  }
}

state.ui.turn_type
  :flatMapLatest(function(type)
    local data = turn_type_ui_data[type]
    if data then
      return draw_engine.screen_ui_draw
        :map(function() return data end)
    else
      return rx.Observable.never()
    end
  end)
  :subscribe(function(data)
    local c = data.color
    local t = data.text
    local r, g, b = unpack(c)
    gfx.setColor(r, g, b, 200)
    gfx.polygon("fill", 1920 - 200, 0, 1920, 0, 1920, 200)
    gfx.setColor(r, g, b)
    gfx.print(t, 1920 - 375, 75, 0, 5, 5)
  end)

--state.ui.turn_type:onNext(turn_type.enemy)
-- Release turn order elements
state.turn_order
  :flatMap(function()
    return rx.Observable.fromTable(state.ui.turn_order:getValue())
  end)
  :subscribe(free_entity)
local turn_order_ui = {
  scale = 5,
  width = 16 * 5,
  height = 16 * 5,
  y = 10,
  init_x = 600,
  offset_x = 92,
}
local function init_turn_icon(gd, id, x)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = turn_order_ui.y
  gd.spatial.face[id] = turn_order_ui.scale
  gd.spatial.flip[id] = turn_order_ui.scale
end
state.turn_order
  :map(function(ent)
    local res = {}
    for i, id in pairs(ent) do
      res[id] = initresource(
        gamedata, init_turn_icon,
        i * turn_order_ui.offset_x + turn_order_ui.init_x
      )
    end
    return res
  end)
  :subscribe(state.ui.turn_order)

draw_engine.screen_ui_draw
  :subscribe(function()
    for i = 1, 3 do
      for j = 1, 3 do
        local w = 6 - 2 * (j - 1)
        if i ~= state.current_turn:getValue() then
          gfx.setColor(220, 200, 50, 50 * j)
        else
          gfx.setColor(50, 220, 100, 100 + 50 * j)
        end
        gfx.setLineWidth(w)
        local x = turn_order_ui.init_x + turn_order_ui.offset_x * i - w * 0.5
        local y = turn_order_ui.y - w * 0.5
        gfx.rectangle(
          "line", x, y, turn_order_ui.width + w, turn_order_ui.height + w
        )
      end
    end
    for i = 1, 6 do
      gfx.setColor(0, 80, 220)
      local x = turn_order_ui.init_x + turn_order_ui.offset_x * (i + 1.0) * 0.5
      local y = turn_order_ui.y
      gfx.rectangle(
        "fill", x, y + 100, 25, 35
      )
    end
    gfx.setLineWidth(1)
  end)

state.ui.turn_order
  :subscribe(coroutine.wrap(function(tab)
    -- HACK due to laziness
    tab = coroutine.yield()
    local _atlas, _anime = shared_actor.get_portrait()
    while true do
      for actorid, iconid in pairs(tab) do
        local quad = gamedata.functional.portrait[actorid]
        animation.play{
          iconid, _atlas, _anime[quad()], 0.7, draw = animation.uidraw
        }
        local _color = resource.atlas.color[_atlas]
        local sub = draw_engine.screen_ui_draw
          :map(function() return _color end)
          :subscribe(gfx.draw)
      end
      tab = coroutine.yield()
    end
  end))


local function active_card_render(id)
  local atlas = cards.get_gfx()
  local anime = gamedata.card.image[id]
  animation.play{id, atlas, anime(), 0.75, draw = animation.uidraw}
end

local function deactive_card_render(id)
  animation.stop(id)
  animation.erase(id)
end

local function show_card(id)
  if state.card.render[id] then return end
  active_card_render(id)
  state.card.render[id] = id
end
local function hide_card(id)
  deactive_card_render(id)
  state.card.render[id] = nil
end

local card_visual = {
  render = rx.BehaviorSubject.create({}),
  insert = rx.Subject.create(),
  remove = rx.Subject.create(),
  set = rx.Subject.create(),
}

combat_engine.state = state

local cs = rx.Subject.create

combat_engine.event = {
  -- Card related event
  card = {
    draw = cs(), discard = cs(), thrash = cs(), shuffle = cs(), play = cs()
  },
  action = {
    buff = cs(), curse = cs(), attack = cs(), gain = cs(), spent = cs(),
    damage = cs(), heal = cs()
  },
  general = {
    round_end = cs(), turn_end = cs(), turn_start = cs(), action_start = cs(),
    action_end = cs(), turn_setup = cs()
  }
}

combat_engine.event.general.action_end
  :filter(function(userid)
    local actions = state.actions[userid]
    local cards = #state.decks[userid].hand
    return cards <= 0 or actions <= 0
  end)
  :subscribe(combat_engine.event.general.turn_end)

combat_engine.event.general.action_end
  :filter(function(id)
    local actions = state.actions[id]
    local cards = #state.decks[id].hand
    return cards > 0 and actions > 0
  end)
  :subscribe(combat_engine.event.general.turn_start)

--combat_engine.event.general.turn_start
--  :map(function(id)
--    local f = turn_script[id]
--    return id, f -- Pick turn script: enemy AI or player UI
--  end)
--  :subscribe(function(id, f) f(id) end)

--combat_engine.event.general.turn_end
--  :subscribe(function(id)
--    actions[id] = 1
--    draw_cards(id, 5)
--  end)

--combat_engine.event.general.turn_end
--  :map(coroutine.wrap(function()
--    local i = 0
--    while true do
--      i = i < #state.turn_order and i + 1 or 1
--      coroutine.yield(i)
--    end
--  end))
--  :subscribe(combat_engine.event.general.turn_start)

combat_engine.event.card.play
  :map(function(card_id, user_id)
    return user_id, gamedata.card.cost[card_id]
  end)
  :subscribe(function(user_id, cost)
    state.actions[user_id] = (state.actions[user_id] - cost)
  end)

combat_engine.event.card.play
  :map(function(id, userid, pile, card) return userid, pile, card end)
  :subscribe(combat_engine.event.card.discard)

combat_engine.event.card.play
  :map(function(card_id, user_id) return user_id end)
  :subscribe(combat_engine.event.general.action_end)

combat_engine.event.card.draw
  :subscribe(function(userid, cardid)
    local _deck = state.decks[userid]
    deck.insert(_deck, "hand", cardid)
    gamedata.spatial.x[cardid] = 2100
    gamedata.spatial.y[cardid] = 770
  end)

--combat_engine.event.action.spent
--  :subscribe(function(id, a)
--    state.actions[id] = state.actions[id] - a
--  end)

combat_engine.event.card.discard
  :subscribe(function(userid, pile, card)
    local _deck = state.decks[userid]
    local id = deck.draw(_deck, pile, card)
    deck.insert(_deck, "discard", id)
    -- HACK
    hide_card(id)
  end)

combat_engine.event.general.turn_start
  :distinct()
  :map(function(id)
    local d = state.decks[id]
    return d.hand
  end)
  :subscribe(function(d) print(d) card_visual.render:onNext(d) end)

local id_stream_turn = state.current_turn
  :filter(function(i) return i <= #state.turn_order:getValue() end)
  :map(function(i)
    local v = state.turn_order:getValue()
    return v[i]
  end)
id_stream_turn
  :subscribe(function(id) combat_engine.event.general.turn_setup:onNext(id) end)
id_stream_turn
  :subscribe(function(id) combat_engine.event.general.turn_start:onNext(id) end)

local function _move(from, to, speed)
  return coroutine.wrap(function(dt)
    local x = from
    speed = math.abs(speed)
    speed = from < to and speed or -speed
    local res = {}
    local min = from < to and from or to
    local max = from < to and to or from
    while true do
      x = x + speed * dt
      for i = 1, 10 do
        res[i] = math.max(min, math.min(max, x + i * 20))
      end
      dt = coroutine.yield(res)
    end
  end)
end

local function _draw_action_points(id)
  local a = state.actions[id]
  local r = 15
  local seg = 10
  local y = 725
  gfx.setColor(255, 255, 0)
  for i = 1, 10 do
    gfx.circle("line", 200 + i * (r + 4) * 2 + 1200, y , r + 3, seg)
  end
  gfx.setColor(50, 100, 220)
  for i = 1, a do
    gfx.circle("fill", 200 + i * (r + 4) * 2 + 1200, y, r + 2, seg)
  end
end

combat_engine.event.general.turn_start
  :flatMapLatest(function(id)
    return draw_engine.screen_ui_draw
      :map(function() return id end)
  end)
  :subscribe(_draw_action_points)

combat_engine.input = {}

combat_engine.action = {}

--function combat_engine.action.card_draw(id, count)
--  local d = all_decks[id]
--  for i = 1, count do
--    local card = deck.move_random(d.draw, d.hand)
--    combat_engine.event.card.draw:onNext{id, card}
--    if #d.draw == 0 then
--      d.draw = d.discard
--      d.discard = {}
--    end
--  end
--end

local horizontal_input = rx.Observable.merge(
  love.keypressed
    :filter(function(k) return k == "left" end)
    :map(function() return 1 end),
  love.keypressed
    :filter(function(k) return k == "right" end)
    :map(function() return -1 end)
)

local vertical_input = rx.Observable.merge(
  love.keypressed
    :filter(function(k) return k == "up" end)
    :map(function() return -1 end),
  love.keypressed
    :filter(function(k) return k == "right" end)
    :map(function() return 1 end)
)

local subject = {
  selected = rx.BehaviorSubject.create(1),
  action = rx.Subject.create(),
  visual_done = rx.BehaviorSubject.create(true),
  hp_visualizer = rx.Subject.create(),
  selected_card = rx.BehaviorSubject.create(1)
}

local function render_hp(id, x, hp, max)
  local s = 0.4
  gfx.setColor(220, 0, 0)
  local str = hp .. " / " .. max
  gfx.print(str, x, 100, 0, s, s)
end

local function create_attack_action(source, target)
  return {
    effect = function(_, id)
      gamedata.combat.damage[id] = (gamedata.combat.damage[id] or 0) + 1
      return gamedata.combat.damage[id]
    end,
    source = source,
    visual = function(dt, attacker, target, dmg)
      local spatial = gamedata.spatial
      local speed = 1000
      local x_src = spatial.x[attacker]
      local x_dst = spatial.x[target] - 30
      while spatial.x[attacker] < x_dst do
        dt = coroutine.yield()
        spatial.x[attacker] = spatial.x[attacker] + speed * dt
      end
      spatial.x[attacker] = x_dst
      local x = spatial.x[target] - 10
      local health = gamedata.combat.health[target]
      subject.hp_visualizer:onNext{target, x, health - dmg, health}
      while spatial.x[attacker] > x_src do
        dt = coroutine.yield()
        spatial.x[attacker] = spatial.x[attacker] - speed * 0.25 * dt
      end
      spatial.x[attacker] = x_src
    end,
    target = target
  }
end

local function run_combat(actors, decks)

end

local function end_combat(decks)
  for id, deck_id in pairs(decks) do free_entity(deck_id) end
end

local function player_turn(userid)
  local start_stream = combat_engine.event.general.turn_start
    :filter(function(id) return id == userid end)
  local setup_stream = combat_engine.event.general.turn_setup
    :filter(function(id) return id == userid end)
  start_stream
    :map(function()
      local strim = combat_engine.input.card_select
        :filter(function(id) return id ~= 0 end)
        :take(1)
      return strim
    end)
    :switch()
    :map(function(i)
      local d = state.decks[userid]
      local key = "hand"
      return d[key][i], userid, key, i
    end)
    :subscribe(function(...) state.card.selected:onNext(...) end)
  start_stream
    :map(function() return 0 end)
    :subscribe(state.card.selected)

  start_stream
    :map(function(id) return state.decks[id] end)
    :subscribe(function(d)
      for _, id in pairs(d.hand) do show_card(id) end
    end)
  --combat_engine.event.general.turn_start
  start_stream
    :map(function(id) return state.decks[id].hand end)
    :subscribe(state.card.selectable)
  start_stream
    :map(function(id) return state.decks[id].hand end)
    :subscribe(function(h)
      for i, id in pairs(h) do
        local speed = gamedata.spatial.x[id] < 0 and 4000 or 1000
        speed = gamedata.spatial.x[id] > 2000 and 2000 or speed
        --move_to(id, ((i - 1) * 180 + 30), 760, speed)
        script_engine.queue(id, function(dt)
          motion.line_segment(id, ((i - 1) * 180 + 30), 760, speed, dt)
        end)
      end
    end)
  setup_stream
    :map(function() return turn_type.ally end)
    :subscribe(state.ui.turn_type)
end

local function draw_card(id)
  local x = gamedata.spatial.x[id]
  local y = gamedata.spatial.y[id]
  local w = gamedata.spatial.width[id]
  local h = gamedata.spatial.height[id]
  gfx.setColor(0, 0, 0)
  gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
  gfx.setColor(220, 208, 129)
  gfx.rectangle("fill", x,  y, w, h, 10, 10, 5)
  gfx.setColor(0, 0, 255)
  gfx.circle("fill", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
  gfx.setColor(255, 255, 200)
  gfx.print(gamedata.card.cost[id], x - w * 0.04, y - h * 0.05, 0, 3, 3)
  gfx.setColor(63, 109, 139)
  local name = gamedata.card.name[id]
  gfx.print(name, x + w * 0.1 + 10, y + h * 0.005, 0, 2, 2)
  local w_rat = 0.8
  local h_rat = 0.48
  gfx.setColor(200, 200, 150)
  --gfx.draw(pot_im, x + w * 0.5 * (1 - w_rat),  y + h * (1 - h_rat) * 0.25 * 0.75, 0, 5, 5)
  gfx.setColor(220, 200, 200)
  local text_start = h_rat + 0.125
  local text_rat = 0.375
  gfx.rectangle(
    "fill", x + w * 0.5 * (1 - w_rat),  y + h * text_start,
    w * w_rat, h * text_rat
  )
  gfx.setColor(63, 109, 139)
  local text = gamedata.card.text[id]
  gfx.print( text, x + w * 0.5 * (1 - w_rat) + 10, y + h * text_start + 10)
end

local function draw_card_select(id)
  for i = 1, 3 do
    local x = gamedata.spatial.x[id]
    local y = gamedata.spatial.y[id]
    local w = gamedata.spatial.width[id]
    local h = gamedata.spatial.height[id]
    gfx.setLineWidth(20 - 5 * i)
    gfx.setColor(0, 255 - i * 50, 0, 255)
    gfx.circle("line", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
    gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
  end
  gfx.setLineWidth(1)
end

local function render_cards(hand)
  local gfx = love.graphics
  local atlas = cards.get_gfx()
  gfx.push()
  local keep = false
  local order_hand = {}
  for i, id in pairs(hand) do table.insert(order_hand, id) end
  table.sort(order_hand, function(a, b)
    return gamedata.spatial.x[a] < gamedata.spatial.x[b]
  end)
  gfx.setStencilTest()
  for _, id in pairs(order_hand) do
    gfx.stencil(function()
      gfx.setColorMask(true, true, true, true)
      if id == state.card.selected:getValue() then
        draw_card_select(id)
      end
      draw_card(id)
    end, "replace", 1, keep)
    keep = true
    gfx.stencil(function()
      local x = gamedata.spatial.x[id]
      local y = gamedata.spatial.y[id]
      local sx = gamedata.spatial.face[id]
      local sy = gamedata.spatial.flip[id]
      local ox, oy = cards.anime_offset()
      gfx.rectangle("fill", x - ox * sx, y - oy * sy, 32 * sx, 27 * sy, 10, 10, 10)
    end, "replace", 2, keep)
  end
  gfx.origin()
  gfx.setColor(255, 255, 255)
  gfx.setStencilTest("equal", 2)
  gfx.draw(resource.atlas.color[atlas])
  gfx.setStencilTest()
  gfx.pop()
end

--[[
card_visual.insert
  :map(function(id)
    local cv = card_visual.render:getValue()
    cv[id] = id
    local atlas = cards.get_gfx()
    local anime = gamedata.card.image[id]
    animation.play{id, atlas, anime(), 0.75, draw = animation.uidraw}
    return cv
  end)
  :subscribe(card_visual.render)

card_visual.remove
  :map(function(id)
    local cv = card_visual.render:getValue()
    cv[id] = nil
    animation.stop(id)
    return cv
  end)
  :subscribe(card_visual.render)

card_visual.set
  :map(function(c)
    local cv = card_visual.render:getValue()
    for _, id in pairs(cv) do
      animation.stop(id)
    end
    return c
  end)
  :subscribe(card_visual.render)
]]--

--[[
card_visual.render
  :subscribe(coroutine.wrap(function(cards)
    for _, id in pairs(cards) do active_card_render(id) end
    while true do
      local prev_cards = cards
      local sub = draw_engine.screen_ui_draw
        :map(function() return cards end)
        :subscribe(render_cards)

      cards = coroutine.yield()
      -- Sorting to only activate what necessary
      local prev_ids = {}
      local cur_ids = {}
      for _, id in pairs(cards) do cur_ids[id] = id end
      for _, id in pairs(prev_cards) do prev_ids[id] = id end
      for _, id in pairs(prev_ids) do
        if cur_ids[id] then
          prev_ids[id] = nil
          cur_ids[id] = nil
        end
      end
      for _, id in pairs(prev_ids) do deactive_card_render(id) end
      for _, id in pairs(cur_ids) do active_card_render(id) end
      sub:unsubscribe()
    end
  end))
]]--
draw_engine.screen_ui_draw
  :map(function() return state.card.render end)
  :subscribe(render_cards)

combat_engine.input.card_select = state.card.selectable
  :flatMapLatest(function(cards)
    return love.mousepressed
      :filter(function(_, _, button) return button == 1 end)
      :map(function(px, py)
        local order_hand = {}
        for i, id in pairs(cards) do
          table.insert(order_hand, i)
        end
        table.sort(order_hand, function(a, b)
          local ida = cards[a]
          local idb = cards[b]
          return gamedata.spatial.x[ida] > gamedata.spatial.x[idb]
        end)
        for _, i in pairs(order_hand) do
          local id = cards[i]
          local x = gamedata.spatial.x[id]
          local y = gamedata.spatial.y[id]
          local w = gamedata.spatial.width[id]
          local h = gamedata.spatial.height[id]
          local r = x < px and px < x + w and y < py and py < y + h
          if r then return i end
        end
        return 0
      end)
  end)


function move_to(id, dst_x, dst_y, speed, handle)
  local x_org = gamedata.spatial.x[id]
  local y_org = gamedata.spatial.y[id]

  local dx = dst_x - x_org
  local dy = dst_y - y_org
  local l = math.sqrt(dx * dx + dy * dy)

  local completed = function()
    gamedata.spatial.x[id] = dst_x
    gamedata.spatial.y[id] = dst_y
    if handle then handle:onNext(true) end
  end
  if l < 1 then
    completed()
    return
  end
  dx = dx / l
  dy = dy / l

  state_engine.update
    :map(function(dt)
      return dx * dt * speed, dy * dt * speed
    end)
    :takeWhile(function(vx, vy)
      local x = gamedata.spatial.x[id]
      local y = gamedata.spatial.y[id]
      return (dst_y - y - vy) * dy >= 0 and (dst_x - x - vx) * dx >= 0
    end)
    :subscribe(
      function(vx, vy)
        gamedata.spatial.x[id] = gamedata.spatial.x[id] + vx
        gamedata.spatial.y[id] = gamedata.spatial.y[id] + vy
      end,
      nil,
      completed
    )
end

function combat_engine.start2(allies, enemies)
  combat_engine.input.target_select = love.world_mousepressed
    :filter(function(_, _, button) return button == 1 end)
    :map(function(px, py)
      local function collision_detect(id)
        local x = gamedata.spatial.x[id]
        local y = gamedata.spatial.y[id]
        local w = gamedata.spatial.width[id]
        local h = gamedata.spatial.height[id]
        return math.abs(x - px) < w and math.abs(y - py) < h
      end
      for _, id in pairs(allies) do
        if collision_detect(id) then return id end
      end
      for _, id in pairs(enemies) do
        if collision_detect(id) then return id end
      end
      return -1
    end)
    :filter(function(id) return id ~= -1 end)

  local decks = {}

  local actor = {}
  local _turn_order = {}
  for _, id in pairs(allies) do
    actor[id] = player_turn
    combat_engine.state.actions[id] = rx.BehaviorSubject.create(1)
    state.actions[id] = 1
    table.insert(_turn_order, id)
  end
  for _, id in pairs(enemies) do
    actor[id] = enemy_turn
    combat_engine.state.actions[id] = rx.BehaviorSubject.create(1)
    state.actions[id] = 1
    table.insert(_turn_order, id)
  end
  state.turn_order:onNext(_turn_order)

  for id, _ in pairs(actor) do
    local d = deck.create()
    local c = gamedata.combat.collection[id] or {}
    d.draw = map(function(f)
      return initresource(gamedata, f, id)
    end, c)
    deck.shuffle(d, "draw")
    decks[id] = d
  end

  --run_combat(actors, decks)
  for i = 1, 10 do
    local d = decks[allies[1]]
    local card_id = deck.draw(d, "draw")
    deck.insert(d, "hand", card_id)
  end
  local atlas = cards.get_gfx()
  for i, id in pairs(decks[allies[1]].hand) do
    gamedata.spatial.x[id] = -200
    gamedata.spatial.y[id] = 770
    --local anime = gamedata.card.image[id]
    --animation.play{id, atlas, anime(), 0.75, draw = animation.uidraw}
    --move_to(id, ((i - 1) * 180 + 30), 770, 4000)
    --card_visual.insert:onNext(id)
  end
  --state.card.render:onNext(decks[allies[1]].hand)
  --state.card.selectable:onNext(decks[allies[1]].hand)
  combat_engine.state.decks = decks


  player_turn(allies[1])
  combat_engine.state.current_turn:onNext(1)
  --combat_engine.event.general.turn_start:onNext(allies[1])
end
