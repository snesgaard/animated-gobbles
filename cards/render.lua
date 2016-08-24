function draw(id)
  gfx.push()
  local x = gamedata.spatial.x[id]
  local y = gamedata.spatial.y[id]
  local w = gamedata.spatial.width[id]
  local h = gamedata.spatial.height[id]
  if i == subject.selected_card:getValue() then
    for i = 1, 3 do
      gfx.setLineWidth(30 - 5 * i)
      gfx.setColor(0, 255 - i * 50, 0, 200 - 50 * i)
      gfx.circle("line", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
      gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
    end
    gfx.setLineWidth(1)
  end
  gfx.setColor(0, 0, 0)
  gfx.rectangle("line", x,  y, w, h, 10, 10, 5)
  gfx.setColor(220, 208, 129)
  gfx.rectangle("fill", x,  y, w, h, 10, 10, 5)
  gfx.setColor(0, 0, 255)
  gfx.circle("fill", x + w * 0.02, y + h * 0.025, w * 0.1, 20)
  gfx.setColor(255, 255, 200)
  gfx.print("1", x - w * 0.04, y - h * 0.05, 0, 3, 3)
  gfx.setColor(63, 109, 139)
  local name = "Potato"
  gfx.print(name, x + w * 0.1 + 10, y + h * 0.005, 0, 2, 2)
  local w_rat = 0.8
  local h_rat = 0.48
  --[[
  gfx.rectangle(
    "fill", x + w * 0.5 * (1 - w_rat),  y + h * (1 - h_rat) * 0.25 * 0.75,
    w * w_rat, h * h_rat
  )
  ]]--
  gfx.setColor(200, 200, 150)
  gfx.draw(pot_im, x + w * 0.5 * (1 - w_rat),  y + h * (1 - h_rat) * 0.25 * 0.75, 0, 5, 5)
  gfx.setColor(220, 200, 200)
  local text_start = h_rat + 0.125
  local text_rat = 0.375
  gfx.rectangle(
    "fill", x + w * 0.5 * (1 - w_rat),  y + h * text_start,
    w * w_rat, h * text_rat
  )
  gfx.setColor(63, 109, 139)
  local str = ""
  str = str .. "Draw 1 card.\n"
  str = str .. "Gain 2 action.\n"
  str = str .. "Deal 1 damage.\n"
  str = str .. "\nAt the start of the next\nround, draw 1 card."
  gfx.print(
    str, x + w * 0.5 * (1 - w_rat) + 10,
    y + h * text_start + 10
  )
  gfx.pop()
end
