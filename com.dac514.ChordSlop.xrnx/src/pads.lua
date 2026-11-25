--[[
  The pad model: sixteen pads, each a chord (root, type, inversion, octave)
  with an optional slash bass. Pure Lua; `src/store.lua` moves pads in and
  out of the preferences, `src/voicing.lua` turns them into notes and
  `src/ui.lua` draws them.
]]

local theory = require "src.theory"
local voicing = require "src.voicing"

local M = {}

---@class Pad
---@field root integer 0-11 pitch class
---@field type integer 0 = empty, else index into theory.CHORD_TYPES
---@field inversion integer 0-3
---@field octave integer 0-9
---@field bass integer? -1 or nil = the chord tone the inversion puts lowest, else a 0-11 pitch class

M.COUNT = 16
M.MAX_INVERSION = 3
M.MIN_OCTAVE = 0
M.MAX_OCTAVE = 9
M.DEFAULT_OCTAVE = 4
M.NO_BASS = -1

---@return Pad
function M.empty()
  return { root = 0, type = 0, inversion = 0, octave = M.DEFAULT_OCTAVE, bass = M.NO_BASS }
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
    bass = int_in(pad.bass, M.NO_BASS, 11, M.NO_BASS),
  }
end

---Where a key sits from C, in semitones: -5 (G) to +6 (F#). Presets render
---in C and move by this much, and a key change moves the pads by the
---difference, so the pads in a key never depend on the keys visited before.
---The cost is one seam: from F# to G the pads go down 11 semitones.
---@param key integer 0-11
---@return integer offset -5..6
function M.key_offset(key)
  key = key % 12
  return key <= 6 and key or key - 12
end

---Semitones to move the pads when the key changes from `from` to `to`.
---@param from integer 0-11
---@param to integer 0-11
---@return integer delta -11..11
function M.key_delta(from, to)
  return M.key_offset(to) - M.key_offset(from)
end

---Do two pads play the same chord in the same octave? Empty pads are equal
---whatever else they hold.
---@param a Pad
---@param b Pad
---@return boolean
function M.equal(a, b)
  if M.is_empty(a) or M.is_empty(b) then
    return M.is_empty(a) and M.is_empty(b)
  end
  local a_bass = voicing.has_bass(a) and a.bass % 12 or M.NO_BASS
  local b_bass = voicing.has_bass(b) and b.bass % 12 or M.NO_BASS
  return a.root == b.root
    and a.type == b.type
    and a.inversion == b.inversion
    and a.octave == b.octave
    and a_bass == b_bass
end

---Do two sets of sixteen pads hold the same chords?
---@param a Pad[]
---@param b Pad[]
---@return boolean
function M.all_equal(a, b)
  for i = 1, M.COUNT do
    if not M.equal(a[i] or M.empty(), b[i] or M.empty()) then
      return false
    end
  end
  return true
end

---Transpose every pad by `delta` semitones. The root wraps and the octave
---carries, clamped to the valid range; a slash bass moves with the root.
---Empty pads are left alone.
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
      local bass = M.NO_BASS
      if voicing.has_bass(pad) then
        bass = (pad.bass + delta) % 12
      end
      out[i] = {
        root = absolute % 12,
        type = pad.type,
        inversion = pad.inversion,
        octave = octave,
        bass = bass,
      }
    end
  end
  return out
end

---Count the pads that are in key.
---@param pads Pad[]
---@param key integer 0-11
---@param mode integer 1-7
---@return integer in_key Pads whose tones are all in the key (see `theory.analyze`).
---@return integer total Pads that are not empty.
function M.fit(pads, key, mode)
  local in_key, total = 0, 0
  for _, pad in ipairs(pads) do
    if not M.is_empty(pad) then
      total = total + 1
      if M.analyze(pad, key, mode).func == "in_key" then
        in_key = in_key + 1
      end
    end
  end
  return in_key, total
end

---Moves that `best_fit` tries, the preferred one first: the smallest move
---wins a tie, and a move down wins over the same move up.
local FIT_MOVES = { 0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, 6 }

---The transposition of all pads together that puts the most of them in key.
---Moving the pads by `delta` fits like leaving them and moving the key by
---`-delta`, so nothing is transposed here; hand the result to `transpose`.
---@param pads Pad[]
---@param key integer 0-11
---@param mode integer 1-7
---@return integer delta -5..6 semitones; 0 when no move beats the pads as they are.
---@return integer in_key Pads in key after that move.
function M.best_fit(pads, key, mode)
  local best_delta, best = 0, -1
  for _, delta in ipairs(FIT_MOVES) do
    local in_key = M.fit(pads, (key - delta) % 12, mode)
    if in_key > best then
      best_delta, best = delta, in_key
    end
  end
  return best_delta, best
end

---Flatten pads into five plain number lists (what the preferences store).
---@param pads Pad[]
---@return integer[] roots, integer[] types, integer[] inversions, integer[] octaves, integer[] basses
function M.to_lists(pads)
  local roots, types, inversions, octaves, basses = {}, {}, {}, {}, {}
  for i = 1, M.COUNT do
    local pad = M.normalize(pads[i])
    roots[i], types[i], inversions[i], octaves[i] = pad.root, pad.type, pad.inversion, pad.octave
    basses[i] = pad.bass
  end
  return roots, types, inversions, octaves, basses
end

---Rebuild pads from the number lists. Always returns `COUNT` pads; missing or
---invalid entries become empty pads. Without a bass list (preferences from
---before slash basses) no pad has a slash bass.
---@param roots integer[]
---@param types integer[]
---@param inversions integer[]
---@param octaves integer[]
---@param basses integer[]?
---@return Pad[]
function M.from_lists(roots, types, inversions, octaves, basses)
  basses = basses or {}
  local pads = {}
  for i = 1, M.COUNT do
    pads[i] = M.normalize {
      root = roots[i],
      type = types[i],
      inversion = inversions[i],
      octave = octaves[i],
      bass = basses[i],
    }
  end
  return pads
end

---Notes a pad plays, lowest first.
---@param pad Pad
---@param style integer? voicing.CLOSE, OPEN or WIDE; default voicing.DEFAULT
---@return integer[]
function M.notes(pad, style)
  if M.is_empty(pad) then
    return {}
  end
  return voicing.notes(pad, style)
end

---Analyse a pad against a key; a slash bass outside the key takes the pad out of it.
---@param pad Pad
---@param key integer 0-11
---@param mode integer 1-7
---@return ChordAnalysis
function M.analyze(pad, key, mode)
  local bass = voicing.has_bass(pad) and pad.bass or nil
  return theory.analyze(pad.root, pad.type, key, mode, bass)
end

---@alias PadFunction "in_key"|"borrowed"|"out"|"empty"

---Display strings for a pad in the given key. The name shows the bass after
---a slash when the lowest note is not the root ("C/E", "F/G").
---@param pad Pad
---@param key integer 0-11
---@param mode integer 1-7
---@return string name, string numeral, PadFunction func
function M.label(pad, key, mode)
  if M.is_empty(pad) then
    return "", "", "empty"
  end
  local analysis = M.analyze(pad, key, mode)
  -- Flattened degrees (bVII, bIII...) read as flats whatever the key prefers.
  local flats = theory.prefers_flats(key, mode) or analysis.numeral:sub(1, 1) == "b"
  local name = theory.chord_name(pad.root, pad.type, flats)
  local bass = voicing.bass_pc(pad)
  if bass ~= pad.root then
    -- the bass is spelled like the root, so a name never mixes C# and Ab
    name = name .. "/" .. theory.note_name(bass, flats)
  end
  return name, analysis.numeral, analysis.func
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
