local event = require "combat/event"
local resource = require "resource"

local asset = {
  sheet = resource.create({
		color = {},
		normal = {},
	}),
	animation = resource.create({
		-- List of quads
		quads = {},
		-- List of coordinates/frameoffsets with respect to the sprites origin,
		x = {},
		y = {},
		--Run time of the animation
		time = {},
    -- In the hitbox table all values are of the type [[number]]
    -- The outer list is a pr. frame basis
    -- The inner list is a pr. hitbox in frame basis
    hitbox = {}
	}),
  -- Global variables
  default_normal,
}

local sprite = {}

sprite.suit = {}

-- Loop because I am too lazy to figure out inheritance in Lua :P
for _, key in pairs({"base", "projectile"}) do
  local _suit = suit.new()
  function _suit:draw(normal_set)
  	--self:exitFrame()
  	love.graphics.push('all')
  	for i = 1,self.draw_queue.n do
  		self.draw_queue[i](normal_set)
  	end
  	love.graphics.pop()
  	--self.draw_queue.n = 0
  	--self:enterFrame()
  end

  function _suit:clear()
    self:enterFrame()
    self.draw_queue.n = 0
  end

  function _suit:registerDraw(f, ...)
  	local args = {...}
  	local nargs = select('#', ...)
  	self.draw_queue.n = self.draw_queue.n + 1
  	self.draw_queue[self.draw_queue.n] = function(normal_set)
  		f(normal_set, unpack(args, 1, nargs))
  	end
  end

  function _suit:sprite(sheet, quad, ...)
    local opt, x, y, r, sx, sy, ox, oy = self.getOptionsAndSize(...)
    r = r or 0
    sx = sx or 1
    sy = sy or 1
    local id = opt.id or sheet
    local color = opt.color or {255, 255, 255, 255}
    local _, _, w, h = quad:getViewport()

    --opt.state = self:registerHitbox(id, x, y, w * sx, h * sy)
    local function default_draw(sheet, quad, opt, x, y, r, sx, sy, ox, oy, color)
      gfx.setColor(unpack(color))
      gfx.draw(sheet, quad, x, -y, r, sx, sy, ox, oy)
    end
    local draw = opt.draw or default_draw
    local normals = opt.normal or asset.default_normal
    local function reg_draw(normal_set, ...)
      if normal_set then normal_set(normals) end
      draw(...)
    end
    self:registerDraw(reg_draw, sheet, quad, opt, x, y, r, sx, sy, ox, oy, color)
  end

  sprite.suit[key] = _suit
end

-- This function has the following signatures:
-- id -> id -> float -> float -> float or 0 -> float or 1 -> float or 1
-- id -> id -> (float -> float -> float or 0 -> float or 1 -> float or 1)
local function _do_sprite_run(
  dt, cycle_type, ...
)
  local function get_param(opt, ...)
    if type(opt) == "table" then
      return opt, ...
    else
      return {}, opt, ...
    end
  end
  local opt, sheet_id, anime_id, x, y, r, sx, sy = get_param(...)
  if type(x) == "number" then
    return sprite.cycle(
      dt, cycle_type, opt, sheet_id, anime_id, function() return x, y, r, sx, sy end
    )
  elseif type(x) ~= "function" then
    error(string.format("Unsupported combination of arguments: %s", type(x)))
  end
  -- This function fetches the spatial state of the sprite
  local state = x
  local _suit = opt.suit or sprite.suit.base
	local sheet = asset.sheet.color[sheet_id]
  local sheet_normal = asset.sheet.normal[sheet_id]

	local quads = asset.animation.quads[anime_id]
  local ox = asset.animation.x[anime_id]
  local oy = asset.animation.y[anime_id]
	local frames = #quads
	local frametime = asset.animation.time[anime_id] / frames
  if cycle_type == "bounce" then
    frametime = 0.5 * asset.animation.time[anime_id] / frames
  end

  local function _handle_frame(t, dt, f)
    t = t + frametime
    for hitbox_id, box_list in pairs(asset.animation.hitbox[anime_id]) do
      --print(hitbox_id, box_list[f])
      local b = box_list[f]
      if #b == 4 then
        local bx, by, bw, bh = unpack(b)
        local x, y = state()
        signal.emit(event.hitbox.appear, hitbox_id, bx + x, by + y, bw, bh)
      end
    end
    while t > 0 do
      t = t - dt
      local x, y, r, sx, sy = state()
      r = r or 0
      sx = sx or 1
      sy = sy or 1
      _suit:sprite(
        sheet, quads[f], {normal = sheet_normal}, x, y, r, sx, sy, ox[f],
        oy[f]
      )
      dt = coroutine.yield()
    end
    return t, dt
  end

	local t = 0
  repeat
    for f = 1, frames do
      t, dt = _handle_frame(t, dt, f)
    end
    if cycle_type == "bounce" then
      for f = frame - 1, 2, -1 do
        t, dt = _handle_frame(t, dt, f)
      end
    end
  until cycle_type == "once"
  return dt
end

function sprite.cycle(dt, ...)
  return _do_sprite_run(dt, "repeat", ...)
end

function sprite.once(dt, ...)
  return _do_sprite_run(dt, "once", ...)
end

function sprite.entity_center(id)
  local sp = gamedata.spatial
  return function() return sp.x[id], sp.y[id], 0, sp.face[id], 1 end
end

function sprite.load(base_path)
  local sheet = gfx.newImage(base_path .. "/sheet.png")
  local normal = gfx.newImage(base_path .. "/normal.png")
  local hitbox = require (base_path .. "/hitbox")
  local info = require (base_path .. "/info")
  -- Allocate into resource table
  local sheet_id = resource.alloc(asset.sheet)
  asset.sheet.color[sheet_id] = sheet
  asset.sheet.normal[sheet_id] = normal

  local anime_ids = {}
  for key, pos in pairs(info) do
    local id = resource.alloc(asset.animation)--anime_ids[key]
    anime_ids[key] = id
    local hit = hitbox[key]
    local x = pos.x
    local y = pos.y
    local h = pos.h
    asset.animation.quads[id] = map(
      function(fs)
        local q = love.graphics.newQuad(
          pos.x, y, fs, h, sheet:getDimensions()
        )
        pos.x = pos.x + fs
        return q
      end, hit.frame_size
    )
    asset.animation.x[id] = hit.offset_x
    asset.animation.y[id] = hit.offset_y
    asset.animation.time[id] = hit.time
    asset.animation.hitbox[id] = hit.hitbox
  end

  return sheet_id, anime_ids
end

function loader.sprite()
  asset.default_normal = gfx.newImage("resource/tileset/no_normal.png")
end

return sprite
