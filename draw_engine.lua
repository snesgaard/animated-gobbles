drawing = {}

local shaders = {}
local colormap
local normalmap
local scenemap
local bloommap
local default_normal

local gfx = love.graphics

function loader.drawing()
  local width, height = gfx.getWidth(), gfx.getHeight()
  shaders.sprite = loadshader(
    "resource/shader/cube.glsl", "resource/shader/cube_vert.glsl"
  )
  shaders.primitive = loadshader("resource/shader/primitives.glsl")
  default_normal = gfx.newImage("resource/tileset/no_normal.png")
  colormap = gfx.newCanvas(width, height)
  scenemap = gfx.newCanvas(width, height)
  normalmap = gfx.newCanvas(width, height)
  bloommap = gfx.newCanvas(width, height)
  sfxmap = gfx.newCanvas(width, height)
end

function drawing.init()
  -- Clear canvas
  gfx.setCanvas(colormap, normalmap, bloommap)
  gfx.clear({255, 255, 255, 255}, {0, 0, 0, 0}, {0, 0, 0, 0})
  gfx.setBackgroundColor(255, 255, 255, 255)
  gfx.setShader(shaders.sprite)
end

function drawing.draw(args)
  local f = args[1] or function() end
  local normal = args.normal or default_normal
  local bloom = args.bloom or false
  local background = args.background or false
  local shader = shaders.sprite
  gfx.setShader(shader)
  shader:send("normals", normal)
  shader:send("bloom", bloom)
  shader:send("background", background)
  f()
end

function drawing.draw_primitive(args)
  local f = args[1] or function() end
  local bloom = args.bloom or false
  local background = args.background or false
  local shader = shaders.primitive
  gfx.setShader(shader)
  shader:send("bloom", bloom)
  shader:send("background", background)
  f()
end

function drawing.from_atlas(atid)
  return function()
    local at = resource.atlas
    local f = function()
      gfx.draw(at.color[atid])
    end
    return {f, normal = at.normal[atid]}
  end
end

function drawing.from_function(f)
  return function()
    return {f}
  end
end

function drawing.run(args)
  local f = args[1] or function() end
  local normal = args.normal
  local bloom = args.bloom
  local background = args.background

  local fargs = f()
  fargs.normal = normal or fargs.normal
  fargs.bloom = bloom or fargs.bloom
  fargs.background = background or fargs.background
  drawing.draw(fargs)
end

function drawing.get_canvas()
  return colormap, normalmap, bloommap, scenemap
end

return draw
