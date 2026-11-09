--[[
  ViewBuilder UI for the main dialog. Builds the view tree and returns the
  builder (so the dev bridge can map ids to views), the root view and a
  controller table that `src/app.lua` drives from MIDI and key events.

  Layout (about 960 x 520):
    header   key, mode, transpose pads | presets
    body     circle of fifths panel    | 4x4 pad grid + pad editor
    footer   MIDI device, pad 1 note, learn | QWERTY, animate | status
]]

local theory = require "src.theory"
local pads_mod = require "src.pads"
local colors = require "src.colors"
local store = require "src.store"
local player = require "src.player"
local input = require "src.input"
local circle = require "src.circle"
local anim = require "src.anim"
local presets = require "src.presets"

local M = {}

local SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
local GAP = renoise.ViewBuilder.DEFAULT_DIALOG_SPACING
local MARGIN = 12
local PANEL_GAP = 16
local PAD_W, PAD_H, PAD_GAP = 122, 64, 6
local GRID_COLS, GRID_ROWS = 4, 4
local GRID_W = GRID_COLS * PAD_W + (GRID_COLS - 1) * PAD_GAP
local LABEL_H = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT
local CIRCLE_SIZE = 400
local CIRCLE_W = CIRCLE_SIZE + 2 * renoise.ViewBuilder.DEFAULT_DIALOG_SPACING -- circle_panel incl. margin

---Held-note slots for things that are not pads (ring and centre buttons).
local HELD_OUTER, HELD_INNER, HELD_CENTER = 100, 200, 300

---@class UiController
---@field pads Pad[]
---@field selected integer Selected pad index.
---@field key integer Root key 0-11.
---@field mode integer 1-7.
---@field learn_armed boolean Next MIDI note-on sets the base note.
---@field circle_mode integer 1 = play, 2 = assign to the selected pad.
---@field preset_name string? The preset the pads came from; nil when unknown.
---@field dirty boolean The pads were edited since that preset was loaded.
---@field press fun(index: integer, velocity: integer?, from_midi: boolean?)
---@field release fun(index: integer)
---@field learned fun(note: integer)
---@field refresh_all fun()
---@field load_preset fun(index: integer) Preset index: factory first, then user presets.
---@field save_preset fun(name: string)
---@field delete_preset fun() Delete the preset the pads came from (user presets only).
---@field destroy fun()

---Key popup labels: both spellings so every key reads naturally.
local KEY_ITEMS =
  { "C", "C# / Db", "D", "D# / Eb", "E", "F", "F# / Gb", "G", "G# / Ab", "A", "A# / Bb", "B" }

local TIP_KEY = "Key: the root note everything is measured from. "
  .. "Changing it turns the circle and, with Transpose pads on, moves every pad along."
local TIP_MODE = "Mode: the scale built on the key (major, minor, Dorian...). "
  .. "It decides which chords count as in key (green) and how the circle is shaded. "
  .. "A preset you picked and have not edited is re-rendered in the new mode."
local TIP_PRESET_BASE = "Presets are ready-made layouts of 16 chords; pick one and it lands on the pads. "
  .. "Factory presets are written as scale degrees and render into the current key and mode; so do the ones you save. "
  .. "An asterisk after the name means the pads were edited since; pick the preset again to get it back."
local TIP_MIDI_BASE = "The lowest MIDI note of the controller pads; the 16 pads answer to this note and the "
  .. "15 above it, arranged by the layout next to it. Default C-3 (note 36) is pad 1 of bank A on an AKAI "
  .. "MPK mini. Or press Learn and hit that pad."
local TIP_LAYOUT = "How the 16 controller notes land on the grid. Rows top to bottom: lowest note top-left. "
  .. "Rows bottom to top: lowest note bottom-left, like a drum machine. MPK mini banks: bank A on the top "
  .. "two rows and bank B below, each laid out like the controller (pads 1-4 bottom, 5-8 top)."

---@return string[]
local function mode_items()
  local items = {}
  for i, mode in ipairs(theory.MODES) do
    items[i] = mode.name
  end
  return items
end

---@return string[]
local function layout_items()
  local items = {}
  for i, layout in ipairs(input.LAYOUTS) do
    items[i] = layout.name
  end
  return items
end

---@return string[]
local function type_items()
  local items = { "(empty)" }
  for i, chord in ipairs(theory.CHORD_TYPES) do
    items[i + 1] = chord.id
  end
  return items
end

---Renoise-style note name with octave for a MIDI/Renoise note value.
---@param note number
---@return string
local function note_label(note)
  note = math.floor(note)
  local name = theory.NOTE_NAMES_SHARP[(note % 12) + 1]
  if #name == 1 then
    name = name .. "-"
  end
  return ("%s%d"):format(name, math.floor(note / 12))
end

---Parse "C-3" / "C#3" / "48" back into a note value.
---@param text string
---@return number?
local function parse_note(text)
  local n = tonumber(text)
  if n then
    return n
  end
  local name, octave = text:upper():match "^%s*([A-G]#?)%-?(%d)%s*$"
  if not name then
    return nil
  end
  for pc, candidate in ipairs(theory.NOTE_NAMES_SHARP) do
    if candidate == name then
      return (pc - 1) + tonumber(octave) * 12
    end
  end
  return nil
end

---Short chord label for a ring button ("Bb", "F#m", "B°").
---@param chord RingChord
---@return string
local function ring_label(chord)
  local id = theory.CHORD_TYPES[chord.type].id
  local suffix = ""
  if id == "min" then
    suffix = "m"
  elseif id == "dim" then
    suffix = "°"
  end
  return theory.note_name(chord.root, chord.flats) .. suffix
end

---@param app table The application module (`src/app.lua`).
---@param palette PadPalette
---@return renoise.ViewBuilder vb, renoise.Views.View root, UiController ctl
function M.build(app, palette)
  local vb = renoise.ViewBuilder()
  local prefs = app.prefs()

  local ctl = {
    pads = store.load_pads(prefs),
    selected = 1,
    key = prefs.root_key.value,
    mode = prefs.mode.value,
    learn_armed = false,
    circle_mode = 1,
    preset_name = prefs.preset_name.value ~= "" and prefs.preset_name.value or nil,
    dirty = prefs.preset_dirty.value,
  }
  if pads_mod.all_empty(ctl.pads) then
    ctl.pads = presets.render(presets.FACTORY[1], ctl.key, ctl.mode)
    store.save_pads(prefs, ctl.pads)
    ctl.preset_name, ctl.dirty = presets.FACTORY[1].name, false
    prefs.preset_name.value, prefs.preset_dirty.value = ctl.preset_name, false
  end
  ---@type table<integer, boolean> pads currently sounding
  local active = {}
  ---@type table<string, boolean> ring buttons currently sounding, by "ring_k"
  local ring_active = {}
  ---@type fun(k: integer, ring: "outer"|"inner")
  local refresh_ring

  ---@param pad Pad
  ---@return string? key ("outer_3") of the ring button holding the pad chord
  local function ring_key_of(pad)
    if pads_mod.is_empty(pad) then
      return nil
    end
    local ring, k = circle.ring_for_pad(pad)
    return ("%s_%d"):format(ring, k)
  end

  ---Is a ring button lit because a pad holding its chord is pressed?
  ---@param ring_key string
  ---@return boolean
  local function ring_lit_by_pads(ring_key)
    for i, pad in ipairs(ctl.pads) do
      if active[i] and ring_key_of(pad) == ring_key then
        return true
      end
    end
    return false
  end
  local syncing = false -- true while the code (not the user) sets control values
  ---@type fun()
  local refresh_circle
  ---@type fun() The pads no longer are the preset they came from (defined with the presets).
  local mark_dirty

  local function flats()
    return theory.prefers_flats(ctl.key, ctl.mode)
  end

  -- Pads ---------------------------------------------------------------------

  ---@param i integer
  local function refresh_pad(i)
    local pad = ctl.pads[i]
    local name, numeral, func = pads_mod.label(pad, ctl.key, ctl.mode)
    local button = vb.views["pad_" .. i] --[[@as renoise.Views.Button]]
    local label = vb.views["num_" .. i] --[[@as renoise.Views.Text]]
    local color = colors.for_function(palette, func)
    local lit_by_ring = ring_active[ring_key_of(pad) or ""]
    if active[i] or i == ctl.selected or lit_by_ring then
      color = palette.highlight(color)
    end
    button.text = name
    button.color = color
    button.tooltip = ("Pad %d · key %s · MIDI %s"):format(
      i,
      input.PAD_KEYS[i],
      note_label(input.pad_note(i, prefs.midi_base_note.value, prefs.midi_layout.value))
    )
    label.text = numeral
    label.style = (i == ctl.selected) and "strong" or "normal"
  end

  local function refresh_pads()
    for i = 1, pads_mod.COUNT do
      refresh_pad(i)
    end
  end

  local function refresh_editor()
    local pad = ctl.pads[ctl.selected]
    syncing = true
    local title = vb.views.editor_title --[[@as renoise.Views.Text]]
    title.text = ("Pad %d"):format(ctl.selected)
    local root = vb.views.pad_root --[[@as renoise.Views.Popup]]
    root.value = pad.root + 1
    local kind = vb.views.pad_type --[[@as renoise.Views.Popup]]
    kind.value = pad.type + 1
    local inv = vb.views.pad_inv --[[@as renoise.Views.ValueBox]]
    inv.value = pad.inversion
    local oct = vb.views.pad_oct --[[@as renoise.Views.ValueBox]]
    oct.value = pad.octave
    local notes = pads_mod.notes(pad)
    local names = {}
    for n, note in ipairs(notes) do
      names[n] = note_label(note)
    end
    local preview = vb.views.editor_notes --[[@as renoise.Views.Text]]
    preview.text = #names > 0 and table.concat(names, "  ") or "empty"
    syncing = false
  end

  local function refresh_key_label()
    local view = vb.views.key_label --[[@as renoise.Views.Text]]
    local names = {}
    for i, pc in ipairs(theory.scale(ctl.key, ctl.mode)) do
      names[i] = theory.note_name(pc, flats())
    end
    view.text = table.concat(names, "   ")
  end

  local function refresh_status()
    local view = vb.views.status --[[@as renoise.Views.Text]]
    local song = renoise.song()
    if not song then
      view.text = "No song"
      return
    end
    local transport = song.transport
    local track = song.selected_track
    if not transport.edit_mode then
      view.text = "Edit mode off: pads audition only"
    elseif track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      view.text = "Select a sequencer track to record"
    elseif transport.playing then
      view.text = ("Live record on %s"):format(track.name)
    else
      view.text = ("Step record on %s, edit step %d"):format(track.name, transport.edit_step)
    end
  end

  function ctl.refresh_all()
    refresh_pads()
    refresh_editor()
    refresh_key_label()
    refresh_status()
    if refresh_circle then
      refresh_circle()
    end
  end

  local function save_pads()
    store.save_pads(prefs, ctl.pads)
  end

  ---@param i integer
  local function select_pad(i)
    local previous = ctl.selected
    ctl.selected = i
    refresh_pad(previous)
    refresh_pad(i)
    refresh_editor()
  end

  ---Redraw the ring button that holds the chord of pad `i`, once the circle exists.
  ---@param i integer
  local function refresh_ring_for_pad(i)
    local pad = ctl.pads[i]
    if refresh_ring and not pads_mod.is_empty(pad) then
      local ring, k = circle.ring_for_pad(pad)
      refresh_ring(k, ring)
    end
  end

  function ctl.press(i, velocity, from_midi)
    player.press(i, ctl.pads[i], velocity, from_midi)
    active[i] = true
    refresh_pad(i)
    refresh_ring_for_pad(i)
  end

  function ctl.release(i)
    player.release(i)
    active[i] = nil
    refresh_pad(i)
    refresh_ring_for_pad(i)
  end

  ---@param update fun(pad: Pad)
  local function edit_selected(update)
    if syncing then
      return
    end
    update(ctl.pads[ctl.selected])
    ctl.pads[ctl.selected] = pads_mod.normalize(ctl.pads[ctl.selected])
    save_pads()
    mark_dirty()
    refresh_pad(ctl.selected)
    refresh_editor()
  end

  -- Key and mode ---------------------------------------------------------------

  ---Turn the circle (labels and wedge) to the current key and mode.
  local function animate_circle()
    anim.go(
      circle.target_rotation(ctl.key),
      circle.wedge_deg(ctl.key, ctl.mode),
      prefs.animate.value
    )
  end

  ---@param new_key integer 0-11
  local function set_key(new_key)
    if new_key == ctl.key then
      return
    end
    local delta = new_key - ctl.key
    if delta > 6 then
      delta = delta - 12
    elseif delta < -6 then
      delta = delta + 12
    end
    if prefs.transpose_pads.value then
      ctl.pads = pads_mod.transpose(ctl.pads, delta)
      save_pads()
    else
      mark_dirty() -- the pads are no longer the preset rendered in this key
    end
    ctl.key = new_key
    prefs.root_key.value = new_key
    ctl.refresh_all()
    animate_circle()
  end

  ---@param new_mode integer 1-7
  ---@param refresh boolean? Refresh and animate right away (default true).
  local function set_mode(new_mode, refresh)
    if new_mode == ctl.mode then
      return
    end
    ctl.mode = new_mode
    prefs.mode.value = new_mode
    syncing = true
    local popup = vb.views.mode --[[@as renoise.Views.Popup]]
    popup.value = new_mode
    syncing = false
    if refresh ~= false then
      ctl.refresh_all()
      animate_circle()
    end
  end

  -- MIDI -----------------------------------------------------------------------

  local function midi_items()
    local items = { "No MIDI input" }
    for _, name in ipairs(renoise.Midi.available_input_devices()) do
      items[#items + 1] = name
    end
    return items
  end

  local function refresh_midi_popup()
    local popup = vb.views.midi_device --[[@as renoise.Views.Popup]]
    local items = midi_items()
    local value = table.find(items, prefs.midi_device.value) or 1
    syncing = true
    popup.items = items
    popup.value = value --[[@as integer]]
    syncing = false
  end

  local function refresh_learn()
    local button = vb.views.learn --[[@as renoise.Views.Button]]
    button.text = ctl.learn_armed and "Hit pad 1..." or "Learn"
    button.color = ctl.learn_armed and palette.borrowed or { 0, 0, 0 }
  end

  function ctl.learned(note)
    ctl.learn_armed = false
    prefs.midi_base_note.value = math.min(note, 127 - pads_mod.COUNT + 1)
    refresh_learn()
    refresh_pads()
    renoise.app():show_status(("ChordSlop: pads start at MIDI note %s"):format(note_label(note)))
  end

  -- Presets --------------------------------------------------------------------

  local PRESET_SEPARATOR = "----"
  local PRESET_NONE = "(unsaved)"
  local factory_count = #presets.FACTORY

  ---Every preset by name: factory first, then the user's own after a separator.
  ---@return string[]
  local function preset_items()
    local items = presets.names()
    local user = store.user_preset_names(prefs)
    if #user > 0 then
      items[#items + 1] = PRESET_SEPARATOR
      for _, name in ipairs(user) do
        items[#items + 1] = name
      end
    end
    return items
  end

  ---Preset index -> user preset index, or nil for factory entries and the separator.
  ---@param index integer
  ---@return integer?
  local function user_index(index)
    local u = index - factory_count - 1
    if u >= 1 and u <= #store.user_preset_names(prefs) then
      return u
    end
    return nil
  end

  ---The preset behind a preset index, if any.
  ---@param index integer
  ---@return Preset?
  local function preset_at(index)
    if index >= 1 and index <= factory_count then
      return presets.FACTORY[index]
    end
    local u = user_index(index)
    if u then
      return store.load_user_preset(prefs, u)
    end
    return nil
  end

  ---Preset index of a name (factory wins on a clash), or nil.
  ---@param name string?
  ---@return integer?
  local function find_preset(name)
    if not name then
      return nil
    end
    for i, item in ipairs(preset_items()) do
      if item == name then
        return i
      end
    end
    return nil
  end

  ---Is the status entry ("<name> *" or "(unsaved)") at the top of the popup?
  ---@return integer 1 when it is, else 0
  local function popup_offset()
    return (ctl.dirty or not find_preset(ctl.preset_name)) and 1 or 0
  end

  ---Rebuild the popup: the origin preset selected, or a status entry on top when
  ---the pads drifted from it ("<name> *") or came from nowhere ("(unsaved)").
  local function refresh_presets()
    local popup = vb.views.preset --[[@as renoise.Views.Popup]]
    local items = preset_items()
    local origin = find_preset(ctl.preset_name)
    local value = origin
    if ctl.dirty or not origin then
      table.insert(items, 1, origin and (ctl.preset_name .. " *") or PRESET_NONE)
      value = 1
    end
    syncing = true
    popup.items = items
    popup.value = value --[[@as integer]]
    syncing = false
    local preset = origin and preset_at(origin) or nil
    local tip = TIP_PRESET_BASE
    if preset then
      tip = ("%s\n\n%s%s"):format(
        preset.name,
        preset.desc or "Your own preset.",
        "\n\n" .. TIP_PRESET_BASE
      )
      if preset.mode then
        tip = tip
          .. ("\nWritten in %s; loading switches the mode."):format(theory.MODES[preset.mode].name)
      end
    end
    popup.tooltip = tip
    local del = vb.views.preset_delete --[[@as renoise.Views.Button]]
    del.active = origin ~= nil and user_index(origin) ~= nil
  end

  ---Remember where the pads came from and whether they still are that.
  ---@param name string?
  ---@param dirty boolean
  local function set_origin(name, dirty)
    ctl.preset_name, ctl.dirty = name, dirty
    prefs.preset_name.value = name or ""
    prefs.preset_dirty.value = dirty
    refresh_presets()
  end

  mark_dirty = function()
    if ctl.preset_name and not ctl.dirty then
      set_origin(ctl.preset_name, true)
    end
  end

  ---The preset the pads came from, if it still exists.
  ---@return Preset?
  local function origin_preset()
    local index = find_preset(ctl.preset_name)
    return index and preset_at(index) or nil
  end

  ---Mode change from the user: an unedited preset is re-rendered in the new mode.
  ---@param new_mode integer 1-7
  local function change_mode(new_mode)
    if new_mode == ctl.mode then
      return
    end
    local preset = not ctl.dirty and origin_preset() or nil
    if preset then
      ctl.pads = presets.remode(preset, ctl.pads, ctl.key, ctl.mode, new_mode)
      save_pads()
    end
    set_mode(new_mode)
  end

  function ctl.load_preset(index)
    local preset = preset_at(index)
    if not preset then
      refresh_presets() -- the separator: snap the popup back
      return
    end
    if preset.mode and preset.mode ~= ctl.mode then
      set_mode(preset.mode, false)
    end
    ctl.pads = presets.render(preset, ctl.key, ctl.mode)
    save_pads()
    ctl.selected = 1
    set_origin(preset.name, false)
    ctl.refresh_all()
    animate_circle()
    renoise.app():show_status(("ChordSlop: %s. %s"):format(preset.name, preset.desc or ""))
  end

  function ctl.save_preset(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
      name = ("Preset %d"):format(#store.user_preset_names(prefs) + 1)
    end
    store.save_user_preset(prefs, presets.capture(ctl.pads, ctl.key, ctl.mode, name))
    set_origin(name, false)
    renoise.app():show_status(
      ("ChordSlop: saved %s (relative to %s %s)"):format(
        name,
        theory.note_name(ctl.key, flats()),
        theory.MODES[ctl.mode].short
      )
    )
  end

  function ctl.delete_preset()
    local origin = find_preset(ctl.preset_name)
    local u = origin and user_index(origin)
    if not u then
      return
    end
    store.delete_user_preset(prefs, u)
    set_origin(nil, false)
  end

  -- Circle of fifths -------------------------------------------------------------

  local layout = circle.layout(CIRCLE_SIZE)
  local rotation = circle.target_rotation(ctl.key)
  local wedge = circle.wedge_deg(ctl.key, ctl.mode)
  local ring_outer, ring_inner = circle.ring_chords(ctl.key, ctl.mode)

  ---@param ctx renoise.Views.Canvas.Context
  local function draw_wheel(ctx)
    local L = layout
    ctx:translate(L.cx, L.cy)
    ctx:rotate(math.rad(rotation))
    -- disc
    ctx.fill_color = "button_back"
    ctx:begin_path()
    ctx:arc(0, 0, L.r_edge, 0, 2 * math.pi)
    ctx:fill()
    -- in-key wedge
    local a0, a1 = circle.wedge_arc_deg(wedge)
    local c = palette.in_key
    ctx.fill_color = { c[1], c[2], c[3], 96 }
    ctx:begin_path()
    ctx:move_to(0, 0)
    ctx:arc(0, 0, L.r_edge, math.rad(a0 - 90), math.rad(a1 - 90))
    ctx:close_path()
    ctx:fill()
    -- ring separators and spokes
    ctx.stroke_color = { 255, 255, 255, 28 }
    ctx.line_width = 1
    for _, r in ipairs { L.r_edge - 1, (L.r_outer + L.r_inner) / 2 } do
      ctx:begin_path()
      ctx:arc(0, 0, r, 0, 2 * math.pi)
      ctx:stroke()
    end
    for k = 0, circle.POSITIONS - 1 do
      local a = math.rad(k * circle.STEP_DEG + circle.STEP_DEG / 2 - 90)
      ctx:begin_path()
      ctx:move_to(L.r_hole * math.cos(a), L.r_hole * math.sin(a))
      ctx:line_to(L.r_edge * math.cos(a), L.r_edge * math.sin(a))
      ctx:stroke()
    end
    -- centre hole
    ctx.fill_color = "body_back"
    ctx:begin_path()
    ctx:arc(0, 0, L.r_hole, 0, 2 * math.pi)
    ctx:fill()
    -- tonic marker, fixed at 12 o'clock
    ctx:set_transform(1, 0, 0, 1, 0, 0)
    ctx.fill_color = palette.in_key
    ctx:begin_path()
    ctx:move_to(L.cx - 8, 0)
    ctx:line_to(L.cx + 8, 0)
    ctx:line_to(L.cx, 10)
    ctx:close_path()
    ctx:fill()
  end

  ---@param k integer
  ---@param ring "outer"|"inner"
  ---@return Pad pad, RingChord chord
  local function ring_pad(k, ring)
    local chord = (ring == "outer") and ring_outer[k + 1] or ring_inner[k + 1]
    return { root = chord.root, type = chord.type, inversion = 0, octave = pads_mod.DEFAULT_OCTAVE },
      chord
  end

  ---Redraw every pad whose chord sits on this ring button.
  ---@param ring_key string
  local function refresh_pads_on_ring(ring_key)
    for i, pad in ipairs(ctl.pads) do
      if ring_key_of(pad) == ring_key then
        refresh_pad(i)
      end
    end
  end

  ---@param k integer
  ---@param ring "outer"|"inner"
  local function ring_pressed(k, ring)
    local pad = ring_pad(k, ring)
    if ctl.circle_mode == 2 then
      ctl.pads[ctl.selected] = pad
      save_pads()
      mark_dirty()
      refresh_pad(ctl.selected)
      refresh_editor()
    end
    local ring_key = ("%s_%d"):format(ring, k)
    ring_active[ring_key] = true
    refresh_ring(k, ring)
    refresh_pads_on_ring(ring_key)
    player.press((ring == "outer" and HELD_OUTER or HELD_INNER) + k, pad, nil, false)
  end

  ---@param k integer
  ---@param ring "outer"|"inner"
  local function ring_released(k, ring)
    player.release((ring == "outer" and HELD_OUTER or HELD_INNER) + k)
    local ring_key = ("%s_%d"):format(ring, k)
    ring_active[ring_key] = nil
    refresh_ring(k, ring)
    refresh_pads_on_ring(ring_key)
    if ctl.circle_mode == 2 then
      select_pad(ctl.selected % pads_mod.COUNT + 1)
    end
  end

  ---@return Pad
  local function tonic_pad()
    local root, type_index = theory.diatonic_chord(ctl.key, ctl.mode, 1, false)
    return { root = root, type = type_index, inversion = 0, octave = pads_mod.DEFAULT_OCTAVE }
  end

  ---@param rot number
  ---@param wedge_deg number
  local function apply_angles(rot, wedge_deg)
    rotation = rot
    wedge = wedge_deg
    for k = 0, circle.POSITIONS - 1 do
      for _, ring in ipairs { "outer", "inner" } do
        local button = vb.views[("ring_%s_%d"):format(ring, k)] --[[@as renoise.Views.Button]]
        button.origin = circle.origin(layout, k, ring, rotation)
      end
    end
    local canvas = vb.views.wheel --[[@as renoise.Views.Canvas]]
    canvas:update()
  end

  function refresh_ring(k, ring)
    local chord = (ring == "outer") and ring_outer[k + 1] or ring_inner[k + 1]
    local button = vb.views[("ring_%s_%d"):format(ring, k)] --[[@as renoise.Views.Button]]
    local ring_key = ("%s_%d"):format(ring, k)
    local color = chord.in_key and palette.in_key or { 0, 0, 0 }
    if ring_active[ring_key] or ring_lit_by_pads(ring_key) then
      color = palette.highlight(color)
    end
    button.text = ring_label(chord)
    button.color = color
    button.tooltip = chord.numeral and ("%s in this key"):format(chord.numeral) or "Outside the key"
  end

  function refresh_circle()
    ring_outer, ring_inner = circle.ring_chords(ctl.key, ctl.mode)
    local use_flats = flats()
    for k = 0, circle.POSITIONS - 1 do
      refresh_ring(k, "outer")
      refresh_ring(k, "inner")
    end
    local center = vb.views.center --[[@as renoise.Views.Button]]
    center.text = ("%s %s"):format(
      theory.note_name(ctl.key, use_flats),
      theory.MODES[ctl.mode].short
    )
    local canvas = vb.views.wheel --[[@as renoise.Views.Canvas]]
    canvas:update()
  end

  local circle_stack = vb:stack {
    id = "circle",
    size = { width = CIRCLE_SIZE, height = CIRCLE_SIZE },
    autosize = false,
  }
  circle_stack:add_view(vb:canvas {
    id = "wheel",
    size = { width = CIRCLE_SIZE, height = CIRCLE_SIZE },
    mode = "transparent",
    render = app.guard(draw_wheel),
  })
  for k = 0, circle.POSITIONS - 1 do
    for _, ring in ipairs { "outer", "inner" } do
      local outer = ring == "outer"
      circle_stack:add_view(vb:button {
        id = ("ring_%s_%d"):format(ring, k),
        origin = circle.origin(layout, k, ring, rotation),
        size = {
          width = outer and layout.btn_w or layout.btn_w_inner,
          height = outer and layout.btn_h or layout.btn_h_inner,
        },
        style = "rounded",
        font = outer and "bold" or "normal",
        pressed = app.guard(function()
          ring_pressed(k, ring)
        end),
        released = app.guard(function()
          ring_released(k, ring)
        end),
      })
    end
  end
  circle_stack:add_view(vb:button {
    id = "center",
    origin = circle.center_origin(layout),
    size = { width = layout.center_w, height = layout.center_h },
    style = "rounded",
    font = "bold",
    tooltip = "The key: press to hear the tonic chord",
    pressed = app.guard(function()
      player.press(HELD_CENTER, tonic_pad(), nil, false)
    end),
    released = app.guard(function()
      player.release(HELD_CENTER)
    end),
  })

  -- Views ----------------------------------------------------------------------

  ---@param i integer
  ---@return renoise.Views.Rack
  local function pad_view(i)
    return vb:column {
      spacing = 0,
      vb:button {
        id = "pad_" .. i,
        size = { width = PAD_W, height = PAD_H },
        font = "big",
        pressed = app.guard(function()
          select_pad(i)
          ctl.press(i, nil, false)
        end),
        released = app.guard(function()
          ctl.release(i)
        end),
      },
      vb:row {
        spacing = 0,
        vb:text {
          id = "num_" .. i,
          size = { width = PAD_W - 28, height = LABEL_H },
          align = "left",
          tooltip = "Roman numeral of this chord in the current key",
        },
        vb:text {
          id = "keycap_" .. i,
          size = { width = 28, height = LABEL_H },
          align = "right",
          style = "disabled",
          font = "mono",
          text = input.PAD_KEYS[i],
          tooltip = "Computer key that plays this pad while the window has focus",
        },
      },
    }
  end

  local grid = vb:column { id = "grid", spacing = PAD_GAP }
  for row = 0, GRID_ROWS - 1 do
    local r = vb:row { spacing = PAD_GAP }
    for col = 1, GRID_COLS do
      r:add_view(pad_view(row * GRID_COLS + col))
    end
    grid:add_view(r)
  end

  -- Two halves as wide as the panels below, so the controls line up with them.
  local header = vb:row {
    id = "header",
    spacing = PANEL_GAP,
    vb:horizontal_aligner { -- a plain row shrinks to its content; an aligner keeps its width
      id = "header_left",
      mode = "left",
      width = CIRCLE_W,
      spacing = SPACING,
      vb:text { text = "Key", style = "disabled", tooltip = TIP_KEY },
      vb:popup {
        id = "key",
        width = 80,
        items = KEY_ITEMS,
        value = ctl.key + 1,
        tooltip = TIP_KEY,
        notifier = app.guard(function(value)
          if not syncing then
            set_key(value - 1)
          end
        end),
      },
      vb:popup {
        id = "mode",
        width = 124,
        items = mode_items(),
        value = ctl.mode,
        tooltip = TIP_MODE,
        notifier = app.guard(function(value)
          if not syncing then
            change_mode(value)
          end
        end),
      },
      vb:space { width = GAP },
      vb:checkbox { id = "transpose", bind = prefs.transpose_pads },
      vb:text {
        text = "Transpose pads with key",
        tooltip = "On: changing the key moves every pad with it. Off: the pads stay and only their numerals and colours follow the key.",
      },
    },
    vb:horizontal_aligner {
      id = "header_right",
      mode = "justify",
      width = GRID_W,
      vb:row {
        spacing = SPACING,
        vb:text { text = "Preset", style = "disabled", tooltip = TIP_PRESET_BASE },
        vb:popup {
          id = "preset",
          width = 200,
          items = preset_items(),
          tooltip = TIP_PRESET_BASE,
          notifier = app.guard(function(value)
            if not syncing then
              ctl.load_preset(value - popup_offset())
            end
          end),
        },
      },
      vb:row {
        spacing = SPACING,
        vb:textfield {
          id = "preset_name",
          width = 120,
          tooltip = "Name for saving the current pads as your own preset",
        },
        vb:button {
          id = "preset_save",
          text = "Save",
          tooltip = "Save the current pads as a preset of yours. It is stored relative to the key, so it follows key changes like the factory ones.",
          notifier = app.guard(function()
            local field = vb.views.preset_name --[[@as renoise.Views.TextField]]
            ctl.save_preset(field.value)
          end),
        },
        vb:button {
          id = "preset_delete",
          text = "Delete",
          tooltip = "Delete the chosen preset of yours (factory presets cannot be deleted)",
          notifier = app.guard(function()
            ctl.delete_preset()
          end),
        },
      },
    },
  }

  local circle_panel = vb:column {
    id = "circle_panel",
    style = "group",
    margin = GAP,
    spacing = GAP,
    circle_stack,
    vb:horizontal_aligner {
      mode = "justify",
      vb:switch {
        id = "circle_mode",
        width = 190,
        items = { "Play", "Assign to pad" },
        value = ctl.circle_mode,
        tooltip = "Play: clicking a chord on the circle just plays it. Assign: it also lands on the selected pad, then the selection moves to the next pad.",
        notifier = app.guard(function(value)
          ctl.circle_mode = value
        end),
      },
      vb:text {
        id = "key_label",
        style = "disabled",
        font = "mono",
        tooltip = "The notes of the current key and mode",
      },
    },
  }

  local editor = vb:row {
    id = "editor",
    spacing = GAP,
    style = "group",
    margin = GAP,
    size = { width = GRID_W, height = LABEL_H + 2 * GAP },
    vb:text { id = "editor_title", font = "bold", width = 44, tooltip = "The selected pad" },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Root", style = "disabled" },
      vb:popup {
        id = "pad_root",
        width = 80,
        items = KEY_ITEMS,
        tooltip = "Root note of the selected pad's chord",
        notifier = app.guard(function(value)
          edit_selected(function(pad)
            pad.root = value - 1
            if pad.type == 0 then
              pad.type = 1
            end
          end)
        end),
      },
    },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Type", style = "disabled" },
      vb:popup {
        id = "pad_type",
        width = 76,
        items = type_items(),
        tooltip = "Chord type of the selected pad",
        notifier = app.guard(function(value)
          edit_selected(function(pad)
            pad.type = value - 1
          end)
        end),
      },
    },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Inv", style = "disabled" },
      vb:valuebox {
        id = "pad_inv",
        width = 50,
        min = 0,
        max = pads_mod.MAX_INVERSION,
        tooltip = "Inversion: how many of the lowest chord tones move up an octave",
        notifier = app.guard(function(value)
          edit_selected(function(pad)
            pad.inversion = value
          end)
        end),
      },
    },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Oct", style = "disabled" },
      vb:valuebox {
        id = "pad_oct",
        width = 50,
        min = pads_mod.MIN_OCTAVE,
        max = pads_mod.MAX_OCTAVE,
        tooltip = "Octave of the chord root (4 = C-4 territory)",
        notifier = app.guard(function(value)
          edit_selected(function(pad)
            pad.octave = value
          end)
        end),
      },
    },
    vb:button {
      id = "pad_clear",
      text = "Clear",
      tooltip = "Empty the selected pad",
      notifier = app.guard(function()
        edit_selected(function(pad)
          pad.type = 0
        end)
      end),
    },
  }

  local pads_panel = vb:column {
    id = "pads_panel",
    spacing = GAP,
    grid,
    editor,
    vb:text {
      id = "editor_notes",
      style = "disabled",
      font = "mono",
      tooltip = "The notes the selected pad plays, lowest first",
    },
  }

  local footer = vb:horizontal_aligner {
    id = "footer",
    mode = "justify",
    vb:row {
      spacing = SPACING,
      vb:text {
        text = "MIDI",
        style = "disabled",
        tooltip = "MIDI input device for triggering pads",
      },
      vb:popup {
        id = "midi_device",
        width = 190,
        items = midi_items(),
        tooltip = "MIDI input device whose notes trigger the pads. Remove it from Renoise's own MIDI inputs (Preferences > MIDI), or edit mode records the raw pad note as well.",
        notifier = app.guard(function(value)
          if syncing then
            return
          end
          local popup = vb.views.midi_device --[[@as renoise.Views.Popup]]
          local name = value > 1 and popup.items[value] or ""
          prefs.midi_device.value = name
          app.set_midi_device(name)
        end),
      },
      vb:popup {
        id = "midi_layout",
        width = 150,
        items = layout_items(),
        bind = prefs.midi_layout,
        tooltip = TIP_LAYOUT,
        notifier = app.guard(function()
          refresh_pads()
        end),
      },
      vb:space { width = GAP },
      vb:text { text = "Low note", style = "disabled", tooltip = TIP_MIDI_BASE },
      vb:valuebox {
        id = "midi_base",
        width = 64,
        min = 0,
        max = 127 - pads_mod.COUNT + 1,
        bind = prefs.midi_base_note,
        tostring = note_label,
        tonumber = parse_note,
        tooltip = TIP_MIDI_BASE,
        notifier = app.guard(function()
          refresh_pads()
        end),
      },
      vb:button {
        id = "learn",
        text = "Learn",
        tooltip = "Press, then hit the controller pad that sends the lowest note; the other pads follow chromatically",
        notifier = app.guard(function()
          ctl.learn_armed = not ctl.learn_armed
          refresh_learn()
        end),
      },
      vb:space { width = GAP },
      vb:checkbox { id = "qwerty", bind = prefs.qwerty_enabled },
      vb:text {
        text = "QWERTY pads",
        tooltip = "Play pads 1-16 from the keyboard (z s x d ... q 2 w 3) while this window has focus",
      },
      vb:space { width = GAP },
      vb:checkbox { id = "animate", bind = prefs.animate },
      vb:text { text = "Animate", tooltip = "Turn the circle smoothly when the key or mode changes" },
    },
    vb:text { id = "status", style = "disabled", tooltip = "What a pad press will do right now" },
  }

  local root = vb:column {
    id = "root",
    margin = MARGIN,
    spacing = GAP,
    header,
    vb:row {
      id = "body",
      spacing = PANEL_GAP,
      circle_panel,
      pads_panel,
    },
    footer,
  }

  -- Song observers -------------------------------------------------------------

  local song = renoise.song()
  if song then
    local on_transport = app.guard(refresh_status)
    app.reg.notifier(song.transport.edit_mode_observable, on_transport)
    app.reg.notifier(song.transport.playing_observable, on_transport)
    app.reg.notifier(song.transport.edit_step_observable, on_transport)
    app.reg.notifier(song.selected_track_index_observable, on_transport)
  end

  function ctl.destroy()
    anim.stop()
  end

  refresh_midi_popup()
  refresh_learn()
  refresh_presets()
  ctl.refresh_all()
  anim.init(app, app.guard(apply_angles), rotation, wedge)
  return vb, root, ctl --[[@as UiController]]
end

return M
