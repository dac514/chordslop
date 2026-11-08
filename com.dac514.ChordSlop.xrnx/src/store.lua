--[[
  Preferences adapter: moves pads and user presets in and out of the
  `renoise.Document` preferences. The only place that knows the list layout.
]]

local pads_mod = require "src.pads"

local M = {}

M.PRESET_MODEL = "ChordSlopPreset"

---@class ChordSlopPresetNode : renoise.Document.DocumentNode
---@field name renoise.Document.ObservableString
---@field roots renoise.Document.ObservableNumberList
---@field types renoise.Document.ObservableNumberList
---@field inversions renoise.Document.ObservableNumberList
---@field octaves renoise.Document.ObservableNumberList

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

---@param node ChordSlopPresetNode|ChordSlopPreferences
---@param prefix string "" for a preset node, "pad_" for the preferences
---@return Pad[]
local function read_pads(node, prefix)
  return pads_mod.from_lists(
    read(node[prefix .. "roots"]),
    read(node[prefix .. "types"]),
    read(node[prefix .. "inversions"]),
    read(node[prefix .. "octaves"])
  )
end

---@param node ChordSlopPresetNode|ChordSlopPreferences
---@param prefix string
---@param pads Pad[]
local function write_pads(node, prefix, pads)
  local roots, types, inversions, octaves = pads_mod.to_lists(pads)
  write(node[prefix .. "roots"], roots)
  write(node[prefix .. "types"], types)
  write(node[prefix .. "inversions"], inversions)
  write(node[prefix .. "octaves"], octaves)
end

---@param prefs ChordSlopPreferences
---@return Pad[]
function M.load_pads(prefs)
  return read_pads(prefs, "pad_")
end

---@param prefs ChordSlopPreferences
---@param pads Pad[]
function M.save_pads(prefs, pads)
  write_pads(prefs, "pad_", pads)
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
---@param name string
---@param pads Pad[]
---@return integer index
function M.save_user_preset(prefs, name, pads)
  local index = M.find_user_preset(prefs, name)
  local entry
  if index then
    entry = prefs.presets:property(index) --[[@as ChordSlopPresetNode]]
  else
    entry = renoise.Document.instantiate(M.PRESET_MODEL) --[[@as ChordSlopPresetNode]]
    index = #prefs.presets + 1
    prefs.presets:insert(index, entry)
    entry = prefs.presets:property(index) --[[@as ChordSlopPresetNode]]
  end
  entry.name.value = name
  write_pads(entry, "", pads)
  return index
end

---@param prefs ChordSlopPreferences
---@param index integer
---@return Pad[]
function M.load_user_preset(prefs, index)
  local entry = prefs.presets:property(index) --[[@as ChordSlopPresetNode]]
  return read_pads(entry, "")
end

---@param prefs ChordSlopPreferences
---@param index integer
function M.delete_user_preset(prefs, index)
  if index >= 1 and index <= #prefs.presets then
    prefs.presets:remove(index)
  end
end

return M
