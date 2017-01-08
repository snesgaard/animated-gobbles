local common = require "combat/ui/common"
local theme = require "combat/ui/theme"


local DEFINE = {
  WIDTH = 50,
  HEIGHT = 70,
  COST_FONT = common.blarg,
  OPT = {
    COST_TEXT = {valign = "middle", align = "center", font = stuff},
  }
}
cards.DEFINE = DEFINE

local RESOURCE = {
  ANIMATION = {},
  FONT = {},
  SHADER = {},
  SHEET,
}

local function get_quad(id)
  local anime = RESOURCE.ANIMATION
  return resource.animation.quads[anime[id]][1]
end

function loader.card_visual()
  local data_dir = "resource/sprite/card"
  RESOURCE.SHEET = love.graphics.newImage(data_dir .. "/sheet.png")

  local index = require (data_dir .. "/info")
  local frame_data = require (data_dir .. "/hitbox")

  table.foreach(frame_data, function(key, val)
    RESOURCE.ANIMATION[key] = initresource(
      resource.animation, animation.init, RESOURCE.SHEET, index[key],
      frame_data[key], true
    )
  end)

  local _shader_txt = [[
  vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
  {
      vec4 texcolor = Texel(texture, texture_coords);
      vec4 _out_color = texcolor * color;
      if (_out_color.a < 0.1) discard;
      return _out_color;
  }
  ]]
  RESOURCE.SHADER.CARD_FRAME = gfx.newShader(_shader_txt)

  RESOURCE.FONT.ICON = gfx.newFont(30)
  RESOURCE.FONT.NAME_LARGE = gfx.newFont(20)
  RESOURCE.FONT.NAME_MEDIUM = gfx.newFont(15)
  RESOURCE.FONT.NAME_SMALL = gfx.newFont(9)

  RESOURCE.FONT.CARD_TEXT = gfx.newFont(12)
  RESOURCE.FONT.CARD_TEXT:setFilter("linear", "linear", 3)
end

local function vertical_offset(valign, font, h)
  if valign == "top" then
    return 0
  elseif valign == "bottom" then
    return h - font:getHeight()
  end
  -- else: "middle"
  return (h - font:getHeight()) / 2
end

local function draw_text(text, opt, x, y, w, h, rot, sx, sy)
  rot = rot or 0
  sx = sx or 1
  sy = sy or 1
  love.graphics.setFont(opt.font)
  y = y + vertical_offset(opt.valign, opt.font, h) * sx
  local theme = opt.color
  local r, g, b, a = gfx.getColor()
  local tr, tg, tb = unpack(theme.normal.fg or {0, 0, 0})
  gfx.setColor(r * tr / 255, g * tg / 255, b * tb / 255, a)
  love.graphics.printf(text, x, y, w / sx, opt.align or "center", rot, sx, sy)
  gfx.setColor(r, g, b, a)
end

local function card_back_render(image, opt, x, y, w, h)
  local quad = get_quad("frame")
  local _, _, qw, qh = quad:getViewport()
  local sx = w / qw
  local sy = h / qh
  local shader = RESOURCE.SHADER.CARD_FRAME
  local sheet = RESOURCE.SHEET
  gfx.setColor(255, 255, 255)
  gfx.stencil(function()
    gfx.setShader(shader)
    gfx.setColorMask(true, true, true, true)
    gfx.draw(sheet, quad, x, y, 0, sx, sy)
    gfx.setShader()
  end, "replace", 1, false)
  if opt.highlight then
    local r, g, b, a = gfx.getColor()
    gfx.setStencilTest("equal", 0)
    gfx.setColor(unpack(opt.highlight))
    gfx.rectangle("fill", x - 5, y - 5, w  + 10, h + 10, 10, 10)
    gfx.setStencilTest()
    gfx.setColor(r, g, b, a)
  end
  gfx.setStencilTest("equal", 0)
end

function cards.suit_draw(cardid, opt, x, y, w, h)
  local sx = w / DEFINE.WIDTH
  local sy = h / DEFINE.HEIGHT
  local sheet = RESOURCE.SHEET
  local image = gamedata.card.image[cardid] or "potato"
  local text = gamedata.card.text[cardid]
  local cost = gamedata.card.cost[cardid]
  local name = gamedata.card.name[cardid]

  local name_font = RESOURCE.FONT.NAME_LARGE
  if string.len(name) > 13 then
    name_font = RESOURCE.FONT.NAME_SMALL
  elseif string.len(name) > 8 then
    name_font = RESOURCE.FONT.NAME_MEDIUM
  end

  --gfx.setColor(255, 255, 255)
  gfx.draw(sheet, get_quad(image), x + 3 * sx, y + 8 * sy, 0, sx, sy)
  gfx.draw(sheet, get_quad("frame"), x, y, 0, sx, sy)
  gfx.draw(sheet, get_quad("cost_icon"), x - 3 * sx, y - 3 * sy, 0, sx, sy)

  local text_scale = sx / 4.0
  draw_text(
    name, {color = theme.card_text, font = name_font, valign = "top"},
    x + 7 * sx, y + 1 * sy, 35 * sx, 5 * sy, 0, text_scale, text_scale
  )
  draw_text(
    text,
    {color = theme.card_text, font = RESOURCE.FONT.CARD_TEXT, valign = "top"},
    x + 3 * sx, y + 42 * sy, 44 * sx, 25 * sy, 0, text_scale, text_scale
  )
  draw_text(
    "" .. cost,
    {color = theme.card_text, font = RESOURCE.FONT.ICON, valign = "top"},
    x - 1.75 * sx, y - 2.75 * sy, 7 * sx, 7 * sx, 0, text_scale, text_scale
  )
end

function cards.suit_highlight(cardid, opt, x, y, w, h)
  local r, g, b, a = gfx.getColor()
  local tr, tg, tb, ta = unpack(opt.highlight or {255, 255, 255, 255})
  gfx.setColor(r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255)
  gfx.setLineWidth(12)
  gfx.rectangle("line", x + 1, y + 1, w - 2, h - 2, 10, 10)
  gfx.setColor(r, g, b, a)
end
