return {
  version = "1.1",
  luaversion = "5.1",
  tiledversion = "0.12.3",
  orientation = "orthogonal",
  width = 30,
  height = 20,
  tilewidth = 16,
  tileheight = 16,
  nextobjectid = 71,
  properties = {},
  tilesets = {
    {
      name = "woodtile3",
      firstgid = 1,
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
      tiles = {
        {
          id = 0,
          properties = {
            ["left"] = "16",
            ["right"] = "16",
            ["type"] = "thin"
          }
        },
        {
          id = 1,
          properties = {
            ["left"] = "16",
            ["right"] = "16"
          }
        },
        {
          id = 2,
          properties = {
            ["left"] = "16",
            ["right"] = "16"
          }
        }
      }
    },
    {
      name = "entity_16x32",
      firstgid = 21,
      tilewidth = 16,
      tileheight = 32,
      spacing = 0,
      margin = 0,
      image = "tileset/entity_16x32.png",
      imagewidth = 320,
      imageheight = 320,
      tileoffset = {
        x = 0,
        y = 0
      },
      properties = {},
      terrains = {},
      tiles = {}
    },
    {
      name = "entity_16x16",
      firstgid = 221,
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
      tiles = {
        {
          id = 0,
          properties = {
            ["type"] = "lantern"
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
      width = 30,
      height = 20,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
      }
    },
    {
      type = "tilelayer",
      name = "geometry",
      x = 0,
      y = 0,
      width = 30,
      height = 20,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 1, 3, 3, 1, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
      }
    },
    {
      type = "objectgroup",
      name = "entity",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          id = 58,
          name = "lantern",
          type = "lantern_A",
          shape = "rectangle",
          x = 174.5,
          y = 72.75,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 59,
          name = "lantern",
          type = "lantern_A",
          shape = "rectangle",
          x = 309.25,
          y = 91.5,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 60,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 392.25,
          y = 72.75,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 61,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 397.5,
          y = 135.75,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 62,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 274,
          y = 133.5,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 63,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 226.5,
          y = 161.5,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 64,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 65.75,
          y = 147.5,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 65,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 214.417,
          y = 261.333,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 66,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 115.417,
          y = 258.75,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 67,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 305.417,
          y = 231.25,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 68,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 409.667,
          y = 283,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        },
        {
          id = 69,
          name = "player",
          type = "gobbles",
          shape = "rectangle",
          x = 145.568,
          y = 191.568,
          width = 16,
          height = 32,
          rotation = 0,
          gid = 21,
          visible = true,
          properties = {}
        },
        {
          id = 70,
          name = "",
          type = "lantern_A",
          shape = "rectangle",
          x = 52.75,
          y = 66.5,
          width = 16,
          height = 16,
          rotation = 0,
          gid = 221,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
