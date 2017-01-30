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

  local font = 'resource/fonts/nonfree/squares.ttf'

  RESOURCE.FONT.ICON = gfx.newFont(font, 30)
  RESOURCE.FONT.NAME_LARGE = gfx.newFont(font, 18)
  RESOURCE.FONT.NAME_MEDIUM = gfx.newFont(font, 15)
  RESOURCE.FONT.NAME_SMALL = gfx.newFont(font, 9)

  RESOURCE.FONT.CARD_TEXT = gfx.newFont(font, 14)

  for _, f in pairs(RESOURCE.FONT) do
    f:setFilter("linear", "linear", 3)
  end
  --RESOURCE.FONT.CARD_TEXT
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
  y = y + vertical_offset(opt.valign, opt.font, h) * sy
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

local card_visual_init = {}
function card_visual_init.number(cardid)
  local image = gamedata.card.image[cardid] or "potato"
  local text = gamedata.card.text[cardid]
  local cost = gamedata.card.cost[cardid]
  local name = gamedata.card.name[cardid]

  return image, text, cost, name
end
function card_visual_init.table(representation)
  local image = representation.image
  local text = representation.text
  local cost = representation.cost
  local name = representation.name

  return image, text, cost, name
end

function cards.suit_draw(cardid, opt, x, y, w, h)
  local sx = w / DEFINE.WIDTH
  local sy = h / DEFINE.HEIGHT
  local sheet = RESOURCE.SHEET

  local init = card_visual_init[type(cardid)]
  local image, text, cost, name = init(cardid)


  local name_font = RESOURCE.FONT.NAME_LARGE
  local name_offset = 0
  if string.len(name) > 17 then
    name_font = RESOURCE.FONT.NAME_SMALL
  elseif string.len(name) > 8 then
    name_font = RESOURCE.FONT.NAME_MEDIUM
    name_offset = 0.5
  end

  --gfx.setColor(255, 255, 255)
  gfx.setColor(12, 95, 132, 255)
  gfx.rectangle("fill", x + 3 * sx, y + 8 * sy, 44 * sx, 29 * sy)
  gfx.setColor(255, 255, 255)
  gfx.draw(sheet, get_quad(image), x + 3 * sx, y + 8 * sy, 0, sx, sy)
  gfx.draw(sheet, get_quad("frame"), x, y, 0, sx, sy)
  gfx.draw(sheet, get_quad("cost_icon"), x - 3 * sx, y - 3 * sy, 0, sx, sy)

  local text_scale = sx / 4.0
  draw_text(
    name, {color = theme.card_text, font = name_font, valign = "top"},
    x + 7 * sx, y + name_offset * sy, 35 * sx, 5 * sy, 0, text_scale, text_scale
  )
  draw_text(
    text,
    {color = theme.card_text, font = RESOURCE.FONT.CARD_TEXT, valign = "top"},
    x + 3 * sx, y + 42 * sy, 44 * sx, 25 * sy, 0, text_scale, text_scale
  )
  draw_text(
    "" .. cost,
    {color = theme.card_text, font = RESOURCE.FONT.ICON, valign = "top"},
    x - 2 * sx, y - 4.25 * sy, 7 * sx, 7 * sx, 0, text_scale, text_scale
  )
end

function cards.suit_highlight(cardid, opt, x, y, w, h)
  local r, g, b, a = gfx.getColor()
  local tr, tg, tb, ta = unpack(opt.highlight or {255, 255, 255, 255})
  gfx.setColor(r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255)
  local s = w / DEFINE.WIDTH
  gfx.setLineWidth(4 * s)
  gfx.rectangle("line", x + 1, y + 1, w - 2, h - 2, 10, 10)
  gfx.setColor(r, g, b, a)
end

-- Here goes some more high level functions
local gfx = love.graphics
local shader_str = [[
  vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
  {
      vec4 texcolor = Texel(texture, texture_coords);
      if (texcolor.a < 0.05) discard;
      return texcolor * color;
  }
]]
local particle_im = gfx.newImage("resource/particle/circle.png")
local card_shader = gfx.newShader(shader_str)

local function draw_card_fade(cardid, opt, x, y, w, h)
  gfx.stencil(function()
    gfx.setColorMask(true, true, true, true)
    gfx.setColor(255, 255, 255, 255)
    gfx.setShader(card_shader)
    cards.suit_draw(cardid, opt, x, y, w, h)
  end, "replace", 1)
  gfx.setShader()
  gfx.setStencilTest("equal", 1)
  gfx.setColor(unpack(opt.color))
  gfx.rectangle("fill", x - 200, y - 200, w + 400, h + 400)
  gfx.setStencilTest()
end

local function draw_card_particle(cardid, opt, x, y, w, h)
  local pt = opt.particle
  gfx.setColor(unpack(opt.color))
  gfx.draw(pt, x, y)
end

function cards.animate_fade(dt, cardid, _suit, x, y, s, text)
  local fade_time = 0.2
  local pt = gfx.newParticleSystem(particle_im, 30)
  local time = fade_time
  --local text = gamedata.card.text[cardid]
  local opt = {
    particle = pt, color = {80, 80, 200, 255}, draw = draw_card_fade,
    text = text
  }

  s = s or 4
  local w = cards.DEFINE.WIDTH * s
  local h = cards.DEFINE.HEIGHT * s

  local function get_interpolant(t) return (fade_time - t) / fade_time end

  while time - dt > 0 do
    time = time - dt
    local t = get_interpolant(time)
    opt.color[4] = 200 * t
    _suit:Button(cardid, opt, x, y, w, h)
    dt = coroutine.yield()
  end

  opt.draw = draw_card_particle
  opt.color[4] = 255
  pt:setAreaSpread("uniform", w * 0.4, h * 0.4)
  pt:setPosition(w * 0.5, h * 0.5)
  pt:setParticleLifetime(0.5)
  pt:setSpread(math.pi * 2)
  pt:setSpeed(400)
  pt:setSizes(10)
  pt:setLinearDamping(4)
  pt:setColors(255, 255, 255, 255, 255, 255, 255, 0)
  pt:emit(30)
  while pt:getCount() > 0 do
    pt:update(dt)
    _suit:Button(cardid, opt, x, y, w, h)
    dt = coroutine.yield()
  end
end
