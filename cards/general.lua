local anime = {}
local atlas
local frame_data
local sheet
local card_frame
local card_frame_shader
local icon_font
local name_font = {}

local DEFINE = {
  WIDTH = 50,
  HEIGHT = 70
}

local _shader_txt = [[
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texcolor = Texel(texture, texture_coords);
    vec4 _out_color = texcolor * color;
    if (_out_color.a < 0.1) discard;
    return _out_color;
}
]]

local card_suit = suit.new()

function card_suit:draw()
	self:exitFrame()
	love.graphics.push('all')
  local n = self.draw_queue.n
	for i = 1,n do
		self.draw_queue[n - i + 1]()
	end
	love.graphics.pop()
	self.draw_queue.n = 0
	self:enterFrame()
end

cards = {}

local text_theme = {
    normal  = {bg = { 0, 0, 66}, fg = {0,0,188}},
    hovered = {bg = { 50,153,187}, fg = {0,0,255}},
    active  = {bg = {255,153,  0}, fg = {0,0,225}}
}

local function get_quad(id)
  return resource.animation.quads[anime[id]][1]
end

function loader.cards()
  -- Initialize animations
  local data_dir = "resource/sprite/card"
  sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  atlas = initresource(resource.atlas, function(at, id)
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 20, "stream"
    )
  end)

  local index = require (data_dir .. "/info")
  frame_data = require (data_dir .. "/hitbox")

  table.foreach(frame_data, function(key, val)
    anime[key] = initresource(
      resource.animation, animation.init, sheet, index[key], frame_data[key],
      true
    )
  end)
  table.foreach(frame_data, function(key, val)
    frame_data[key].hitbox = collision_engine.batch_alloc_sequence(
      frame_data[key].hitbox, hitbox_hail, hitbox_seek
    )
  end)
  local ox, oy = cards.anime_offset()
  for _, id in pairs(anime) do
    local x = resource.animation.x[id]
    for i, _ in pairs(x) do x[i] = ox end
    local y = resource.animation.y[id]
    for i, _ in pairs(y) do y[i] = oy end
  end

  icon_font = gfx.newFont(30)
  name_font.large = gfx.newFont(20)
  name_font.medium = gfx.newFont(15)
  name_font.small = gfx.newFont(9)

  card_frame_shader = gfx.newShader(_shader_txt)

  draw_engine.ui.screen.card = cards.draw
end

function cards.anime_offset()
  return -25 * 8 * 0.5 * 0.2 / 5, -35 * (1 - 0.2) * 0.25 * 0.75
end
function cards.get_gfx()
  return atlas, anime
end

function cards.init(gamedata, id, card_data)
  gamedata.spatial.x[id] = 0
  gamedata.spatial.y[id] = 0
  gamedata.spatial.width[id] = DEFINE.WIDTH
  gamedata.spatial.height[id] = DEFINE.HEIGHT
  gamedata.spatial.face[id] = 4
  gamedata.spatial.flip[id] = 4

  gamedata.card.cost[id] = card_data.cost or 11
  gamedata.card.name[id] = card_data.name or "Not Found"
  gamedata.card.image[id] = card_data.image
  local effects = {}

  for key, val in pairs(card_data) do
    if type(val) == "table" then
      effects[key] = util.deep_copy(val)
    end
  end
  gamedata.card.effect[id] = effects

  gamedata.card.text[id] = cards.compile_text(gamedata.card.effect[id])

  if card_data.react then
    gamedata.card.react[id] = card_data.react(id)
  end
end

function cards.compile_text(effects)
  local str
  for _, effect in pairs(effects) do
    if effect.text_compiler then
      local part_str = effect.text_compiler(effect)
      if not str then
        str = part_str
      else
        str = string.format("%s %s", str, part_str)
      end
    end
  end
  return str or "Nope"
end

local function card_back_render(_, opt, x, y, width, height)
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
  local r, g, b, a = 200, 200, 0, 200
  if opt.highlight then
    local r, g, b, a = unpack(opt.highlight)
    gfx.setStencilTest("equal", 0)
    gfx.setColor(r, g, b, a)
    gfx.rectangle("fill", x - 5, y - 5, width  + 10, height + 10, 10, 10)
    gfx.setStencilTest()
    gfx.setColor(255, 255, 255)
  end
end

function cards.batch_render(card_ids, x, y)
  card_suit.layout:reset(x, y, -20, 0)
  local card_uis = {}
  local hover_render = true
  for i, cid in pairs(card_ids) do
    card_uis[i] = cards.render(cid, hover_render)
    hover_render = hover_render and not card_uis[i].hovered
  end
  return card_uis
end

local function card_illustration_render(_, opt, x, y, width, height)
  local quad = get_quad(opt.pid)
  local sx = width
  local sy = height
  gfx.setStencilTest("equal", 0)
  gfx.draw(sheet, quad, x, y, 0, sx, sy)
  gfx.setStencilTest()
end

local function cost_icon_render(_, opt, x, y, width, height)
  local quad = get_quad("cost_icon")
  local sx = width
  local sy = height
  gfx.draw(sheet, quad, x, y, 0, sx, sy)
end

function cards.suit_draw(cardid, opt, x, y, w, h)
  local cost = gamedata.card.cost[id]
  local sx = w / DEFINE.WIDTH
  local sy = h / DEFINE.HEIGHT

end

function cards.render(id, highlight, x, y)
  local x = x or gamedata.spatial.x[id]
  local y = y or gamedata.spatial.y[id]
  local w = gamedata.spatial.width[id]
  local h = gamedata.spatial.height[id]
  local sx = gamedata.spatial.face[id]
  local sy = gamedata.spatial.flip[id]

  local cost = gamedata.card.cost[id]

  --x, y, w, h = card_suit.layout:col(w * sx, h * sy)
  local ui_ids = {}
  table.insert(ui_ids, card_suit:Label(
    "" .. cost, {color = text_theme, font = icon_font}, x - 1.5 * sx,
    y - 1.5 * sy, 25, 25
  ))
  local text = gamedata.card.text[id]
  table.insert(ui_ids, card_suit:Label(
    text, {color = text_theme, valign = "top"}, x + 3 * sx, y + 42 * sy,
    44 * sx, 25 * sy
  ))
  local name = gamedata.card.name[id]
  local font = name_font.large
  if string.len(name) > 13 then
    font = name_font.small
  elseif string.len(name) > 8 then
    font = name_font.medium
  end
  table.insert(ui_ids, card_suit:Label(
    name, {color = text_theme, font = font, valign = "center"},
    x + 7 * sx, y + 1 * sy, 35 * sx, 5 * sy
  ))
  card_suit:Button(
    nil, {draw = cost_icon_render}, x - 3 * sx, y - 3 * sy, sx, sy
  )
  local pid = gamedata.card.image[id] or "potato"
  card_suit:Button(
    nil, {draw = card_illustration_render, pid = pid}, x + 3 * sx,
    y + 8 * sy, sx, sy
  )
  table.insert(ui_ids, card_suit:Button(
    id, {draw = card_back_render, highlight = highlight},
    x, y, w * sx, h * sy
  ))
  local hit = false
  for _, ui_el in pairs(ui_ids) do
    hit = hit or ui_el.hit
  end
  return hit
end

function cards.draw()
  card_suit:draw()
end

require "cards/draw"

require "cards/potato"
require "cards/evil_potato"
require "cards/dual_potato"
require "cards/fury"
