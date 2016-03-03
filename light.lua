require "io"
require "math"

gfx = love.graphics

rays = 1200
raysteps = 1200
size = 800
occres = 800

light = {
  color = {},
  x = {},
  y = {},
  radius = {},
}

function init_light(res, id, x, y, radius, color)
  res.x[id] = x
  res.y[id] = y
  res.radius[id] = radius
  res.color[id] = color or {255, 255, 255}
end

function loadshader(path, path2)
  local f = io.open(path, "rb")
  local fstring = f:read("*all")
  f:close()

  if path2 == nil then
    return love.graphics.newShader(fstring)
  else
    local f2 = io.open(path2, "rb")
    local fstring2 = f2:read("*all")
    f2:close()
    return love.graphics.newShader(fstring, fstring2)
  end
end

function love.load()
  local filter = "nearest"
  love.graphics.setDefaultFilter(filter, filter, 0)
  occmap = gfx.newCanvas(occres, occres, 'r8')
  polarmap = gfx.newCanvas(rays, raysteps, 'r8')
  polarquad = gfx.newQuad(0, 0, rays, raysteps, occres, occres)
  occshader = loadshader("occ.glsl", "occvert.glsl")
  pwrapshader = loadshader("polarwrap.glsl")

  shadowmap = gfx.newCanvas(rays, 1, 'rg32f')
  varmap = gfx.newCanvas(rays, 1, 'rgba32f')
  shadowquad = gfx.newQuad(0, 0, rays, 1, rays, raysteps)
  castshader = loadshader("polarcast.glsl")
  meanshader = loadshader("mean.glsl")
  shadowshader = loadshader("shadowmap.glsl")

  local im = gfx.newImage("cube.png")
  local rx = {}
  local ry = {}
  local size = {}
  for i = 1,50 do
    table.insert(rx, love.math.random(0, gfx.getWidth()))
    table.insert(ry, love.math.random(0, gfx.getHeight()))
    table.insert(size, love.math.random() * 1.7 + 0.3)
  end
  draw_scene1 = function(t)
    --gfx.rectangle("fill", 400 + math.cos(t * 3) * 30, 200 + math.sin(t * 3) * 30, 20, 20)
    --gfx.rectangle("fill", 500, 350, 20, 20)
    for i, x in pairs(rx) do
      gfx.draw(im, x, ry[i], 0, size[i], size[i])
    end
    --gfx.draw(idleim, 200, 300, t, 2, 2)
  end
  draw_scene2 = function()
    local step = 125
    for x = step + 10, gfx.getWidth(), step do
      for y = step + 10, gfx.getHeight(), step do
        gfx.draw(im, x, y)
      end
    end
  end
  draw_scene3 = function()
    local step = 125
    gfx.draw(im, 300, 300)
    gfx.draw(im, 290, 290)
  end
  draw_scene = draw_scene2
  local vert = {
    {1, 0, 1, 0},
    {0, 0, 0, 0},
    {0, 1, 0, 1},
    {1, 1, 1, 1},
  }
  shadowmesh = gfx.newMesh(vert, "fan")

  colorcanvas = gfx.newCanvas(gfx.getWidth(), gfx.getHeight())
  normalcanvas = gfx.newCanvas(gfx.getWidth(), gfx.getHeight())
  cubeshader = loadshader("cube.glsl")
  --shadowmesh:setTexture(varmap)
  -- Initialize light
  init_light(light, 1, 400, 600, 1000, {0, 0, 255})
  init_light(light, 2, 1250, 550, 1000, {255, 0, 0})
  init_light(light, 3, 400, 350, 1000, {0, 255, 0})

  init_light(light, 4, 1250, 250, 1000, {255, 255, 0})
  --init_light(light, 5, 400, 300, 1000, {255, 255, 0})
  --init_light(light, 6, 1200, 300, 1000, {0, 255, 255})
end


function love.update(dt)

end

function draw_light(res, id, scene, colormap, normalmap)
  local r = res.radius[id]
  local d = r * 2
  local s = occres / d
  local x = res.x[id]
  local y = res.y[id]
  gfx.setShader(occshader)
  gfx.setCanvas(occmap)
  gfx.clear()
  gfx.scale(s)
  gfx.translate(-x, -y)
  gfx.translate(occres * 0.5 / s, occres * 0.5 / s)
  local sf = function()
    --occshader:send("inv_screen", {0, 0})
    occshader:send("inv_screen", {2 / occres, 2 / occres})
    scene(t)
  end
  love.graphics.setStencilTest("less", 1)
  gfx.stencil(sf)
  --occshader:send("inv_screen", {-2 / occres, -2 / occres})
  occshader:send("inv_screen", {0, 0})
  scene(t)
  love.graphics.setStencilTest()
  -- Wrap scene to polar coordinates
  gfx.origin()
  gfx.setCanvas(polarmap)
  gfx.setShader(pwrapshader)
  shadowmesh:setTexture(occmap)
  gfx.draw(shadowmesh, 0, 0, 0, rays, raysteps)
  -- Trace through each ray, obtaining the nearest occluder
  gfx.setCanvas(shadowmap)
  gfx.setShader(castshader)
  castshader:send("STEP", 1.0 / raysteps)
  castshader:sendInt("L", raysteps)
  gfx.draw(polarmap, shadowquad)
  -- Filter shadow map with variance method
  gfx.setCanvas(varmap)
  gfx.setShader(meanshader)
  meanshader:send("texeloffset", 1.0 / rays)
  meanshader:sendInt("rad", 10)
  gfx.draw(shadowmap)
  -- Draw ssa
  gfx.setCanvas()
  gfx.setShader(shadowshader)
  shadowshader:send("colormap", colormap)
  shadowshader:send("normalmap", normalmap)
  shadowshader:send("inv_screen", {1.0 / gfx.getWidth(), 1.0 / gfx.getHeight()})
  --shadowshader:send("normalmap", normalmap)
  local color = res.color[id]
  gfx.setColor(unpack(color))
  shadowmesh:setTexture(shadowmap)
  gfx.setBlendMode("add")
  gfx.draw(shadowmesh, x - r , y -r, 0, d, d)
  gfx.setShader()
  gfx.setBlendMode("alpha")
  gfx.setColor(255, 255, 255)
  --gfx.rectangle("line", x - r, y -r , d, d)
  if false then
    gfx.draw(polarmap, 700, 0)
    gfx.rectangle("line", 700, 0, occres, occres)
    gfx.rectangle("line", 700, 0, occres, occres / 2)
    gfx.rectangle("line", 700, 0, occres / 2, occres)
  end
end

function love.draw()
  local t = love.timer.getTime()
  local scene = function()
    draw_scene(t)
  end
  gfx.setCanvas(colorcanvas, normalcanvas)
  gfx.clear({255, 255, 255, 255}, {0, 0, 0, 0})
  gfx.setShader(cubeshader)
  scene()
  -- First draw scene without light, acquire color and normals
  -- Then draw scene from all light's perspective
  for id, _ in pairs(light.x) do
    --light.x[id] = 1000 + math.sin(t) * 200
    draw_light(light, id, scene, colorcanvas, normalcanvas)
  end
  -- Draw ambient light
  gfx.setBlendMode("add")
  --gfx.draw(colorcanvas, 0, 0)
  gfx.setColor(255, 255, 255, 20)
  gfx.draw(colorcanvas, 0, 0)
  gfx.setBlendMode("alpha")
  --gfx.draw(normalcanvas)
end
