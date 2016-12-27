local common = require "combat/ui/common"
local screen_suit = common.screen_suit
local theme = require "combat/ui/theme"

local DEFINE = {
  margin = 2
}

local function bg_draw(_, opt, x, y, w, h)
  local theme = opt.color.normal
  gfx.setColor(unpack(theme.fg))
  gfx.setLineWidth(5)
  gfx.setStencilTest("equal", 0)
  local r = 8
  gfx.rectangle(
    "fill", x - r * 0.5, y - r * 0.5,
    w + r, h + r, r
  )
  gfx.setStencilTest( )
end

local function entry_draw(data, opt, x, y, w, h)
  local draw = opt.userdraw or screen_suit.theme.Button
  gfx.stencil(function()
    gfx.setColorMask(true, true, true, true)
    draw(data, opt, x, y, w, h)
  end, "replace", 1, opt.index ~= 1)
end

local function _do_draw(entries, opt, x, y, width, height)
  local block_height = height * #entries + DEFINE.margin * (#entries + 1)
  if opt.align == "right" then
    x = x - width
  elseif opt.align == "center" then
    x = x - width * 0.5
  end
  if opt.valign == "bottom" then
    y = y - block_height
  elseif opt.valign == "center" then
    y = y - block_height * 0.5
  end
  screen_suit.layout:reset(x, y, DEFINE.margin, DEFINE.margin)
  local state = {}
  for i, name in ipairs(entries) do
    state[name] = screen_suit:Button(
      name, {
        color = opt.color, font = opt.font, draw = entry_draw,
        userdraw = opt.draw, index = i
      }, screen_suit.layout:row(width, height)
    )
  end
  screen_suit.layout:reset(x - DEFINE.margin, y - DEFINE.margin)
  local bg_state = screen_suit:Button(
    entries, {draw = bg_draw, color = opt.color},
    screen_suit.layout:col(width + DEFINE.margin * 2, block_height)
  )
  return state, bg_state
end

return function(entries, opt, x, y, width, height)
  if type(opt) ~= "table" then
    height = width
    width = y
    y = x
    x = opt
    opt = {
      color = theme.player, font = common.font.s20, align = "left",
      valign = "top"
    }
  end

  return _do_draw(entries, opt, x, y, width, height)
end
