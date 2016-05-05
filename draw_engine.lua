require "io"

draw_engine = {}

local shaders = {}
local colormap
local normalmap
local scenemap
local bloommap
local default_normal
local qmesh
local squad
local occlusionmap
local polarmap
local shadowmap

local glowmap_front
local glowmap_back

local type_drawer = {}

draw_engine.type_drawer = type_drawer
draw_engine.shaders = shaders

local gfx = love.graphics

function loader.draw_engine()
  local width, height = gfx.getWidth(), gfx.getHeight()
  colormap = gfx.newCanvas(width, height)
  normalmap = gfx.newCanvas(width, height)
  glowmap = gfx.newCanvas(width, height)
  scenemap = gfx.newCanvas(width, height)

  shaders.sprite = draw_engine.load_obj_shader("sprite.glsl")
  shaders.primitive = draw_engine.load_obj_shader("primitive.glsl")
  shaders.light = draw_engine.load_light_shader("pointlight.glsl")
  shaders.shadow = {
    occlusion = draw_engine.load_shader("occ.glsl"),
    wrap = draw_engine.load_shader("polarwrap.glsl"),
    cast = draw_engine.load_shader("polarcast.glsl")
  }
  shaders.blur = draw_engine.load_glow_shader("blur.glsl")
  shaders.combine = draw_engine.load_shader("bloom_combine.glsl")

  default_normal = gfx.newImage("resource/tileset/no_normal.png")

  local vert = {
    {1, 0, 1, 0},
    {0, 0, 0, 0},
    {0, 1, 0, 1},
    {1, 1, 1, 1},
  }
  qmesh = gfx.newMesh(vert, "fan")

  draw_engine.allocate_shadow_buffers(800, 400, 400)
  draw_engine.allocate_glow_buffers(0.25)
end

function draw_engine.get_canvas()
  return scenemap, colormap, glowmap, normalmap
end

function draw_engine.register_type(id, td)
  type_drawer[id] = td
end

function draw_engine.allocate_shadow_buffers(
  occlusion_resolution, rays, raystep
)
  occlusionmap = gfx.newCanvas(
    occlusion_resolution, occlusion_resolution, 'r8'
  )
  polarmap = gfx.newCanvas(rays, raystep, 'r8')
  shadowmap = gfx.newCanvas(rays, 1, 'rg32f')
  squad = gfx.newQuad(0, 0, rays, 1, rays, raystep)
end

function draw_engine.allocate_glow_buffers(scale)
  local width, height = gfx.getWidth(), gfx.getHeight()
  glowmap_front = gfx.newCanvas(width * scale, height * scale)
  glowmap_front:setFilter("linear", "linear")
  glowmap_back = gfx.newCanvas(width * scale, height * scale)
  glowmap_back:setFilter("linear", "linear")
end

function draw_engine.load_glow_shader(path)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  local vblur = gfx.newShader("#define VERTICAL\n" .. fstring)
  local hblur = gfx.newShader("#define HORIZONTAL\n" .. fstring)
  return {vertical = vblur, horizontal = hblur}
end

function draw_engine.load_obj_shader(path)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  local stencil = gfx.newShader("#define STENCIL\n" .. fstring)
  local occlusion = gfx.newShader("#define OCCLUSION\n" .. fstring)
  local color = gfx.newShader("#define COLOR\n" .. fstring)
  return {stencil = stencil, occlusion = occlusion, color = color}
end

function draw_engine.load_light_shader(path)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  local shadowmap = gfx.newShader("#define SHADOWMAP\n" .. fstring)
  local base = gfx.newShader("#define BASE\n" .. fstring)
  return {shadowmap = shadowmap, base = base}
end

function draw_engine.load_shader(path)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  return gfx.newShader(fstring)
end

draw_engine.pick_shader = {
  stencil = function(t) return t.stencil end,
  occlusion = function(t) return t.occlusion end,
  color = function(t) return t.color end,
}

function draw_engine.create_sprite(f, nmap)
  local shader = shaders.sprite
  local nmap = nmap or default_normal

  local function stencil(opague)
    gfx.setShader(shader.stencil)
    shader.stencil:send("_do_opague", opague)
    shader.stencil:send("_do_sfx", not opague)
    f()
  end
  local function occlusion()
    gfx.setShader(shader.occlusion)
    f()
  end
  local function color(opague)
    gfx.setShader(shader.color)
    shader.color:send("normals", nmap)
    shader.color:send("_do_opague", opague)
    shader.color:send("_do_sfx", not opague)
    f()
  end

  return {stencil = stencil, occlusion = occlusion, color = color}
end

function draw_engine.create_atlas(atlas_id)
  local atlas = resource.atlas
  local cmap = atlas.color[atlas_id]
  local nmap = atlas.normal[atlas_id]
  return draw_engine.create_sprite(function()
    gfx.draw(cmap)
  end, nmap)
end

function draw_engine.create_level(level, layer)
  local l = level.layers[layer]
  return draw_engine.create_sprite(function()
    level:drawLayer(l)
  end)
end

function draw_engine.create_primitive(draw_func, opague, glow)
  local shader = shaders.primitive

  local function stencil(_opague)
    if _opague == opague then
      gfx.setShader(shader.stencil)
      draw_func()
    end
  end
  local function occlusion()
    if opague then
      gfx.setShader(shader.occlusion)
      draw_func()
    end
  end
  local function color()
    gfx.setShader(shader.color)
    shader.color:send("_is_opague", opague)
    shader.color:send("_is_sfx", not opague)
    shader.color:send("_is_glow", glow)
    draw_func()
  end

  return {stencil = stencil, occlusion = occlusion, color = color}
end


function draw_engine.ambient(scenemap, colormap, color, intensity)
  color = color or {255, 255, 255, 255}
  intensity = intensity or 1
  gfx.setShader()
  local prev_canvas = {gfx.getCanvas()}
  gfx.setCanvas(scenemap)
  local r, g, b, a = unpack(color)
  gfx.setColor(r * intensity, g * intensity, b * intensity, a)
  gfx.push()
  gfx.origin()
  gfx.draw(colormap)
  gfx.pop()
  gfx.setCanvas(unpack(prev_canvas))
end

function draw_engine.foreground_shading(id, scenemap, colormap, normalmap)
  local spa = gamedata.spatial
  local r = spa.width[id]
  local d = r * 2
  local x = spa.x[id]
  local y = spa.y[id]
  local color = gamedata.radiometry.color[id] or {255, 255, 255}
  local amplitude = gamedata.radiometry.intensity[id] or 1
  local shader = shaders.light
  local w, h = scenemap:getWidth(), scenemap:getHeight()

  gfx.setColor(unpack(color))
  gfx.setCanvas(scenemap)
  gfx.setShader(shader.base)
  shader.base:send("normalmap", normalmap)
  shader.base:send("amplitude", amplitude)
  shader.base:send("inv_screen", {1.0 / w, 1.0 / h})
  qmesh:setTexture(colormap)
  gfx.draw(qmesh, (x - r), (-y - r), 0, d, d)
end

function draw_engine.background_shadows(
  id, scenemap, colormap, normalmap, occlusion
)
  local spa = gamedata.spatial
  local r = spa.width[id]
  local d = r * 2
  local x = spa.x[id]
  local y = spa.y[id]
  local color = gamedata.radiometry.color[id] or {255, 255, 255}
  local amplitude = gamedata.radiometry.intensity[id] or 1
  local shader = shaders.light
  local w, h = scenemap:getWidth(), scenemap:getHeight()
  local occres = occlusionmap:getWidth()
  local rays = polarmap:getWidth()
  local raysteps = polarmap:getHeight()
  local shader = shaders.shadow
  local s = occres / d

  gfx.setShader(shader.occlusion)
  gfx.setCanvas(occlusionmap)
  gfx.clear(0,0,0,0)
  gfx.push()
  gfx.origin()

  gfx.scale(s)
  gfx.translate(-x, y)
  gfx.translate(occres * 0.5 / s, occres * 0.5 / s)
  gfx.setStencilTest()
  gfx.setBlendMode("alpha")
  occlusion()
  -- Wrap scene to polar coordinates
  gfx.origin()
  gfx.setShader(shader.wrap)
  gfx.setCanvas(polarmap)
  qmesh:setTexture(occlusionmap)
  gfx.draw(qmesh, 0, 0, 0, rays, raysteps)
  -- Trace through each ray, obtaining the nearest occluder
  gfx.setShader(shader.cast)
  gfx.setCanvas(shadowmap)
  shader.cast:send("STEP", 1.0 / raysteps)
  shader.cast:sendInt("L", raysteps)
  gfx.draw(polarmap, squad)
  -- Filter shadow map with variance method
  -- Draw ssa
  gfx.setCanvas(scenemap)
  love.graphics.setStencilTest("equal", 0)
  gfx.setShader(shaders.light.shadowmap)
  shaders.light.shadowmap:send("shadowmap", shadowmap)
  shaders.light.shadowmap:send("normalmap", normalmap)
  shaders.light.shadowmap:send("inv_screen", {1.0 / w, 1.0 / h})
  shaders.light.shadowmap:send("amplitude", amplitude)
  --shadowshader:send("normalmap", normalmap)

  local color = gamedata.radiometry.color[id]
  gfx.pop()
  gfx.setColor(unpack(color))
  qmesh:setTexture(colormap)
  gfx.setBlendMode("add")
  gfx.draw(qmesh, (x - r), (-y - r), 0, d, d)

  if false then
    gfx.setBlendMode("replace")
    gfx.push()
    gfx.origin()
    gfx.setShader()
    gfx.draw(occlusionmap, 700, 0)
    gfx.rectangle("line", 700, 0, occres, occres)
    gfx.rectangle("line", 700, 0, occres, occres / 2)
    gfx.rectangle("line", 700, 0, occres / 2, occres)
    gfx.pop()
  end
end


function draw_engine.glow(glowmap)
  local m = qmesh
  local w = glowmap_front:getWidth()
  local h = glowmap_front:getHeight()
  -- Store previous state
  gfx.push()
  gfx.origin()
  -- Draw to subsampled framebuffer
  gfx.setColor(255, 255, 255)
  gfx.setBlendMode("replace")
  gfx.setCanvas(glowmap_front)
  gfx.clear()
  gfx.setShader()
  m:setTexture(glowmap)
  gfx.draw(m, 0, 0, 0, w, h)
  gfx.setBlendMode("alpha")
  for i = 1,5 do
    -- Vertical blur
    gfx.setCanvas(glowmap_back)
    gfx.clear()
    local vblur = shaders.blur.vertical
    gfx.setShader(vblur)
    vblur:send("inv_y", 1.0 / h)
    m:setTexture(glowmap_front)
    gfx.draw(m, 0, 0, 0, w, h)
    -- Horizontal blur
    gfx.setCanvas(glowmap_front)
    gfx.clear()
    local hblur = shaders.blur.horizontal
    gfx.setShader(hblur)
    hblur:send("inv_x", 1.0 / w)
    m:setTexture(glowmap_back)
    gfx.draw(m, 0, 0, 0, w, h)
  end
  gfx.setShader()
  gfx.setBlendMode("replace")
  gfx.setCanvas(glowmap)
  m:setTexture(glowmap_front)
  gfx.draw(m, 0, 0, 0, glowmap:getWidth(), glowmap:getHeight())
  gfx.pop()
end


function draw_engine.final_render(scenemap, glowmap)
  gfx.origin()
  gfx.setBlendMode("alpha")
  gfx.setCanvas()
  gfx.setShader(shaders.combine)
  shaders.combine:send("bloom_tex", glowmap)
  shaders.combine:send("exposure", 1.0)
  gfx.draw(scenemap)
end
