local t = require "tests.helper"
local presets = require "src.presets"
local pads_mod = require "src.pads"
local theory = require "src.theory"
local circle = require "src.circle"

local function names(pads, key, mode)
  local out = {}
  for i, pad in ipairs(pads) do
    local name = pads_mod.label(pad, key, mode)
    out[i] = name ~= "" and name or "-"
  end
  return table.concat(out, " ")
end

t.check(#presets.FACTORY >= 18, "a generous set of factory presets")
for _, preset in ipairs(presets.FACTORY) do
  t.check(type(preset.desc) == "string" and #preset.desc > 10, preset.name .. " has a description")
end
t.eq(#presets.names(), #presets.FACTORY, "names match presets")

-- every factory preset stays in its key: no grey pads, in any key
for _, preset in ipairs(presets.FACTORY) do
  local modes = preset.mode and { preset.mode } or { 1, 2, 3, 4, 5, 6, 7 }
  for _, mode in ipairs(modes) do
    for key = 0, 11 do
      local rendered = presets.render(preset, key, mode)
      for i, pad in ipairs(rendered) do
        if not pads_mod.is_empty(pad) then
          local name, numeral, func = pads_mod.label(pad, key, mode)
          local level = circle.pad_level(pad, key, mode)
          t.check(
            func == "in_key" and level == "home",
            ("%s pad %d (%s %s) is %s/%s in key %d mode %d"):format(
              preset.name,
              i,
              name,
              numeral,
              func,
              level,
              key,
              mode
            )
          )
        end
      end
    end
  end
end

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

local power = presets.render(find "Power", 0, 1)
t.eq(theory.CHORD_TYPES[power[1].type].id, "5", "power chords are fifths")
t.eq(power[9].octave, 3, "octave offset applied")
local low = presets.render(find "Power", 0, 1, 0)
t.eq(low[9].octave, 0, "octave offset clamps at 0")

local minor = find "Minor"
t.eq(minor.mode, theory.MODE_AEOLIAN, "minor preset switches to Aeolian")
local am = presets.render(minor, 9, minor.mode)
t.eq(names(am, 9, minor.mode):sub(1, 11), "Am Dm Em F ", "A minor i iv v VI")
t.eq(theory.CHORD_TYPES[am[8].type].id, "maj", "explicit major V in minor")

-- capture: pads -> relative preset -> pads round trip
local source = presets.render(find "Jazz", 2, 1) -- D major
local captured = presets.capture(source, 2, 1, "mine")
t.eq(captured.name, "mine", "captured name")
t.eq(captured.mode, 1, "captured mode")
local back = presets.render(captured, 2, 1)
for i = 1, 16 do
  t.eq(
    names({ back[i] }, 2, 1) .. back[i].inversion .. back[i].octave,
    names({ source[i] }, 2, 1) .. source[i].inversion .. source[i].octave,
    "round trip pad " .. i
  )
end
local moved = presets.render(captured, 4, 1) -- E major
t.eq(moved[3].root, 4, "captured preset transposes: Imaj7 lands on E")
t.eq(presets.capture_pad(pads_mod.empty(), 0, 1), false, "empty pad captures as false")
local low = presets.capture_pad({ root = 0, type = 1, inversion = 2, octave = 3 }, 0, 1)
t.eq(low and low.o, -1, "octave offset captured")
t.eq(low and low.i, 2, "inversion captured")

-- capture writes diatonic chords as degrees, so they adapt to another mode
t.eq(captured.pads[1] and captured.pads[1].s, true, "diatonic seventh captured as s")
t.eq(captured.pads[1] and captured.pads[1].t, nil, "no fixed type for a diatonic seventh")
t.eq(captured.pads[4] and captured.pads[4].t, "6", "a sixth chord keeps its type")
t.eq(
  names({ presets.render(captured, 2, theory.MODE_AEOLIAN)[1] }, 2, 6),
  "Em7b5",
  "captured ii adapts to minor"
)
local triads = presets.capture(presets.render(presets.FACTORY[1], 0, 1), 0, 1, "tri")
t.eq(triads.pads[2] and triads.pads[2].t, nil, "diatonic triad captured without type")
t.eq(triads.pads[2] and triads.pads[2].s, nil, "diatonic triad captured without s")
t.eq(triads.pads[8], false, "empty pad stays empty")

-- remode: a preset on the grid follows the mode
local jazz = find "Jazz"
local c_major = presets.render(jazz, 0, 1)
local c_minor = presets.remode(jazz, c_major, 0, 1, theory.MODE_AEOLIAN)
t.eq(
  names(c_minor, 0, theory.MODE_AEOLIAN),
  "Dm7b5 Gm7 Cm7 C6 Ebmaj7 Abmaj7 Dm7b5 Gm7 Fm7 Bb7 Ebmaj7 Abmaj7 Dm7b5 Gm7 Cm7 Abmaj7",
  "jazz preset re-rendered in C Aeolian"
)
local green = 0
for _, pad in ipairs(c_minor) do
  local _, _, func = pads_mod.label(pad, 0, theory.MODE_AEOLIAN)
  if func == "in_key" then
    green = green + 1
  end
end
t.eq(green, 15, "fifteen of sixteen jazz pads are in key in Aeolian (C6 is not)")
t.eq(c_minor[13].inversion, 1, "inversions survive remode")

-- remode keeps the register the pads have after a key transposition
local b_major = pads_mod.transpose(c_major, -1) -- C -> B, shortest route
t.eq(b_major[3].octave, 3, "transposing down carries the tonic chord to octave 3")
local b_minor = presets.remode(jazz, b_major, 11, 1, theory.MODE_AEOLIAN)
t.eq(b_minor[3].root, 11, "tonic stays on B")
t.eq(b_minor[3].octave, 3, "tonic keeps its octave")
t.eq(names({ b_minor[3] }, 11, theory.MODE_AEOLIAN), "Bm7", "tonic becomes minor seventh")
t.eq(b_minor[1].octave, 4, "ii keeps its octave")

-- remode moves a root by the shortest route when the degree wraps across C
local cs_major = presets.render(presets.FACTORY[1], 1, 1) -- C# major: degree 7 is C (B#)
t.eq(cs_major[7].root, 0, "degree 7 of C# major is C")
local cs_minor = presets.remode(presets.FACTORY[1], cs_major, 1, 1, theory.MODE_AEOLIAN)
t.eq(cs_minor[7].root, 11, "degree 7 of C# minor is B")
t.eq(cs_minor[7].octave, cs_major[7].octave - 1, "B sits a semitone below the C it replaces")
t.eq(cs_minor[8].type, 0, "empty slots stay empty")

t.done()
