local common = require "combat/ui/common"
local draw_text_box = require "combat/ui/text_box"
local _suit = common.screen_suit
local theme = require "combat/ui/theme"

local function _draw_target_border(id, opt, x, y, w, h)
  gfx.stencil(function()
    gfx.rectangle("fill", x, y, w, h)
  end, "replace", 1)
  gfx.setStencilTest("equal", 0)
  gfx.setLineWidth(6)
  gfx.setColor(255, 255, 255)
  gfx.polygon("line", x, y, x + w * 0.1, y, x, y + h * 0.1)
  gfx.polygon("line", x + w, y + h, x + w * 0.9, y + h, x + w, y + h * 0.9)
  gfx.polygon("line", x, y + h, x + w * 0.1, y + h, x, y + h * 0.9)
  gfx.polygon("line", x + w, y, x + w * 0.9, y, x + w, y + h * 0.1)
  gfx.setStencilTest()
end

return function(dt, party, enemies)
  local function _draw(id)
    local x, y = gamedata.spatial.x[id], gamedata.spatial.y[id]
    local w, h = 10, 10--gamedata.spatial.width[id], gamedata.spatial.height[id]

    local ix, iy = camera.transform(camera_id, level, x - w, y - h)
    local ex, ey = camera.transform(camera_id, level, x + w, y + h)
    return _suit:Button(
      id, {draw = _draw_target_border} , ix, ey, ex - ix, iy - ey
    )
  end
  local function _finisher(_hit_id)
    coroutine.yield(_hit_id)
    return _finisher(_hit_id)
  end
  while true do
    local x, y = unpack(combat_engine.DEFINE.LAYOUT.MSG_BOX)
    _suit.layout:reset(x, y)
    _suit:Label(
      "Select Target",
      {
        draw = ui.draw_text_box,
        font = common.font.s35,
        color = theme.player
      },
      _suit.layout:row(300, 50)
    )
    local pui = map(_draw, party)
    local eui = map(_draw, enemies)


    for i, ui in pairs(pui) do
      if ui.hit then
        --return _finisher(combat_engine.data.party[i]
        return party[i]
      end
    end
    for i, ui in pairs(eui) do
      if ui.hit then
        --return _finisher(combat_engine.data.enemy[i])
        return enemy[i]
      end
    end
    coroutine.yield()
  end
end
