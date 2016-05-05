local seed = {}
local available_id = {}
local function createresource(resource)
  --resource.__seed__ = 1
  --resource.__available_id__ = {}
  seed[resource] = 1
  available_id[resource] = {}
  return resource
end
function allocresource(resource)
  local available_id = available_id[resource]
  local id = available_id[#available_id]
  if id then
    available_id[#available_id] = nil
    return id
  end
  local s = seed[resource]
  seed[resource] = s + 1
  return s
end
function freeresource(resource, id)
  table.insert(available_id[resource], id)
  for _, v in pairs(resource) do
    v[id] = nil
  end
end
function initresource(resource, f, ...)
  local id = allocresource(resource)
  f(resource, id, ...)
  return id
end

gamedata = createresource({
  ai = {
    -- General purpose AI scripting stuff
    control = {},
    -- AI actions that interacts with the world via hitbox collisions
    action = {},
  },
  -- Reactions to in-game events
  reaction = {
    slide = {},
    stuf = {},
    knockdown = {},
  },
  spatial = {
    x = {},
    y = {},
    vx = {},
    vy = {},
    width = {},
    height = {},
    face = {},
    ground = {},
  },
  radiometry = {
    color = {},
    intensity = {},
    draw = {},
  },
  combat = {
    health = {},
    damage = {},
    defense = {},
    attack = {},
    invincibility = {},
  },
  tag = {
    point_light = {},
    entity = {},
    background = {},
    particle = {},
    sfx = {},
    ui = {},
  }
})

function freegamedata(id)
  for _, subtab in pairs(gamedata) do
    for _, subsubtab in pairs(subtab) do
      subsubtab[id] = nil
    end
  end
end

resource = {
  hitbox = createresource({
    x = {},
    y = {},
    width = {},
    height = {},
    seek = {},
    hail = {},
  }),
  animation = createresource({
    quads = {},
    width = {},
    height = {},
    -- Origin
    x = {},
    y = {},
    normals = {},
  }),
  images = createresource({}),
  shader = createresource({}),
  mesh = createresource({}),
  particle = createresource({}),
  atlas = createresource({
    color = {},
    normal = {},
  }),
  canvas = createresource({})
}

system = {
  -- Time
  time = 0,
  dt = 0,
  -- Input
  pressed = {},
  released = {},
  buffer = {},
}
