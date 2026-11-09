local t = require "tests.helper"
local circle = require "src.circle"
local theory = require "src.theory"

local function near(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-9)
end

t.eq(circle.position_of(0), 0, "C at position 0")
t.eq(circle.position_of(7), 1, "G at position 1")
t.eq(circle.position_of(5), 11, "F at position 11")
t.eq(circle.major_at(13), 7, "major_at wraps")
t.eq(circle.minor_at(0), 9, "relative minor of C is A")
t.eq(circle.minor_at(1), 4, "relative minor of G is E")

local L = circle.layout(340)
local o = circle.origin(L, 0, "outer", 0)
t.eq(o.x, math.floor(L.cx - L.btn_w / 2 + 0.5), "C label centred horizontally")
t.eq(o.y, math.floor(L.cy - L.r_outer - L.btn_h / 2 + 0.5), "C label at the top")
local east = circle.origin(L, 3, "outer", 0)
t.check(east.x > L.cx and near(east.y + L.btn_h / 2, L.cy, 1), "position 3 is at 3 o'clock")
local rotated = circle.origin(L, 1, "outer", -30)
t.eq(rotated.x, o.x, "rotation -30 puts G where C was (x)")
t.eq(rotated.y, o.y, "rotation -30 puts G where C was (y)")
local inner = circle.origin(L, 0, "inner", 0)
t.check(inner.y > o.y, "inner ring sits closer to the centre")
local c = circle.center_origin(L)
t.eq(c.x, math.floor(L.cx - L.center_w / 2 + 0.5), "center x")

t.eq(circle.target_rotation(0, 1), 0, "C major needs no rotation")
t.eq(circle.target_rotation(7, 1), -30, "G major rotates one step counter-clockwise")
t.eq(circle.target_rotation(5, 1), -330, "F major rotates eleven steps")
t.eq(circle.target_rotation(9, 6), 0, "A minor sits under C, at the top")
t.eq(circle.target_rotation(0, 6), -270, "C minor sits under Eb")
t.eq(circle.target_rotation(0, 2), -270, "C Dorian: Cm sits under Eb")
local tr, tk = circle.tonic_slot(0, 7)
t.eq(tr .. tk, "inner9", "C Locrian: C dim sits on the inner ring under Eb")

t.eq(circle.shortest_delta(350, 10), 20, "delta wraps forward")
t.eq(circle.shortest_delta(10, 350), -20, "delta wraps backward")
t.eq(circle.shortest_delta(0, 180), 180, "half turn is positive")
t.eq(circle.shortest_delta(0, -330), 30, "F from C goes the short way")

t.eq(circle.ease(0), 0, "ease start")
t.eq(circle.ease(1), 1, "ease end")
t.check(near(circle.ease(0.5), 0.5), "ease midpoint")
local last = 0
local monotonic = true
for i = 1, 20 do
  local v = circle.ease(i / 20)
  if v < last then
    monotonic = false
  end
  last = v
end
t.check(monotonic, "ease is monotonic")
t.eq(circle.tween(0, 90, 12, 12), 90, "tween ends at target")
t.eq(circle.tween(0, 90, 0, 12), 0, "tween starts at origin")
t.eq(circle.tween(0, 90, 5, 0), 90, "zero frames jumps")

t.eq(circle.diatonic_span(0, 1), 11, "C Ionian span starts at F")
t.eq(circle.diatonic_span(0, 4), 0, "C Lydian span starts at C")
t.eq(circle.diatonic_span(9, 6), 11, "A Aeolian span starts at F")
t.eq(circle.diatonic_span(0, 7), 6, "C Locrian span starts at F#")
local a0, a1 = circle.span_arc_deg(11)
t.eq(a0, 315, "wedge start")
t.eq(a1, 525, "wedge end covers seven positions")
t.eq(circle.wedge_deg(0, 1), 330, "C Ionian wedge starts at F (330 degrees)")
t.eq(circle.wedge_deg(0, 4), 0, "C Lydian wedge starts at C")
local w0, w1 = circle.wedge_arc_deg(90)
t.eq(w0, 75, "wedge arc start from a free angle")
t.eq(w1, 285, "wedge arc end from a free angle")

-- Levels of the ring slots, counted in columns from the first home column.
t.eq(circle.slot_level(0, "outer", 1), "home", "first home column")
t.eq(circle.slot_level(2, "outer", 1), "home", "third home column")
t.eq(circle.slot_level(3, "inner", 1), "home", "diminished slot is home")
t.eq(circle.slot_level(3, "outer", 1), "near", "column after the window is near")
t.eq(circle.slot_level(11, "outer", 1), "near", "column before the window is near (outer)")
t.eq(circle.slot_level(11, "inner", 1), "near", "column before the window is near (inner)")
t.eq(circle.slot_level(4, "inner", 1), "far", "inner slot after the diminished one is far")
t.eq(circle.slot_level(5, "outer", 1), "far", "fifth column is far in major")
t.eq(circle.slot_level(5, "outer", 6), "home", "the major V is home in minor")
t.eq(circle.slot_level(-1, "outer", 1), "near", "negative columns wrap")

local function suffix(c)
  local id = theory.CHORD_TYPES[c.type].id
  return id == "min" and "m" or id == "dim" and "°" or ""
end
---@return string home, string near
local function levels(key, mode)
  local o, i = circle.ring_chords(key, mode)
  local out = { home = {}, near = {}, far = {} }
  for _, ring in ipairs { o, i } do
    for k = 1, 12 do
      local c = ring[k]
      table.insert(out[c.level], theory.note_name(c.root, c.flats) .. suffix(c))
    end
  end
  return table.concat(out.home, " "), table.concat(out.near, " ")
end
local home, nearby = levels(0, 1)
t.eq(home, "C G F Am Em B° Dm", "C major home")
t.eq(nearby, "D Bb Gm", "C major next door")
home, nearby = levels(0, 6)
t.eq(home, "G Ab Eb Bb Fm Cm Gm D°", "C minor home, with the major V")
t.eq(nearby, "Db F Bbm", "C minor next door")
home, nearby = levels(9, 6)
t.eq(home, "C G E F Am Em B° Dm", "A minor home: the chords of C major plus E")

local outer, inner = circle.ring_chords(0, 1)
t.eq(outer[1].numeral, "I", "C major is I")
t.eq(outer[2].numeral, "V", "G major is V")
t.eq(outer[12].numeral, "IV", "F major is IV")
t.eq(outer[3].numeral, "II", "D major in C has a numeral")
t.eq(outer[7].numeral, "bV", "chords far from home keep their numeral")
t.eq(inner[1].numeral, "vi", "A minor is vi")
t.eq(inner[2].numeral, "iii", "E minor is iii")
t.eq(inner[3].numeral, "vii°", "B is the diminished degree")
t.eq(theory.CHORD_TYPES[inner[3].type].id, "dim", "inner ring shows B dim")
t.eq(inner[12].numeral, "ii", "D minor is ii")
t.eq(#outer[1].outside, 0, "C major has no note outside C")
t.eq(outer[3].outside[1], 6, "D major in C uses F#")
t.eq(circle.ring_tooltip(outer[1]), "I: in the key.", "home tooltip")
t.eq(
  circle.ring_tooltip(outer[3]),
  "II: next door. One step from the key, it changes one note: F#.",
  "near tooltip"
)
t.eq(
  circle.ring_tooltip(outer[9]),
  "bVI: far from home. It uses Ab and Eb.",
  "far tooltip spells flats on the flat side"
)
local cmin_outer = circle.ring_chords(0, 6)
t.eq(
  circle.ring_tooltip(cmin_outer[2]),
  "V: home in minor. The usual dominant, with B from harmonic minor.",
  "minor dominant tooltip"
)
t.eq(outer[11].flats, true, "Bb side of the circle spells flats in C")
t.eq(outer[2].flats, false, "G side spells sharps in C")
t.eq(outer[7].flats, false, "tritone from C spells F# (C prefers sharps)")
local fo = circle.ring_chords(5, 1)
t.eq(fo[6].flats, true, "tritone from F spells flats (F prefers flats)")
t.eq(fo[12].flats, false, "the tonic itself is not flat-side")
t.eq(fo[1].flats, false, "C is on the sharp side of F")

---@return Pad
local function pad(root, id)
  return { root = root, type = assert(theory.type_index(id)), inversion = 0, octave = 4 }
end
local function slot(p, key, mode)
  local ring, k = circle.ring_for_pad(p, key, mode)
  return ring .. k
end
t.eq(slot(pad(7, "maj"), 0, 1), "outer1", "G major maps to the outer ring at G")
t.eq(slot(pad(9, "min"), 0, 1), "inner0", "A minor maps to the inner ring under C")
t.eq(slot(pad(11, "dim"), 0, 1), "inner2", "B dim maps to the inner ring under D")
t.eq(slot(pad(0, "dom7"), 0, 1), "outer0", "C7 maps to the outer ring at C")
t.eq(slot(pad(2, "5"), 0, 1), "inner11", "D5 in C major lights Dm")
t.eq(slot(pad(2, "5"), 2, 1), "outer2", "D5 in D major lights D")
t.eq(slot(pad(7, "sus4"), 0, 1), "outer1", "Gsus4 in C major: both are home, outer wins")

t.eq(circle.pad_level(pad(2, "5"), 0, 1), "home", "D5 is home in C major")
t.eq(circle.pad_level(pad(4, "5"), 0, 1), "home", "E5 is home in C major")
t.eq(circle.pad_level(pad(2, "maj"), 0, 1), "near", "D major is next door in C major")
t.eq(circle.pad_level(pad(2, "dom7"), 0, 1), "near", "D7 is next door in C major")
t.eq(circle.pad_level(pad(11, "min"), 0, 1), "near", "Bm on the B° slot is only next door")
t.eq(circle.pad_level(pad(8, "maj"), 0, 1), "far", "Ab is far from C major")
t.eq(circle.pad_level(pad(7, "dom7"), 0, 6), "home", "G7 is home in C minor")
t.eq(circle.pad_level(pad(7, "maj7"), 0, 6), "near", "Gmaj7 on the V slot of C minor is near")
t.eq(circle.pad_level(pad(2, "5"), 0, 6), "near", "D5 in C minor: A is not in the key")

t.done()
