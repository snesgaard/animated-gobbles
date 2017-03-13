local event = require "combat/event"
local common = require "combat/ui/common"
local _suit = common.screen_suit
local text_box = require "combat/ui/text_box"
local theme = require "combat/ui/theme"

local DEFINE = {
  MARGIN = 12
}

local RESOURCE = {
  SHEET = {},
  ANIMATION = {},
  FONT = {}
}

function loader.buff()
  local data_dir = "resource/sprite/icon"
  RESOURCE.SHEET = love.graphics.newImage(data_dir .. "/sheet.png")

  local index = require (data_dir .. "/info")
  local frame_data = require (data_dir .. "/hitbox")

  table.foreach(frame_data, function(key, val)
    RESOURCE.ANIMATION[key] = initresource(
      resource.animation, animation.init, RESOURCE.SHEET, index[key],
      frame_data[key], true
    )
  end)
  local font = 'resource/fonts/nonfree/squares.ttf'
  RESOURCE.FONT.COUNT = gfx.newFont(font, 11)
end

local function get_quad(id)
  local anime = RESOURCE.ANIMATION
  return resource.animation.quads[anime[id]][1]
end

local function _draw_icon(type, opt, x, y, w, h)
  local userid = opt.userid

  local value = opt.value

  gfx.setColor(150, 150, 100, 255)
  gfx.setLineWidth(2)
  gfx.rectangle("line", x - 1, y - 1, w + 2, h + 2, 2)
  gfx.circle("line", x + w, y + h, w * 0.35, 20)
  if value >= 0 then
    gfx.setColor(206, 166, 38)
  else
    gfx.setColor(120, 40, 195)
  end
  gfx.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 2)
  gfx.circle("fill", x + w, y + h, w * 0.35, 20)

  gfx.setColor(255, 255, 255, 150)
  gfx.draw(RESOURCE.SHEET, get_quad(type), x, y)
  gfx.setColor(0, 0, 0, 175)
  local font = RESOURCE.FONT.COUNT
  gfx.setFont(font)
  local tw = 10
  if value < 0 then value = -value end
  gfx.printf("" .. value, x + w - tw * 0.4, y + h - font:getHeight() * 0.5, tw, "center")
end

local function create_explaination(type, value)
  local positive = {
    power = "Increases damage/heal dealt by %i.",
    armor = "Decreases damage taken by %i.",
    charge = "Doubles the next %i attacks/heals.",
    shield = "Blocks the next %i attacks.",
    regen = "Restore %i health at the end of your turn.",
    bleed = "Restore %i health after each action.",
    crit = "%i%% change to deal double damage",
  }
  local negative = {
    power = "Decrease damage/heal dealt by %i.",
    armor = "Increase damage taken by %i.",
    charge = "Halves the next %i attacks/heals.",
    shield = "Doubles damage for the next %i attacks taken.",
    regen = "Take %i damage at the end of your turn.",
    bleed = "Take %i damage after each action.",
    crit = "%i%% change to miss."
  }
  if type == "crit" then value = value * 10 end
  if value > 0 then
    local str = positive[type]
    return string.format(str, value)
  else
    local str = negative[type]
    return string.format(str, -value)
  end
end

local function create_render_order(state)
  local res = {}
  for type, _ in pairs(state.shown) do
    res[#res + 1] = type
  end
  table.sort(res, function(a, b) return state.time[a] < state.time[b] end)
  return res
end

local function initialize(userid)
  local state = {
    shown = {},
    time = {},
    render_order = {},
    react = {},
    explain = {}
  }

  for type, val in pairs(gamedata.combat.buff) do
    if val[userid] then
      state.shown[type] = val[userid]
      state.time[type] = love.timer.getTime()
    end
  end
  state.render_order = create_render_order(state)
  local _buff_react = {}
  for type, _ in pairs(gamedata.combat.buff) do
    _buff_react[#_buff_react + 1] = signal.type(event.core.character[type])
      .map(function(id, value)
        return id, gamedata.combat.buff[type][id], type
      end)
  end
  state.react.all = signal.merge(unpack(_buff_react))
    .filter(function(id) return id == userid end)
    .listen(function(_, value, type)
      return function()
        state.shown[type] = value
        if not value then
          state.time[type] = nil
        else
          state.time[type] = state.time[type] or love.timer.getTime()
        end
        state.render_order = create_render_order(state)
        if state.explain.type then
          state.explain.str = create_explaination(
            state.explain.type, state.shown[state.explain.type]
          )
        end
      end
    end)
  return state
end

-- Drawn with respect to
return function(dt, engine, x, y, w, userid)
  local state = initialize(userid)

  while true do
    for _, r in pairs(state.react) do r() end
    _suit.layout:reset(x, y, DEFINE.MARGIN, DEFINE.MARGIN)
    _suit.layout:push(_suit.layout:row(100, 20))
    local i = 0
    local entered
    local left
    for _, type in pairs(state.render_order) do
      if i == 5 then
        i = 0
        _suit.layout:pop()
        _suit.layout:push(_suit.layout:row(w, 20))
      end
      i = i + 1
      --print(state.shown[type], type)
      local opt = {
        draw = _draw_icon, userid = userid, value = state.shown[type]
      }
      local ix, iy, iw, ih = _suit.layout:col(20, 20)
      local ui = _suit:Button(type, opt, ix, y + (y - iy), iw, ih)
      entered = ui.entered and type or entered
      left = ui.left and type or left
    end
    if not entered and left then
      state.explain.type = nil
      state.explain.str = nil
    elseif entered then
      state.explain.type = entered
      state.explain.str = create_explaination(entered, state.shown[entered])
    end
    if state.explain.str then
      _suit:Button(
        state.explain.str,
        {draw = text_box, color = theme.player, title = state.explain.type},
        800, 100, 200, 30
      )
    end
    dt = coroutine.yield()
  end
end
