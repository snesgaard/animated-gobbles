loader = {}
actor = {}
init = {}
parser = {}
drawer = {}

require "io"
require "light"
require "math"
require "camera"
require "draw_engine"
require "state_engine"
require "collision_engine"
require "entity_engine"
require "sfx"
require "debug_console"

require "actor/gobbles/base"
require "prop/latern_A"

gfx = love.graphics

local camera_id
local fb = {}

function love.load()
  camera_id = setdefaults()
  level = sti.new("resource/test3.lua")
  renderbox.do_it = false
  -- Load entity
  loader.draw_engine()
  loader.sfx()
  loader.gobbles()
  loader.lantern_A()
  --loader.blast()
  --love.event.quit()
  --initresource(gamedata, init.lantern_A, 300, -80)
  --gobid = actor.gobbles(gamedata, 100, -60)
  -- Light
  --light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 800, 1200, 1200)
  light.create_dynamic(gamedata, gfx.getWidth(), gfx.getHeight(), 200, 400, 400)
  light.create_static(gamedata)

  -- Intansiate objects
  ent_table = {}
  for _, obj in pairs(level.layers.entity.objects) do
    local type_parse = parser[obj.type]
    local type_init = init[obj.type]
    if type_parse and type_init then
      local args = {type_parse(obj)}
      local id = initresource(gamedata, type_init, unpack(args))
      ent_table[obj.name] = id
      print("entity", obj.name, id)
    end
  end
  concurrent.detach(camera.follow, camera_id, ent_table.player, level)
  --initresource(gamedata, init.gobbles, 200, -100)
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
  signal.send("update", dt)
  for id, co in pairs(gamedata.ai.control) do
    coroutine.resume(co, id)
  end
  update.action(gamedata)
  update.movement(gamedata, level)
  collision_engine.update(dt)
  state_engine.update()
  entity_engine.update(dt)
  animation.update()
  --coroutine.resume(animatelight, gamedata, lightids)
end

function love.draw()
  camera.transformation(camera_id, level)
  -- Clear canvas
  local scenemap, colormap, glowmap, normalmap = draw_engine.get_canvas()
  gfx.setCanvas(scenemap, colormap, glowmap, normalmap)
  gfx.clear({0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0})
  gfx.setStencilTest()

  for id, _ in pairs(gamedata.tag.entity) do
    local draw = gamedata.radiometry.draw[id]
    if draw then coroutine.resume(draw, id) end
  end
  for id, _ in pairs(gamedata.tag.sfx) do
    local draw = gamedata.radiometry.draw[id]
    if draw then coroutine.resume(draw, id) end
  end
  local sqdraw = draw_engine.create_primitive(function()
    gfx.setColor(255, 255, 255, 255)
    gfx.rectangle("fill", 100, 100, 100, 20)
  end, false, true, true)
  local leveldraw = draw_engine.create_level(level, "geometry")
  local bgdraw = draw_engine.create_level(level, "background")
  -- SFX
  goobles_drawing_stuff.color(false)
  draw_engine.type_drawer.sfx.color(false)
  sqdraw.color()
  gfx.setStencilTest("equal", 0)
  gfx.stencil(function()
    goobles_drawing_stuff.stencil(false)
    sqdraw.stencil(false)
    draw_engine.type_drawer.sfx.stencil(false)
    --draw_engine.type_drawer.sfx.stencil(false)
  end, "replace", 2, false)
  -- Foreground
  gfx.setBlendMode("alpha")
  leveldraw.color(true)
  goobles_drawing_stuff.color(true)
  -- Draw ambient light
  gfx.setBlendMode("alpha")
  draw_engine.ambient(scenemap, colormap, {100, 100, 255, 255}, 0.4)
  gfx.setBlendMode("add")
  gfx.stencil(function()
    goobles_drawing_stuff.stencil(true)
    leveldraw.stencil(true)
  end, "replace", 1, true)
  gfx.setStencilTest("equal", 1)
  -- Now do light rendering
  for id, _ in pairs(gamedata.tag.point_light) do
    draw_engine.foreground_shading(id, scenemap, colormap, normalmap)
  end
  -- Now for the background
  -- Clear all drawers for the foreground
  -- TODO: Make this more type oriented like the above
  --
  --
  gfx.setCanvas(scenemap, colormap, glowmap, normalmap)
  for id, _ in pairs(gamedata.tag.background) do
    local draw = gamedata.radiometry.draw[id]
    if draw then coroutine.resume(draw, id) end
  end
  -- Do sfx first
  gfx.setStencilTest("equal", 0)
  gfx.setBlendMode("alpha")
  draw_engine.type_drawer.lantern_A_glow.color(false)
  gfx.setBlendMode("alpha")
  bgdraw.color(true)
  draw_engine.type_drawer.lantern_A.color(true)
  gfx.setBlendMode("screen")
  draw_engine.ambient(scenemap, colormap, {100, 100, 255, 255}, 0.2)

  local occlusion = function()
    leveldraw.occlusion()
    goobles_drawing_stuff.occlusion(true)
  end

  for id, _ in pairs(gamedata.tag.point_light) do
    draw_engine.background_shadows(id, scenemap, colormap, normalmap, occlusion)
  end
  lantern_A.clear()
  draw_engine.glow(glowmap)
  if not debug.buffer_view then
    draw_engine.final_render(scenemap, glowmap)

    gfx.setBlendMode("screen")
    gfx.setCanvas()
    gfx.origin()
    gfx.setShader()
    gfx.setStencilTest()

    if debug.draw_hitbox then
      camera.transformation(camera_id, level)
      collision_engine.draw_boundries()
      gfx.origin()
    end
    if debug.draw_entity then
      gfx.push()
      gfx.origin()
      camera.transformation(camera_id, level)
      gfx.setColor(255, 255, 255, 100)
      gfx.setBlendMode("alpha")
      for id, _ in pairs(gamedata.tag.entity) do
        local x = gamedata.spatial.x[id]
        local y = gamedata.spatial.y[id]
        local w = gamedata.spatial.width[id]
        local h = gamedata.spatial.height[id]
        gfx.rectangle("line", x - w, -y + h, w * 2, -h * 2)
      end
      gfx.pop()
    end

    for id, _ in pairs(gamedata.tag.ui) do
      local draw = gamedata.radiometry.draw[id]
      if draw then
        local status, _ = coroutine.resume(draw, id)
        if coroutine.status(draw) == "dead" then
          gamedata.radiometry.draw[id] = nil
        end
      end
    end
  else
    gfx.setBlendMode("screen")
    gfx.setCanvas()
    gfx.origin()
    gfx.setShader()
    gfx.setStencilTest()
    gfx.setColor(255, 255, 255, 255)
    local w, h = 1920 * 0.5, 1080 * 0.5
    gfx.draw(scenemap, 0, 0, 0, 0.5, 0.5)
    gfx.draw(colormap, w, 0, 0, 0.5, 0.5)
    gfx.draw(glowmap, 0, h, 0, 0.5, 0.5)
    gfx.draw(normalmap, w, h, 0, 0.5, 0.5)
    gfx.rectangle("line", 0, 0, w, h)
    gfx.rectangle("line", w, 0, w, h)
    gfx.rectangle("line", 0, h, w, h)
    gfx.rectangle("line", w, h, w, h)
    gfx.print("Scene", 1, 1)
    gfx.print("Color", w + 1, 1)
    gfx.print("Glow", 1, h + 1)
    gfx.print("Normals", w + 1, h + 1)
    gfx.print(string.format("FPS %f", 1.0 / system.dt), 300)
  end
  gfx.setCanvas()
  gfx.origin()
  gfx.setShader()
  gfx.setBlendMode("alpha")
  --for _, atlas in pairs(resource.atlas.color) do atlas:clear() end
end
