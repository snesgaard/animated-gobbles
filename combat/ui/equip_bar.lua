local common = require "combat/ui/common"
local theme = require "combat/ui/theme"

local screen_suit = common.screen_suit

local DEFINE = {
  WIDTH = 200,
  HEIGHT = 40,
}

local function draw(text, opt, x, y, w, h)
  local theme = opt.color.normal
  gfx.setColor(unpack(theme.fg))
  gfx.setLineWidth(5)
  local mx = 15
  local my = 5
  local r = 20
  gfx.rectangle(
    "fill", x - mx - r * 0.5, y - my - r * 0.5,
    w + 2 * mx + r, h + 2 * my + r, r
  )
  gfx.setColor(unpack(theme.bg))
  gfx.rectangle("fill", x - r * 0.5, y - r * 0.5, w + r, h + r, r)
  suit.theme.Label(text, opt, x, y, w, h)
end

local bar = {}

function bar.weapon(dt, y)
  while true do
    screen_suit:Button(
      "bar_weapon", {draw = draw, color = theme.player}, -20, y, DEFINE.WIDTH,
      DEFINE.HEIGHT
    )
    coroutine.yield()
  end
end

function bar.armor(dt, y)
  while true do
    screen_suit:Button(
      "bar_armor", {draw = draw, color = theme.player}, -20, y, DEFINE.WIDTH,
      DEFINE.HEIGHT
    )
    coroutine.yield()
  end
end

function bar.ring(dt, y)
  while true do
    screen_suit:Button(
      "bar_ring", {draw = draw, color = theme.player}, -20, y, DEFINE.WIDTH,
      DEFINE.HEIGHT
    )
    coroutine.yield()
  end
end

function bar.height()
  return DEFINE.HEIGHT
end

function bar.width()
  return DEFINE.WIDTH
end

return bar
