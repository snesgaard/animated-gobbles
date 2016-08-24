return {
  version = "1.1",
  luaversion = "5.1",
  tiledversion = "0.14.2",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 26,
  height = 16,
  tilewidth = 16,
  tileheight = 16,
  nextobjectid = 29,
  properties = {},
  tilesets = {
    {
      name = "woodtile",
      firstgid = 1,
      tilewidth = 16,
      tileheight = 16,
      spacing = 0,
      margin = 0,
      image = "tileset/woodtile.png",
      imagewidth = 128,
      imageheight = 16,
      tileoffset = {
        x = 0,
        y = 0
      },
      properties = {},
      terrains = {},
      tilecount = 8,
      tiles = {}
    },
    {
      name = "woodtile3",
      firstgid = 9,
      tilewidth = 16,
      tileheight = 16,
      spacing = 0,
      margin = 0,
      image = "tileset/woodtile3.png",
      imagewidth = 32,
      imageheight = 160,
      tileoffset = {
        x = 0,
        y = 0
      },
      properties = {},
      terrains = {},
      tilecount = 20,
      tiles = {}
    },
    {
      name = "entity_16x16",
      firstgid = 29,
      tilewidth = 16,
      tileheight = 16,
      spacing = 0,
      margin = 0,
      image = "tileset/entity_16x16.png",
      imagewidth = 320,
      imageheight = 320,
      tileoffset = {
        x = 0,
        y = 0
      },
      properties = {},
      terrains = {},
      tilecount = 400,
      tiles = {
        {
          id = 0,
          properties = {
            ["stuff"] = "a1"
          }
        }
      }
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "background",
      x = 0,
      y = 0,
      width = 26,
      height = 16,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "base64",
      compression = "zlib",
      data = "eJzjYmBg4KID5qETpodfRv0z6p9R/4z6Z9Q/lGMA8RcR4Q=="
    },
    {
      type = "tilelayer",
      name = "geometry",
      x = 0,
      y = 0,
      width = 26,
      height = 16,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "base64",
      compression = "zlib",
      data = "eJxjYBgFo2AUjAIIYKITZhzFoxiIAQAzALc="
    },
    {
      type = "objectgroup",
      name = "entity",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      objects = {
        {
          id = 11,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 76,
          y = 111,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 29,
          visible = true,
          properties = {}
        },
        {
          id = 12,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 197.667,
          y = 151.667,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 29,
          visible = true,
          properties = {}
        },
        {
          id = 13,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 318.334,
          y = 110.334,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 29,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
