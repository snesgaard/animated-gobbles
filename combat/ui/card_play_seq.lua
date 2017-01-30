local common = require "combat/ui/common"

local DEFINE = {
  MIN_CARD_TIME = 1.0,
  X = 820,
  Y_INIT = -325,
  Y_FINAL = 25,
  MOVE_TIME = 1000
}

-- HACK TEST CODE


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



return function(dt, cardid, seq, card_presentation)
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
    cards.animate_fade(dt, cardid, common.screen_suit, DEFINE.X, DEFINE.Y_FINAL)
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
