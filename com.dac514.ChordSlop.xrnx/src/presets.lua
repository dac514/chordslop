--[[
  Factory presets. Each preset is a 4x4 palette of chords written as scale
  degrees, so it renders into any key and mode. Pure Lua; `src/store.lua`
  handles the user's own (absolute) presets.

  A pad spec is a small table:
    d  scale degree 1-7 (required)
    a  accidental on the root: -1 flat, +1 sharp (default 0)
    t  chord type id from theory.CHORD_TYPES (default: the diatonic triad,
       or major when the root is altered)
    s  true for the diatonic seventh instead of the triad
    i  inversion 0-3 (default 0)
    o  octave offset from the base octave (default 0)
  `false` leaves the pad empty.
]]

local theory = require "src.theory"
local pads_mod = require "src.pads"

local M = {}

---@class PresetPad
---@field d integer Scale degree 1-7.
---@field a integer? Accidental on the root (-1, +1).
---@field t string? Chord type id; nil = diatonic.
---@field s boolean? Diatonic seventh.
---@field i integer? Inversion.
---@field o integer? Octave offset.

---@class Preset
---@field name string
---@field mode integer? Mode the preset is written for; loading it switches the mode.
---@field pads (PresetPad|false)[] Up to 16 entries, row by row.

local MAJ = theory.MODE_IONIAN
local MIN = theory.MODE_AEOLIAN
local DOR = 2

---@type Preset[]
M.FACTORY = {
  {
    name = "Diatonic: triads + sevenths",
    pads = {
      { d = 1 },
      { d = 2 },
      { d = 3 },
      { d = 4 },
      { d = 5 },
      { d = 6 },
      { d = 7 },
      false,
      { d = 1, s = true },
      { d = 2, s = true },
      { d = 3, s = true },
      { d = 4, s = true },
      { d = 5, s = true },
      { d = 6, s = true },
      { d = 7, s = true },
      false,
    },
  },
  {
    name = "Pop: I V vi IV",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 5 },
      { d = 6 },
      { d = 4 },
      { d = 6 },
      { d = 4 },
      { d = 1 },
      { d = 5 },
      { d = 1, s = true },
      { d = 5, s = true },
      { d = 6, s = true },
      { d = 4, s = true },
      { d = 1, t = "sus2" },
      { d = 5, t = "sus4" },
      { d = 6, t = "min7", i = 1 },
      { d = 4, t = "add9" },
    },
  },
  {
    name = "50s: I vi IV V",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 4 },
      { d = 5 },
      { d = 1 },
      { d = 6 },
      { d = 2 },
      { d = 5 },
      { d = 1, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, t = "6" },
      { d = 6, t = "min7", i = 1 },
      { d = 4, t = "6" },
      { d = 5, t = "dom7", i = 2 },
    },
  },
  {
    name = "Jazz: ii V I",
    mode = MAJ,
    pads = {
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, s = true },
      { d = 1, t = "6" },
      { d = 3, s = true },
      { d = 6, t = "dom7" },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 4, s = true },
      { d = 4, a = 1, t = "m7b5" },
      { d = 3, s = true },
      { d = 3, a = -1, t = "dim7" },
      { d = 2, a = -1, t = "dom7" },
      { d = 7, s = true },
      { d = 7, a = -1, t = "maj7" },
      { d = 1, s = true, i = 2 },
    },
  },
  {
    name = "Blues: 12 bars",
    mode = MAJ,
    pads = {
      { d = 1, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 4, t = "dom7" },
      { d = 4, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 5, t = "dom7" },
      { d = 4, t = "dom7" },
      { d = 1, t = "dom7" },
      { d = 5, t = "dom7" },
      { d = 1, t = "6" },
      { d = 4, t = "6" },
      { d = 7, a = -1, t = "dom7" },
      { d = 5, t = "sus4" },
    },
  },
  {
    name = "Minor: i iv v VI",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 4 },
      { d = 5 },
      { d = 6 },
      { d = 7 },
      { d = 3 },
      { d = 2 },
      { d = 5, t = "maj" },
      { d = 1, s = true },
      { d = 4, s = true },
      { d = 5, t = "dom7" },
      { d = 6, s = true },
      { d = 7, s = true },
      { d = 3, s = true },
      { d = 2, s = true },
      { d = 1, t = "mmaj7" },
    },
  },
  {
    name = "Andalusian: i VII VI V",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 7 },
      { d = 6 },
      { d = 5, t = "maj" },
      { d = 1, s = true },
      { d = 7, s = true },
      { d = 6, s = true },
      { d = 5, t = "dom7" },
      { d = 4 },
      { d = 3 },
      { d = 7 },
      { d = 5, t = "sus4" },
      { d = 1, i = 1 },
      { d = 7, i = 1 },
      { d = 6, i = 1 },
      { d = 5, t = "maj", i = 1 },
    },
  },
  {
    name = "Dorian vamp",
    mode = DOR,
    pads = {
      { d = 1, s = true },
      { d = 4, t = "dom7" },
      { d = 1, s = true },
      { d = 2, s = true },
      { d = 1 },
      { d = 4 },
      { d = 2 },
      { d = 7 },
      { d = 1, t = "m6" },
      { d = 4, t = "6" },
      { d = 7, s = true },
      { d = 3, s = true },
      { d = 1, s = true, i = 1 },
      { d = 4, t = "dom7", i = 1 },
      { d = 2, s = true, i = 1 },
      { d = 1, t = "sus4" },
    },
  },
  {
    name = "Neo-soul sevenths",
    mode = MAJ,
    pads = {
      { d = 1, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 4, s = true },
      { d = 5, s = true },
      { d = 3, s = true },
      { d = 6, t = "dom7" },
      { d = 1, s = true, i = 2 },
      { d = 3, a = -1, t = "maj7" },
      { d = 2, s = true, i = 1 },
      { d = 7, a = -1, t = "maj7" },
      { d = 4, s = true, i = 2 },
      { d = 3, s = true, i = 1 },
      { d = 6, s = true, i = 1 },
      { d = 5, t = "sus4" },
    },
  },
  {
    name = "Power chords",
    pads = {
      { d = 1, t = "5" },
      { d = 4, t = "5" },
      { d = 5, t = "5" },
      { d = 7, a = -1, t = "5" },
      { d = 6, t = "5" },
      { d = 2, t = "5" },
      { d = 3, t = "5" },
      { d = 3, a = -1, t = "5" },
      { d = 1, t = "5", o = -1 },
      { d = 4, t = "5", o = -1 },
      { d = 5, t = "5", o = -1 },
      { d = 7, a = -1, t = "5", o = -1 },
      { d = 6, t = "5", o = -1 },
      { d = 2, t = "5", o = -1 },
      { d = 3, t = "5", o = -1 },
      { d = 3, a = -1, t = "5", o = -1 },
    },
  },
  {
    name = "Suspended / ambient",
    pads = {
      { d = 1, t = "sus2" },
      { d = 1, t = "sus4" },
      { d = 5, t = "sus2" },
      { d = 5, t = "sus4" },
      { d = 4, t = "sus2" },
      { d = 4, t = "sus4" },
      { d = 2, t = "sus2" },
      { d = 2, t = "sus4" },
      { d = 1, t = "add9" },
      { d = 4, t = "add9" },
      { d = 5, t = "add9" },
      { d = 6, t = "sus4" },
      { d = 1, t = "sus2", o = -1 },
      { d = 5, t = "sus4", o = -1 },
      { d = 4, t = "sus2", o = -1 },
      { d = 6, t = "sus2", o = -1 },
    },
  },
}

---@return string[]
function M.names()
  local names = {}
  for i, preset in ipairs(M.FACTORY) do
    names[i] = preset.name
  end
  return names
end

---Turn one pad spec into a pad for a key/mode.
---@param spec PresetPad
---@param key integer
---@param mode integer
---@param base_octave integer
---@return Pad
function M.render_pad(spec, key, mode, base_octave)
  local scale = theory.scale(key, mode)
  local acc = spec.a or 0
  local root = (scale[spec.d] + acc) % 12
  local type_index
  if spec.t then
    type_index = assert(theory.type_index(spec.t), "unknown chord type " .. spec.t)
  elseif acc ~= 0 then
    type_index = assert(theory.type_index "maj")
  else
    local _, diatonic = theory.diatonic_chord(key, mode, spec.d, spec.s)
    type_index = diatonic
  end
  return pads_mod.normalize {
    root = root,
    type = type_index,
    inversion = spec.i or 0,
    octave = math.max(
      pads_mod.MIN_OCTAVE,
      math.min(pads_mod.MAX_OCTAVE, base_octave + (spec.o or 0))
    ),
  }
end

---Render a preset into sixteen pads.
---@param preset Preset
---@param key integer 0-11
---@param mode integer 1-7
---@param base_octave integer? Default pads_mod.DEFAULT_OCTAVE.
---@return Pad[]
function M.render(preset, key, mode, base_octave)
  base_octave = base_octave or pads_mod.DEFAULT_OCTAVE
  local pads = {}
  for i = 1, pads_mod.COUNT do
    local spec = preset.pads[i]
    if spec then
      pads[i] = M.render_pad(spec, key, mode, base_octave)
    else
      pads[i] = pads_mod.empty()
    end
  end
  return pads
end

return M
