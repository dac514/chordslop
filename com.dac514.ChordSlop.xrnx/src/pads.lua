--[[
  The pad model: sixteen pads, each a chord (root, type, inversion, octave).
  Pure Lua; `src/store.lua` moves pads in and out of the preferences and
  `src/ui.lua` draws them.
]]

local theory = require "src.theory"

local M = {}

---@class Pad
---@field root integer 0-11 pitch class
---@field type integer 0 = empty, else index into theory.CHORD_TYPES
---@field inversion integer 0-3
---@field octave integer 0-9

M.COUNT = 16
M.MAX_INVERSION = 3
M.MIN_OCTAVE = 0
M.MAX_OCTAVE = 9
M.DEFAULT_OCTAVE = 4

---@return Pad
function M.empty()
  return { root = 0, type = 0, inversion = 0, octave = M.DEFAULT_OCTAVE }
end

---@param pad Pad
---@return boolean
function M.is_empty(pad)
  return pad.type == 0
end

---@param value any
---@param lo integer
---@param hi integer
---@param default integer
---@return integer
local function int_in(value, lo, hi, default)
  if type(value) ~= "number" then
    return default
  end
  value = math.floor(value)
  if value < lo or value > hi then
    return default
  end
  return value
end

---Normalise a pad: out-of-range fields fall back to defaults, invalid type -> empty.
---@param pad table?
---@return Pad
function M.normalize(pad)
  if type(pad) ~= "table" then
    return M.empty()
  end
  return {
    root = int_in(pad.root, 0, 11, 0),
    type = int_in(pad.type, 0, #theory.CHORD_TYPES, 0),
    inversion = int_in(pad.inversion, 0, M.MAX_INVERSION, 0),
    octave = int_in(pad.octave, M.MIN_OCTAVE, M.MAX_OCTAVE, M.DEFAULT_OCTAVE),
  }
end

---Transpose every pad by `delta` semitones. The root wraps and the octave
---carries, clamped to the valid range. Empty pads are left alone.
---@param pads Pad[]
---@param delta integer
---@return Pad[]
function M.transpose(pads, delta)
  local out = {}
  for i, pad in ipairs(pads) do
    if M.is_empty(pad) then
      out[i] = M.normalize(pad)
    else
      local absolute = pad.octave * 12 + pad.root + delta
      local octave = math.floor(absolute / 12)
      if octave < M.MIN_OCTAVE then
        octave = M.MIN_OCTAVE
      elseif octave > M.MAX_OCTAVE then
        octave = M.MAX_OCTAVE
      end
      out[i] = { root = absolute % 12, type = pad.type, inversion = pad.inversion, octave = octave }
    end
  end
  return out
end

---Flatten pads into four plain number lists (what the preferences store).
---@param pads Pad[]
---@return integer[] roots, integer[] types, integer[] inversions, integer[] octaves
function M.to_lists(pads)
  local roots, types, inversions, octaves = {}, {}, {}, {}
  for i = 1, M.COUNT do
    local pad = M.normalize(pads[i])
    roots[i], types[i], inversions[i], octaves[i] = pad.root, pad.type, pad.inversion, pad.octave
  end
  return roots, types, inversions, octaves
end

---Rebuild pads from four number lists. Always returns `COUNT` pads; missing or
---invalid entries become empty pads.
---@param roots integer[]
---@param types integer[]
---@param inversions integer[]
---@param octaves integer[]
---@return Pad[]
function M.from_lists(roots, types, inversions, octaves)
  local pads = {}
  for i = 1, M.COUNT do
    pads[i] = M.normalize {
      root = roots[i],
      type = types[i],
      inversion = inversions[i],
      octave = octaves[i],
    }
  end
  return pads
end

---Notes a pad plays.
---@param pad Pad
---@return integer[]
function M.notes(pad)
  if M.is_empty(pad) then
    return {}
  end
  return theory.build_notes(pad.root, pad.type, pad.inversion, pad.octave)
end

---@alias PadFunction "in_key"|"borrowed"|"out"|"empty"

---Display strings for a pad in the given key.
---@param pad Pad
---@param key integer 0-11
---@param mode integer 1-7
---@return string name, string numeral, PadFunction func
function M.label(pad, key, mode)
  if M.is_empty(pad) then
    return "", "", "empty"
  end
  local analysis = theory.analyze(pad.root, pad.type, key, mode)
  -- Flattened degrees (bVII, bIII...) read as flats whatever the key prefers.
  local flats = theory.prefers_flats(key, mode) or analysis.numeral:sub(1, 1) == "b"
  return theory.chord_name(pad.root, pad.type, flats), analysis.numeral, analysis.func
end

---Are all pads empty?
---@param pads Pad[]
---@return boolean
function M.all_empty(pads)
  for _, pad in ipairs(pads) do
    if not M.is_empty(pad) then
      return false
    end
  end
  return true
end

return M
