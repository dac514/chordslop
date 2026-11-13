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
local n4 = pads.label({ root = 10, type = maj, inversion = 0, octave = 4 }, 0, 1)
t.eq(n4, "Bb", "bVII in C spells as a flat")
local n5 = pads.label({ root = 6, type = maj, inversion = 0, octave = 4 }, 7, 1)
t.eq(n5, "F#", "sharp key keeps sharps for in-key roots")

t.eq(pads.all_empty { e, pads.empty() }, true, "all_empty")
t.eq(pads.all_empty { e, p }, false, "not all_empty")

-- fit: how many pads are in key, and the move of all pads that fits best
local presets = require "src.presets"
local function rendered(name)
  for _, preset in ipairs(presets.FACTORY) do
    if preset.name:find(name, 1, true) then
      return presets.render(preset, 0, 1) -- C major
    end
  end
  error("no preset " .. name)
end
local pop = rendered "Pop"
local in_key, total = pads.fit(pop, 0, 1)
t.eq(in_key, 16, "a preset in its own key: every pad is in key")
t.eq(total, 16, "fit counts the pads that are not empty")
t.eq(pads.fit(pop, 9, 1), 0, "C major pads seen from A major: none is in key")
local delta, best = pads.best_fit(pop, 9, 1)
t.eq(delta, -3, "best fit moves C major pads down to A major")
t.eq(best, 16, "best fit returns the count after the move")
local moved = pads.transpose(pop, delta)
t.eq(pads.fit(moved, 9, 1), 16, "after the move every pad is in key")
t.eq(pads.best_fit(moved, 9, 1), 0, "pads that fit need no move")

-- transposing with the key keeps the fit: pads that left the key stay outside
local power = rendered "Power"
local _, power_total = pads.fit(power, 0, 1)
t.eq(power_total, 12, "empty pads are not counted")
t.eq(pads.fit(power, 9, 1), 6, "C major power chords seen from A major: A5, D5 and E5 fit")
for d = -5, 6 do
  t.eq(
    pads.fit(pads.transpose(power, d), (9 + d) % 12, 1),
    6,
    "transposing with the key keeps the fit, delta " .. d
  )
end

-- ties: the smallest move wins, and down wins over up
local ab = { { root = 8, type = maj, inversion = 0, octave = 4 } }
t.eq(pads.fit(ab, 2, 1), 0, "Ab major is not in D major")
local tie, tie_best = pads.best_fit(ab, 2, 1)
t.eq(tie, -1, "G (down 1) and A (up 1) both fit D major: down wins")
t.eq(tie_best, 1, "the one pad fits after the move")
local c = { { root = 0, type = maj, inversion = 0, octave = 4 } }
t.eq(pads.best_fit(c, 2, 1), 2, "C fits D major as D (up 2), A (down 3) or G (down 5): up 2 wins")

local none, none_total = pads.fit({ pads.empty() }, 0, 1)
t.eq(none, 0, "empty pads: none in key")
t.eq(none_total, 0, "empty pads: none counted")
t.eq(pads.best_fit({ pads.empty() }, 0, 1), 0, "empty pads need no move")

t.done()
