local weapon_path = "actor/gobbles/"
--local furnace_blade = require(weapon_path .. "furnace_blade")

require "ai"

-- Defines
local width = 1.5
local height = 10
local walkspeed = 30
local runspeed = 90
local jumpspeed = 150
local runjumpspeed = 150

local atlas
local anime = {}
local hitbox = {}


local key = {
  left = "left",
  right = "right",
  down = "down",
  runtoggle = "lalt",
  jump = "space",
  attackA= "a"
}

local gd = gamedata

local action = {}
local control = {}
local states = {}
local gobbles = {}
local weapon = {}
local active_weapon = {}
local data = {}


local hitbox_seek = {
  [0xff0000] = "enemy",
}
local hitbox_hail = {
  [0xff00] = "ally",
}

-- APIS for weapon code
function test_state(id)
  local t = 1.5
  local type = "repeat"
  animation.play(id, atlas, anime.furnace_blade_A, t, type)
  entity_engine.sequence(id, data.width, data.height, data.vx, t, type)

  --collision_engine.stop(id)
  collision_engine.sequence{id, data.hitbox[0xff0000], t}
  collision_engine.sequence{id, data.hitbox[0xff00], t}
end

function loader.gobbles()
  -- Initialize animations
  local sheet = love.graphics.newImage("resource/sheet/gobbles.png")
  atlas = initresource(resource.atlas, function(at, id)
    local nmap = love.graphics.newImage("resource/sheet/gobbles_nmap.png")
    resource.atlas.color[id] = love.graphics.newSpriteBatch(
      sheet, 200, "stream"
    )
    resource.atlas.normal[id] = nmap
  end)

  local index = require "resource/sheet/gobbles"
  data = require "resource/frame/gobbles/furnace_blade_A"
  anime.furnace_blade_A = initresource(
    resource.animation, animation.init, sheet, index.furnace_blade_A2, data, true
  )
  data.hitbox = collision_engine.batch_alloc_sequence(
    data.hitbox, hitbox_hail, hitbox_seek
  )
  --initanime("idle", 4, 15, 22)
  --initanime("walk", 10, 16, 22)
  --initanime("run", 8, 17, 22)
  --initanime("descend", 4, 15, 21)
  --initanime("ascend", 4, 15, 22)
  -- Load normal map
  --nmap:setFilter("linear", "linear")
  -- Initialize hitboxes
  hitbox = {
    body = initresource(
      resource.hitbox, coolision.createaxisbox, -width, -height, width * 2,
      height * 2, "ally"
    )
  }
  --local fb_ground = furnace_blade.load(atlas, anime, initanime, gobbles)
  --weapon.furnace_blade = fb_ground

  -- Fork weapon setting server
  signal.send("set_weapon", 1, "furnace_blade")

  -- HACK
  goobles_drawing_stuff = draw_engine.create_atlas(atlas)
end

function init.gobbles(gd, id, x, y)
    gd.spatial.x[id] = x
    gd.spatial.y[id] = y
    gd.spatial.width[id] = width
    gd.spatial.height[id] = height
    gd.spatial.vx[id] = 0
    gd.spatial.vy[id] = 0
    gd.spatial.face[id] = 1

    gamedata.tag.entity[id] = true

    state_engine.set(id, test_state)
    --signal.send("state@" .. id, states.ground_move)
end

function parser.gobbles(obj)
  local x = obj.x + obj.width * 0.5
  local y = -obj.y + height * 0.5
  return x, y
end
