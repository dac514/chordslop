local t = require "tests.helper"
local presets = require "src.presets"
local pads_mod = require "src.pads"
local theory = require "src.theory"

local function names(pads, key, mode)
  local out = {}
  for i, pad in ipairs(pads) do
    local name = pads_mod.label(pad, key, mode)
    out[i] = name ~= "" and name or "-"
  end
  return table.concat(out, " ")
end

t.check(#presets.FACTORY >= 8, "a good handful of factory presets")
t.eq(#presets.names(), #presets.FACTORY, "names match presets")

-- every preset renders in every key and mode without errors and stays in range
for _, preset in ipairs(presets.FACTORY) do
  t.check(#preset.pads <= pads_mod.COUNT, preset.name .. ": at most 16 pads")
  for key = 0, 11 do
    for mode = 1, 7 do
      local ok, pads = pcall(presets.render, preset, key, mode)
      t.check(
        ok,
        preset.name .. " renders in key " .. key .. " mode " .. mode .. ": " .. tostring(pads)
      )
      if ok then
        t.eq(#pads, 16, preset.name .. ": sixteen pads")
      end
    end
  end
end

local diatonic = presets.render(presets.FACTORY[1], 0, 1)
t.eq(
  names(diatonic, 0, 1),
  "C Dm Em F G Am Bdim - Cmaj7 Dm7 Em7 Fmaj7 G7 Am7 Bm7b5 -",
  "diatonic preset in C major"
)
t.eq(diatonic[8].type, 0, "slot 8 is empty")

local function find(name)
  for _, preset in ipairs(presets.FACTORY) do
    if preset.name:find(name, 1, true) then
      return preset
    end
  end
  error("no preset " .. name)
end

local blues = presets.render(find "Blues", 0, 1)
t.eq(theory.CHORD_TYPES[blues[1].type].id, "dom7", "blues I7")
t.eq(blues[5].root, 5, "blues IV root is F")
t.eq(theory.CHORD_TYPES[blues[9].type].id, "dom7", "blues V7")
t.eq(blues[15].root, 10, "bVII in C is Bb")

local minor = find "Minor"
t.eq(minor.mode, theory.MODE_AEOLIAN, "minor preset switches to Aeolian")
local am = presets.render(minor, 9, minor.mode)
t.eq(names(am, 9, minor.mode):sub(1, 11), "Am Dm Em F ", "A minor i iv v VI")
t.eq(theory.CHORD_TYPES[am[8].type].id, "maj", "explicit major V in minor")

local power = presets.render(find "Power", 0, 1)
t.eq(power[9].octave, 3, "octave offset applied")
local low = presets.render(find "Power", 0, 1, 0)
t.eq(low[9].octave, 0, "octave offset clamps at 0")

local jazz = presets.render(find "Jazz", 0, 1)
t.eq(theory.chord_name(jazz[10].root, jazz[10].type, false), "F#m7b5", "#iv half-diminished")
t.eq(theory.chord_name(jazz[13].root, jazz[13].type, true), "Db7", "tritone sub bII7")
t.eq(jazz[16].inversion, 2, "inversion carried")

t.done()
