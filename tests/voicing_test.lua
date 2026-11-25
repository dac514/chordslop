local t = require "tests.helper"
local voicing = require "src.voicing"
local theory = require "src.theory"

local function list(xs)
  return table.concat(xs, ",")
end
local function pad(root, id, inversion, octave, bass)
  return {
    root = root,
    type = assert(theory.type_index(id), id),
    inversion = inversion or 0,
    octave = octave or 4,
    bass = bass or -1,
  }
end
local function has_pc(notes, pc, from)
  for i = from or 1, #notes do
    if notes[i] % 12 == pc then
      return true
    end
  end
  return false
end

t.eq(voicing.style(nil), voicing.DEFAULT, "missing style -> default")
t.eq(voicing.style(9), voicing.DEFAULT, "invalid style -> default")
t.eq(voicing.style(1), voicing.CLOSE, "close style")
t.eq(#voicing.notes { root = 0, type = 0, inversion = 0, octave = 4 }, 0, "empty pad")

-- Close is the chord stacked from the root, as before
for i = 1, #theory.CHORD_TYPES do
  for inv = 0, 3 do
    local p = { root = 2, type = i, inversion = inv, octave = 4 }
    t.eq(
      list(voicing.notes(p, voicing.CLOSE)),
      list(theory.build_notes(2, i, inv, 4)),
      ("close %s inversion %d"):format(theory.CHORD_TYPES[i].id, inv)
    )
  end
end
t.eq(list(voicing.notes(pad(5, "maj", 0, 4, 7), voicing.CLOSE)), "43,53,57,60", "close F/G")

-- Open: Cm is C-3 bass, then G-4 C-5 D#5 (what Cubase plays)
t.eq(list(voicing.notes(pad(0, "min"), voicing.OPEN)), "36,55,60,63", "open Cm")
t.eq(list(voicing.notes(pad(7, "min"), voicing.OPEN)):sub(1, 3), "43,", "open Gm bass")
local g13 = voicing.notes(pad(7, "13"), voicing.OPEN)
t.eq(g13[1], 43, "G13 bass")
t.check(not has_pc(g13, 7, 2), "G13 leaves the root out above the bass")
t.check(not has_pc(g13, 2, 2), "G13 leaves the fifth out")
t.eq(#g13, 5, "G13: bass and four upper notes")
local cmaj7 = voicing.notes(pad(0, "maj7"), voicing.OPEN)
t.check(not has_pc(cmaj7, 0, 2), "Cmaj7 leaves the root to the bass")
t.eq(#cmaj7, 4, "Cmaj7: bass and three upper notes")
local first = voicing.notes(pad(0, "maj7", 1), voicing.OPEN)
t.eq(first[1] % 12, 4, "first inversion puts the third in the bass")
t.check(has_pc(first, 0, 2), "Cmaj7/E keeps the root above")
t.check(not has_pc(first, 4, 2), "Cmaj7/E does not double the third")
local f_over_g = voicing.notes(pad(5, "maj", 0, 4, 7), voicing.OPEN)
t.eq(f_over_g[1], 43, "F/G: the slash bass is lowest")
t.eq(#f_over_g, 4, "F/G: bass and the triad")
local fmaj7_g = voicing.notes(pad(5, "maj7", 0, 4, 7), voicing.OPEN)
t.check(not has_pc(fmaj7_g, 0, 2), "Fmaj7/G leaves out the fifth")
t.check(has_pc(fmaj7_g, 5, 2), "Fmaj7/G keeps its root")
local power = voicing.notes(pad(0, "5"), voicing.OPEN)
t.eq(#power, 4, "power chord: bass and three upper notes")
for _, n in ipairs(power) do
  t.check(n % 12 == 0 or n % 12 == 7, "power chord has only root and fifth")
end

-- every type and root: bass in the octave below, top near the target, in order
for i = 1, #theory.CHORD_TYPES do
  for root = 0, 11 do
    for inv = 0, 3 do
      local p = { root = root, type = i, inversion = inv, octave = 4 }
      local notes = voicing.notes(p, voicing.OPEN)
      local what = ("open %s root %d inv %d: %s"):format(
        theory.CHORD_TYPES[i].id,
        root,
        inv,
        list(notes)
      )
      t.check(notes[1] >= 36 and notes[1] <= 47, what .. " bass in C-3..B-3")
      t.eq(notes[1] % 12, voicing.bass_pc(p), what .. " bass pitch class")
      -- three notes a tone apart (A B C#) can only come within 4 of the target,
      -- and avoiding a semitone on top can cost one more
      t.check(math.abs(notes[#notes] - voicing.TARGET_TOP) <= 5, what .. " top near target")
      t.check(notes[#notes] - notes[#notes - 1] >= 2, what .. " no semitone on top")
      t.check(notes[2] - notes[1] >= voicing.MIN_GAP, what .. " upper notes clear of the bass")
      for k = 2, #notes do
        t.check(notes[k] > notes[k - 1], what .. " ascending")
      end
      local wide = voicing.notes(p, voicing.WIDE)
      t.eq(wide[1], notes[1], what .. " wide has the same bass")
      t.check(#wide > #notes, what .. " wide has more notes")
      for k = 2, #wide do
        t.check(wide[k] > wide[k - 1], what .. " wide ascending")
      end
    end
  end
end

-- extended chords avoid a semitone on top: G13 is F A B E, Dm9 is F A C E
t.eq(list(voicing.notes(pad(7, "13"), voicing.OPEN)), "43,53,57,59,64", "open G13")
t.eq(list(voicing.notes(pad(2, "m9"), voicing.OPEN)), "38,53,57,60,64", "open Dm9")

-- the octave moves everything; at the ends of the range the chord moves by octaves
local up = voicing.notes(pad(0, "min", 0, 5), voicing.OPEN)
t.eq(list(up), "48,67,72,75", "octave 5 is an octave higher")
for _, octave in ipairs { 0, 9 } do
  for style = 1, 3 do
    for i = 1, #theory.CHORD_TYPES do
      for _, n in ipairs(voicing.notes(pad(11, theory.CHORD_TYPES[i].id, 3, octave), style)) do
        t.check(n >= theory.MIN_NOTE and n <= theory.MAX_NOTE, "in range at octave " .. octave)
      end
    end
  end
end

-- Wide: the fifth and the octave above the bass
t.eq(list(voicing.notes(pad(0, "maj"), voicing.WIDE)), "36,43,48,55,60,64", "wide C")

-- every pad that can exist: notes ascend, stay in range, never repeat, and
-- the lowest note is the bass pitch class, even at octaves 0 and 9
local bad = {}
local function fail(what)
  if #bad < 10 then
    bad[#bad + 1] = what
  end
end
local count = 0
for style = 1, #voicing.STYLES do
  for type_index = 1, #theory.CHORD_TYPES do
    for root = 0, 11 do
      for inversion = 0, 3 do
        for bass = -1, 11 do
          for octave = 0, 9 do
            count = count + 1
            local p = {
              root = root,
              type = type_index,
              inversion = inversion,
              octave = octave,
              bass = bass,
            }
            local notes = voicing.notes(p, style)
            local what = ("%s %s root %d inv %d bass %d oct %d: %s"):format(
              voicing.STYLES[style],
              theory.CHORD_TYPES[type_index].id,
              root,
              inversion,
              bass,
              octave,
              list(notes)
            )
            if #notes < 2 then
              fail(what .. " too few notes")
            end
            for k, n in ipairs(notes) do
              if n < theory.MIN_NOTE or n > theory.MAX_NOTE then
                fail(what .. " out of range")
              end
              if k > 1 and n <= notes[k - 1] then
                fail(what .. " not ascending")
              end
            end
            if #notes > 12 then
              fail(what .. " more notes than note columns")
            end
            if notes[1] % 12 ~= voicing.bass_pc(p) then
              fail(what .. " lowest note is not the bass")
            end
          end
        end
      end
    end
  end
end
t.check(#bad == 0, ("%d pads, all sound: %s"):format(count, table.concat(bad, "; ")))

t.done()
