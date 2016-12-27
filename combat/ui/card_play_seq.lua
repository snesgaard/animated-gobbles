local DEFINE = {
  MIN_CARD_TIME = 1.0,
  X = 20,
  Y_INIT = -325,
  Y_FINAL = 25,
  MOVE_TIME = 1000
}

return function(dt, cardid, seq)
  local state = {
    x = {},
    y = {},
    terminate = false
  }
  local proc = {}
  local pool = lambda_pool.new()
  function proc.card_enter(dt)
    state.x[cardid] = DEFINE.X
    state.y[cardid] = DEFINE.Y_INIT
    combat.visual.move_to(
      cardid, DEFINE.X, DEFINE.Y_FINAL, DEFINE.MOVE_TIME, dt, state
    )
    return proc.seq(dt)
  end
  function proc.card_exit(dt)
    combat.visual.move_to(
      cardid, DEFINE.X, DEFINE.Y_INIT, DEFINE.MOVE_TIME, dt, state
    )
    combat.visual.wait(0.25, dt)
    state.terminate = true
  end
  function proc.seq(dt)
    local ts = love.timer.getTime()
    seq(dt)
    local te = love.timer.getTime()
    combat.visual.wait(DEFINE.MIN_CARD_TIME - te + ts, dt)
    return proc.card_exit(dt)
  end
  pool:run(proc.card_enter)
  while not state.terminate do
    pool:update(dt)
    cards.render(cardid, nil, state.x[cardid], state.y[cardid])
    dt = coroutine.yield()
  end
end
