local t = require "tests.helper"
local theory = require "src.theory"

local function list(xs)
  return table.concat(xs, ",")
end

-- chord types
t.eq(theory.type_index "min7", 8, "type_index min7")
t.eq(theory.type_index "nope", nil, "type_index unknown")

-- build_notes
t.eq(
  list(theory.build_notes(0, assert(theory.type_index "maj"), 0, 4)),
  "48,52,55",
  "C major root position at C-4"
)
t.eq(
  list(theory.build_notes(0, assert(theory.type_index "maj"), 1, 4)),
  "52,55,60",
  "C major first inversion"
)
t.eq(
  list(theory.build_notes(0, assert(theory.type_index "maj"), 2, 4)),
  "55,60,64",
  "C major second inversion"
)
t.eq(
  list(theory.build_notes(0, assert(theory.type_index "maj"), 3, 4)),
  "55,60,64",
  "inversion clamps to chord size"
)
t.eq(
  list(theory.build_notes(2, assert(theory.type_index "min7"), 0, 4)),
  "50,53,57,60",
  "Dm7 at octave 4"
)
t.eq(
  list(theory.build_notes(11, assert(theory.type_index "maj7"), 0, 9)),
  "119,119,119,119",
  "clamped at 119"
)
t.eq(
  list(theory.build_notes(0, assert(theory.type_index "5"), 0, 0)),
  "0,7",
  "power chord at octave 0"
)

-- scales
t.eq(list(theory.scale(0, 1)), "0,2,4,5,7,9,11", "C Ionian")
t.eq(list(theory.scale(9, 6)), "9,11,0,2,4,5,7", "A Aeolian")
t.eq(list(theory.scale(2, 2)), "2,4,5,7,9,11,0", "D Dorian")
t.eq(theory.degree_of(7, 0, 1), 5, "G is degree 5 in C")
t.eq(theory.degree_of(6, 0, 1), nil, "F# not in C major")

-- relative major / flats
t.eq(theory.relative_major(9, 6), 0, "A minor relative major is C")
t.eq(theory.relative_major(2, 2), 0, "D Dorian relative major is C")
t.eq(theory.relative_major(0, 1), 0, "C major relative major is C")
t.eq(theory.relative_major(11, 7), 0, "B Locrian relative major is C")
t.eq(theory.prefers_flats(5, 1), true, "F major uses flats")
t.eq(theory.prefers_flats(7, 1), false, "G major uses sharps")
t.eq(theory.prefers_flats(7, 6), true, "G minor (Bb major) uses flats")
t.eq(theory.note_name(10, true), "Bb", "flat spelling")
t.eq(theory.note_name(10, false), "A#", "sharp spelling")

-- diatonic chords in C major: I ii iii IV V vi vii°
local expect_triads = { "maj", "min", "min", "maj", "maj", "min", "dim" }
for degree, id in ipairs(expect_triads) do
  local root, idx = theory.diatonic_chord(0, 1, degree, false)
  t.eq(theory.CHORD_TYPES[idx].id, id, "C major triad degree " .. degree)
  t.eq(root, theory.scale(0, 1)[degree], "C major triad root degree " .. degree)
end
local expect_sevenths = { "maj7", "min7", "min7", "maj7", "dom7", "min7", "m7b5" }
for degree, id in ipairs(expect_sevenths) do
  local _, idx = theory.diatonic_chord(0, 1, degree, true)
  t.eq(theory.CHORD_TYPES[idx].id, id, "C major seventh degree " .. degree)
end
-- every mode produces only known chord types
for mode = 1, 7 do
  for degree = 1, 7 do
    t.check(pcall(theory.diatonic_chord, 5, mode, degree, true), "diatonic seventh mode " .. mode)
  end
end

-- analysis
local function an(root, id, key, mode)
  local a = theory.analyze(root, assert(theory.type_index(id)), key, mode)
  return a.numeral .. "|" .. a.func
end
t.eq(an(0, "maj", 0, 1), "I|in_key", "C in C")
t.eq(an(2, "min", 0, 1), "ii|in_key", "Dm in C")
t.eq(an(7, "dom7", 0, 1), "V7|in_key", "G7 in C")
t.eq(an(11, "dim", 0, 1), "vii°|in_key", "Bdim in C")
t.eq(an(11, "m7b5", 0, 1), "viiø7|in_key", "Bm7b5 in C")
t.eq(an(10, "maj", 0, 1), "bVII|borrowed", "Bb in C is borrowed from C minor")
t.eq(an(2, "maj", 0, 1), "II|borrowed", "D major in C: root in key, tone out")
t.eq(an(1, "maj", 0, 1), "bII|out", "Db major in C is out")
t.eq(an(9, "min", 9, 6), "i|in_key", "Am in A minor")
t.eq(an(7, "maj", 9, 6), "VII|in_key", "G in A minor is diatonic VII")
t.eq(an(4, "maj", 9, 6), "V|borrowed", "E major in A minor (harmonic) is borrowed")
t.eq(an(0, "aug", 0, 1), "I+|borrowed", "Caug in C")
t.eq(theory.chord_name(2, assert(theory.type_index "min7"), false), "Dm7", "chord_name")
t.eq(theory.chord_name(10, assert(theory.type_index "maj"), true), "Bb", "chord_name flats")

t.done()
