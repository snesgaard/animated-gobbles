require "io"
require "math"

local function loadshader(path, path2)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()

  if path2 == nil then
    return love.graphics.newShader(fstring)
  else
    path2 = "resource/shader/" .. path2
    local f2 = io.open(path2, "rb")
    local fstring2 = f2:read("*all")
    f2:close()
    return love.graphics.newShader(fstring, fstring2)
  end
end

local function loadshaderfile(path)
  path = "resource/shader/" .. path
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()
  return fstring
end


light = {}
-- Stores framebuffers
local fb = {}
local mesh = {}
local shaders = {}

function light.create_fb(gamedata, width, height, occres, rays, raystep)
  fb.occmap = gfx.newCanvas(occres, occres, 'r8')
  fb.polarmap = gfx.newCanvas(rays, raysteps, 'r8')
  fb.shadowmap = gfx.newCanvas(rays, 1, 'rg32f')
  --fb.colormap = gfx.newCanvas(width, height)
  --fb.normalmap = gfx.newCanvas(width, height)
  local bs = 0.25
  fb.bloom_front = gfx.newCanvas(width * bs, height * bs)
  fb.bloom_front:setFilter("linear", "linear")
  fb.bloom_back = gfx.newCanvas(width * bs, height * bs)
  fb.bloom_back:setFilter("linear", "linear")
end
function light.create_quad(gamedata, occres, rays, raysteps)
  mesh.polarquad = gfx.newQuad(0, 0, rays, raysteps, occres, occres)
  mesh.shadowquad = gfx.newQuad(0, 0, rays, 1, rays, raysteps)
end

function light.create_dynamic(gamedata, width, height, occres, rays, raystep)
  light.create_fb(gamedata, width, height, occres, rays, raystep)
  light.create_quad(gamedata, occres, rays, raystep)
end

function light.create_shader(gamedata)
  shaders.occ = loadshader("occ.glsl", "occvert.glsl")
  shaders.wrap = loadshader("polarwrap.glsl")
  shaders.pcast = loadshader("polarcast.glsl")
  shaders.smap = loadshader("shadowmap.glsl")
  -- Create blurring shaders
  local blur_str = loadshaderfile("blur.glsl")
  shaders.vblur = gfx.newShader("#define VERTICAL\n" .. blur_str)
  shaders.hblur = gfx.newShader("#define HORIZONTAL\n" .. blur_str)
  shaders.bloom_combo = loadshader("bloom_combine.glsl")
end

function light.create_mesh(gamedata)
  local vert = {
    {1, 0, 1, 0},
    {0, 0, 0, 0},
    {0, 1, 0, 1},
    {1, 1, 1, 1},
  }
  mesh.light = gfx.newMesh(vert, "fan")
end

function light.create_static(gamedata)
  light.create_shader(gamedata)
  light.create_mesh(gamedata)
end

function light.init_point(gd, id, x, y, radius, color, intensity)
  gd.spatial.x[id] = x
  gd.spatial.y[id] = y
  gd.spatial.width[id] = radius
  gd.radiometry.color[id] = color
  gd.radiometry.intensity[id] = intensity
end

function light.draw_point(id, scene, colormap, normalmap)
  -- Fetch references and data
  local gfx = love.graphics
  local prev_canvas = gfx.getCanvas()
  local res = gamedata.spatial

  local occres = fb.occmap:getWidth()
  local rays = fb.polarmap:getWidth()
  local raysteps = fb.polarmap:getHeight()
  local r = res.width[id]
  local d = r * 2
  local s = occres / d
  local x = res.x[id]
  local y = res.y[id]
  -- Draw occluders using the light's view
  gfx.setShader(shaders.occ)
  gfx.setCanvas(fb.occmap)
  gfx.clear(0,0,0,0)
  gfx.push()
  gfx.origin()
  gfx.scale(s)
  gfx.translate(-x, y)
  gfx.translate(occres * 0.5 / s, occres * 0.5 / s)
  local sf = function()
    shaders.occ:send("inv_screen", {0, 0})
    --occshader:send("inv_screen", {3 / occres, 3 / occres})
    scene(t)
  end
  --love.graphics.setStencilTest("less", 1)
  --gfx.stencil(sf)
  --shaders.occ:send("inv_screen", {-2 / occres, -2 / occres})
  shaders.occ:send("inv_screen", {0, 0})
  scene(t)
  love.graphics.setStencilTest()
  -- Wrap scene to polar coordinates
  gfx.origin()
  gfx.setCanvas(fb.polarmap)
  gfx.setShader(shaders.wrap)
  mesh.light:setTexture(fb.occmap)
  gfx.draw(mesh.light, 0, 0, 0, rays, raysteps)
  -- Trace through each ray, obtaining the nearest occluder
  gfx.setCanvas(fb.shadowmap)
  gfx.setShader(shaders.pcast)
  shaders.pcast:send("STEP", 1.0 / raysteps)
  shaders.pcast:sendInt("L", raysteps)
  gfx.draw(fb.polarmap, mesh.shadowquad)
  -- Filter shadow map with variance method
  -- Draw ssa
  gfx.setCanvas(prev_canvas)
  gfx.setShader(shaders.smap)
  shaders.smap:send("colormap", colormap)
  shaders.smap:send("normalmap", normalmap)
  local w = colormap:getWidth()
  local h = colormap:getHeight()
  shaders.smap:send("inv_screen", {1.0 / w, 1.0 / h})
  --shadowshader:send("normalmap", normalmap)

  local color = gamedata.radiometry.color[id]
  gfx.pop()
  gfx.setColor(unpack(color))
  mesh.light:setTexture(fb.shadowmap)
  gfx.setBlendMode("add")
  gfx.draw(mesh.light, (x - r), (-y - r), 0, d, d)
  gfx.setShader()
  gfx.setBlendMode("alpha")
  gfx.setColor(255, 255, 255)
  --gfx.rectangle("line", x - r, y -r , d, d)
  if false then
    gfx.push()
    gfx.origin()
    gfx.draw(fb.occmap, 700, 0)
    gfx.rectangle("line", 700, 0, occres, occres)
    gfx.rectangle("line", 700, 0, occres, occres / 2)
    gfx.rectangle("line", 700, 0, occres / 2, occres)
    gfx.pop()
  end
end

function light.draw_ambient(colormap, color, intensity)
  gfx.push()
  -- Draw ambient
  local r, g, b = unpack(color)
  gfx.setColor(r, g, b, 255 * intensity)
  gfx.origin()
  gfx.draw(colormap)
  gfx.pop()
end

function light.bloom(scenemap, bloom_map)
  local m = mesh.light
  local w = fb.bloom_front:getWidth()
  local h = fb.bloom_front:getHeight()
  -- Store previous state
  local prev_canvas = gfx.getCanvas()
  gfx.push()
  gfx.origin()
  -- Draw to subsampled framebuffer
  gfx.setColor(255, 255, 255)
  gfx.setCanvas(fb.bloom_front)
  gfx.clear()
  gfx.setShader()
  m:setTexture(bloom_map)
  gfx.draw(m, 0, 0, 0, w, h)
  gfx.setBlendMode("alpha")
  for i = 1,5 do
    -- Vertical blur
    gfx.setCanvas(fb.bloom_back)
    gfx.clear()
    gfx.setShader(shaders.vblur)
    shaders.vblur:send("inv_y", 1.0 / h)
    m:setTexture(fb.bloom_front)
    gfx.draw(m, 0, 0, 0, w, h)
    -- Horizontal blur
    gfx.setCanvas(fb.bloom_front)
    gfx.clear()
    gfx.setShader(shaders.hblur)
    shaders.hblur:send("inv_x", 1.0 / w)
    m:setTexture(fb.bloom_back)
    gfx.draw(m, 0, 0, 0, w, h)
  end
  gfx.setBlendMode("alpha")
  -- Restore previos state
  gfx.setCanvas(prev_canvas)
  gfx.setShader(shaders.bloom_combo)
  shaders.bloom_combo:send("blur_tex", fb.bloom_front)
  shaders.bloom_combo:send("bloom_tex", bloom_map)
  shaders.bloom_combo:send("exposure", 0.8)
  gfx.draw(scenemap)
  gfx.setShader()
  --gfx.draw(fb.bloom_front)
  --gfx.draw(bloom_map)
  gfx.pop()
end
