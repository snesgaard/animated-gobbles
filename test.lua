loader = {}
actor = {}

require "io"
require "actor/gobbles"
require "light"
require "math"

gfx = love.graphics

local function loadshader(path, path2)
  --path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()

  if path2 == nil then
    return love.graphics.newShader(fstring)
  else
    --path2 = "resource/shader/" .. path2
    local f2 = io.open(path2, "rb")
    local fstring2 = f2:read("*all")
    f2:close()
    return love.graphics.newShader(fstring, fstring2)
  end
end

function love.load()
  setdefaults()
  level = sti.new("resource/test2.lua")
  local ent = level.layers.entity
  for y = 1, ent.height do
    for x = 1, ent.width do
      local d = ent.data[y][x]
      if d then
        local t = d.tileset
        --table.foreach(d.properties, print)
        local tileset = level.tilesets[t]
      end
    end
  end
  local geo = level.layers.geometry
  local _geodraw = geo.draw
  function geo.draw()
    --love.graphics.setColor(200, 200, 200)
    _geodraw()
  end
  -- Setup background
  local bg = level.layers.background
  local _draw = bg.draw
  local s = loadshader("resource/shader/blur.glsl")
  local canvas = love.graphics.newCanvas(
    gamedata.visual.width, gamedata.visual.height
  )
  -- Setup entity layer
  local ent = level.layers.entity
  function ent:draw()
    --love.graphics.scale(1, -1)
    for _, atlas in pairs(gamedata.resource.atlas) do
      --love.graphics.draw(atlas, 0, 0)
      --atlas:clear()
    end
    local at = gamedata.resource.atlas
    love.graphics.draw(at.gobbles, 0, 0)
    --love.graphics.setColor(255, 255, 255, 100)
    if renderbox.do_it then
      for bid, lx in pairs(renderbox.lx) do
        local hx = renderbox.hx[bid]
        local ly = renderbox.ly[bid]
        local hy = renderbox.hy[bid]
        gfx.rectangle("line", lx, hy, hx - lx, ly - hy)
      end
    end
    --love.graphics.setColor(5, 5, 0, 0)
  end
  renderbox.do_it = false
  -- Load entity
  loader.gobbles(gamedata)
  --love.event.quit()
  gobid = actor.gobbles(gamedata, 100, -60)
  -- Light
  light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 800, 1200, 1200)
  light.create_static(gamedata)
  lightids = {
    initresource(
      gamedata.light.point, light.init_point, 100, 85, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 180, 65, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 260, 65, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 100, 165, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 180, 165, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 260, 125, 60, {243, 156, 31}, 1
    ),
    initresource(
      gamedata.light.point, light.init_point, 260, 175, 60, {243, 156, 31}, 1
    ),
  }
  local laternim = gfx.newImage("resource/sheet/lantern.png")
  gamedata.resource.atlas.lantern = love.graphics.newSpriteBatch(
    laternim, 200, "stream"
  )
  local index = {x = 0, y = 0, w = laternim:getWidth(), h = laternim:getHeight()}
  local animid = initresource(
    gamedata.animations, animation.init, laternim, index, 5, 2, 11
  )
  animatelight = coroutine.create(function(gd, lids)
    local phase = {}
    local freq = {}
    local anime = {}
    local rng = love.math.random
    for _, id in pairs(lightids) do
      phase[id] = rng() * math.pi * 0.5
      freq[id] = rng() * 2 + 3
      anime[id] = animation.draw(gd, "lantern", animid, 0.75)
    end
    local lp = gamedata.light.point
    while true do
      for _, id in pairs(lightids) do
        local p = freq[id] * gd.system.time + phase[id]
        local sinp = math.sin(p)
        local cosp = math.cos(p)

        lp.radius[id] = 60 + sinp * 3
        cosp = math.abs(cosp)
        sinp = math.abs(sinp)
        local s = cosp + sinp
        lp.color[id] = {
          (243 * cosp + sinp * 195) / s,
          (156 * cosp + sinp * 119) / s,
          (31 * cosp + sinp * 10) / s,
        }
        coroutine.resume(anime[id], gd.system.dt, lp.x[id], lp.y[id], 0, 1, 1)
      end
      coroutine.yield()
    end
  end)
  drawlamp = function(gamedata, id)
    local lp = gamedata.light.point
    --gfx.rectangle("fill", lp.x[id], lp.y[id], 10, 10)
    --gfx.draw(laternim, lp.x[id] - 2, lp.y[id]  - 11)
    gfx.draw(gamedata.resource.atlas.lantern)
  end
  --gamedata.visual.x, gamedata.visual.y = 100, 100
  gamedata.visual.scale = 5
  cubeshad = loadshader("resource/shader/cube.glsl", "resource/shader/cube_vert.glsl")
  dnmap = gfx.newImage("resource/tileset/no_normal.png")
end

function love.update(dt)
  -- Clean resources for next
  for _, atlas in pairs(gamedata.resource.atlas) do
    atlas:clear()
  end
  for id, ctrl in pairs(gamedata.actor.control) do
    coroutine.resume(ctrl, gamedata, id)
  end
  update.system(gamedata, dt)
  update.ai_n_combat(gamedata)
  update.movement(gamedata, level)
  coroutine.resume(animatelight, gamedata, lightids)
end

function love.draw()
  local x, y = gamedata.visual.x, gamedata.visual.y
  --love.graphics.translate(-x, y)
  love.graphics.scale(gamedata.visual.scale)
  local scene = function()
    --level:draw()
    level:drawLayer(level.layers.geometry)
    cubeshad:send("normals", gamedata.resource.images.gobbles_normals)
    level:drawLayer(level.layers.entity)
    --level.layers.entity:draw()
    --gfx.rectangle("fill", 100, 100, 100, 100)
  end
  -- Clear canvas
  gfx.setCanvas(
    gamedata.resource.canvas.colormap, gamedata.resource.canvas.normalmap
  )
  gfx.clear({255, 255, 255, 255}, {0, 0, 0, 0})
  gfx.setBackgroundColor(255, 255, 255, 255)
  -- Draw background onto color map
  gfx.setCanvas(gamedata.resource.canvas.colormap)
  gfx.setShader()
  level:draw(level.layers.background)
  for _, lightid in ipairs(lightids) do
    drawlamp(gamedata, lightid)
  end
  gfx.setCanvas(
    gamedata.resource.canvas.colormap, gamedata.resource.canvas.normalmap
  )
  --level:draw(level.layers.background)
  gfx.setShader(cubeshad)
  cubeshad:send("normals", dnmap)
  scene()
  gfx.setCanvas()
  gfx.setShader()
  gfx.setBackgroundColor(0, 0, 0, 0)
  if true then
    for _, lightid in ipairs(lightids) do
      light.draw_point(
        gamedata, lightid, scene, gamedata.resource.canvas.colormap,
        gamedata.resource.canvas.normalmap
      )
    end
    -- Draw ambient
    light.draw_ambient(gamedata, gamedata.resource.canvas.colormap)
  end
  gfx.origin()
  --gfx.draw(gamedata.resource.canvas.normalmap)
end
