require "math"

animation = {}

function animation.init(anime, id, im, index, frames, ox, oy, normal_hack)
  anime.quads[id] = {}
  local x = index.x
  local y = index.y
  local w = index.w
  local h = index.h
  local fw = w / frames
  for i = 1, frames do
    local q = love.graphics.newQuad(
      x + fw * (i - 1), y, fw, h, im:getDimensions()
    )
    table.insert(anime.quads[id], q)
  end
  anime.width[id] = fw
  anime.height[id] = h
  anime.x[id] = ox or 0
  anime.y[id] = oy or 0
  anime.normals[id] = normal_hack or false
end

function animation.init(anime, id, im, index, frame_data, normal_hack)
  local frames = #frame_data.frame_size
  local x = index.x
  local y = index.y
  local w = index.w
  local h = index.h
  anime.x[id] = frame_data.offset_x or 0
  anime.y[id] = frame_data.offset_y or 0
  anime.quads[id] = {}
  for i = 1, frames do
    local fw = frame_data.frame_size[i]
    local q = love.graphics.newQuad(
      x, y, fw, h, im:getDimensions()
    )
    table.insert(anime.quads[id], q)
    x = x + fw
  end
  anime.normals[id] = normal_hack or false
end

function animation.draw(batch_id, atid, anid, time, type, from, to)
  local atlas = resource.atlas.color[atid]
  local anime = resource.animation

  type = type or "repeat"
  from = from or 1
  to = to or #anime.quads[anid]
  local ox = anime.x[anid]
  local oy = anime.y[anid]
  local nh = anime.normals[anid]

  local i = from
  local dir = 1
  local border
  local ft
  if type == "repeat" then
    border = function(i, dir)
      return from, 1
    end
    ft = time / (to - from + 1)
  elseif type == "bounce" then
    border = function(i, dir)
      if dir == 1 then
        return math.max(from, to - 1), -1
      else
        return math.min(from + 1, to), 1
      end
    end
    ft = time / (to - from) * 0.5
  elseif type == "once" then
    border = function(i, dir)
      return to, 0
    end
    ft = time / (to - from + 1)
  end
  local f = function(dt, x, y, r, sx, sy)
    local t = ft
    --dt = 0
    while true do
      while t > 0 do
        t = t - dt
        --x = math.floor(x - sx * ox)
        --y = math.floor(y - sy * oy)
        x = x - sx * ox[i]
        y = y - sy * oy[i]
        -- HACK
        local a = (sx > 0 or not nh) and 1 or -1
        atlas:setColor(255, 255, 255, 255 * a)
        atlas:set(batch_id, anime.quads[anid][i], x, y, r, sx, sy)
        dt, x, y, r, sx, sy = coroutine.yield(true)
      end
      t = ft + t
      i = i + dir
      if i > to or i < from then
         i, dir = border(i, dir)
         --if dir == 0 then return end
      end
      -- HACK: Return when animation no longer evolving
    end
  end
  return f
end

function animation.entitydraw(id, func)
  local act = gamedata.spatial
  local x = act.x[id]
  local y = act.y[id]
  local f = act.face[id] or 1
  return func(system.dt, x, -y, 0, f, 1)
end

function animation.uidraw(id, func)
  local act = gamedata.spatial
  local x = act.x[id]
  local y = act.y[id]
  local fx = act.face[id] or 1
  local fy = act.flip[id] or 1
  return func(system.dt, x, y, 0, fx, fy)
end

local bleh_q = love.graphics.newQuad(0, 0, 32, 32, 32, 32)
local _all_batch_ids = {}
local _free_batch_ids = {}
local function _fetch_batch_id(atlas_id, id)
  local batch_ids = _all_batch_ids[atlas_id]
  if not batch_ids then
    batch_ids = {}
    _all_batch_ids[atlas_id] = batch_ids
  end
  local bid = batch_ids[id]
  if not bid then
    local function _alloc_bid()
      local _free_table = _free_batch_ids[atlas_id] or {}
      for bid, bid in pairs(_free_table) do
        _free_table[bid] = nil
        return bid
      end
      return resource.atlas.color[atlas_id]:add(0, 0, 0, 0, 0)
    end
    bid = _alloc_bid()
    batch_ids[id] = bid
  end
  return bid
end
function animation.entitydrawer(arg)
  local id, atid, anid, time, type, from, to = unpack(arg)
  local batch_id = _fetch_batch_id(atid, id)
  local anime = animation.draw(batch_id, atid, anid, time, type, from, to)
  local g = coroutine.wrap(function(...)
    anime(...)
    signal.send("animation_done@" .. id)
  end)
  local draw = arg.draw or animation.entitydraw
  local function f(id)
    draw(id, g)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end


local _entity_animations = {}
function animation.update()
  for id, co in pairs(_entity_animations) do
    coroutine.resume(co, id)
  end
end
function animation.play(arg)
  local id = arg[1]
  _entity_animations[id] = animation.entitydrawer(arg)
end
function animation.stop(id)
  _entity_animations[id] = nil
end
function animation.is_playing(id)
  return _entity_animations[id] ~= nil
end
function animation.erase(id)
  animation.stop(id)
  for atlas_id, batch_table in pairs(_all_batch_ids) do
    local _atlas = resource.atlas.color[atlas_id]
    local bid = batch_table[id]
    if bid then
      _atlas:set(bid, 0, 0, 0, 0, 0)
      local _free_atlas = _free_batch_ids[atlas_id] or {}
      _free_atlas[bid] = bid
      _free_batch_ids[atlas_id] = _free_atlas
     end
  end
end
function animation.release(id, ...)
  local atlases = {...}
  for _, atlas_id in pairs(atlases) do
    local _batches = _all_batch_ids[atlas_id]
    if _batches then _batches[id] = nil end
  end
end

return animation
