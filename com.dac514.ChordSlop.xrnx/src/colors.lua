--[[
  Pad colours. Pure Lua: the UI hands in the theme's button colour (when it
  can read it) and gets back the palette for in-key, borrowed and out-of-key
  pads. Colours are `{ r, g, b }` with 0-255 integer components.
]]

local M = {}

---@alias RGB integer[] `{ r, g, b }`, each 0-255

---Mix two colours: `t = 0` gives `a`, `t = 1` gives `b`.
---@param a RGB
---@param b RGB
---@param t number 0-1
---@return RGB
function M.blend(a, b, t)
  local out = {}
  for i = 1, 3 do
    local v = a[i] + (b[i] - a[i]) * t
    out[i] = math.max(0, math.min(255, math.floor(v + 0.5)))
  end
  return out
end

---@class PadPalette
---@field in_key RGB
---@field borrowed RGB
---@field out RGB `{0,0,0}` means "theme default" for a Renoise button
---@field highlight fun(color: RGB): RGB Brightened version for the selected pad

M.GREEN = { 60, 170, 90 }
M.AMBER = { 220, 150, 40 }
M.DEFAULT_BUTTON = { 70, 70, 70 }

---Build the pad palette around the theme's button colour.
---@param button_back RGB? nil when the theme is unavailable
---@return PadPalette
function M.palette(button_back)
  local base = button_back or M.DEFAULT_BUTTON
  local palette = {
    in_key = M.blend(base, M.GREEN, 0.55),
    borrowed = M.blend(base, M.AMBER, 0.55),
    out = { 0, 0, 0 },
  }
  function palette.highlight(color)
    local from = (color[1] == 0 and color[2] == 0 and color[3] == 0) and base or color
    return M.blend(from, { 255, 255, 255 }, 0.3)
  end
  return palette
end

---Colour for a pad function.
---@param palette PadPalette
---@param func "in_key"|"borrowed"|"out"|"empty"
---@return RGB
function M.for_function(palette, func)
  if func == "in_key" then
    return palette.in_key
  elseif func == "borrowed" then
    return palette.borrowed
  end
  return palette.out
end

return M
