--[[
  Geometry of the small piano keyboard under the pad editor. Pure Lua
  (`tests/keyboard_test.lua`); `src/ui.lua` draws it on a canvas.

  The keyboard starts on a C. White keys are `white_w` wide; a black key is
  `black_w` wide and sits on the line between its two white keys, a little
  to the left or right like on a real piano.
]]

local M = {}

---Is the note on a black key?
---@param note integer
---@return boolean
function M.is_black(note)
  local pc = note % 12
  return pc == 1 or pc == 3 or pc == 6 or pc == 8 or pc == 10
end

---White keys below each pitch class within its octave (C 0, C# 1, D 1, ...).
local WHITE_INDEX = { [0] = 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6 }
---Where a black key sits on its line: -1 leans left, +1 leans right.
local LEAN = { [1] = -1, [3] = 1, [6] = -1, [8] = 0, [10] = 1 }

---Number of white keys from `low` (a C) to `high`, both included.
---@param low integer
---@param high integer
---@return integer
function M.white_count(low, high)
  local count = 0
  for note = low, high do
    if not M.is_black(note) then
      count = count + 1
    end
  end
  return count
end

---Horizontal extent of a key.
---@param note integer
---@param low integer The first key, a C.
---@param white_w number
---@param black_w number
---@return number x, number width, boolean black
function M.key_x(note, low, white_w, black_w)
  local rel = note - low
  local octave = math.floor(rel / 12)
  local pc = rel % 12
  local whites_before = octave * 7 + WHITE_INDEX[pc]
  if not M.is_black(note) then
    return whites_before * white_w, white_w, false
  end
  -- a black key sits on the line between the white keys around it
  local line = whites_before * white_w
  local x = line - black_w / 2 + LEAN[pc] * black_w / 6
  return x, black_w, true
end

return M
