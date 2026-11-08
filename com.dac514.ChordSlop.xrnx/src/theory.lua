--[[
  Music theory: note names, chord types, scales/modes, roman numeral analysis.
  Pure Lua on purpose (no `renoise.*`, no Renoise stdlib additions) so that
  `just test` can run it under plain LuaJIT.

  Pitch classes are 0-11 (C = 0). Notes are Renoise note values 0-119 where
  48 = C-4. Octaves follow Renoise (octave 4 -> 48 + pitch class).
]]

local M = {}

---@class ChordType
---@field id string Stable identifier used by presets.
---@field symbol string Chord symbol suffix after the root name ("" for major).
---@field numeral string Suffix after the roman numeral ("°", "7", "maj7", ...).
---@field intervals integer[] Semitones from the root, ascending.

---Chord types by index. Pads and preferences store the index; 0 means "empty".
---@type ChordType[]
M.CHORD_TYPES = {
  { id = "maj", symbol = "", numeral = "", intervals = { 0, 4, 7 } },
  { id = "min", symbol = "m", numeral = "", intervals = { 0, 3, 7 } },
  { id = "dim", symbol = "dim", numeral = "°", intervals = { 0, 3, 6 } },
  { id = "aug", symbol = "aug", numeral = "+", intervals = { 0, 4, 8 } },
  { id = "sus2", symbol = "sus2", numeral = "sus2", intervals = { 0, 2, 7 } },
  { id = "sus4", symbol = "sus4", numeral = "sus4", intervals = { 0, 5, 7 } },
  { id = "maj7", symbol = "maj7", numeral = "maj7", intervals = { 0, 4, 7, 11 } },
  { id = "min7", symbol = "m7", numeral = "7", intervals = { 0, 3, 7, 10 } },
  { id = "dom7", symbol = "7", numeral = "7", intervals = { 0, 4, 7, 10 } },
  { id = "dim7", symbol = "dim7", numeral = "°7", intervals = { 0, 3, 6, 9 } },
  { id = "m7b5", symbol = "m7b5", numeral = "ø7", intervals = { 0, 3, 6, 10 } },
  { id = "mmaj7", symbol = "mMaj7", numeral = "mMaj7", intervals = { 0, 3, 7, 11 } },
  { id = "6", symbol = "6", numeral = "6", intervals = { 0, 4, 7, 9 } },
  { id = "m6", symbol = "m6", numeral = "6", intervals = { 0, 3, 7, 9 } },
  { id = "add9", symbol = "add9", numeral = "add9", intervals = { 0, 4, 7, 14 } },
  { id = "5", symbol = "5", numeral = "5", intervals = { 0, 7 } },
}

---@class Mode
---@field name string
---@field short string Abbreviation for tight labels.
---@field steps integer[] The seven scale degrees as semitone offsets from the tonic.
---@field brightness integer 0 (Lydian) .. 6 (Locrian): fifths below the tonic where the in-key span starts on the circle.

---Diatonic modes by index (1 Ionian .. 7 Locrian).
---@type Mode[]
M.MODES = {
  { name = "Ionian (major)", short = "maj", steps = { 0, 2, 4, 5, 7, 9, 11 }, brightness = 1 },
  { name = "Dorian", short = "dor", steps = { 0, 2, 3, 5, 7, 9, 10 }, brightness = 3 },
  { name = "Phrygian", short = "phr", steps = { 0, 1, 3, 5, 7, 8, 10 }, brightness = 5 },
  { name = "Lydian", short = "lyd", steps = { 0, 2, 4, 6, 7, 9, 11 }, brightness = 0 },
  { name = "Mixolydian", short = "mix", steps = { 0, 2, 4, 5, 7, 9, 10 }, brightness = 2 },
  { name = "Aeolian (minor)", short = "min", steps = { 0, 2, 3, 5, 7, 8, 10 }, brightness = 4 },
  { name = "Locrian", short = "loc", steps = { 0, 1, 3, 5, 6, 8, 10 }, brightness = 6 },
}

M.MODE_IONIAN = 1
M.MODE_AEOLIAN = 6

---@type string[]
M.NOTE_NAMES_SHARP = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
---@type string[]
M.NOTE_NAMES_FLAT = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII" }

M.MIN_NOTE = 0
M.MAX_NOTE = 119

---@param value number
---@param lo number
---@param hi number
---@return number
local function clamp(value, lo, hi)
  if value < lo then
    return lo
  elseif value > hi then
    return hi
  end
  return value
end

---Index of a chord type by its id.
---@param id string
---@return integer?
function M.type_index(id)
  for i, t in ipairs(M.CHORD_TYPES) do
    if t.id == id then
      return i
    end
  end
  return nil
end

---The pitch class whose Ionian scale has the same notes as `key`/`mode`.
---@param key integer 0-11
---@param mode integer 1-7
---@return integer
function M.relative_major(key, mode)
  local steps = M.MODES[mode].steps
  local degree = ((1 - mode) % 7) + 1
  return (key + steps[degree]) % 12
end

---Whether note names in this key read better with flats (F, Bb, Eb, Ab, Db majors).
---@param key integer 0-11
---@param mode integer 1-7
---@return boolean
function M.prefers_flats(key, mode)
  local major = M.relative_major(key, mode)
  return major == 5 or major == 10 or major == 3 or major == 8 or major == 1
end

---@param pc integer 0-11
---@param flats boolean?
---@return string
function M.note_name(pc, flats)
  local names = flats and M.NOTE_NAMES_FLAT or M.NOTE_NAMES_SHARP
  return names[(pc % 12) + 1]
end

---Build the note values of a chord.
---@param root integer 0-11
---@param type_index integer 1..#CHORD_TYPES
---@param inversion integer 0-3; the lowest `inversion` tones move up an octave (clamped to the chord size)
---@param octave integer 0-9 Renoise octave of the root (4 -> 48 + root)
---@return integer[] notes Ascending, each clamped to 0..119.
function M.build_notes(root, type_index, inversion, octave)
  local chord = M.CHORD_TYPES[type_index]
  local base = octave * 12 + root
  local notes = {}
  for i, interval in ipairs(chord.intervals) do
    notes[i] = base + interval
  end
  inversion = clamp(inversion or 0, 0, #notes - 1)
  for _ = 1, inversion do
    local lowest = table.remove(notes, 1)
    notes[#notes + 1] = lowest + 12
  end
  for i, note in ipairs(notes) do
    notes[i] = clamp(note, M.MIN_NOTE, M.MAX_NOTE)
  end
  table.sort(notes)
  return notes
end

---The seven pitch classes of a scale.
---@param key integer 0-11
---@param mode integer 1-7
---@return integer[]
function M.scale(key, mode)
  local pcs = {}
  for i, step in ipairs(M.MODES[mode].steps) do
    pcs[i] = (key + step) % 12
  end
  return pcs
end

---@param pc integer 0-11
---@param key integer 0-11
---@param mode integer 1-7
---@return integer? degree 1-7, or nil when the pitch class is not in the scale
function M.degree_of(pc, key, mode)
  for i, spc in ipairs(M.scale(key, mode)) do
    if spc == pc % 12 then
      return i
    end
  end
  return nil
end

---@param intervals integer[]
---@return integer?
local function type_for_intervals(intervals)
  for i, t in ipairs(M.CHORD_TYPES) do
    if #t.intervals == #intervals then
      local same = true
      for j = 1, #intervals do
        if t.intervals[j] ~= intervals[j] then
          same = false
          break
        end
      end
      if same then
        return i
      end
    end
  end
  return nil
end

---The chord built by stacking thirds on a scale degree.
---@param key integer 0-11
---@param mode integer 1-7
---@param degree integer 1-7
---@param seventh boolean? Add the diatonic seventh.
---@return integer root, integer type_index
function M.diatonic_chord(key, mode, degree, seventh)
  local scale = M.scale(key, mode)
  local root = scale[degree]
  local intervals = { 0 }
  local count = seventh and 4 or 3
  for n = 1, count - 1 do
    local pc = scale[((degree - 1 + 2 * n) % 7) + 1]
    intervals[#intervals + 1] = (pc - root) % 12
  end
  local index = type_for_intervals(intervals)
  assert(index, "no chord type for diatonic intervals")
  return root, index
end

---@param set integer[]
---@param pc integer
---@return boolean
local function contains(set, pc)
  for _, v in ipairs(set) do
    if v == pc then
      return true
    end
  end
  return false
end

---@param tones integer[]
---@param set integer[]
---@return boolean
local function all_in(tones, set)
  for _, pc in ipairs(tones) do
    if not contains(set, pc) then
      return false
    end
  end
  return true
end

---@class ChordAnalysis
---@field numeral string Roman numeral with accidental and suffix, e.g. "ii", "V7", "bVII", "vii°".
---@field func "in_key"|"borrowed"|"out"

---Analyse a chord against a key: numeral and how well it fits.
---`in_key`: every tone is in the scale. `borrowed`: every tone is in the parallel
---major/minor scale, or the root is in the scale but a tone is not (secondary
---dominants and the like). `out`: anything else.
---@param root integer 0-11
---@param type_index integer 1..#CHORD_TYPES
---@param key integer 0-11
---@param mode integer 1-7
---@return ChordAnalysis
function M.analyze(root, type_index, key, mode)
  local chord = M.CHORD_TYPES[type_index]
  local tones = {}
  for i, interval in ipairs(chord.intervals) do
    tones[i] = (root + interval) % 12
  end
  local scale = M.scale(key, mode)
  local func
  if all_in(tones, scale) then
    func = "in_key"
  else
    local major_ish = M.MODES[mode].brightness <= 2
    local parallel = M.scale(key, major_ish and M.MODE_AEOLIAN or M.MODE_IONIAN)
    if all_in(tones, parallel) or contains(scale, root % 12) then
      func = "borrowed"
    else
      func = "out"
    end
  end

  local degree = M.degree_of(root, key, mode)
  local accidental = ""
  if not degree then
    -- Prefer the lowered upper neighbour (bVII, bIII, bVI); every non-scale
    -- pitch class in a diatonic scale sits a semitone below some degree.
    for i, pc in ipairs(scale) do
      if (pc - 1) % 12 == root % 12 then
        degree, accidental = i, "b"
        break
      end
    end
  end
  assert(degree, "degree lookup failed")
  local numeral = ROMAN[degree]
  local third = chord.intervals[2]
  if third == 3 then
    numeral = numeral:lower()
  end
  return { numeral = accidental .. numeral .. chord.numeral, func = func }
end

---@param root integer 0-11
---@param type_index integer 1..#CHORD_TYPES
---@param flats boolean?
---@return string e.g. "Dm7"
function M.chord_name(root, type_index, flats)
  return M.note_name(root, flats) .. M.CHORD_TYPES[type_index].symbol
end

return M
