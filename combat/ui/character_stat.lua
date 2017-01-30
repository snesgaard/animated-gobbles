local event = require "combat/event"
local theme = require "combat/ui/theme"
local common = require "combat/ui/common"
local menu = require "combat/ui/menu"
local buff_ui = require "combat/ui/buff"

local screen_suit = common.screen_suit

local DEFINE = {
  screen_y = 300,
  screen_width = 150,
  screen_height = 23,
  margin = 5,
  deck_width = 65,
  deck_aspect = 1.4
}

local RESOURCE = {
  SHEET = {},
  ANIMATION = {},
  FONT = {}
}

local function health_bar_draw(_, opt, x, y, w, h)
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

local function text_box_draw(_, opt, x, y, w, h)
  local theme = opt.color.normal
  gfx.setColor(unpack(theme.fg))
  gfx.setLineWidth(5)
  local mx = 10
  local my = 2
  gfx.rectangle("fill", x - mx, y - my, w + 2 * mx, h + 2 * my, 15)
  gfx.setColor(unpack(theme.bg))
  gfx.rectangle("fill", x, y, w, h, 25)
end

local function draw_card_entry(id, opt, x, y, w, h)
  local name = gamedata.card.name[id]
  return screen_suit.theme.Button(name, opt, x, y, w, h)
end

local function pile_draw(_, opt, x, y, w, h)
  local color = opt.color.normal
  gfx.setColor(unpack(color.fg))
  gfx.rectangle("fill", x, y, w, h)
end

local function alpha_sort_card(card_list)
  card_list = util.deep_copy(card_list)
  table.sort(card_list, function(card_a, card_b)
    return gamedata.card.name[card_a] < gamedata.card.name[card_b]
  end)
  return card_list
end


local function initialize(userid)
  local pick_theme = {
    [combat_engine.DEFINE.FACTION.PLAYER] = theme.player,
    [combat_engine.DEFINE.FACTION.ENEMY] = theme.enemy,
  }
  local usertheme = pick_theme[combat_engine.faction(userid)]
  local health = gamedata.combat.health[userid]
  local damage = gamedata.combat.damage[userid] or 0

  local x = gamedata.spatial.x[userid]
  local y = gamedata.spatial.y[userid]
  local h = gamedata.spatial.height[userid]

  local menutheme = util.deep_copy(usertheme)
  menutheme.hovered = {fg = menutheme.normal.bg, bg = menutheme.normal.fg}
  menutheme.active = menutheme.hovered

  local state = {
    x = camera.transform(camera_id, level, x, y + h),
    opt = {
      health_bar = {
        draw = health_bar_draw, hp_color = theme.health, health = health,
        damage = damage, color = usertheme
      },
      box = {
        draw = text_box_draw, color = usertheme
      },
      health_text = {
        font = common.font.s20, color = usertheme, align = "left"
      },
      damage_text = {
        font = common.font.s20, color = usertheme, align = "right"
      },
      mid_text = {
        font = common.font.s20, color = usertheme
      },
      draw = {
        color = usertheme, draw = pile_draw
      },
      discard = {
        color = usertheme, draw = pile_draw
      },
      draw_list = {
        color = menutheme, align = "left", valign = "center",
        draw = draw_card_entry
      },
      discard_list = {
        color = menutheme, align = "right", valign = "center",
        draw = draw_card_entry
      }
    },
    uid = {discard = {}, draw = {}},
    card = {
      discard = alpha_sort_card(gamedata.deck.discard[userid]),
      draw = alpha_sort_card(gamedata.deck.draw[userid]),
    },
    menu_draw,
    pool = lambda_pool.new()
  }
  return state
end

local function card_list_control(parent, card_list, opt, x, y, w, h)
  while not parent.hovered or #card_list <= 0 do
    parent, card_list = coroutine.yield()
  end
  local bg_state = true
  while (parent.hovered or bg_state) and #card_list > 0 do
    card_state, bg_state_ui = menu(card_list, opt, x, y, w, h)
    bg_state = bg_state_ui.hovered
    for _, card in pairs(card_list) do
      bg_state = bg_state or card_state[card].hovered
    end
    for _, card in pairs(card_list) do
      if card_state[card].hovered then
        local ch = gamedata.spatial.height[card] * gamedata.spatial.flip[card]
        --gamedata.spatial.y[card] = y - ch * 0.5
        local cy = y - ch * 0.5
        local cx
        if opt.align == "left" then
          --gamedata.spatial.x[card] = x + w
          cx = x + w
        elseif opt.align == "right" then
          local cw = gamedata.spatial.width[card] * gamedata.spatial.face[card]
          --gamedata.spatial.x[card] = x - cw - w
          cx = x - cw - w
        end
        --cards.render(card)
        common.screen_suit:Button(
          card, {
            draw = function(...)
              gfx.setColor(255, 255, 255)
              cards.suit_draw(...)
            end,
          }, cx, cy, cards.DEFINE.WIDTH * 4,
          cards.DEFINE.HEIGHT * 4
        )
      end
    end
    parent, card_list = coroutine.yield()
  end
  return card_list_control(parent, card_list, opt, x, y, w, h)
end

return function(dt, userid)
  local function is_user(id) return id == userid end
  local state = initialize(userid)
  local tokens = {}
  tokens.damage = signal.merge(event.core.character.damage, event.core.character.heal)
    .filter(is_user)
    .listen(function(id)
      local dmg = gamedata.combat.damage[id] or 0
      return function()
        state.opt.health_bar.damage = dmg
      end
    end)
  tokens.play = signal.type(event.core.card.play)
    .filter(is_user)
    .listen(function(userid, cardid)
      local cards = alpha_sort_card(gamedata.deck.discard[userid])
      state.card.discard = cards
    end)
  tokens.draw = signal.type(event.core.card.draw)
    .filter(is_user)
    .listen(function(userid)
      local draw = alpha_sort_card(gamedata.deck.draw[userid])
      local discard = alpha_sort_card(gamedata.deck.discard[userid])
      return function()
        state.card.discard = discard
        state.card.draw = draw
      end
    end)

  local discard_co = coroutine.wrap(card_list_control)
  local draw_co = coroutine.wrap(card_list_control)

  state.pool:run(
    "buff", buff_ui, state.x - DEFINE.screen_width * 0.5, DEFINE.screen_y - 40,
    DEFINE.screen_width, userid
  )
  while true do
    for _, t in pairs(tokens) do t() end
    screen_suit.layout:reset(
      state.x - DEFINE.screen_width * 0.5, DEFINE.screen_y, DEFINE.margin,
      DEFINE.margin
    )
    -- Draw background for healht numbers
    screen_suit:Button(
      nil, state.opt.box,
      screen_suit.layout:row(DEFINE.screen_width, DEFINE.screen_height)
    )
    -- Draw the health bar
    screen_suit:Button(
      nil, state.opt.health_bar,
      screen_suit.layout:row(DEFINE.screen_width, DEFINE.screen_height * 0.5)
    )
    -- Draw the discard and draw buttons side by side
    screen_suit.layout:push(screen_suit.layout:row())
    local deck_margin = DEFINE.screen_width - 2 * DEFINE.deck_width
    screen_suit.layout:padding(deck_margin, deck_margin)
    local deck_height = DEFINE.deck_width * DEFINE.deck_aspect
    local _discard_state = screen_suit:Button(
      state.uid.discard, state.opt.discard,
      screen_suit.layout:col(DEFINE.deck_width, deck_height)
    )
    local _draw_state = screen_suit:Button(
      state.uid.draw, state.opt.draw,
      screen_suit.layout:col(DEFINE.deck_width, deck_height)
    )
    local cx, cy = screen_suit.layout:col(DEFINE.deck_width, deck_height)
    screen_suit.layout:pop()
    -- Draw the healt text
    local health_height = (DEFINE.screen_width - 30) * 0.5
    screen_suit.layout:reset(
      state.x - DEFINE.screen_width * 0.5, DEFINE.screen_y, 5, 5
    )
    local health = state.opt.health_bar.health
    local damage = state.opt.health_bar.damage
    screen_suit:Label(
      "" .. (health - damage), state.opt.damage_text,
      screen_suit.layout:col(health_height, DEFINE.screen_height)
    )
    screen_suit:Label(
      "/", state.opt.mid_text, screen_suit.layout:col(20, DEFINE.screen_height)
    )
    screen_suit:Label(
      "" .. health, state.opt.health_text,
      screen_suit.layout:col(health_height, DEFINE.screen_height)
    )
    screen_suit.layout:reset(
      state.x - DEFINE.screen_width * 0.5 + 5, DEFINE.screen_y - 30, 12, 5
    )
    state.pool:update(dt)
    draw_co(
      _draw_state, state.card.draw, state.opt.draw_list,
      cx - deck_margin - 10, cy + deck_height * 0.5, 200, 20
    )
    discard_co(
      _discard_state, state.card.discard, state.opt.discard_list,
      state.x - DEFINE.screen_width * 0.5 + deck_margin + 10,
      cy + deck_height * 0.5, 200, 20
    )
    --[[
    if _draw_state.hovered and #state.card.draw > 0 then
      menu(
        state.card.draw, state.opt.draw_list, cx - deck_margin - 10,
        cy + deck_height * 0.5, 100, 20
      )
    end
    if _discard_state.hovered and #state.card.discard > 0 then
      menu(
        state.card.discard, state.opt.discard_list,
        state.x + 10 - DEFINE.screen_width * 0.5,
        cy  + deck_height * 0.5, 100, 20
      )
    end
    --]]
    dt = coroutine.yield()
  end
end
