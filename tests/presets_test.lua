local t = require "tests.helper"
local presets = require "src.presets"
local pads_mod = require "src.pads"
local theory = require "src.theory"
local circle = require "src.circle"
local voicing = require "src.voicing"

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

-- no two pads of a factory preset play the same notes, in any key and voicing
for _, preset in ipairs(presets.FACTORY) do
  local modes = preset.mode and { preset.mode } or { 1, 2, 3, 4, 5, 6, 7 }
  for _, mode in ipairs(modes) do
    for key = 0, 11 do
      local rendered = presets.render(preset, key, mode)
      for style = 1, #voicing.STYLES do
        ---@type table<string, integer> notes -> first pad that plays them
        local seen = {}
        for i, pad in ipairs(rendered) do
          if not pads_mod.is_empty(pad) then
            local notes = table.concat(pads_mod.notes(pad, style), ",")
            t.check(
              not seen[notes],
              ("%s pad %d plays the notes of pad %s in key %d mode %d, %s"):format(
                preset.name,
                i,
                tostring(seen[notes]),
                key,
                mode,
                voicing.STYLES[style]
              )
            )
            seen[notes] = seen[notes] or i
          end
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
for _, i in ipairs { 7, 8, 15, 16 } do
  t.eq(power[i].type, 0, "six degrees carry a perfect fifth, so power pad " .. i .. " is empty")
end
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
t.eq(captured.pads[13] and captured.pads[13].s, true, "diatonic seventh captured as s")
t.eq(captured.pads[13] and captured.pads[13].t, nil, "no fixed type for a diatonic seventh")
t.eq(captured.pads[1] and captured.pads[1].x, 9, "diatonic ninth captured as x")
t.eq(captured.pads[1] and captured.pads[1].t, nil, "no fixed type for a diatonic ninth")
t.eq(captured.pads[2] and captured.pads[2].x, 13, "diatonic thirteenth captured as x")
t.eq(captured.pads[4] and captured.pads[4].t, "6add9", "a sixth chord keeps its type")
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
  "Dm7b5 Gm7 Cm9 C6add9 Ebmaj7 Abmaj9 Dm7b5 Gm7 Fm7 Bb7 Eb7sus4 Abmaj7 Dm7b5 G9sus4 Cm7 Fm9",
  "jazz preset re-rendered in C Aeolian: ninths follow the mode, or fall back to sevenths"
)
local green = 0
for _, pad in ipairs(c_minor) do
  local _, _, func = pads_mod.label(pad, 0, theory.MODE_AEOLIAN)
  if func == "in_key" then
    green = green + 1
  end
end
t.eq(green, 13, "thirteen jazz pads are in key in Aeolian (not C6add9, Eb7sus4, G9sus4)")
local pop = find "Pop"
local pop_minor = presets.remode(pop, presets.render(pop, 0, 1), 0, 1, theory.MODE_AEOLIAN)
t.eq(pop_minor[5].inversion, 1, "inversions survive remode")
t.eq(names({ pop_minor[8] }, 0, theory.MODE_AEOLIAN), "Fm/G", "IV/V becomes iv/v in minor")

-- remode keeps the register the pads have after a key transposition
local b_major = pads_mod.transpose(c_major, -1) -- C -> B, shortest route
t.eq(b_major[3].octave, 3, "transposing down carries the tonic chord to octave 3")
local b_minor = presets.remode(jazz, b_major, 11, 1, theory.MODE_AEOLIAN)
t.eq(b_minor[3].root, 11, "tonic stays on B")
t.eq(b_minor[3].octave, 3, "tonic keeps its octave")
t.eq(names({ b_minor[3] }, 11, theory.MODE_AEOLIAN), "Bm9", "tonic major ninth becomes minor ninth")
t.eq(b_minor[1].octave, 4, "ii keeps its octave")

-- remode moves a root by the shortest route when the degree wraps across C
local cs_major = presets.render(presets.FACTORY[1], 1, 1) -- C# major: degree 7 is C (B#)
t.eq(cs_major[7].root, 0, "degree 7 of C# major is C")
local cs_minor = presets.remode(presets.FACTORY[1], cs_major, 1, 1, theory.MODE_AEOLIAN)
t.eq(cs_minor[7].root, 11, "degree 7 of C# minor is B")
t.eq(cs_minor[7].octave, cs_major[7].octave - 1, "B sits a semitone below the C it replaces")
t.eq(cs_minor[8].type, 0, "empty slots stay empty")

-- slash bass: rendered from a degree, captured back, moved by remode
local slash = presets.render_pad({ d = 4, b = 5 }, 2, 1, 4) -- G/A in D major
t.eq(slash.root, 7, "slash chord root")
t.eq(slash.bass, 9, "slash bass from its degree")
t.eq(presets.render_pad({ d = 1 }, 2, 1, 4).bass, -1, "no b, no slash bass")
local spec = presets.capture_pad(slash, 2, 1)
t.eq(spec and spec.b, 5, "slash bass captured as a degree")
t.eq(spec and spec.ba, nil, "an in-key bass has no accidental")
local flat = presets.capture_pad({ root = 0, type = 1, inversion = 0, octave = 4, bass = 10 }, 0, 1)
t.eq(flat and flat.b, 7, "a flat bass is the degree above")
t.eq(flat and flat.ba, -1, "with a flat")
local back_flat = presets.render_pad(flat --[[@as PresetPad]], 0, 1, 4)
t.eq(back_flat.bass, 10, "flat bass round trip")

-- diatonic extensions follow the mode
local function ext(d, x, key, mode)
  return names({ presets.render_pad({ d = d, x = x }, key, mode, 4) }, key, mode)
end
t.eq(ext(2, 9, 0, 1), "Dm9", "ii9 in C major")
t.eq(ext(1, 9, 0, 1), "Cmaj9", "Imaj9 in C major")
t.eq(ext(5, 9, 0, 1), "G9", "V9 in C major")
t.eq(ext(5, 13, 0, 1), "G13", "V13 in C major")
t.eq(ext(6, 11, 0, 1), "Am11", "vi11 in C major")
t.eq(ext(1, 9, 9, 6), "Am9", "i9 in A minor")
t.eq(ext(3, 9, 0, 1), "Em7", "iii9 does not exist in major: the seventh plays")
t.eq(ext(1, 11, 0, 1), "Cmaj7", "no type for Cmaj7(11): the seventh plays")

-- every preset in every key: capture and render give the same pads back,
-- and a change to any mode keeps every pad valid and its root in range
local problems = {}
local function problem(what)
  if #problems < 10 then
    problems[#problems + 1] = what
  end
end
for _, preset in ipairs(presets.FACTORY) do
  local from_modes = preset.mode and { preset.mode } or { 1, 2, 3, 4, 5, 6, 7 }
  for _, from in ipairs(from_modes) do
    for key = 0, 11 do
      local rendered = presets.render(preset, key, from)
      local again = presets.render(presets.capture(rendered, key, from, "x"), key, from)
      for i = 1, pads_mod.COUNT do
        local a, b = rendered[i], again[i]
        if
          a.root ~= b.root
          or a.type ~= b.type
          or a.inversion ~= b.inversion
          or a.octave ~= b.octave
          or a.bass ~= b.bass
        then
          problem(
            ("%s key %d mode %d pad %d does not round trip"):format(preset.name, key, from, i)
          )
        end
      end
      for to = 1, 7 do
        local ok, moved = pcall(presets.remode, preset, rendered, key, from, to)
        if not ok then
          problem(("%s key %d mode %d -> %d: %s"):format(preset.name, key, from, to, moved))
        else
          for i, pad in ipairs(moved) do
            local normal = pads_mod.normalize(pad)
            if
              normal.type ~= pad.type
              or normal.bass ~= pad.bass
              or normal.octave ~= pad.octave
              or #pads_mod.notes(pad) ~= #pads_mod.notes(normal)
            then
              problem(
                ("%s key %d mode %d -> %d pad %d invalid"):format(preset.name, key, from, to, i)
              )
            end
            local name = pads_mod.label(pad, key, to)
            if not pads_mod.is_empty(pad) and name == "" then
              problem(("%s pad %d has no name"):format(preset.name, i))
            end
          end
        end
      end
    end
  end
end
t.check(
  #problems == 0,
  "every preset round trips and survives every mode: " .. table.concat(problems, "; ")
)

-- the longest pad name a factory preset shows, so the pad font can be checked
local longest = ""
for _, preset in ipairs(presets.FACTORY) do
  local modes = preset.mode and { preset.mode } or { 1, 2, 3, 4, 5, 6, 7 }
  for _, mode in ipairs(modes) do
    for key = 0, 11 do
      for _, pad in ipairs(presets.render(preset, key, mode)) do
        local name = pads_mod.label(pad, key, mode)
        if #name > #longest then
          longest = name
        end
      end
    end
  end
end
t.check(#longest <= 12, "longest factory pad name fits the pad: " .. longest)

t.done()
