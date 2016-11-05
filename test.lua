loader = {}
actor = {}
init = {}
parser = {}
drawer = {}

suit = require ("modules/SUIT")
require "io"
require "light"
require "math"
require "camera"
require "motion"
require "draw_engine"
require "state_engine"
require "collision_engine"
require "entity_engine"
require "debug_console"
require "combat/combat_engine"
require "script_engine"
require "lambda_process"

require "actor/sfx"
require "actor/engineer"
require "actor/witch"
require "actor/testbox"
require "prop/prop"
require "prop/latern_A"
require "actor/shared"

require "deck"
require "cards/general"

gfx = love.graphics

camera_id = nil --HACK Should be local
local fb = {}

-- Create stream for buffered input
-- Here each key press is repeated for 150ms
-- This is primarily for catching inputs from the past

function love.mousepressed(x, y, button)
  signal.emit("mousepressed", x, y, button)
end

function love.keypressed(key)
  signal.emit("keypressed", key)
end

function love.keyreleased(key)
  signal.emit("keyreleased", key)
end

function love.load()
  camera_id = setdefaults()
  level = sti.new("resource/test4.lua")
  print("transform", camera.inv_transform(camera_id, level, 0, 0))
  print("transform", camera.inv_transform(camera_id, level, 1920, 0))
  print("transform", camera.inv_transform(camera_id, level, 1920, 1080))
  print("transform", camera.inv_transform(camera_id, level, 0, 1080))
  --love.event.quit()
  renderbox.do_it = false
  -- Load entity
  loader.draw_engine()
  loader.combat_engine()
  loader.shared()
  loader.sfx()
  loader.prop()
  loader.lantern_A()
  loader.engineer()
  loader.witch()
  loader.testbox()
  loader.cards()
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

  local ally = {}
  local enemy = {}
  table.insert(ally, initresource(gamedata, init.engineer, 145, -133.5))
  local id = ally[1]
  local card_collection = {}
  for i = 1, 29 do table.insert(card_collection, cards.potato) end
  for i = 1, 1 do table.insert(card_collection, cards.evil_potato) end
  gamedata.combat.collection[id] = card_collection
  table.insert(ally, initresource(gamedata, init.witch, 95, -133.5))
  id = ally[2]
  local card_collection = {}
  for i = 1, 1 do table.insert(card_collection, cards.potato) end
  for i = 1, 29 do table.insert(card_collection, cards.evil_potato) end
  gamedata.combat.collection[id] = card_collection
  table.insert(enemy, initresource(gamedata, init.testbox, 260, -145))
  combat_engine.begin(ally, enemy)

  local token1 = {}
  local token2 = {}

  local sig = signal.zip(
      signal.type(token1).map(function() return "hello" end),
      signal.type(token2).map(function() return "world" end)
  ).listen(print)

  sig()
  signal.emit(token1)
  signal.emit(token1)
  signal.emit(token1)
  signal.emit(token2)
  signal.emit(token2)
  signal.emit(token2)
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

function free_entity(id)
  collision_engine.stop(id)
  animation.erase(id)
  entity_engine.stop(id)
  freeresource(gamedata, id)
end

local quit_listen = signal.type("keypressed")
  .filter(function(key) return key == "escape" end)
  .listen(love.event.quit)

function love.update(dt)
  -- Clean resources for next
  signal.clear()
  quit_listen()
  update.system(dt)
  for id, co in pairs(gamedata.ai.control) do
    coroutine.resume(co, id)
  end
  update.movement(gamedata, level)
--  state_engine.update:onNext(dt)
--  signal.emit("update", dt)
  --entity_engine.sequence_sync:onNext(dt)
  --state_engine.update()
  combat_engine.update(dt)
  lambda.update(dt)
  entity_engine.update(dt)
  animation.update()
  collision_engine.update(dt)
end

function love.draw()
  camera.transformation(camera_id, level)
  -- Clear canvas
  local scenemap, colormap, glowmap, normalmap = draw_engine.get_canvas()
  gfx.setCanvas(scenemap, colormap, glowmap, normalmap)
  gfx.clear({0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0})
  gfx.setStencilTest()

  local leveldraw = draw_engine.create_level(level, "geometry")
  local bgdraw = draw_engine.create_level(level, "background")

  local draw_fg_sfx = function()
    --goobles_drawing_stuff.color(false)
    --draw_engine.type_drawer.sfx.color(false)
    --draw_engine.foreground_draw:onNext(false)
    --signal.emit(draw_engine.signal.foreground_draw, false)
    for _, f in pairs(draw_engine.foreground) do
      f.color(false)
    end
  end
  -- SFX
  --goobles_drawing_stuff.color(false)
  --draw_engine.type_drawer.sfx.color(false)
  --draw_engine.draw_signal:onNext{type = "foreground", opague = false}
  draw_fg_sfx()
  gfx.setStencilTest("equal", 0)
  gfx.stencil(function()
    --draw_fg_sfx()
    --goobles_drawing_stuff.stencil(false)
    --draw_engine.foreground_stencil:onNext(false)
    --signal.emit(draw_engine.signal.foreground_stencil, false)
    --draw_engine.type_drawer.sfx.stencil(false)
    --draw_engine.type_drawer.sfx.stencil(false)
    for _, f in pairs(draw_engine.foreground) do
      f.stencil(false)
    end
  end, "replace", 2, false)
  -- Foreground
  gfx.setBlendMode("alpha")
  leveldraw.color(true)
  --goobles_drawing_stuff.color(true)
  --draw_engine.foreground_draw:onNext(true)
  --signal.emit(draw_engine.signal.foreground_draw, true)
  for _, f in pairs(draw_engine.foreground) do f.color(true) end
  -- Draw ambient light
  gfx.setBlendMode("alpha")
  draw_engine.ambient(scenemap, colormap, {255, 255, 200, 255}, 0.5)
  gfx.setBlendMode("add")
  gfx.stencil(function()
    --goobles_drawing_stuff.stencil(true)
    leveldraw.stencil(true)
    --draw_engine.foreground_stencil:onNext(true)
    --signal.emit(draw_engine.signal.foreground_stencil, true)
    for _, f in pairs(draw_engine.foreground) do f.stencil(true) end
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
  draw_engine.ambient(scenemap, colormap, {255, 255, 100, 255}, 0.3)

  local occlusion = function()
    leveldraw.occlusion()
    --goobles_drawing_stuff.occlusion(true)
    --draw_engine.foreground_occlusion:onNext(true)
    --signal.emit(draw_engine.signal.foreground_occlusion, true)
    for _, f in pairs(draw_engine.foreground) do f.occlusion(true) end
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

    gfx.setBlendMode("alpha")
    gfx.origin()
    camera.transformation(camera_id, level)
    --draw_engine.world_ui_draw:onNext(true)
    --signal.emit(draw_entity.signal.world_ui_draw)
    for _, f in pairs(draw_engine.ui.world) do f() end
    gfx.origin()
    --draw_engine.screen_ui_draw:onNext(true)
    for _, f in pairs(draw_engine.ui.screen) do f() end
    --signal.emit(draw_entity.signal.screen_ui_draw)
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
