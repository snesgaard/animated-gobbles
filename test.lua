loader = {}
actor = {}
init = {}
parser = {}
drawer = {}

require "io"
require "light"
require "math"
require "camera"
require "draw"
require "sfx"

require "actor/gobbles/base"
require "prop/latern_A"

gfx = love.graphics

local camera_id
local fb = {}

function love.load()
  camera_id = setdefaults()
  gamedata.ai.control[camera_id] = camera.wobble(0, 0)
  level = sti.new("resource/test3.lua")
  table.foreach(level.layers.geometry, print)
  renderbox.do_it = false
  -- Load entity
  loader.sfx()
  loader.gobbles()
  loader.lantern_A()
  loader.drawing()
  --loader.blast()
  --love.event.quit()
  --initresource(gamedata, init.lantern_A, 300, -80)
  --gobid = actor.gobbles(gamedata, 100, -60)
  -- Light
  --light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 800, 1200, 1200)
  light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 200, 400, 400)
  light.create_static(gamedata)
  cubeshad = loadshader("resource/shader/cube.glsl", "resource/shader/cube_vert.glsl")
  primshad = loadshader("resource/shader/primitives.glsl")
  dnmap = gfx.newImage("resource/tileset/no_normal.png")
  fb.colormap = gfx.newCanvas(width, height)
  fb.scenemap = gfx.newCanvas(width, height)
  fb.normalmap = gfx.newCanvas(width, height)
  fb.bloommap = gfx.newCanvas(width, height)

  -- Intansiate objects
  for _, obj in pairs(level.layers.entity.objects) do
    local type_parse = parser[obj.type]
    local type_init = init[obj.type]
    if type_parse and type_init then
      local args = {type_parse(obj)}
      initresource(gamedata, type_init, unpack(args))
    end
  end

  --initresource(gamedata, init.blast, 100, 100)
end

map_geometry = {}
function map_geometry.check_thin_platform(id)
  local gd = gamedata
  local xl = gd.spatial.x[id] - gd.spatial.width[id]
  local xu = gd.spatial.x[id] + gd.spatial.width[id]
  local y = gd.spatial.y[id] - gd.spatial.height[id] - 1
  return tilemap.all_of_type(level, "geometry", xl, xu, y, y, "thin")
end
function map_geometry.diplace(id, dx, dy)
  physics.displace_entity(level, "geometry", id, dx or 0, dy or 0)
end

function love.update(dt)
  -- Clean resources for next
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
    drawing.draw{function()
      level:drawLayer(level.layers.geometry)
    end}
    drawing.run{drawer.gobbles}
    drawing.run{drawer.sfx, bloom = true}
  end
  -- Clear canvas
  drawing.init()
  --- Draw background
  drawing.draw{function()
    level:drawLayer(level.layers.background)
  end, background = true}
  for bgobj, _ in pairs(gamedata.tag.background) do
    local draw = gamedata.radiometry.draw[bgobj]
    if draw then coroutine.resume(draw, bgobj) end
  end
  lantern_A.draw()
  lantern_A.clear()
  gfx.setColor(255, 255, 255, 255)
  --gfx.setCanvas(fb.colormap, fb.normalmap, fb.bloommap)
  -- Draw foreground
  for ent, _ in pairs(gamedata.tag.entity) do
    local draw = gamedata.radiometry.draw[ent]
    if draw then
      coroutine.resume(draw, ent)
    end
  end
  for ent, _ in pairs(gamedata.tag.sfx) do
    local draw = gamedata.radiometry.draw[ent]
    if draw then
      coroutine.resume(draw, ent)
    end
  end
  --level:draw(level.layers.background)
  --gfx.setShader(cubeshad)
  scene()
  local cmap, nmap, bmap, smap = drawing.get_canvas()
  --gfx.setCanvas(fb.scenemap)
  gfx.setCanvas(smap)
  gfx.clear()
  gfx.setShader()
  gfx.setBackgroundColor(0, 0, 0, 0)
  if true then
    for lightid, _ in pairs(gamedata.tag.point_light) do
      light.draw_point(lightid, scene, cmap, nmap)
    end
    -- Draw ambient
    light.draw_ambient(cmap, {100, 100, 255}, 0.1)
    -- Draw bloom
    --gfx.origin()
    --gfx.draw(fb.glowmap)
    gfx.setCanvas()
    light.bloom(smap, bmap)
  else
    gfx.push()
    gfx.origin()
    gfx.setShader()
    gfx.setCanvas()
    gfx.setColor(255, 255, 255, 255)
    gfx.draw(nmap)
    gfx.pop()
  end
  if renderbox.do_it then
    gfx.setColor(255, 255, 255, 200)
    local spa = gamedata.spatial
    for id, _ in pairs(gamedata.tag.entity) do
      gfx.rectangle(
        "line", spa.x[id] - spa.width[id], -spa.y[id] - spa.height[id],
        spa.width[id] * 2, spa.height[id] * 2
      )
    end
  end
  for _, atlas in pairs(resource.atlas.color) do
    atlas:clear()
  end
end
