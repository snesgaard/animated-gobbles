local common = require "combat/ui/common"

local DEFINE = {
  MIN_CARD_TIME = 1.0,
  X = 820,
  Y_INIT = -325,
  Y_FINAL = 25,
  MOVE_TIME = 1000
}

-- HACK TEST CODE
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

local function do_card_fade(dt, cardid)
  local fade_time = 0.2
  local pt = gfx.newParticleSystem(particle_im, 30)
  local time = fade_time
  local opt = {particle = pt, color = {80, 80, 200, 255}, draw = draw_card_fade}

  local s = 4
  local w = cards.DEFINE.WIDTH * s
  local h = cards.DEFINE.HEIGHT * s
  local x = DEFINE.X
  local y = DEFINE.Y_FINAL

  local function get_interpolant(t) return (fade_time - t) / fade_time end

  while time - dt > 0 do
    time = time - dt
    local t = get_interpolant(time)
    opt.color[4] = 200 * t
    common.screen_suit:Button(cardid, opt, x, y, w, h)
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
    common.screen_suit:Button(cardid, opt, x, y, w, h)
    dt = coroutine.yield()
  end
end

local function do_card_appearance(dt, cardid)
  local function do_card_draw(cardid, opt, x, y, w, h)
    gfx.setColor(255, 255, 255, opt.alpha)
    cards.suit_draw(cardid, opt, x, y, w, h)
  end
  local opt = {draw = do_card_draw, alpha = 0}
  local fade_time = 0.2
  local time = fade_time

  local function get_interpolant(t) return (fade_time - t) / fade_time end
  local base_scale = 4
  local extra_scale = 6
  while time - dt > 0 do
    time = time - dt
    local t = get_interpolant(time)
    opt.alpha = t * 255
    local s = base_scale + extra_scale * (1 - t)
    local ex_s = s - base_scale
    common.screen_suit:Button(
      cardid, opt, DEFINE.X - ex_s * 0.5 * cards.DEFINE.WIDTH,
      DEFINE.Y_FINAL - ex_s * 0.5 * cards.DEFINE.HEIGHT, cards.DEFINE.WIDTH * s,
      cards.DEFINE.HEIGHT * s
    )
    dt = coroutine.yield()
  end
end

-- END OF HACK



return function(dt, cardid, seq)
  local card_proc = "card"
  local seq_proc = "seq"
  local state = {
    terminate = false,
    pool = lambda_pool.new()
  }
  local proc = {}
  function proc.card_appear(dt, cardid)
    do_card_appearance(dt, cardid)
    state.pool:run(seq_proc, proc.do_seq)
    return proc.card_normal(dt, cardid)
  end
  function proc.card_normal(dt, cardid)
    local s = 4
    local function _draw(...)
      gfx.setColor(255, 255, 255)
      cards.suit_draw(...)
    end
    common.screen_suit:Button(
      cardid, {draw = _draw}, DEFINE.X, DEFINE.Y_FINAL,
      cards.DEFINE.WIDTH * s, cards.DEFINE.HEIGHT * s
    )
    dt = coroutine.yield()
    return proc.card_normal(dt, cardid)
  end
  function proc.card_disappearance(dt, cardid)
    do_card_fade(dt, cardid)
    state.terminate = true
  end
  function proc.do_seq(dt)
    seq(dt)
    state.pool:run(card_proc, proc.card_disappearance, cardid)
  end

  state.pool:run(card_proc, proc.card_appear, cardid)
  while not state.terminate do
    state.pool:update(dt)
    dt = coroutine.yield()
  end
end
