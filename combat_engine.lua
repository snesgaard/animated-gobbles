require "deck"

local gfx = love.graphics

combat_engine = {}

local all_decks = {}
local actions = {}

local state = {
  card_active = rx.BehaviorSubject.create({}),
  actions = {},
  decks = {},
  selected_card = rx.BehaviorSubject.create(-1),
  turn_script = {},
  turn_order = {},
}

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
    action_end = cs()
  }
}

combat_engine.event.general.action_end
  :filter(function(id)
    local actions = state.actions[id]
    local cards = #state.decks[id].hand
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

--
--combat_engine.event.card.play
--  :map(function(card_id, user_id)
--    return user_id, gamedata.card.cost[card_id]
--  end)
--  :subscribe(combat_engine.event.action.spent)

combat_engine.event.card.play
  :subscribe(combat_engine.event.card.discard)

combat_engine.event.card.play
  :map(function(card_id, user_id) return user_id end)
  :subscribe(combat_engine.event.general.action_end)

combat_engine.event.card.play
  :map(function() return -1 end)
  :subscribe(state.selected_card)

--combat_engine.event.action.spent
--  :subscribe(function(id, a)
--    state.actions[id] = state.actions[id] - a
--  end)

combat_engine.event.card.discard
  :subscribe(function(card_id, user_id)
    local d = state.decks[user_id]
    deck.move(d.hand, d.discard, card_id)
    card_visual.remove:onNext(card_id)
  end)

combat_engine.event.general.turn_start
  :distinct()
  :map(function(id)
    print(id)
    local d = state.decks[id]
    print(#d.hand)
    return d.hand
  end)
  :subscribe(function(d) print(d) card_visual.render:onNext(d) end)

combat_engine.input = {}

combat_engine.action = {}

function combat_engine.action.card_draw(id, count)
  local d = all_decks[id]
  for i = 1, count do
    local card = deck.move_random(d.draw, d.hand)
    combat_engine.event.card.draw:onNext{id, card}
    if #d.draw == 0 then
      d.draw = d.discard
      d.discard = {}
    end
  end
end

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

function combat_engine.start(allies, enemies)

  local function select_draw()
    local id = allies[subject.selected:getValue()]
    gfx.setColor(255, 200, 95)
    --gfx.rectangle("fill", 130, 100, 32, 72)
    gfx.push()
    local x = gamedata.spatial.x[id]
    gfx.translate(x, 145)
    --gfx.polygon("line", -25, 64, 25, 64, 5, 0, -5, 0)
    gfx.rectangle("line", -16, -32, 32, 64)
    gfx.pop()
  end
  local _drawer = draw_engine.create_primitive(select_draw, false, true, true)
  --draw_engine.foreground_draw:subscribe(_drawer.color)
  horizontal_input
    :scan(function(i, di)
      return math.max(1, math.min(#allies, i + di))
    end, 1)
    :subscribe(subject.selected)
  --draw_engine.foreground_stencil:subscribe(_drawer.stencil)
  subject.hp_visualizer:
    subscribe(coroutine.wrap(function(arg)
      local active_render = {}
      while true do
        local id, x, hp, max_hp = unpack(arg)
        local sub = active_render[id]
        if sub then sub:unsubscribe() end
        active_render[id] = draw_engine.world_ui_draw
          :map(function() return id, x, hp, max_hp end)
          :subscribe(render_hp)
        arg = coroutine.yield()
      end
    end))
  for _, id in pairs(allies) do
    local x = gamedata.spatial.x[id] - 10
    local health = gamedata.combat.health[id]
    local dmg = (gamedata.combat.damage[id] or 0)
    subject.hp_visualizer:onNext{id, x, health - dmg, health}
  end
  for _, id in pairs(enemies) do
    local x = gamedata.spatial.x[id] - 10
    local health = gamedata.combat.health[id]
    local dmg = (gamedata.combat.damage[id] or 0)
    subject.hp_visualizer:onNext{id, x, health - dmg, health}
  end

  local order = {}
  for _, id in pairs(allies) do
    table.insert(order, id)
  end
  for _, id in pairs(enemies) do
    table.insert(order, id)
  end

  local player_deck = deck.create()
  local function init_card(gd, id)
    gd.spatial.x[id] = 0
    gd.spatial.y[id] = 0
    gd.spatial.width[id] = 25 * 8
    gd.spatial.height[id] = 35 * 8
  end
  player_deck.draw = map(function()
    return initresource(gamedata, init_card)
  end, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13})

  horizontal_input
    :map(function(di)
      local next_i = -di + subject.selected_card:getValue()
      return math.max(1, math.min(next_i, #player_deck.hand))
    end)
    :subscribe(subject.selected_card)
  love.mousepressed
    :filter(function(_, _, button) return button == 1 end)
    :map(function(px, py)
      for i = #player_deck.hand, 1, -1 do
        local id = player_deck.hand[i]
        local x = gamedata.spatial.x[id]
        local y = gamedata.spatial.y[id]
        local w = gamedata.spatial.width[id]
        local h = gamedata.spatial.height[id]
        local r = x < px and px < x + w and y < py and py < y + h
        if r then return i end
      end
      return -1
    end)
    :filter(function(i) return i ~= -1 end)
    :subscribe(subject.selected_card)

  for i = 1, 10 do
    local id = deck.move_random(player_deck.draw, player_deck.hand)
    local d = i < 6 and 30 or 30
    gamedata.spatial.x[id] = (i - 1) * 180 + d
    gamedata.spatial.y[id] = 770
  end

  local card_select_render = rx.BehaviorSubject.create(-1)
  draw_engine.screen_ui_draw
    :subscribe(function()
      local id = card_select_render
    end)

  local pot_im = gfx.newImage("resource/sprite/card/frame/potato.png")
  draw_engine.screen_ui_draw
    :subscribe(function()
      for i, id in pairs(player_deck.hand) do
        gfx.push()
        local x = gamedata.spatial.x[id]
        local y = gamedata.spatial.y[id]
        local w = gamedata.spatial.width[id]
        local h = gamedata.spatial.height[id]
        if i == subject.selected_card:getValue() then
          for i = 1, 3 do
            gfx.setLineWidth(30 - 5 * i)
            gfx.setColor(0, 255 - i * 50, 0, 200 - 50 * i)
            gfx.circle("line", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
            gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
          end
          gfx.setLineWidth(1)
        end
        gfx.setColor(0, 0, 0)
        gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
        gfx.setColor(220, 208, 129)
        gfx.rectangle("fill", x,  y, w, h, 10, 10, 5)
        gfx.setColor(0, 0, 255)
        gfx.circle("fill", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
        gfx.setColor(255, 255, 200)
        gfx.print("1", x - w * 0.04, y - h * 0.05, 0, 3, 3)
        gfx.setColor(63, 109, 139)
        local name = "Potato"
        gfx.print(name, x + w * 0.1 + 10, y + h * 0.005, 0, 2, 2)
        local w_rat = 0.8
        local h_rat = 0.48
        --[[
        gfx.rectangle(
          "fill", x + w * 0.5 * (1 - w_rat),  y + h * (1 - h_rat) * 0.25 * 0.75,
          w * w_rat, h * h_rat
        )
        ]]--
        gfx.setColor(200, 200, 150)
        gfx.draw(pot_im, x + w * 0.5 * (1 - w_rat),  y + h * (1 - h_rat) * 0.25 * 0.75, 0, 5, 5)
        gfx.setColor(220, 200, 200)
        local text_start = h_rat + 0.125
        local text_rat = 0.375
        gfx.rectangle(
          "fill", x + w * 0.5 * (1 - w_rat),  y + h * text_start,
          w * w_rat, h * text_rat
        )
        gfx.setColor(63, 109, 139)
        local str = ""
        str = str .. "Draw 1 card.\n"
        str = str .. "Gain 2 action.\n"
        str = str .. "Deal 1 damage.\n"
        str = str .. "\nAt the start of the next\nround, draw 1 card."
        gfx.print(
          str, x + w * 0.5 * (1 - w_rat) + 10,
          y + h * text_start + 10
        )
        gfx.pop()
      end
    end)
end

local function run_combat(actors, decks)

end

local function end_combat(decks)
  for id, deck_id in pairs(decks) do free_entity(deck_id) end
end

local function player_turn(userid)
  combat_engine.event.general.turn_start
    :filter(function(id) return id == userid end)
    :map(function()
      local strim = combat_engine.input.card_select
        :filter(function(id) return id ~= -1 end)
        :take(1)
      return strim
    end)
    :switch()
    :subscribe(function(id) state.selected_card:onNext(id) end)

  combat_engine.event.general.turn_start
    :filter(function(id) return id == userid end)
    :map(function() return -1 end)
    :subscribe(state.selected_card)

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
      if id == state.selected_card:getValue() then
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

local function active_card_render(id)
  local atlas = cards.get_gfx()
  local anime = gamedata.card.image[id]
  animation.play{id, atlas, anime(), 0.75, draw = animation.uidraw}
end

local function deactive_card_render(id)
  animation.stop(id)
end

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

combat_engine.input.card_select = card_visual.render
  :flatMapLatest(function(cards)
    return love.mousepressed
      :filter(function(_, _, button) return button == 1 end)
      :map(function(px, py)
        local order_hand = {}
        for i, id in pairs(cards) do
          table.insert(order_hand, id)
        end
        table.sort(order_hand, function(a, b)
          return gamedata.spatial.x[a] > gamedata.spatial.x[b]
        end)
        for _, id in pairs(order_hand) do
          local x = gamedata.spatial.x[id]
          local y = gamedata.spatial.y[id]
          local w = gamedata.spatial.width[id]
          local h = gamedata.spatial.height[id]
          local r = x < px and px < x + w and y < py and py < y + h
          if r then return id end
        end
        return -1
      end)
  end)


function move_to(id, dst_x, dst_y, speed, handle)
  local x_org = gamedata.spatial.x[id]
  local y_org = gamedata.spatial.y[id]

  local dx = dst_x - x_org
  local dy = dst_y - y_org
  local l = math.sqrt(dx * dx + dy * dy)
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
      function()
        gamedata.spatial.x[id] = dst_x
        gamedata.spatial.y[id] = dst_y
        if handle then handle:onNext(true) end
      end
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
  for _, id in pairs(allies) do
    actor[id] = player_turn
    combat_engine.state.actions[id] = rx.BehaviorSubject.create(1)
    state.actions[id] = 1
  end
  for _, id in pairs(enemies) do
    actor[id] = enemy_turn
    combat_engine.state.actions[id] = rx.BehaviorSubject.create(1)
    state.actions[id] = 1
  end

  for id, _ in pairs(actor) do
    local d = deck.create()
    local c = gamedata.combat.collection[id] or {}
    d.draw = map(function(f)
      return initresource(gamedata, f, id)
    end, c)
    decks[id] = d
  end

  --run_combat(actors, decks)
  for i = 1, 10 do
    local d = decks[allies[1]]
    deck.move_random(d.draw, d.hand)
  end
  local atlas = cards.get_gfx()
  for i, id in pairs(decks[allies[1]].hand) do
    gamedata.spatial.x[id] = -200
    gamedata.spatial.y[id] = 770
    --local anime = gamedata.card.image[id]
    --animation.play{id, atlas, anime(), 0.75, draw = animation.uidraw}
    move_to(id, ((i - 1) * 180 + 30), 770, 4000)
    --card_visual.insert:onNext(id)
  end
  state.card_active:onNext(decks[allies[1]].hand)
  combat_engine.state.decks = decks


  player_turn(allies[1])
  combat_engine.event.general.turn_start:onNext(allies[1])
end
