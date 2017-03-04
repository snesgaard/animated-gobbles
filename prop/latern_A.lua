local gfx = love.graphics
local fun = require "modules/functional"
local sprite = require "sprite"

local atlas
local anime = {}
local frame_data = {}

lantern_A = {}
local flares = {}

local base_width = 200
local flicker_amp = 2
local base_height = 2
local flare_amp = 0.2

local function launch_seq(args)
  local type = args.type or "repeat"
  local id = args[1]
  local key = args[2]
  local time = args[3]
  local to = args.to
  local from = args.from
  local callback = args.callback or {}
  local still = args.still
  animation.play{id, atlas, anime[key], time, type, from, to}
  local vx = not still and frame_data[key].vx or {}
  collision_engine.stop(id)
  for chrom, cb in pairs(callback) do
    collision_engine.sequence{
      id, frame_data[key].hitbox[chrom], time, type = type, to = to,
      from = from, callback = callback
    }
  end
end

local function draw_flare(id)
  local spa = gamedata.spatial
  local x = spa.x[id] - 0.5
  local y = spa.y[id]
  local s = spa.height[id] or 0
  gfx.setColor(100, 50, 0, 50)
  gfx.circle("fill", x, -y, 3.5 * s, 10)
  gfx.setColor(200, 200, 0, 50)
  gfx.circle("fill", x, -y, s * 2, 10)
end
local function all_draw_flare()
  fun.fmap(draw_flare, flares)
end

function lantern_A.flicker(id, freq, phase)
  local function f(id)
    local p = freq * system.time + phase
    local sinp = math.sin(p)
    local cosp = math.cos(p)
    gamedata.spatial.width[id] = base_width + sinp * flicker_amp
    gamedata.spatial.height[id] = base_height + sinp * flare_amp
    cosp = math.abs(cosp)
    sinp = math.abs(sinp)
    local s = (cosp + sinp) * 1
    gamedata.radiometry.color[id] = {
      (243 * cosp + sinp * 195) / s,
      (156 * cosp + sinp * 119) / s,
      (31 * cosp + sinp * 10) / s,
    }
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

local function create_draw(id)
  --local anime = animation.draw(atlas, animid, 0.75)
  --animation.play(id, atlas, animid, 0.75)
  local spatial = gamedata.spatial
  local function f(id)
    --animation.entitydraw(id, anime)
    table.insert(flares, id)
    return f(coroutine.yield())
  end
  return coroutine.create(f)
end

function loader.lantern_A()
  -- Initialize animations
  atlas, anime, frame_data = prop.get_resource(true)

  local sprite_draw = draw_engine.create_atlas(atlas)
  local glow_draw = draw_engine.create_primitive(
    all_draw_flare, false, false, true
  )

  draw_engine.register_type("lantern_A", sprite_draw)
  draw_engine.register_type("lantern_A_glow", glow_draw)
end

function init.lantern_A(gd, id, x, y)
  local spatial = gd.spatial
  spatial.x[id] = x
  spatial.y[id] = y
  spatial.width[id] = base_width

  local rng = love.math.random
  gd.ai.control[id] = lantern_A.flicker(id, 3.14 / 0.75, rng() * math.pi * 0.5)

  local radiometry = gd.radiometry
  local s = 0.0
  radiometry.color[id] = {243 * s, 156 * s, 151 * s}
  --radiometry.draw[id] = create_draw(id)
  --launch_seq{id, "lantern_A", 1.0}
  -- HACK remove from global scoep later
  --print("launch", atlas, anime)
  --lambda.run(sprite.cycle, atlas, anime.latern_A, sprite.entity_center(id))

  gamedata.tag.point_light[id] = true
  gamedata.tag.background[id] = true
end

function parser.lantern_A(obj)
  local x = math.floor(obj.x + obj.width * 0.5)
  local y = math.floor(-obj.y + obj.height * 0.5)
  return x, y
end

function lantern_A.clear()
  flares = {}
  --resource.atlas.color[atlas]:clear()
end
