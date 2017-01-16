-- Specialized suit instances, draws in order according to x coordinate

return function()
  local s = suit.new()
  -- Array for storing coordinates
  s.x = {}
  s.active_x = nil
  -- Change draw register to record x position
  function s:registerDraw(f, val, opt, x, y, w, h)
  	local args = {val, opt, x, y, w, h}
  	local nargs = #args
  	self.draw_queue.n = self.draw_queue.n + 1
  	self.draw_queue[self.draw_queue.n] = function()
  		f(unpack(args, 1, nargs))
  	end
    self.x[self.draw_queue.n] = x
  end

  function s:registerMouseHit(id, ul_x, ul_y, hit)
  	if hit(self.mouse_x - ul_x, self.mouse_y - ul_y) then
  		self.hovered = id
      local do_replace = (not self.active or ul_x > self.active_x)
  		if do_replace and self.mouse_button_down then
  			self.active = id
        self.active_x = ul_x
  		end
  	end
  	return self:getStateName(id)
  end

  function s:getActive() return self.active end

  -- CHange draw to first order according to x-position
  function s:draw()
    -- Sort drawers according to the x-axis
  	self:exitFrame()
  	love.graphics.push('all')

    local draw_order = range(self.draw_queue.n)
    table.sort(draw_order, function(a, b)
      return self.x[a] < self.x[b]
    end)
  	for _, i in pairs(draw_order) do
  		self.draw_queue[i]()
  	end

  	love.graphics.pop()
  	self.draw_queue.n = 0
    self.x = {}
  	self:enterFrame()
  end

  return s
end
