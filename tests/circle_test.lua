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

t.eq(circle.target_rotation(0), 0, "C needs no rotation")
t.eq(circle.target_rotation(7), -30, "G rotates one step counter-clockwise")
t.eq(circle.target_rotation(5), -330, "F rotates eleven steps")

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

local outer, inner = circle.ring_chords(0, 1)
t.eq(outer[1].numeral, "I", "C major is I")
t.eq(outer[2].numeral, "V", "G major is V")
t.eq(outer[12].numeral, "IV", "F major is IV")
t.eq(outer[3].numeral, nil, "D major not diatonic in C")
t.eq(outer[3].in_key, false, "D major out of key")
t.eq(inner[1].numeral, "vi", "A minor is vi")
t.eq(inner[2].numeral, "iii", "E minor is iii")
t.eq(inner[3].numeral, "vii°", "B is the diminished degree")
t.eq(theory.CHORD_TYPES[inner[3].type].id, "dim", "inner ring shows B dim")
t.eq(inner[12].numeral, "ii", "D minor is ii")
t.eq(inner[4].in_key, false, "F# minor out of key")
t.eq(outer[11].flats, true, "Bb side of the circle spells flats in C")
t.eq(outer[2].flats, false, "G side spells sharps in C")
t.eq(outer[7].flats, false, "tritone from C spells F# (C prefers sharps)")
local fo = circle.ring_chords(5, 1)
t.eq(fo[6].flats, true, "tritone from F spells flats (F prefers flats)")
t.eq(fo[12].flats, false, "the tonic itself is not flat-side")
t.eq(fo[1].flats, false, "C is on the sharp side of F")
local maj_t = assert(theory.type_index "maj")
local min_t = assert(theory.type_index "min")
local dim_t = assert(theory.type_index "dim")
local r1, k1 = circle.ring_for_pad { root = 7, type = maj_t, inversion = 0, octave = 4 }
t.eq(r1 .. k1, "outer1", "G major maps to the outer ring at G")
local r2, k2 = circle.ring_for_pad { root = 9, type = min_t, inversion = 0, octave = 4 }
t.eq(r2 .. k2, "inner0", "A minor maps to the inner ring under C")
local r3, k3 = circle.ring_for_pad { root = 11, type = dim_t, inversion = 0, octave = 4 }
t.eq(r3 .. k3, "inner2", "B dim maps to the inner ring under D")
local r4, k4 = circle.ring_for_pad {
  root = 0,
  type = assert(theory.type_index "dom7"),
  inversion = 0,
  octave = 4,
}
t.eq(r4 .. k4, "outer0", "C7 maps to the outer ring at C")

t.done()
