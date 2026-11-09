--[[
  Presets: 4x4 chord palettes written as scale degrees, so they render into
  any key and mode. Every factory preset stays inside its key (minor presets
  may use the harmonic-minor V), which `tests/presets_test.lua` enforces, so
  loading one always gives sixteen chords that belong together. Factory
  presets live here; the user's own are captured from the pads in the same
  relative form (see `capture`) and stored by `src/store.lua`. Pure Lua.

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
---@field desc string? One line about the sound or use.
---@field mode integer? Mode the preset is written for; loading it switches the mode.
---@field pads (PresetPad|false)[] Up to 16 entries, row by row.

local MAJ = theory.MODE_IONIAN
local MIN = theory.MODE_AEOLIAN
local DOR, PHR, LYD, MIX = 2, 3, 4, 5

---@type Preset[]
M.FACTORY = {
  {
    name = "Diatonic: triads + sevenths",
    desc = "Every chord of the key: triads on the first two rows, sevenths below. Works in any mode.",
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
    desc = "The four-chord loop in both orders, then sevenths and colour chords.",
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
    desc = "Doo-wop and ballad changes, with the ii substitute and sixth chords.",
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
    name = "Canon: I V vi iii IV",
    desc = "The Pachelbel progression, root position on top, inversions below for a smooth bass.",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 5 },
      { d = 6 },
      { d = 3 },
      { d = 4 },
      { d = 1 },
      { d = 4 },
      { d = 5 },
      { d = 1, i = 1 },
      { d = 5, i = 1 },
      { d = 6, i = 1 },
      { d = 3, i = 1 },
      { d = 4, i = 1 },
      { d = 1, i = 2 },
      { d = 4, i = 2 },
      { d = 5, i = 2 },
    },
  },
  {
    name = "Jazz: ii V I",
    desc = "Sevenths everywhere: the ii V I, the iii vi ii V turnaround, inversions for voice leading.",
    mode = MAJ,
    pads = {
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, s = true },
      { d = 1, t = "6" },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 4, s = true },
      { d = 7, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true, i = 1 },
      { d = 5, s = true, i = 1 },
      { d = 1, s = true, i = 2 },
      { d = 6, s = true, i = 1 },
    },
  },
  {
    name = "Bossa / latin",
    desc = "Major sevenths, sixths and minor sixths that lean into each other.",
    mode = MAJ,
    pads = {
      { d = 1, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, t = "6" },
      { d = 6, s = true },
      { d = 2, t = "m6" },
      { d = 5, t = "sus4" },
      { d = 5, s = true, i = 1 },
      { d = 4, s = true },
      { d = 4, t = "6" },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 1, s = true, i = 2 },
      { d = 2, s = true, i = 1 },
      { d = 5, s = true, i = 2 },
      { d = 6, s = true, i = 1 },
    },
  },
  {
    name = "Gospel / R&B",
    desc = "Lush sevenths and sixths with a suspended dominant and inverted cadences.",
    mode = MAJ,
    pads = {
      { d = 1, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, t = "6" },
      { d = 4, t = "6" },
      { d = 5, t = "sus4" },
      { d = 4, s = true },
      { d = 3, s = true },
      { d = 2, s = true },
      { d = 1, i = 1 },
      { d = 2, s = true, i = 1 },
      { d = 5, s = true, i = 2 },
      { d = 1, s = true, i = 2 },
      { d = 6, s = true, i = 1 },
    },
  },
  {
    name = "Neo-soul sevenths",
    desc = "Mellow major-key sevenths; the lower rows are the same chords in inversions.",
    mode = MAJ,
    pads = {
      { d = 1, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 4, s = true },
      { d = 5, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 1, s = true, i = 2 },
      { d = 4, s = true, i = 1 },
      { d = 2, s = true, i = 1 },
      { d = 5, s = true, i = 1 },
      { d = 4, s = true, i = 2 },
      { d = 3, s = true, i = 1 },
      { d = 6, s = true, i = 1 },
      { d = 5, t = "sus4" },
    },
  },
  {
    name = "Lo-fi hip hop",
    desc = "Minor sevenths and major sevenths that loop forever; try the inversions on the last row.",
    mode = MAJ,
    pads = {
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, s = true },
      { d = 6, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 4, s = true },
      { d = 3, s = true },
      { d = 2, s = true },
      { d = 1, s = true },
      { d = 1, t = "6" },
      { d = 4, s = true, i = 1 },
      { d = 3, s = true, i = 1 },
      { d = 6, s = true, i = 1 },
    },
  },
  {
    name = "Minor: i iv v VI",
    desc = "Natural minor with the harmonic-minor V and V7 for the pull back home.",
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
    name = "Sad minor ballad",
    desc = "i VI III VII and friends; slow, open, with sevenths on the lower rows.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 3 },
      { d = 7 },
      { d = 4 },
      { d = 1 },
      { d = 5, t = "dom7" },
      { d = 1 },
      { d = 1, s = true },
      { d = 6, s = true },
      { d = 3, s = true },
      { d = 7, s = true },
      { d = 4, s = true },
      { d = 1, i = 1 },
      { d = 5, t = "maj" },
      { d = 6, i = 1 },
    },
  },
  {
    name = "Andalusian: i VII VI V",
    desc = "The flamenco descent, with sevenths, a sus4 dominant and first inversions.",
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
    name = "Trance / EDM minor",
    desc = "Big minor loops: i VI III VII, the low octave for basslines, add9s for width.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 3 },
      { d = 7 },
      { d = 1 },
      { d = 7 },
      { d = 6 },
      { d = 7 },
      { d = 1, o = -1 },
      { d = 6, o = -1 },
      { d = 3, o = -1 },
      { d = 7, o = -1 },
      { d = 1, t = "sus2" },
      { d = 6, t = "add9" },
      { d = 3, t = "add9" },
      { d = 7, t = "sus4" },
    },
  },
  {
    name = "Cinematic minor",
    desc = "Epic and dark: open fifths, slow minor triads and a few wide sevenths.",
    mode = MIN,
    pads = {
      { d = 1, t = "5" },
      { d = 6, t = "5" },
      { d = 3, t = "5" },
      { d = 7, t = "5" },
      { d = 1 },
      { d = 4 },
      { d = 6 },
      { d = 5, t = "maj" },
      { d = 1, t = "sus2" },
      { d = 6, t = "maj7" },
      { d = 3, t = "add9" },
      { d = 7, t = "sus4" },
      { d = 1, o = -1 },
      { d = 4, o = -1 },
      { d = 6, o = -1 },
      { d = 2, t = "m7b5" },
    },
  },
  {
    name = "Dorian vamp",
    desc = "Modal jazz and funk: i7 to IV7, the Dorian ii, sixth chords.",
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
    name = "Dark Phrygian",
    desc = "The flat second rules: i, bII, bVII and bvii, for metal, flamenco and tension.",
    mode = PHR,
    pads = {
      { d = 1 },
      { d = 2 },
      { d = 7 },
      { d = 4 },
      { d = 1, s = true },
      { d = 2, s = true },
      { d = 7, s = true },
      { d = 4, s = true },
      { d = 1, t = "5" },
      { d = 2, t = "5" },
      { d = 7, t = "5" },
      { d = 3, t = "5" },
      { d = 1, o = -1 },
      { d = 2, o = -1 },
      { d = 1, t = "sus4" },
      { d = 2, t = "maj7" },
    },
  },
  {
    name = "Lydian dream",
    desc = "Bright and floating: I, II and the raised fourth, with add9s.",
    mode = LYD,
    pads = {
      { d = 1 },
      { d = 2 },
      { d = 3 },
      { d = 7 },
      { d = 1, s = true },
      { d = 2, s = true },
      { d = 3, s = true },
      { d = 7, s = true },
      { d = 1, t = "add9" },
      { d = 2, t = "add9" },
      { d = 5, t = "add9" },
      { d = 3, t = "sus4" },
      { d = 1, o = -1 },
      { d = 2, o = -1 },
      { d = 1, t = "maj7", i = 1 },
      { d = 2, t = "dom7", i = 1 },
    },
  },
  {
    name = "Mixolydian groove",
    desc = "Rock and funk: I bVII IV, the dominant seventh on the tonic, sus chords.",
    mode = MIX,
    pads = {
      { d = 1 },
      { d = 7 },
      { d = 4 },
      { d = 5 },
      { d = 1, s = true },
      { d = 7, s = true },
      { d = 4, s = true },
      { d = 5, s = true },
      { d = 1, t = "sus4" },
      { d = 1 },
      { d = 7 },
      { d = 4 },
      { d = 1, o = -1 },
      { d = 7, o = -1 },
      { d = 4, o = -1 },
      { d = 5, o = -1 },
    },
  },
  {
    name = "Power chords",
    desc = "Fifths only, on the degrees that have a perfect fifth, two octaves.",
    mode = MAJ,
    pads = {
      { d = 1, t = "5" },
      { d = 4, t = "5" },
      { d = 5, t = "5" },
      { d = 6, t = "5" },
      { d = 2, t = "5" },
      { d = 3, t = "5" },
      { d = 1, t = "5" },
      { d = 5, t = "5" },
      { d = 1, t = "5", o = -1 },
      { d = 4, t = "5", o = -1 },
      { d = 5, t = "5", o = -1 },
      { d = 6, t = "5", o = -1 },
      { d = 2, t = "5", o = -1 },
      { d = 3, t = "5", o = -1 },
      { d = 1, t = "5", o = -1 },
      { d = 5, t = "5", o = -1 },
    },
  },
  {
    name = "Suspended / ambient",
    desc = "No thirds: sus2, sus4 and add9 pads that sit under anything.",
    mode = MAJ,
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

---Write one pad as a spec relative to a key/mode. Roots outside the scale
---are spelled as the flattened upper degree (bVII, bIII, ...).
---@param pad Pad
---@param key integer
---@param mode integer
---@return PresetPad|false
function M.capture_pad(pad, key, mode)
  if pads_mod.is_empty(pad) then
    return false
  end
  local scale = theory.scale(key, mode)
  local degree = theory.degree_of(pad.root, key, mode)
  local acc = 0
  if not degree then
    for i, pc in ipairs(scale) do
      if (pc - 1) % 12 == pad.root then
        degree, acc = i, -1
        break
      end
    end
  end
  assert(degree, "pad root not representable")
  local spec = { d = degree, t = theory.CHORD_TYPES[pad.type].id }
  if acc ~= 0 then
    spec.a = acc
  end
  if pad.inversion ~= 0 then
    spec.i = pad.inversion
  end
  if pad.octave ~= pads_mod.DEFAULT_OCTAVE then
    spec.o = pad.octave - pads_mod.DEFAULT_OCTAVE
  end
  return spec
end

---Capture the pads as a preset relative to the current key and mode, so it
---renders back into any key.
---@param pads Pad[]
---@param key integer
---@param mode integer
---@param name string
---@return Preset
function M.capture(pads, key, mode, name)
  local specs = {}
  for i = 1, pads_mod.COUNT do
    specs[i] = M.capture_pad(pads[i] or pads_mod.empty(), key, mode)
  end
  return { name = name, mode = mode, pads = specs }
end

return M
