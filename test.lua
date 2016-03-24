loader = {}
actor = {}
init = {}
parser = {}

require "io"
require "light"
require "math"
require "camera"

require "actor/gobbles"
require "prop/latern_A"

gfx = love.graphics

local camera_id
local fb = {}

function love.load()
  camera_id = setdefaults()
  gamedata.ai.control[camera_id] = camera.wobble(0, 0)
  level = sti.new("resource/test3.lua")
  table.foreach(level, print)
  renderbox.do_it = false
  -- Load entity
  loader.gobbles()
  loader.lantern_A()
  --love.event.quit()
  --initresource(gamedata, init.lantern_A, 300, -80)
  --gobid = actor.gobbles(gamedata, 100, -60)
  -- Light
  light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 800, 1200, 1200)
  light.create_static(gamedata)
  cubeshad = loadshader("resource/shader/cube.glsl", "resource/shader/cube_vert.glsl")
  dnmap = gfx.newImage("resource/tileset/no_normal.png")
  fb.colormap = gfx.newCanvas(width, height)
  fb.normalmap = gfx.newCanvas(width, height)

  -- Intansiate objects
  for _, obj in pairs(level.layers.entity.objects) do
    local type_parse = parser[obj.type]
    local type_init = init[obj.type]
    if type_parse and type_init then
      local args = {type_parse(obj)}
      initresource(gamedata, type_init, unpack(args))
    end
  end
end

function love.update(dt)
  -- Clean resources for next
  --for _, atlas in pairs(resource.atlas) do
  --  atlas.color:clear()
  --end
  --for id, ctrl in pairs(gamedata.actor.control) do
  --  coroutine.resume(ctrl, gamedata, id)
  --end
  update.system(dt)
  for id, co in pairs(gamedata.ai.control) do
    coroutine.resume(co, id)
  end
  update.action(gamedata)
  update.movement(gamedata, level)
  --coroutine.resume(animatelight, gamedata, lightids)
end

function love.draw()
  camera.transformation(camera_id, level)
  local scene = function()
    level:drawLayer(level.layers.geometry)
    for id, atlas in pairs(resource.atlas.color) do
      local normal = resource.atlas.normal[id]
      if normal then cubeshad:send("normals", normal) end
      gfx.draw(atlas)
    end
  end
  -- Clear canvas
  gfx.setCanvas(fb.colormap, fb.normalmap)
  gfx.clear({255, 255, 255, 255}, {0, 0, 0, 0})
  gfx.setBackgroundColor(255, 255, 255, 255)
  -- Draw background onto color map
  gfx.setCanvas(fb.colormap)
  gfx.setShader()
  level:drawLayer(level.layers.background)
  for bgobj, _ in pairs(tag.background) do
    local draw = gamedata.radiometry.draw[bgobj]
    if draw then coroutine.resume(draw, bgobj) end
  end
  for _, atlas in pairs(resource.atlas.color) do
    gfx.draw(atlas)
    atlas:clear()
  end
  gfx.setCanvas(fb.colormap, fb.normalmap)
  for ent, _ in pairs(tag.entity) do
    local draw = gamedata.radiometry.draw[ent]
    if draw then
      coroutine.resume(draw, ent)
    end
  end
  --level:draw(level.layers.background)
  gfx.setShader(cubeshad)
  cubeshad:send("normals", dnmap)
  scene()
  gfx.setCanvas()
  gfx.setShader()
  gfx.setBackgroundColor(0, 0, 0, 0)
  if true then
    for lightid, _ in pairs(tag.point_light) do
      light.draw_point(lightid, scene, fb.colormap, fb.normalmap)
    end
    -- Draw ambient
    light.draw_ambient(fb.colormap, {100, 100, 255}, 0.2)
  else
    gfx.origin()
    gfx.draw(fb.colormap)
  end
  for _, atlas in pairs(resource.atlas.color) do
    atlas:clear()
  end
end
