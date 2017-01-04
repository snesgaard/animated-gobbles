local common = require "combat/ui/common"


local DEFINE = {
  WIDTH = 50,
  HEIGHT = 70,
  COST_FONT = common.blarg,
  OPT = {
    COST_TEXT = {valign = "middle", align = "center", font = stuff},
  }
}

local RESOURCE = {
  ANIMATION = {},
  FONT = {},
  SHADER = {},
  SHEET,
}

local function get_quad(id)
  return resource.animation.quads[anime[id]][1]
end

function cards.load_visual()
  local data_dir = "resource/sprite/card"
  RESOURCE.SHEET = love.graphics.newImage(data_dir .. "/sheet.png")

  local index = require (data_dir .. "/info")
  local frame_data = require (data_dir .. "/hitbox")

  table.foreach(frame_data, function(key, val)
    RESOURCE.ANIMATION[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frame_data[key],
      true
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

local function draw_text(text, opt, x, y, w, h)
  love.graphics.setFont(opt.font)
  y = y + theme.getVerticalOffsetForAlign(opt.valign, opt.font, h)
  love.graphics.printf(text, x+2, y, w-4, opt.align or "center")
end

local function card_back_render(opt, x, y, width, height)
  local quad = get_quad("frame")
  local _, _, qw, qh = quad:getViewport()
  local sx = width / qw
  local sy = height / qh
  gfx.setColor(255, 255, 255)
  gfx.stencil(function()
    gfx.setShader(card_frame_shader)
    gfx.setColorMask(true, true, true, true)
    gfx.draw(sheet, quad, x, y, 0, sx, sy)
    gfx.setShader()
  end, "replace", 1, false)
  if opt.highlight then
    local r, g, b, a = unpack(opt.highlight)
    gfx.setStencilTest("equal", 0)
    gfx.setColor(r, g, b, a)
    gfx.rectangle("fill", x - 5, y - 5, width  + 10, height + 10, 10, 10)
    gfx.setStencilTest()
    gfx.setColor(255, 255, 255)
  end
end

return function(cardid, opt, x, y, w, h)
end
