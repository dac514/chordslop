--[[
  ViewBuilder UI for the main dialog. Builds the view tree and returns the
  builder (so the dev bridge can map ids to views), the root view and a
  controller table that `src/app.lua` drives from MIDI and key events.

  Layout (about 880 x 560):
    header   title | key, mode, transpose pads
    body     circle of fifths panel      | 4x4 pad grid + pad editor
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
local PAD_W, PAD_H, PAD_GAP = 104, 56, 6
local GRID_COLS, GRID_ROWS = 4, 4
local LABEL_H = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT
local CIRCLE_SIZE = 400

---Held-note slots for things that are not pads (ring and centre buttons).
local HELD_OUTER, HELD_INNER, HELD_CENTER = 100, 200, 300

---@class UiController
---@field pads Pad[]
---@field selected integer Selected pad index.
---@field key integer Root key 0-11.
---@field mode integer 1-7.
---@field learn_armed boolean Next MIDI note-on sets the base note.
---@field circle_mode integer 1 = play, 2 = assign to the selected pad.
---@field press fun(index: integer, velocity: integer?, from_midi: boolean?)
---@field release fun(index: integer)
---@field learned fun(note: integer)
---@field refresh_all fun()
---@field load_preset fun(index: integer) Popup index: factory first, then user presets.
---@field save_preset fun(name: string)
---@field delete_preset fun(index: integer)
---@field destroy fun()

---Key popup labels: both spellings so every key reads naturally.
local KEY_ITEMS =
  { "C", "C# / Db", "D", "D# / Eb", "E", "F", "F# / Gb", "G", "G# / Ab", "A", "A# / Bb", "B" }

---@return string[]
local function mode_items()
  local items = {}
  for i, mode in ipairs(theory.MODES) do
    items[i] = mode.name
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

---Pads for a first run: the diatonic triads (1-7) and sevenths (9-15) of the key.
---@param key integer
---@param mode integer
---@return Pad[]
local function default_pads(key, mode)
  local pads = {}
  for i = 1, pads_mod.COUNT do
    pads[i] = pads_mod.empty()
  end
  for degree = 1, 7 do
    local root, triad = theory.diatonic_chord(key, mode, degree, false)
    pads[degree] = { root = root, type = triad, inversion = 0, octave = pads_mod.DEFAULT_OCTAVE }
    local _, seventh = theory.diatonic_chord(key, mode, degree, true)
    pads[degree + 8] =
      { root = root, type = seventh, inversion = 0, octave = pads_mod.DEFAULT_OCTAVE }
  end
  return pads
end

---Short chord label for a ring button ("Bb", "F#m", "B°").
---@param chord RingChord
---@param flats boolean
---@return string
local function ring_label(chord, flats)
  local id = theory.CHORD_TYPES[chord.type].id
  local suffix = ""
  if id == "min" then
    suffix = "m"
  elseif id == "dim" then
    suffix = "°"
  end
  return theory.note_name(chord.root, flats) .. suffix
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
  }
  if pads_mod.all_empty(ctl.pads) then
    ctl.pads = default_pads(ctl.key, ctl.mode)
    store.save_pads(prefs, ctl.pads)
  end
  ---@type table<integer, boolean> pads currently sounding
  local active = {}
  local syncing = false -- true while the code (not the user) sets control values
  ---@type fun()
  local refresh_circle

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
    if active[i] or i == ctl.selected then
      color = palette.highlight(color)
    end
    button.text = name
    button.color = color
    button.tooltip = ("Pad %d · key %s · MIDI %s"):format(
      i,
      input.PAD_KEYS[i],
      note_label(prefs.midi_base_note.value + i - 1)
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

  function ctl.press(i, velocity, from_midi)
    player.press(i, ctl.pads[i], velocity, from_midi)
    active[i] = true
    refresh_pad(i)
  end

  function ctl.release(i)
    player.release(i)
    active[i] = nil
    refresh_pad(i)
  end

  ---@param update fun(pad: Pad)
  local function edit_selected(update)
    if syncing then
      return
    end
    update(ctl.pads[ctl.selected])
    ctl.pads[ctl.selected] = pads_mod.normalize(ctl.pads[ctl.selected])
    save_pads()
    refresh_pad(ctl.selected)
    refresh_editor()
  end

  -- Key and mode ---------------------------------------------------------------

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
    end
    ctl.key = new_key
    prefs.root_key.value = new_key
    ctl.refresh_all()
    anim.rotate_to(circle.target_rotation(new_key), prefs.animate.value)
  end

  ---@param new_mode integer 1-7
  local function set_mode(new_mode)
    if new_mode == ctl.mode then
      return
    end
    ctl.mode = new_mode
    prefs.mode.value = new_mode
    ctl.refresh_all()
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
  local factory_count = #presets.FACTORY

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

  ---Popup index -> user preset index, or nil for factory entries and the separator.
  ---@param index integer
  ---@return integer?
  local function user_index(index)
    local u = index - factory_count - 1
    if u >= 1 and u <= #store.user_preset_names(prefs) then
      return u
    end
    return nil
  end

  ---@param select integer? Popup index to select afterwards.
  local function refresh_presets(select)
    local popup = vb.views.preset --[[@as renoise.Views.Popup]]
    local items = preset_items()
    syncing = true
    popup.items = items
    if select and select >= 1 and select <= #items then
      popup.value = select
    end
    syncing = false
    local del = vb.views.preset_delete --[[@as renoise.Views.Button]]
    del.active = user_index(popup.value) ~= nil
  end

  ---@param pads Pad[]
  local function replace_pads(pads)
    ctl.pads = pads
    save_pads()
    ctl.selected = 1
    ctl.refresh_all()
  end

  function ctl.load_preset(index)
    if index <= factory_count then
      local preset = presets.FACTORY[index]
      if preset.mode and preset.mode ~= ctl.mode then
        ctl.mode = preset.mode
        prefs.mode.value = preset.mode
        syncing = true
        local mode_popup = vb.views.mode --[[@as renoise.Views.Popup]]
        mode_popup.value = preset.mode
        syncing = false
      end
      replace_pads(presets.render(preset, ctl.key, ctl.mode))
      renoise.app():show_status(("ChordSlop: loaded %s"):format(preset.name))
      return
    end
    local u = user_index(index)
    if u then
      replace_pads(store.load_user_preset(prefs, u))
      renoise.app():show_status(("ChordSlop: loaded %s"):format(store.user_preset_names(prefs)[u]))
    end
  end

  function ctl.save_preset(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
      name = ("Preset %d"):format(#store.user_preset_names(prefs) + 1)
    end
    local u = store.save_user_preset(prefs, name, ctl.pads)
    refresh_presets(factory_count + 1 + u)
    renoise.app():show_status(("ChordSlop: saved %s"):format(name))
  end

  function ctl.delete_preset(index)
    local u = user_index(index)
    if not u then
      return
    end
    store.delete_user_preset(prefs, u)
    refresh_presets(1)
  end

  -- Circle of fifths -------------------------------------------------------------

  local layout = circle.layout(CIRCLE_SIZE)
  local rotation = circle.target_rotation(ctl.key)
  local ring_outer, ring_inner = circle.ring_chords(ctl.key, ctl.mode)

  ---@param ctx renoise.Views.Canvas.Context
  local function draw_wheel(ctx)
    local L = layout
    local k_start = circle.diatonic_span(ctl.key, ctl.mode)
    ctx:translate(L.cx, L.cy)
    ctx:rotate(math.rad(rotation))
    -- disc
    ctx.fill_color = "button_back"
    ctx:begin_path()
    ctx:arc(0, 0, L.r_edge, 0, 2 * math.pi)
    ctx:fill()
    -- in-key wedge
    local a0, a1 = circle.span_arc_deg(k_start)
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

  ---@param k integer
  ---@param ring "outer"|"inner"
  local function ring_pressed(k, ring)
    local pad = ring_pad(k, ring)
    if ctl.circle_mode == 2 then
      ctl.pads[ctl.selected] = pad
      save_pads()
      refresh_pad(ctl.selected)
      refresh_editor()
    end
    player.press((ring == "outer" and HELD_OUTER or HELD_INNER) + k, pad, nil, false)
  end

  ---@param k integer
  ---@param ring "outer"|"inner"
  local function ring_released(k, ring)
    player.release((ring == "outer" and HELD_OUTER or HELD_INNER) + k)
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
  local function apply_rotation(rot)
    rotation = rot
    for k = 0, circle.POSITIONS - 1 do
      for _, ring in ipairs { "outer", "inner" } do
        local button = vb.views[("ring_%s_%d"):format(ring, k)] --[[@as renoise.Views.Button]]
        button.origin = circle.origin(layout, k, ring, rotation)
      end
    end
    local canvas = vb.views.wheel --[[@as renoise.Views.Canvas]]
    canvas:update()
  end

  function refresh_circle()
    ring_outer, ring_inner = circle.ring_chords(ctl.key, ctl.mode)
    local use_flats = flats()
    for k = 0, circle.POSITIONS - 1 do
      for _, ring in ipairs { "outer", "inner" } do
        local chord = (ring == "outer") and ring_outer[k + 1] or ring_inner[k + 1]
        local button = vb.views[("ring_%s_%d"):format(ring, k)] --[[@as renoise.Views.Button]]
        button.text = ring_label(chord, use_flats)
        button.color = chord.in_key and palette.in_key or { 0, 0, 0 }
        button.tooltip = chord.numeral and ("%s in this key"):format(chord.numeral)
          or "Outside the key"
      end
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
        },
        vb:text {
          id = "keycap_" .. i,
          size = { width = 28, height = LABEL_H },
          align = "right",
          style = "disabled",
          font = "mono",
          text = input.PAD_KEYS[i],
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

  local header = vb:horizontal_aligner {
    id = "header",
    mode = "justify",
    vb:row {
      spacing = SPACING,
      vb:text { text = "Key", style = "disabled" },
      vb:popup {
        id = "key",
        width = 80,
        items = KEY_ITEMS,
        value = ctl.key + 1,
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
        notifier = app.guard(function(value)
          if not syncing then
            set_mode(value)
          end
        end),
      },
      vb:space { width = GAP },
      vb:checkbox { id = "transpose", bind = prefs.transpose_pads },
      vb:text {
        text = "Transpose pads with key",
        tooltip = "Changing the key moves every pad with it",
      },
    },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Preset", style = "disabled" },
      vb:popup {
        id = "preset",
        width = 180,
        items = preset_items(),
        tooltip = "Factory presets follow the key and mode; your own presets are stored as written",
        notifier = app.guard(function()
          if not syncing then
            refresh_presets()
          end
        end),
      },
      vb:button {
        id = "preset_load",
        text = "Load",
        notifier = app.guard(function()
          local popup = vb.views.preset --[[@as renoise.Views.Popup]]
          ctl.load_preset(popup.value)
        end),
      },
      vb:space { width = GAP },
      vb:textfield {
        id = "preset_name",
        width = 120,
        tooltip = "Name for saving the current pads as a preset",
      },
      vb:button {
        id = "preset_save",
        text = "Save",
        notifier = app.guard(function()
          local field = vb.views.preset_name --[[@as renoise.Views.TextField]]
          ctl.save_preset(field.value)
        end),
      },
      vb:button {
        id = "preset_delete",
        text = "Delete",
        notifier = app.guard(function()
          local popup = vb.views.preset --[[@as renoise.Views.Popup]]
          ctl.delete_preset(popup.value)
        end),
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
        tooltip = "Assign: clicking a chord puts it on the selected pad and moves to the next one",
        notifier = app.guard(function(value)
          ctl.circle_mode = value
        end),
      },
      vb:text { id = "key_label", style = "disabled", font = "mono" },
    },
  }

  local editor = vb:row {
    id = "editor",
    spacing = GAP,
    style = "group",
    margin = GAP,
    vb:text { id = "editor_title", font = "bold", width = 44 },
    vb:row {
      spacing = SPACING,
      vb:text { text = "Root", style = "disabled" },
      vb:popup {
        id = "pad_root",
        width = 80,
        items = KEY_ITEMS,
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
    vb:text { id = "editor_notes", style = "disabled", font = "mono" },
  }

  local footer = vb:horizontal_aligner {
    id = "footer",
    mode = "justify",
    vb:row {
      spacing = SPACING,
      vb:text { text = "MIDI", style = "disabled" },
      vb:popup {
        id = "midi_device",
        width = 190,
        items = midi_items(),
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
      vb:text { text = "Pad 1", style = "disabled" },
      vb:valuebox {
        id = "midi_base",
        width = 64,
        min = 0,
        max = 127 - pads_mod.COUNT + 1,
        bind = prefs.midi_base_note,
        tostring = note_label,
        tonumber = parse_note,
        tooltip = "MIDI note of pad 1; pads 2-16 follow chromatically (MPK mini: C-3 = pad 1, bank A)",
        notifier = app.guard(function()
          refresh_pads()
        end),
      },
      vb:button {
        id = "learn",
        text = "Learn",
        tooltip = "Then hit the controller pad you want as pad 1",
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
      vb:text { text = "Animate", tooltip = "Turn the circle when the key changes" },
    },
    vb:text { id = "status", style = "disabled" },
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
  refresh_presets(1)
  ctl.refresh_all()
  anim.init(app, app.guard(apply_rotation), rotation)
  return vb, root, ctl --[[@as UiController]]
end

return M
