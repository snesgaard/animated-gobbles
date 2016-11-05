local seed = {}
local available_id = {}
function createresource(resource)
  --resource.__seed__ = 1
  --resource.__available_id__ = {}
  seed[resource] = 1
  available_id[resource] = {}
  return resource
end
function allocresource(resource)
  local sub_available_id = available_id[resource]
  local id = sub_available_id[#sub_available_id]
  if id then
    sub_available_id[#sub_available_id] = nil
    return id
  end
  local s = seed[resource]
  seed[resource] = s + 1
  return s
end
function freeresource(resource, id)
  if type(id) ~= "number" then error("Unsupported id type:", id) end
  table.insert(available_id[resource], id)
  local function _erase(t, id)
    t[id] = nil
    for _, sub in pairs(t) do
      if type(sub) == "table" then _erase(sub, id) end
    end
  end
  _erase(resource, id)
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
    flip = {},
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
    collection = {},
  },
  tag = {
    point_light = {},
    entity = {},
    background = {},
    particle = {},
    sfx = {},
    ui = {},
  },
  functional = {
    portrait = {}
  },
  card = {
    image = {},
    text = {},
    activate = {},
    name = {},
    cost = {},
    target = {},
    effects = {},
    play = {}
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
