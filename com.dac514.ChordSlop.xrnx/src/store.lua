--[[
  Preferences adapter: moves the current pads and the user's presets in and
  out of the `renoise.Document` preferences. The only place that knows the
  list layout.

  User presets are stored relative to a key, as degree/accidental/type/
  inversion/octave-offset lists plus the mode (see `src/presets.lua`), so
  they render into whatever key is current, like the factory presets.
]]

local pads_mod = require "src.pads"
local theory = require "src.theory"

local M = {}

M.PRESET_MODEL = "ChordSlopPreset"

---@class ChordSlopPresetNode : renoise.Document.DocumentNode
---@field name renoise.Document.ObservableString
---@field mode renoise.Document.ObservableNumber
---@field degrees renoise.Document.ObservableNumberList 0 = empty pad
---@field accidentals renoise.Document.ObservableNumberList
---@field types renoise.Document.ObservableNumberList Chord type index.
---@field inversions renoise.Document.ObservableNumberList
---@field octaves renoise.Document.ObservableNumberList Octave offsets.

---@param list renoise.Document.ObservableNumberList
---@return number[]
local function read(list)
  local out = {}
  for i = 1, #list do
    out[i] = list:property(i).value
  end
  return out
end

---Resize the list to `values` and copy them in.
---@param list renoise.Document.ObservableNumberList
---@param values number[]
local function write(list, values)
  while #list > #values do
    list:remove(#list)
  end
  while #list < #values do
    list:insert(#list + 1, 0)
  end
  for i, v in ipairs(values) do
    list:property(i).value = v
  end
end

---@param prefs ChordSlopPreferences
---@return Pad[]
function M.load_pads(prefs)
  return pads_mod.from_lists(
    read(prefs.pad_roots),
    read(prefs.pad_types),
    read(prefs.pad_inversions),
    read(prefs.pad_octaves)
  )
end

---@param prefs ChordSlopPreferences
---@param pads Pad[]
function M.save_pads(prefs, pads)
  local roots, types, inversions, octaves = pads_mod.to_lists(pads)
  write(prefs.pad_roots, roots)
  write(prefs.pad_types, types)
  write(prefs.pad_inversions, inversions)
  write(prefs.pad_octaves, octaves)
end

---@param prefs ChordSlopPreferences
---@return string[]
function M.user_preset_names(prefs)
  local names = {}
  for i = 1, #prefs.presets do
    local entry = prefs.presets:property(i) --[[@as ChordSlopPresetNode]]
    names[i] = entry.name.value
  end
  return names
end

---@param prefs ChordSlopPreferences
---@param name string
---@return integer?
function M.find_user_preset(prefs, name)
  for i, existing in ipairs(M.user_preset_names(prefs)) do
    if existing == name then
      return i
    end
  end
  return nil
end

---Save (or overwrite) a user preset.
---@param prefs ChordSlopPreferences
---@param preset Preset Relative preset from `presets.capture`.
---@return integer index
function M.save_user_preset(prefs, preset)
  local index = M.find_user_preset(prefs, preset.name)
  if not index then
    index = #prefs.presets + 1
    prefs.presets:insert(index, renoise.Document.instantiate(M.PRESET_MODEL))
  end
  local entry = prefs.presets:property(index) --[[@as ChordSlopPresetNode]]
  entry.name.value = preset.name
  entry.mode.value = preset.mode or 0
  local degrees, accidentals, types, inversions, octaves = {}, {}, {}, {}, {}
  for i = 1, pads_mod.COUNT do
    local spec = preset.pads[i]
    if spec then
      degrees[i] = spec.d
      accidentals[i] = spec.a or 0
      types[i] = theory.type_index(spec.t or "maj") or 1
      inversions[i] = spec.i or 0
      octaves[i] = spec.o or 0
    else
      degrees[i], accidentals[i], types[i], inversions[i], octaves[i] = 0, 0, 0, 0, 0
    end
  end
  write(entry.degrees, degrees)
  write(entry.accidentals, accidentals)
  write(entry.types, types)
  write(entry.inversions, inversions)
  write(entry.octaves, octaves)
  return index
end

---@param prefs ChordSlopPreferences
---@param index integer
---@return Preset
function M.load_user_preset(prefs, index)
  local entry = prefs.presets:property(index) --[[@as ChordSlopPresetNode]]
  local degrees = read(entry.degrees)
  local accidentals = read(entry.accidentals)
  local types = read(entry.types)
  local inversions = read(entry.inversions)
  local octaves = read(entry.octaves)
  local specs = {}
  for i = 1, pads_mod.COUNT do
    local d = degrees[i] or 0
    local chord = theory.CHORD_TYPES[types[i] or 0]
    if d >= 1 and d <= 7 and chord then
      local spec = { d = d, t = chord.id }
      if (accidentals[i] or 0) ~= 0 then
        spec.a = accidentals[i]
      end
      if (inversions[i] or 0) ~= 0 then
        spec.i = inversions[i]
      end
      if (octaves[i] or 0) ~= 0 then
        spec.o = octaves[i]
      end
      specs[i] = spec
    else
      specs[i] = false
    end
  end
  local mode = entry.mode.value
  return {
    name = entry.name.value,
    mode = (mode >= 1 and mode <= #theory.MODES) and mode or nil,
    pads = specs,
  }
end

---@param prefs ChordSlopPreferences
---@param index integer
function M.delete_user_preset(prefs, index)
  if index >= 1 and index <= #prefs.presets then
    prefs.presets:remove(index)
  end
end

return M
