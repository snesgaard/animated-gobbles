motion = {}

function motion.line_segment(id, dst_x, dst_y, speed, dt)
  local x_org = gamedata.spatial.x[id]
  local y_org = gamedata.spatial.y[id]

  local dx = dst_x - x_org
  local dy = dst_y - y_org
  local l = math.sqrt(dx * dx + dy * dy)

  local completed = function()
    gamedata.spatial.x[id] = dst_x
    gamedata.spatial.y[id] = dst_y
  end
  if l < 1 then
    completed()
    return dt
  end
  dx = dx / l
  dy = dy / l

  local x, y = x_org, y_org
  local vx, vy = 0, 0
  while (dst_y - y - vy) * dy >= 0 and (dst_x - x - vx) * dx >= 0 do
    vx, vy = dx * dt * speed, dy * dt * speed
    x = x + vx
    y = y + vy
    gamedata.spatial.x[id] = x
    gamedata.spatial.y[id] = y
    dt = coroutine.yield()
  end
  completed()
  return dt
end
