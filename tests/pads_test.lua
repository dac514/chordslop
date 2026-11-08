local t = require "tests.helper"
local pads = require "src.pads"
local theory = require "src.theory"

local function list(xs)
  return table.concat(xs, ",")
end

local e = pads.empty()
t.eq(e.type, 0, "empty pad has type 0")
t.eq(pads.is_empty(e), true, "is_empty")

local maj = assert(theory.type_index "maj")
local p = { root = 11, type = maj, inversion = 0, octave = 4 }
local up = pads.transpose({ p }, 2)
t.eq(up[1].root, 1, "transpose wraps root")
t.eq(up[1].octave, 5, "transpose carries octave")
local down = pads.transpose({ { root = 0, type = maj, inversion = 1, octave = 0 } }, -1)
t.eq(down[1].root, 11, "transpose down wraps")
t.eq(down[1].octave, 0, "transpose clamps octave at 0")
t.eq(down[1].inversion, 1, "transpose keeps inversion")
t.eq(pads.transpose({ pads.empty() }, 5)[1].type, 0, "empty pads stay empty")

local roots, types, invs, octs = pads.to_lists { p }
t.eq(#roots, 16, "to_lists pads to 16")
t.eq(types[2], 0, "missing pads are empty")
local back = pads.from_lists(roots, types, invs, octs)
t.eq(back[1].root, 11, "round trip root")
t.eq(back[16].octave, 4, "round trip default octave")

local bad = pads.from_lists({ 99 }, { 200 }, { -1 }, { 40 })
t.eq(bad[1].root, 0, "invalid root -> 0")
t.eq(bad[1].type, 0, "invalid type -> empty")
t.eq(bad[1].inversion, 0, "invalid inversion -> 0")
t.eq(bad[1].octave, 4, "invalid octave -> default")

t.eq(list(pads.notes(p)), "59,63,66", "notes of B major")
t.eq(#pads.notes(e), 0, "empty pad has no notes")

local name, numeral, func =
  pads.label({ root = 2, type = assert(theory.type_index "min7"), inversion = 0, octave = 4 }, 0, 1)
t.eq(name, "Dm7", "label name")
t.eq(numeral, "ii7", "label numeral")
t.eq(func, "in_key", "label func")
local _, _, f2 = pads.label(e, 0, 1)
t.eq(f2, "empty", "label of empty pad")
local n3 = pads.label({ root = 10, type = maj, inversion = 0, octave = 4 }, 5, 1)
t.eq(n3, "Bb", "flat key spells flats")

t.eq(pads.all_empty { e, pads.empty() }, true, "all_empty")
t.eq(pads.all_empty { e, p }, false, "not all_empty")

t.done()
