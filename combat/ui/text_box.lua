return function (text, opt, x, y, w, h)
  local theme = opt.color.normal
  gfx.setColor(unpack(theme.fg))
  gfx.setLineWidth(5)
  local mx = 10
  local my = 5
  local r = 16
  gfx.rectangle(
    "fill", x - mx - r * 0.5, y - my - r * 0.5,
    w + 2 * mx + r, h + 2 * my + r, r
  )
  gfx.setColor(unpack(theme.bg))
  gfx.rectangle("fill", x - r * 0.5, y - r * 0.5, w + r, h + r, r)
  suit.theme.Label(text, opt, x, y, w, h)
end
