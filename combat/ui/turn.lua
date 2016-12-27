local event = require "combat/event"
local gfx = love.graphics
local common = require "combat/ui/common"
local DEFINE = {
  margin = 20,
  width = 380,
  height = 75,
  marker_width = 120,
  point = {
    enter_time = 0.5,
    enter_scale = 3.0,
    exit_time = 0.25,
    exit_scale = 0,
  }
}
local function make_label_poly(x, y, w, h)
  return {
    x, y + h * 0.5,
    x + DEFINE.margin, y,
    x + w - DEFINE.margin, y,
    x + w, y + h * 0.5,
    x + w - DEFINE.margin, y + h,
    x + DEFINE.margin, y + h
  }
end

local trans_marker_shader_str =[[
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float a = 1 - clamp(texture_coords.x, 0.0, 1.0);
    a *= a;
    return vec4(color.rgb, a * color.a);
}
]]
local marker_shader = gfx.newShader(trans_marker_shader_str)
local marker_quad = common.quad_mesh

local function corner_draw(_, opt, x, y, width, height)
  gfx.setColor(unpack(opt.color.base))
  gfx.polygon("fill", x, y, x + width, y, x + width, y + height)
end

local function point_frame_draw(_, opt, x, y, width, height)
  gfx.setColor(unpack(opt.color.normal.fg))
  gfx.setLineWidth(2)
  gfx.circle("line", x + width, y, width + 1, 20)
end

local function point_draw(_, opt, x, y, width, height)
  local r, g, b = unpack(opt.color.base)
  local a = opt.alpha
  local scale = opt.scale
  gfx.setColor(r, g, b, a)
  gfx.setLineWidth(1)
  gfx.circle("fill", x + width, y, width * scale, 20)
end

local function animate_points(dt, point_opt, index, state)
  local opt = point_opt[index]
  opt.alpha = 0
  opt.scale = 0

  while state.action_point < index do
    dt = coroutine.yield()
  end

  local function animate_enter(dt)
    opt.scale = DEFINE.point.enter_scale
    local time = DEFINE.point.enter_time
    local da = 255 / time
    local ds = (1.0 - DEFINE.point.enter_scale) / time
    while time - dt > 0 do
      time = time - dt
      opt.alpha = opt.alpha + da * dt
      opt.scale = opt.scale + ds * dt
      dt = coroutine.yield()
    end
    opt.scale = 1
    opt.alpha = 255
    return dt
  end
  dt = animate_enter(dt)

  while state.action_point >= index do
    dt = coroutine.yield()
  end

  local function animate_exit(dt)
    opt.scale = 1.0
    local time = DEFINE.point.exit_time
    local da = 255 / time
    local ds = (DEFINE.point.exit_scale - 1.0) / time
    while time - dt > 0 do
      time = time - dt
      opt.alpha = opt.alpha - da * dt
      opt.scale = opt.scale + ds * dt
      dt = coroutine.yield()
    end
    opt.alpha = 0
    opt.scale = DEFINE.point.exit_scale
    return dt
  end
  dt = animate_exit(dt)

  return animate_points(dt, point_opt, index, state)
end

local function label_draw(text, opt, x,y,w,h)
  local r, g, b = unpack(opt.color.base)
  gfx.setColor(r, g, b)
  --gfx.rectangle("fill", x, y, w, h)

  local poly_line = make_label_poly(x, y, w, h)
  gfx.polygon("fill", unpack(poly_line))
  suit.theme.Label(text, opt, x,y,w,h)
  gfx.polygon("line", unpack(poly_line))
end

local function transition_draw(_, opt, x, y, w, h)
  local tx = opt.transition
  local poly_line = make_label_poly(x, y, w, h)
  gfx.stencil(function()
    gfx.rectangle("fill", x + (w - tx), y, tx, h)
  end, "replace", 1, false)
  gfx.setStencilTest("equal", 1)

  opt.color = opt.current
  label_draw(opt.current.type, opt, x, y, w, h)
  gfx.setStencilTest("equal", 0)
  opt.color = opt.previous
  label_draw(opt.previous.type, opt, x, y, w, h)
  gfx.stencil(function()
    gfx.polygon("fill", unpack(poly_line))
  end, "replace", 1, false)
  gfx.setStencilTest("equal", 1)
  gfx.setColor(255, 255, 255)

  gfx.setShader(marker_shader)
  gfx.draw(marker_quad, x + (w - tx), y, 0, DEFINE.marker_width, h)
  gfx.setStencilTest()
  gfx.setShader()
end

local function make_label_color(type)
  local color = {
      normal  = {bg = { 0, 0, 255}, fg = {255,255,188}},
      hovered = {bg = { 50,153,187}, fg = {0,0,255}},
      active  = {bg = {255,153,  0}, fg = {0,0,225}},
      type = type
  }
  if type == "Player" then
    color.base = {80, 120, 250, 255}
  elseif type == "Enemy" then
    color.base = {200, 20, 50, 255}
  elseif type == "Neutral" then
    color.base = {20, 150, 50, 255}
  else
    error("Unknown turn type provided: " .. type)
  end

  return color
end

return function(dt, type, previous_type)
  local pool = lambda_pool.new()
  local opt = {
    font = combat_engine.resource.turn_ui_font, color = color,
    align = "center", draw = transition_draw, transition = 0.0
  }
  opt.current = make_label_color(type)
  opt.previous = make_label_color(previous_type)

  local state = {action_point = combat_engine.data.action_point}

  pool:run(function(dt, opt)
    local time = 0.5
    local fx = DEFINE.width + DEFINE.marker_width
    local freq = fx / time
    while opt.transition + freq * dt < fx do
      opt.transition = opt.transition + freq * dt
      dt = coroutine.yield()
    end
    --opt.transition = 1.5
    opt.draw = label_draw
    opt.color = opt.current
  end, opt)
  local point_opt = {}
  for i = 1, 10 do
    point_opt[i] = {
      color = opt.current, draw = point_draw, scale = 0, alpha = 0
    }
    pool:run(animate_points, point_opt, i, state)
  end

  local tokens = {}
  tokens.pcard = signal.type(event.core.card.play)
    .filter(function(userid)
      local fac = combat_engine.faction(userid)
      return fac == combat_engine.DEFINE.FACTION.PLAYER
    end)
    .listen(function(userid, cardid)
      state.action_point = combat_engine.data.action_point
    end)
  tokens.ecard = signal.type(event.core.card.play)
    .filter(function(userid)
      local fac = combat_engine.faction(userid)
      return fac == combat_engine.DEFINE.FACTION.ENEMY
    end)
    .listen(function(userid, cardid)
      return function()
        state.action_point = combat_engine.data.action_point
      end
    end)

  while true do
    for _, t in pairs(tokens) do t() end
    pool:update(dt)
    local gfx_w = gfx:getWidth() - 50
    local w = DEFINE.width
    local h = DEFINE.height
    common.screen_suit.layout:reset(gfx_w - w, 10)
    common.screen_suit:Label(
      type, opt, common.screen_suit.layout:col(w, h)
    )
    common.screen_suit.layout:reset(gfx_w - w, h + 35, 25, 20)
    for i = 1,10 do
      local x, y, w, h = common.screen_suit.layout:col(15, 10)
      common.screen_suit:Button(
        "corner_triangle",
        {draw = point_frame_draw, color = opt.current},
        x, y, w, h
      )
      common.screen_suit:Button(
        "corner_triangle", point_opt[i], x, y, w, h
      )
    end
    dt = coroutine.yield()
  end
end
