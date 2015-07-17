require "math"
local path = ... .. "."
local axisbox = require (path .. "axisbox")

coolision = {}

local projectspan = function(box, x, y)
  local lx, hx = axisbox.getboundx(box)
  local ly, hy = axisbox.getboundy(box)
  local lp = lx * x + ly * y
  local hp = hx * x + hy * y
  return math.min(lp, hp), math.max(lp, hp)
end

local function sort(axisboxtable, x, y)
  local axiscompare = function(boxa, boxb)
    local la, ha = projectspan(boxa, x, y)
    local lb, hb = projectspan(boxb, x, y)
    return la < lb
  end

  table.sort(axisboxtable, axiscompare)

  return axisboxtable
end

local function groupedsort(axisboxtable, x, y)
  local axiscompare = function(gboxa, gboxb)
    local la, ha = projectspan(gboxa.box, x, y)
    local lb, hb = projectspan(gboxb.box, x, y)
    return la < lb
  end

  table.sort(axisboxtable, axiscompare)
end

local function xoverlaptest(boxa, boxb)
  local lxa, hxa = axisbox.getboundx(boxa)
  local lxb, hxb = axisbox.getboundx(boxb)

  return not (hxa < lxb or hxb < lxa)
end

local function yoverlaptest(boxa, boxb)
  local lya, hya = axisbox.getboundy(boxa)
  local lyb, hyb = axisbox.getboundy(boxb)

  return not (hya < lyb or hyb < lya)
end

coolision.collisiondetect = function(axisboxtable, x, y)
  local sortedtable = sort(axisboxtable, x, y)

  local collisiontable = {}

  for k, boxa in pairs(axisboxtable) do
    local potentialcol = {}
    for _, boxb in next, axisboxtable, k do
      if xoverlaptest(boxa, boxb) then
        table.insert(potentialcol, boxb)
      else
        break
      end
    end
    -- check for y collision and register
    local cola = {}
    for _, boxb in pairs(potentialcol) do
      if yoverlaptest(boxa, boxb) then
        table.insert(cola, boxb)
      end
    end
    if #cola > 0 then
      collisiontable[boxa] = cola
    end
  end

  return collisiontable
end

coolision.groupedcd = function(seekers, hailers, x, y)
  if #seekers == 0 or #hailers == 0 then return {} end
  -- Concatenate tables and assign labels
  local groupboxtable = {}
  table.foreach(seekers,
    function(k, v)
      table.insert(groupboxtable, {isseeker = true, box = v})
    end
  )
  table.foreach(hailers,
    function(k, v)
      table.insert(groupboxtable, {isseeker = false, box = v})
    end
  )
  -- Sort with respect to specified axis
  groupedsort(groupboxtable, x, y)
  -- Seek collisions along sorted axis
  local collisiontable = {}
  for k, groupa in pairs(groupboxtable) do
    local potentialcol = {}
    for _, groupb in next, groupboxtable, k do
      if xoverlaptest(groupa.box, groupb.box) then
        -- Only add if grouping was different
        if groupa.isseeker == not groupb.isseeker then
          table.insert(potentialcol, groupb)
        end
      else
        break
      end
    end
    -- check for y collision and register
    local cola = {}
    for _, groupb in pairs(potentialcol) do
      if yoverlaptest(groupa.box, groupb.box) then
        table.insert(cola, groupb.box)
      end
    end
    if #cola > 0 then
      collisiontable[groupa.box] = cola
    end
  end

  return collisiontable
end

coolision.newAxisBox = function(x, y, w, h, callback)
  local box = {}

  box.x = x
  box.y = y
  box.w = w
  box.h = h
  box.hitcallback = callback

  return box
end

coolision.vflipaxisbox = function(box)
  box.x = -box.x - box.w
end
