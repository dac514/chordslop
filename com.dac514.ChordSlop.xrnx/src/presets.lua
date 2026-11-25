--[[
  Presets: 4x4 chord palettes written as scale degrees, so they render into
  any key and mode. Every factory preset stays inside its key (minor presets
  may use the harmonic-minor V), which `tests/presets_test.lua` enforces, so
  loading one always gives chords that belong together. No two pads of a
  factory preset play the same notes, in any key; the same test enforces
  that. A row may spell a progression, and a chord that returns uses another
  inversion or octave. A pad stays empty when the set of chords is complete.
  Factory presets live here; the user's own are captured from the pads in the
  same relative form (see `capture`) and stored by `src/store.lua`. Pure Lua.

  A pad spec is a small table:
    d  scale degree 1-7 (required)
    a  accidental on the root: -1 flat, +1 sharp (default 0)
    t  chord type id from theory.CHORD_TYPES (default: the diatonic triad,
       or major when the root is altered)
    s  true for the diatonic seventh instead of the triad
    x  9, 11 or 13 for the diatonic ninth, eleventh or thirteenth chord
       (thirds stacked in the key, so they follow the mode like `s`; when
       the mode has no chord type for that stack, the seventh plays)
    i  inversion 0-3 (default 0): which chord tone is lowest
    o  octave offset (default 0): 0 puts the root where it lands in C
       (octave 4), moved by `pads.key_offset(key)`, so up from the tonic
    b  scale degree 1-7 of a slash bass (default: none, the inversion decides)
    ba accidental on the slash bass: -1 flat, +1 sharp (default 0)
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
---@field x integer? Diatonic extension: 9, 11 or 13.
---@field i integer? Inversion.
---@field o integer? Octave offset.
---@field b integer? Scale degree of a slash bass.
---@field ba integer? Accidental on the slash bass.

---@class Preset
---@field name string
---@field legacy_octaves boolean? A user preset saved by an older ChordSlop: `o` is from octave 4, whatever the key.
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
    desc = "The four-chord loop, then the same chords over a moving bass (C/E, G/B, F/G), ninths and add9s.",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 5 },
      { d = 6 },
      { d = 4 },
      { d = 1, i = 1 },
      { d = 5, i = 1 },
      { d = 6, i = 2 },
      { d = 4, b = 5 },
      { d = 1, x = 9 },
      { d = 5, t = "9sus4" },
      { d = 6, x = 9 },
      { d = 4, s = true },
      { d = 1, t = "sus2" },
      { d = 5, t = "add9" },
      { d = 6, t = "madd9" },
      { d = 4, t = "add9" },
    },
  },
  {
    name = "Songwriter steps",
    desc = "A bass line that walks one step at a time under the chords: I, V/7, vi, vi/5, IV, I/3, ii7.",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 5, i = 1 },
      { d = 6 },
      { d = 6, b = 5 },
      { d = 4 },
      { d = 1, i = 1 },
      { d = 2, s = true },
      { d = 5, t = "7sus4" },
      { d = 4, s = true },
      { d = 5, b = 4 },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 1, t = "add9" },
      { d = 2, i = 1 },
      { d = 5, t = "sus4" },
      { d = 5 },
    },
  },
  {
    name = "50s: I vi IV V",
    desc = "Doo-wop and ballad changes, with sixth chords, the ii substitute and a ninth on V.",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 4 },
      { d = 5 },
      { d = 1, t = "6" },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, s = true },
      { d = 2 },
      { d = 4, t = "6" },
      { d = 5, x = 9 },
      { d = 1, i = 2 },
      { d = 3, s = true },
      { d = 4, b = 5 },
      { d = 5, x = 13 },
    },
  },
  {
    name = "Canon: I V vi iii IV",
    desc = "The Pachelbel progression with its stepping bass (G/B, Em/G, C/E), then ninths and sevenths.",
    mode = MAJ,
    pads = {
      { d = 1 },
      { d = 5, i = 1 },
      { d = 6 },
      { d = 3, i = 1 },
      { d = 4 },
      { d = 1, i = 1 },
      { d = 2, s = true },
      { d = 5 },
      { d = 1, x = 9 },
      { d = 5, t = "9sus4" },
      { d = 6, x = 9 },
      { d = 3, s = true },
      { d = 4, s = true },
      { d = 1, i = 2 },
      { d = 4, b = 5 },
      { d = 5, s = true },
    },
  },
  {
    name = "Pluck over pedal",
    desc = "Chords over one held bass note on V, for plucks and arpeggiators, with ninths below.",
    mode = MAJ,
    pads = {
      { d = 4, b = 5 },
      { d = 2, b = 5 },
      { d = 1, i = 2 },
      { d = 6, b = 5 },
      { d = 3, i = 1 },
      { d = 5 },
      { d = 4, s = true, b = 5 },
      { d = 2, s = true, b = 5 },
      { d = 1, t = "add9" },
      { d = 4, t = "add9" },
      { d = 5, t = "add9" },
      { d = 6, t = "madd9" },
      { d = 1, x = 9 },
      { d = 4, t = "6add9" },
      { d = 5, t = "9sus4" },
      { d = 6, x = 9 },
    },
  },
  {
    name = "Jazz: ii V I",
    desc = "Ninths and thirteenths: the ii V I, the iii vi ii V turnaround, sus and eleventh colours.",
    mode = MAJ,
    pads = {
      { d = 2, x = 9 },
      { d = 5, x = 13 },
      { d = 1, x = 9 },
      { d = 1, t = "6add9" },
      { d = 3, s = true },
      { d = 6, x = 9 },
      { d = 2, x = 11 },
      { d = 5, x = 9 },
      { d = 4, s = true },
      { d = 7, s = true },
      { d = 3, t = "7sus4" },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, t = "9sus4" },
      { d = 1, s = true },
      { d = 4, x = 9 },
    },
  },
  {
    name = "Ninth floor jazz",
    desc = "Piano ninths round the key, with the bass on a chord tone on the last row.",
    mode = MAJ,
    pads = {
      { d = 1, x = 9 },
      { d = 6, x = 9 },
      { d = 2, x = 9 },
      { d = 5, x = 13 },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, x = 11 },
      { d = 5, t = "9sus4" },
      { d = 4, x = 9 },
      { d = 7, s = true },
      { d = 3, t = "7sus4" },
      { d = 5, x = 9 },
      { d = 1, t = "6add9" },
      { d = 4, t = "maj7#11" },
      { d = 2, x = 9, i = 2 },
      { d = 5, x = 13, i = 3 },
    },
  },
  {
    name = "Circle of sevenths",
    desc = "Down the circle of fifths inside the key (vi ii V I IV vii iii), with ninths and elevenths.",
    mode = MAJ,
    pads = {
      { d = 6, x = 9 },
      { d = 2, x = 9 },
      { d = 5, x = 13 },
      { d = 1, x = 9 },
      { d = 4, s = true },
      { d = 7, s = true },
      { d = 3, s = true },
      { d = 6, s = true },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 1, s = true },
      { d = 4, x = 9 },
      { d = 3, t = "7sus4" },
      { d = 6, x = 11 },
      { d = 2, x = 11 },
      { d = 5, t = "9sus4" },
    },
  },
  {
    name = "Bossa / latin",
    desc = "Major ninths, thirteenths, sixths and minor sixths that lean into each other.",
    mode = MAJ,
    pads = {
      { d = 1, x = 9 },
      { d = 2, x = 9 },
      { d = 5, x = 13 },
      { d = 1, t = "6add9" },
      { d = 6, x = 9 },
      { d = 2, t = "m6" },
      { d = 5, t = "9sus4" },
      { d = 5, s = true, i = 1 },
      { d = 4, t = "maj7#11" },
      { d = 4, t = "6add9" },
      { d = 3, s = true },
      { d = 7, s = true },
      { d = 1, s = true, i = 2 },
      { d = 2, s = true },
      { d = 5, x = 9 },
      { d = 6, s = true },
    },
  },
  {
    name = "Gospel / R&B",
    desc = "Lush ninths and elevenths, IV over V, IV over I and a thirteenth on the dominant.",
    mode = MAJ,
    pads = {
      { d = 1, x = 9 },
      { d = 3, s = true },
      { d = 6, x = 9 },
      { d = 2, x = 11 },
      { d = 5, x = 13 },
      { d = 1, t = "6add9" },
      { d = 4, b = 5 },
      { d = 5, t = "9sus4" },
      { d = 4, x = 9 },
      { d = 7, s = true },
      { d = 1, t = "add9", i = 1 },
      { d = 4, b = 1 },
      { d = 2, x = 9 },
      { d = 5, x = 9 },
      { d = 1, s = true, i = 1 },
      { d = 6, s = true, i = 2 },
    },
  },
  {
    name = "Neo-soul sevenths",
    desc = "Mellow major-key ninths and elevenths; the lower rows put other chord tones in the bass.",
    mode = MAJ,
    pads = {
      { d = 1, x = 9 },
      { d = 3, s = true },
      { d = 6, x = 11 },
      { d = 2, x = 9 },
      { d = 4, x = 9 },
      { d = 5, t = "9sus4" },
      { d = 3, t = "7sus4" },
      { d = 6, x = 9 },
      { d = 1, s = true, i = 2 },
      { d = 4, s = true, i = 1 },
      { d = 2, s = true, i = 1 },
      { d = 5, x = 13 },
      { d = 4, t = "6add9" },
      { d = 3, s = true, i = 2 },
      { d = 6, s = true },
      { d = 2, x = 11 },
    },
  },
  {
    name = "Elevenths after dark",
    desc = "Minor elevenths and major ninths for neo-soul and late-night keys, with VI over VII.",
    mode = MIN,
    pads = {
      { d = 1, x = 11 },
      { d = 6, x = 9 },
      { d = 4, x = 11 },
      { d = 7, t = "9sus4" },
      { d = 1, x = 9 },
      { d = 3, x = 9 },
      { d = 4, x = 9 },
      { d = 7, x = 13 },
      { d = 6, t = "maj7#11" },
      { d = 1, t = "madd9" },
      { d = 7, x = 9 },
      { d = 5, t = "7sus4" },
      { d = 3, t = "6add9" },
      { d = 6, b = 7 },
      { d = 1, x = 11, i = 1 },
      { d = 5, t = "7b9" },
    },
  },
  {
    name = "Slow jam R&B",
    desc = "Minor ninths, major ninths and thirteenths, with a flat-nine dominant to lead home.",
    mode = MIN,
    pads = {
      { d = 1, x = 9 },
      { d = 4, x = 9 },
      { d = 7, x = 13 },
      { d = 3, x = 9 },
      { d = 6, x = 9 },
      { d = 2, s = true },
      { d = 5, t = "7b9" },
      { d = 1, x = 11 },
      { d = 4, x = 11 },
      { d = 7, x = 9 },
      { d = 3, t = "6add9" },
      { d = 6, t = "maj7#11" },
      { d = 1, s = true },
      { d = 4, s = true },
      { d = 7, t = "9sus4" },
      { d = 5, t = "sus4" },
    },
  },
  {
    name = "Lo-fi hip hop",
    desc = "Ninths and elevenths that loop forever; chords that return put another tone in the bass.",
    mode = MAJ,
    pads = {
      { d = 2, x = 9 },
      { d = 5, x = 13 },
      { d = 1, x = 9 },
      { d = 6, x = 9 },
      { d = 3, s = true },
      { d = 6, x = 11 },
      { d = 2, x = 11 },
      { d = 5, x = 9 },
      { d = 4, x = 9 },
      { d = 3, t = "7sus4" },
      { d = 2, s = true, i = 1 },
      { d = 1, s = true, i = 2 },
      { d = 1, t = "6add9" },
      { d = 4, s = true, i = 1 },
      { d = 3, s = true, i = 1 },
      { d = 5, t = "9sus4" },
    },
  },
  {
    name = "Disco strut",
    desc = "Dorian sevenths and ninths with a dominant IV, for bright pianos and funky stabs.",
    mode = DOR,
    pads = {
      { d = 1, s = true },
      { d = 4, x = 9 },
      { d = 7, s = true },
      { d = 1, x = 9 },
      { d = 2, s = true },
      { d = 5, s = true },
      { d = 3, s = true },
      { d = 4, t = "dom7" },
      { d = 1, x = 11 },
      { d = 4, x = 13 },
      { d = 7, x = 9 },
      { d = 5, x = 9 },
      { d = 3, x = 9 },
      { d = 1, s = true, i = 2 },
      { d = 4, i = 2 },
      { d = 4, t = "9sus4" },
    },
  },
  {
    name = "Minor: i iv v VI",
    desc = "Natural minor with the harmonic-minor V, a flat-nine dominant and minor ninths.",
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
      { d = 5, t = "7b9" },
      { d = 6, s = true },
      { d = 7, s = true },
      { d = 3, s = true },
      { d = 1, x = 9 },
      { d = 1, t = "mmaj7" },
    },
  },
  {
    name = "Sad minor ballad",
    desc = "i VI III VII and friends; slow and open, with ninths and the bass on other chord tones.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 3 },
      { d = 7 },
      { d = 4 },
      { d = 1, i = 2 },
      { d = 5, t = "dom7" },
      { d = 1, i = 1 },
      { d = 1, x = 9 },
      { d = 6, x = 9 },
      { d = 3, t = "add9" },
      { d = 7, t = "sus4" },
      { d = 4, x = 9 },
      { d = 6, i = 1 },
      { d = 5, t = "maj" },
      { d = 7, i = 1 },
    },
  },
  {
    name = "Stadium ballad",
    desc = "Big minor triads and add9s over a falling bass (i, i/b7, iv/b6, V), for grand pianos.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 3 },
      { d = 7 },
      { d = 1, b = 7 },
      { d = 4, i = 1 },
      { d = 5, t = "sus4" },
      { d = 5, t = "maj" },
      { d = 1, t = "madd9" },
      { d = 6, t = "add9" },
      { d = 3, t = "add9" },
      { d = 7, t = "sus2" },
      { d = 4, t = "madd9" },
      { d = 6, s = true },
      { d = 3, i = 2 },
      { d = 7, i = 1 },
    },
  },
  {
    name = "Andalusian: i VII VI V",
    desc = "The flamenco descent, with sevenths, a flat-nine dominant and first inversions.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 7 },
      { d = 6 },
      { d = 5, t = "maj" },
      { d = 1, s = true },
      { d = 7, s = true },
      { d = 6, s = true },
      { d = 5, t = "7b9" },
      { d = 4 },
      { d = 3 },
      { d = 2, s = true },
      { d = 5, t = "sus4" },
      { d = 1, i = 1 },
      { d = 7, i = 1 },
      { d = 6, i = 1 },
      { d = 5, t = "maj", i = 1 },
    },
  },
  {
    name = "Sunset synthwave",
    desc = "Minor loops for warm polysynths: i, VImaj7, III, VII, a minor ninth on iv and VI over VII.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6, s = true },
      { d = 3 },
      { d = 7 },
      { d = 4, x = 9 },
      { d = 6 },
      { d = 1, s = true },
      { d = 7, t = "6" },
      { d = 1, t = "madd9" },
      { d = 3, s = true },
      { d = 7, t = "add9" },
      { d = 5, t = "maj" },
      { d = 6, b = 7 },
      { d = 1, i = 1 },
      { d = 4, s = true },
      { d = 7, t = "sus4" },
    },
  },
  {
    name = "Trance / EDM minor",
    desc = "Big minor loops: i VI III VII with iv and v, add9s and major ninths for width.",
    mode = MIN,
    pads = {
      { d = 1 },
      { d = 6 },
      { d = 3 },
      { d = 7 },
      { d = 4 },
      { d = 5 },
      { d = 1, t = "madd9" },
      { d = 6, t = "add9" },
      { d = 1, t = "sus2" },
      { d = 6, s = true },
      { d = 3, t = "add9" },
      { d = 7, t = "sus4" },
      { d = 1, x = 9 },
      { d = 6, x = 9 },
      { d = 3, t = "6add9" },
      { d = 7, t = "add9" },
    },
  },
  {
    name = "Arp clouds",
    desc = "Soft minor ninths, major sevenths and sus chords for an arpeggiator on a warm synth.",
    mode = MIN,
    pads = {
      { d = 1, t = "madd9" },
      { d = 6, x = 9 },
      { d = 4, x = 9 },
      { d = 1, t = "9sus4" },
      { d = 3, s = true },
      { d = 4, s = true },
      { d = 1, x = 11 },
      { d = 7, t = "6add9" },
      { d = 6, s = true },
      { d = 5, s = true },
      { d = 3, t = "add9" },
      { d = 4, t = "9sus4" },
      { d = 6, b = 7 },
      { d = 1, s = true },
      { d = 7, t = "sus4" },
      { d = 6, t = "add9" },
    },
  },
  {
    name = "Cinematic minor",
    desc = "Epic and dark: open fifths, slow minor triads, chords over a held tonic and wide sevenths.",
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
      { d = 6, s = true },
      { d = 3, t = "add9" },
      { d = 7, t = "sus4" },
      { d = 1, t = "madd9" },
      { d = 4, b = 1 },
      { d = 6, i = 1 },
      { d = 2, t = "m7b5" },
    },
  },
  {
    name = "Epic heroes",
    desc = "Heroic minor: sus2 and add9 chords, VI and VII over the tonic, open fifths for brass.",
    mode = MIN,
    pads = {
      { d = 1, t = "sus2" },
      { d = 6, t = "add9" },
      { d = 7, t = "sus2" },
      { d = 1 },
      { d = 6, i = 1 },
      { d = 7, b = 1 },
      { d = 1, i = 2 },
      { d = 4, b = 1 },
      { d = 1, t = "5" },
      { d = 6, t = "5" },
      { d = 7, t = "5" },
      { d = 3, t = "5" },
      { d = 3, t = "add9" },
      { d = 6, s = true },
      { d = 5, t = "maj" },
      { d = 5, t = "sus4" },
    },
  },
  {
    name = "Dorian vamp",
    desc = "Modal jazz and funk: i7 to IV7, ninths, elevenths and thirteenths, the Dorian sixth.",
    mode = DOR,
    pads = {
      { d = 1, s = true },
      { d = 4, t = "dom7" },
      { d = 1, x = 9 },
      { d = 4, x = 9 },
      { d = 1, x = 11 },
      { d = 4, x = 13 },
      { d = 2, s = true },
      { d = 7, s = true },
      { d = 1, t = "m6" },
      { d = 4, t = "6" },
      { d = 3, x = 9 },
      { d = 5, x = 9 },
      { d = 1, s = true, i = 1 },
      { d = 4, t = "dom7", i = 1 },
      { d = 4, t = "9sus4" },
      { d = 1, t = "sus4" },
    },
  },
  {
    name = "Floating Dorian",
    desc = "Ethereal pads: minor elevenths, major ninths and sus chords that drift without resolving.",
    mode = DOR,
    pads = {
      { d = 1, x = 11 },
      { d = 3, x = 9 },
      { d = 4, t = "9sus4" },
      { d = 5, x = 9 },
      { d = 1, x = 9 },
      { d = 7, x = 9 },
      { d = 4, x = 13 },
      { d = 5, x = 11 },
      { d = 3, t = "maj7#11" },
      { d = 1, t = "m6" },
      { d = 7, t = "6add9" },
      { d = 2, t = "7sus4" },
      { d = 1, t = "madd9" },
      { d = 3, t = "6add9" },
      { d = 4, x = 9 },
      { d = 7, b = 1 },
    },
  },
  {
    name = "Quartal haze",
    desc = "Suspended chords stacked in fourths, for modal grooves in the spirit of late-50s jazz.",
    mode = DOR,
    pads = {
      { d = 1, t = "7sus4" },
      { d = 4, t = "9sus4" },
      { d = 5, t = "7sus4" },
      { d = 7, t = "sus2" },
      { d = 1, t = "9sus4" },
      { d = 2, t = "7sus4" },
      { d = 3, t = "sus2" },
      { d = 7, t = "sus4" },
      { d = 1, t = "sus4" },
      { d = 4, t = "sus4" },
      { d = 5, t = "sus4" },
      { d = 4, t = "sus2" },
      { d = 3, b = 4 },
      { d = 7, b = 1 },
      { d = 1, x = 11 },
      { d = 4, x = 13 },
    },
  },
  {
    name = "Dark Phrygian",
    desc = "The flat second rules: i, bII and bII over the tonic, for metal, flamenco and tension.",
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
      { d = 1, t = "sus4" },
      { d = 2, b = 1 },
      { d = 2, t = "maj7#11" },
      { d = 3 },
    },
  },
  {
    name = "Lydian dream",
    desc = "Bright and floating: I, II and the raised fourth, II over I, add9s and major ninths.",
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
      { d = 1, t = "maj7#11" },
      { d = 2, b = 1 },
      { d = 1, x = 9 },
      { d = 2, x = 13 },
    },
  },
  {
    name = "Mixolydian groove",
    desc = "Rock and funk: I bVII IV, dominant ninths and thirteenths on the tonic, bVII over I.",
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
      { d = 1, t = "sus2" },
      { d = 7, t = "add9" },
      { d = 4, t = "add9" },
      { d = 1, x = 9 },
      { d = 1, x = 13 },
      { d = 7, b = 1 },
      { d = 1, t = "9sus4" },
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
      false,
      false,
      { d = 1, t = "5", o = -1 },
      { d = 4, t = "5", o = -1 },
      { d = 5, t = "5", o = -1 },
      { d = 6, t = "5", o = -1 },
      { d = 2, t = "5", o = -1 },
      { d = 3, t = "5", o = -1 },
      false,
      false,
    },
  },
  {
    name = "Suspended / ambient",
    desc = "No thirds: sus2, sus4, add9 and seventh-sus chords that sit under anything.",
    mode = MAJ,
    pads = {
      { d = 1, t = "sus2" },
      { d = 1, t = "sus4" },
      { d = 5, t = "sus2" },
      { d = 5, t = "sus4" },
      { d = 4, t = "sus2" },
      { d = 3, t = "sus4" },
      { d = 2, t = "sus2" },
      { d = 2, t = "sus4" },
      { d = 1, t = "add9" },
      { d = 4, t = "add9" },
      { d = 5, t = "add9" },
      { d = 6, t = "sus4" },
      { d = 4, t = "sus2", b = 5 },
      { d = 5, t = "sus4", b = 4 },
      { d = 6, t = "7sus4" },
      { d = 2, t = "9sus4" },
    },
  },
}

-- The popup lists the factory presets in alphabetical order.
table.sort(M.FACTORY, function(a, b)
  return a.name:lower() < b.name:lower()
end)

---The preset a first start loads.
M.DEFAULT_NAME = "Diatonic: triads + sevenths"

---A factory preset by its exact name.
---@param name string
---@return Preset?
function M.find(name)
  for _, preset in ipairs(M.FACTORY) do
    if preset.name == name then
      return preset
    end
  end
  return nil
end

---@return Preset
function M.default()
  return assert(M.find(M.DEFAULT_NAME), "default preset missing")
end

---Are the pads still the preset, rendered in this key and mode?
---@param preset Preset
---@param pads Pad[]
---@param key integer 0-11
---@param mode integer 1-7
---@return boolean
function M.matches(preset, pads, key, mode)
  return pads_mod.all_equal(pads, M.render(preset, key, mode))
end

---@return string[]
function M.names()
  local names = {}
  for i, preset in ipairs(M.FACTORY) do
    names[i] = preset.name
  end
  return names
end

---Semitones from the tonic up to the root of a pad spec: the degree in the
---scale (0-11), then the accidental, which may step below the tonic or up to
---the next one.
---@param spec PresetPad
---@param key integer
---@param mode integer
---@return integer
local function interval(spec, key, mode)
  return (theory.scale(key, mode)[spec.d] - key) % 12 + (spec.a or 0)
end

---Turn one pad spec into a pad for a key/mode. The pad lands where the spec
---lands in C, moved by `pads.key_offset(key)`, so a preset has the same shape
---in every key and loading it in a key gives what a key change to it gives.
---@param spec PresetPad
---@param key integer
---@param mode integer
---@param base_octave integer
---@param legacy boolean? The old rule: every root in `base_octave + o`, whatever the key.
---@return Pad
function M.render_pad(spec, key, mode, base_octave, legacy)
  local scale = theory.scale(key, mode)
  local acc = spec.a or 0
  local root = (scale[spec.d] + acc) % 12
  local type_index
  if spec.t then
    type_index = assert(theory.type_index(spec.t), "unknown chord type " .. spec.t)
  elseif acc ~= 0 then
    type_index = assert(theory.type_index "maj")
  else
    if spec.x then
      local _, extended = theory.diatonic_extended(key, mode, spec.d, spec.x)
      type_index = extended
    end
    if not type_index then
      local _, diatonic = theory.diatonic_chord(key, mode, spec.d, spec.s or spec.x ~= nil)
      type_index = diatonic
    end
  end
  local bass = pads_mod.NO_BASS
  if spec.b then
    bass = (scale[spec.b] + (spec.ba or 0)) % 12
  end
  local octave
  if legacy then
    octave = base_octave + (spec.o or 0)
  else
    octave = math.floor(
      ((base_octave + (spec.o or 0)) * 12 + interval(spec, key, mode) + pads_mod.key_offset(key))
        / 12
    )
  end
  return pads_mod.normalize {
    root = root,
    type = type_index,
    inversion = spec.i or 0,
    octave = math.max(pads_mod.MIN_OCTAVE, math.min(pads_mod.MAX_OCTAVE, octave)),
    bass = bass,
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
      pads[i] = M.render_pad(spec, key, mode, base_octave, preset.legacy_octaves)
    else
      pads[i] = pads_mod.empty()
    end
  end
  return pads
end

---Re-render a preset into another mode while keeping each pad's register.
---`pads` are the preset as it is on the grid now (rendered in `from_mode`,
---possibly transposed since). Every pad gets the chord of `to_mode`; its root
---moves by the shortest route from the old one (a mode change shifts a degree
---by a semitone or two), so the octave carries like `pads.transpose`.
---@param preset Preset
---@param pads Pad[]
---@param key integer 0-11
---@param from_mode integer 1-7
---@param to_mode integer 1-7
---@param base_octave integer? Default pads_mod.DEFAULT_OCTAVE.
---@return Pad[]
function M.remode(preset, pads, key, from_mode, to_mode, base_octave)
  local before = M.render(preset, key, from_mode, base_octave)
  local after = M.render(preset, key, to_mode, base_octave)
  local out = {}
  for i = 1, pads_mod.COUNT do
    local pad = pads[i] or pads_mod.empty()
    if pads_mod.is_empty(after[i]) or pads_mod.is_empty(pad) then
      out[i] = pads_mod.normalize(after[i])
    else
      local delta = ((after[i].root - before[i].root + 6) % 12) - 6
      local absolute = pad.octave * 12 + pad.root + delta
      local root = absolute % 12
      local bass = pads_mod.NO_BASS
      if after[i].bass >= 0 then
        -- the bass keeps its distance to the root of the new chord
        bass = (after[i].bass + root - after[i].root) % 12
      end
      out[i] = pads_mod.normalize {
        root = root,
        type = after[i].type,
        inversion = after[i].inversion,
        octave = math.max(
          pads_mod.MIN_OCTAVE,
          math.min(pads_mod.MAX_OCTAVE, math.floor(absolute / 12))
        ),
        bass = bass,
      }
    end
  end
  return out
end

---Spell a pitch class as a scale degree and an accidental. Notes outside
---the scale are the flattened upper degree (bVII, bIII, ...).
---@param pc integer
---@param key integer
---@param mode integer
---@return integer degree, integer accidental
local function spell(pc, key, mode)
  local degree = theory.degree_of(pc, key, mode)
  if degree then
    return degree, 0
  end
  for i, spc in ipairs(theory.scale(key, mode)) do
    if (spc - 1) % 12 == pc % 12 then
      return i, -1
    end
  end
  error "pitch class not representable"
end

---Write one pad as a spec relative to a key/mode. Roots outside the scale
---are spelled as the flattened upper degree (bVII, bIII, ...). A chord that
---is the diatonic triad or seventh of its degree is written as such (no `t`),
---so the preset adapts when it is rendered into another mode; so is a
---diatonic ninth, eleventh or thirteenth.
---@param pad Pad
---@param key integer
---@param mode integer
---@return PresetPad|false
function M.capture_pad(pad, key, mode)
  if pads_mod.is_empty(pad) then
    return false
  end
  local degree, acc = spell(pad.root, key, mode)
  local spec = { d = degree, t = theory.CHORD_TYPES[pad.type].id }
  if acc ~= 0 then
    spec.a = acc
  else
    local _, triad = theory.diatonic_chord(key, mode, degree, false)
    local _, seventh = theory.diatonic_chord(key, mode, degree, true)
    if pad.type == triad then
      spec.t = nil
    elseif pad.type == seventh then
      spec.t = nil
      spec.s = true
    else
      for _, x in ipairs { 9, 11, 13 } do
        local _, extended = theory.diatonic_extended(key, mode, degree, x)
        if pad.type == extended then
          spec.t = nil
          spec.x = x
          break
        end
      end
    end
  end
  if pad.inversion ~= 0 then
    spec.i = pad.inversion
  end
  -- the inverse of render_pad: the octave offset that puts the root back here
  local placed = M.render_pad(spec, key, mode, pads_mod.DEFAULT_OCTAVE)
  if pad.octave ~= placed.octave then
    spec.o = pad.octave - placed.octave
  end
  if pad.bass and pad.bass >= 0 then
    local b, ba = spell(pad.bass, key, mode)
    spec.b = b
    if ba ~= 0 then
      spec.ba = ba
    end
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
