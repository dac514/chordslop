--[[
  Entry point. Renoise runs this file once every time the tool is (re)loaded.

  Keep it thin and idempotent:
  * Preferences are created here, once. `src/` reads them through
    `renoise.tool().preferences`, so a dev-bridge soft reload (which re-requires
    `src/` without re-running this file) never creates a second document.
  * Behaviour lives in `src/app.lua` and is started with `APP.start()`.
  * The dev bridge in `dev/` is loaded only when present. `just package` strips
    `dev/`, so released builds never reference it.
]]

local bundle_path = renoise.tool().bundle_path
local DEV = io.exists(bundle_path .. "dev/bridge.lua")

-- Renoise resolves relative `require` paths only while loading main.lua (its
-- working directory is elsewhere during callbacks). Make `require "src.x"`
-- work everywhere, including the dev bridge's soft reload.
package.path = bundle_path .. "?.lua;" .. package.path

-- Renoise can reload this tool by itself whenever its window regains focus after
-- a file changed (`_AUTO_RELOAD_DEBUG = true`). It is off here because opening a
-- dialog counts as "regaining focus", which makes `just reload-soft` unreliable;
-- `just reload` does a full reload through OSC instead.
_AUTO_RELOAD_DEBUG = false

-- Preferences: created once per tool load; Renoise persists them as
-- preferences.xml inside the tool folder.
--
-- The preset model must be registered before the preferences document exists:
-- Renoise instantiates the items of `presets` from preferences.xml at that moment.
if not renoise.tool().preferences then
  renoise.Document.create "ChordSlopPreset" {
    name = "",
    roots = { 0 },
    types = { 0 },
    inversions = { 0 },
    octaves = { 4 },
  }

  local function sixteen(value)
    local list = {}
    for i = 1, 16 do
      list[i] = value
    end
    return list
  end

  renoise.tool().preferences = renoise.Document.create "ChordSlopPreferences" {
    midi_device = "",
    midi_base_note = 36, -- C1: AKAI MPK mini pad 1, bank A
    qwerty_enabled = true,
    animate = true,
    root_key = 0, -- pitch class 0-11
    mode = 1, -- 1 Ionian .. 7 Locrian
    transpose_pads = true,
    pad_roots = sixteen(0),
    pad_types = sixteen(0), -- 0 = empty pad; first run loads the first factory preset
    pad_inversions = sixteen(0),
    pad_octaves = sixteen(4),
    presets = renoise.Document.DocumentList(),
  }
end

-- The application module is a deliberate global so the dev bridge can reach it
-- (`APP.dialogs`, `APP.stop()`, `APP.start()`).
APP = require "src.app"
APP.start()

if DEV then
  require("dev.bridge").start()
end
