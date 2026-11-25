--[[
  Voicing: which notes a pad plays. Pure Lua (`tests/voicing_test.lua`).

  Close  the chord stacked from its root, as ChordSlop always played it. The
         inversion moves the lowest tones up an octave. A slash bass adds one
         note an octave below the root.
  Open   a single bass note an octave below the pad octave (C-3..B-3 at octave
         4), and above it the chord in close position in a fixed register.
         Chords of four or more tones leave out the tone the bass already
         plays, and chords of six tones also leave out the fifth. Because
         every pad puts its top note as close as it can to the same target,
         the top voice moves only a little from pad to pad, with no memory
         of the chord before.
  Wide   like Open, with the fifth (when it is a chord tone) and the octave
         above the bass: a bigger sound for pads and strings.

  The bass is the slash bass of the pad when it has one; otherwise the chord
  tone that the inversion puts lowest (0 root, 1 third, 2 fifth, 3 seventh).
  The notes depend on the pad alone, so playing, recording and the editor
  always agree.
]]

local theory = require "src.theory"

local M = {}

M.CLOSE = 1
M.OPEN = 2
M.WIDE = 3

---Style names by index, for the voicing switch and the preferences.
---@type string[]
M.STYLES = { "Close", "Open", "Wide" }

M.DEFAULT = M.OPEN

---The note the top voice aims at for a pad in octave 4 (F-5). Each octave
---up or down moves it by 12.
M.TARGET_TOP = 65

---Fewest semitones between the bass and the lowest upper note.
M.MIN_GAP = 5

---Wide: fewest semitones between the octave above the bass and the upper notes.
M.WIDE_GAP = 3

---@param value integer
---@return integer
local function clamp_note(value)
  return math.max(theory.MIN_NOTE, math.min(theory.MAX_NOTE, value))
end

---@param list integer[]
---@param value integer
---@return boolean
local function has(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

---Pitch classes of the chord, in the order of its intervals, without repeats.
---@param root integer
---@param type_index integer
---@return integer[]
local function chord_tones(root, type_index)
  local tones = {}
  for _, interval in ipairs(theory.CHORD_TYPES[type_index].intervals) do
    local pc = (root + interval) % 12
    if not has(tones, pc) then
      tones[#tones + 1] = pc
    end
  end
  return tones
end

---Does the pad have a slash bass?
---@param pad Pad
---@return boolean
function M.has_bass(pad)
  return type(pad.bass) == "number" and pad.bass >= 0
end

---Pitch class of the lowest note: the slash bass, or the chord tone that the
---inversion puts lowest.
---@param pad Pad
---@return integer
function M.bass_pc(pad)
  if M.has_bass(pad) then
    return pad.bass % 12
  end
  local intervals = theory.CHORD_TYPES[pad.type].intervals
  local inversion = math.max(0, math.min(pad.inversion or 0, #intervals - 1))
  return (pad.root + intervals[inversion + 1]) % 12
end

---Remove one pitch class from a list (in place).
---@param list integer[]
---@param pc integer
local function remove(list, pc)
  for i, v in ipairs(list) do
    if v == pc then
      table.remove(list, i)
      return
    end
  end
end

---The pitch classes above the bass in the Open style.
---@param tones integer[] chord tones, root first
---@param root integer
---@param bass integer
---@return integer[]
local function open_upper(tones, root, bass)
  local upper = {}
  for i, pc in ipairs(tones) do
    upper[i] = pc
  end
  local fifth = (root + 7) % 12
  if #tones >= 4 then
    if has(tones, bass) then
      remove(upper, bass)
    else
      remove(upper, fifth)
    end
  end
  if #tones >= 6 and fifth ~= bass then
    remove(upper, fifth)
  end
  return upper
end

---Place a set of pitch classes in close position with the top note as near
---the target as it can be, and the lowest note at or above `floor`. Every
---rotation is tried in every octave; the nearest top note wins and a tie
---goes to the lower voicing.
---@param pcs integer[] distinct pitch classes
---@param target integer
---@param floor integer
---@return integer[] notes ascending
local function place(pcs, target, floor)
  local sorted = {}
  for i, pc in ipairs(pcs) do
    sorted[i] = pc
  end
  table.sort(sorted)
  local best, best_dist
  for start = 1, #sorted do
    local notes = {}
    for k = 0, #sorted - 1 do
      local pc = sorted[((start - 1 + k) % #sorted) + 1]
      if k == 0 then
        notes[1] = pc
      else
        notes[#notes + 1] = notes[#notes] + ((pc - notes[#notes]) % 12)
      end
    end
    local top = notes[#notes]
    local shift = math.floor((target - top) / 12 + 0.5) * 12
    for octave = shift - 24, shift + 24, 12 do
      local low = notes[1] + octave
      local dist = math.abs(top + octave - target)
      if
        low >= floor
        and (not best_dist or dist < best_dist or (dist == best_dist and low < best[1]))
      then
        best, best_dist = {}, dist
        for i, n in ipairs(notes) do
          best[i] = n + octave
        end
      end
    end
  end
  return best
end

---Notes of a pad in the Close style.
---@param pad Pad
---@return integer[]
local function close(pad)
  local notes = theory.build_notes(pad.root, pad.type, pad.inversion or 0, pad.octave)
  if M.has_bass(pad) then
    table.insert(notes, 1, clamp_note((pad.octave - 1) * 12 + pad.bass % 12))
  end
  return notes
end

---@param pad Pad
---@param wide boolean
---@return integer[]
local function open(pad, wide)
  local tones = chord_tones(pad.root, pad.type)
  local bass_pc = M.bass_pc(pad)
  local bass = (pad.octave - 1) * 12 + bass_pc
  local target = M.TARGET_TOP + (pad.octave - 4) * 12
  local out = { bass }
  local floor = bass + M.MIN_GAP
  if wide then
    -- the fifth above the bass when it belongs to the chord, then the octave
    if has(tones, (bass_pc + 7) % 12) then
      out[#out + 1] = bass + 7
    end
    out[#out + 1] = bass + 12
    floor = bass + 12 + M.WIDE_GAP
  end
  local notes
  if #tones <= 2 then
    -- power chord: root and fifth, and the top note again an octave lower
    -- (or, when that would crowd the bass, the lowest note an octave higher)
    notes = place(tones, target, floor)
    if notes[#notes] - 12 >= floor then
      table.insert(notes, 1, notes[#notes] - 12)
    else
      notes[#notes + 1] = notes[1] + 12
    end
  else
    notes = place(open_upper(tones, pad.root, bass_pc), target, floor)
  end
  for _, n in ipairs(notes) do
    out[#out + 1] = n
  end
  for i, n in ipairs(out) do
    out[i] = clamp_note(n)
  end
  table.sort(out)
  -- clamping at the ends of the range can stack notes: drop repeats
  local unique = {}
  for _, n in ipairs(out) do
    if n ~= unique[#unique] then
      unique[#unique + 1] = n
    end
  end
  return unique
end

---Notes a pad plays in a voicing style, ascending.
---@param pad Pad
---@param style integer? M.CLOSE, M.OPEN or M.WIDE; default M.DEFAULT
---@return integer[]
function M.notes(pad, style)
  if not pad.type or pad.type == 0 then
    return {}
  end
  style = style or M.DEFAULT
  if style == M.CLOSE then
    return close(pad)
  end
  return open(pad, style == M.WIDE)
end

---Normalise a stored style index.
---@param value any
---@return integer
function M.style(value)
  if type(value) == "number" and value >= 1 and value <= #M.STYLES then
    return math.floor(value)
  end
  return M.DEFAULT
end

return M
