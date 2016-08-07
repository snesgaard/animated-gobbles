local _atlas
local _frame_data
local _anime = {}
local _drawer

local sequence_args = {
  blast_A = {
    key = "blast_A", time = 0.5, callback = {}, type = "once"
  }
}

local function launch_seq(id, args)
  local type = args.type or "repeat"
  local key = args[2] or args.key
  local time = args[3] or args.time
  local to = args.to
  local from = args.from
  local callback = args.callback or {}
  local still = args.still
  animation.play(id, _atlas, _anime[key], time, type, from, to)
  local vx = not still and _frame_data[key].vx or {}
  entity_engine.sequence(
    id, _frame_data[key].width, _frame_data[key].height, vx, time, type, from, to
  )
  collision_engine.stop(id)
  for chrom, cb in pairs(callback) do
    collision_engine.sequence{
      id, _frame_data[key].hitbox[chrom], time, type = type, to = to,
      from = from, callback = callback
    }
  end
end

function loader.sfx()
  -- Initialize animations
  local data_dir = "resource/sprite/sfx"
  local sheet = love.graphics.newImage(data_dir .. "/sheet.png")
  _atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage(data_dir .. "/normal.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    --resource.atlas.normal[id] = nmap
  end)

  local _index = require (data_dir .. "/info")
  _frame_data = require (data_dir .. "/hitbox")

  table.foreach(_frame_data, function(key, val)
    _anime[key] = initresource(
      resource.animation, animation.init, sheet, _index[key], _frame_data[key],
      true
    )
  end)
  table.foreach(_frame_data, function(key, val)
    _frame_data[key].hitbox = collision_engine.batch_alloc_sequence(
      _frame_data[key].hitbox, hitbox_hail, hitbox_seek
    )
  end)
  _drawer = draw_engine.create_atlas(_atlas)
  draw_engine.foreground_draw
    :subscribe(_drawer.color)
  draw_engine.foreground_stencil
    :subscribe(_drawer.stencil)
end

function init.blast_A(gd, id, x, y, face)
  gamedata.spatial.x[id] = x
  gamedata.spatial.y[id] = y
  gamedata.spatial.face[id] = face
  gamedata.spatial.height[id] = 32
  gamedata.spatial.width[id] = 32
  launch_seq(id, sequence_args.blast_A)
  entity_engine.event
    :filter(function(e)
      return e.id == id and e.type == entity_engine.event_types.done
    end)
    :take(1)
    :map(function(e) return e.id end)
    :subscribe(free_stream)
end
