input = {}

function input.isdown(key)
  local p = system.pressed[key] or 0
  local r = system.released[key] or 0
  return p > r
end

function input.ispressed(key)
  local p = system.pressed[key] or 0
  local t = system.time
  local b = system.buffer[key] or 0.2
  return p and t - p < b
end

function input.latch(key)
  system.pressed[key] = 0
end


return input
