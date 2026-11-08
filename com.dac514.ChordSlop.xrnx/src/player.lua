--[[
  Plays pads through the selected instrument on the selected track and, when
  edit mode is on, records them into the pattern (see `src/record.lua` for
  the placement rules). Keeps the table of held pads so that every note-on
  gets its note-off, whatever happens to the dialog in between.
]]

local pads_mod = require "src.pads"
local record = require "src.record"

local M = {}

M.UNDO = "ChordSlop: record chord"
M.UNDO_BATCH_MS = 4000

---@class HeldPad
---@field instrument integer
---@field track integer
---@field notes integer[]
---@field rec HeldRecord? Set while live-recording, so the release can write note-offs.

---Held pads by pad index.
---@type table<integer, HeldPad>
M.held = {}

---@param transport renoise.Transport
---@param velocity integer?
---@param from_midi boolean?
---@return integer 0-127
local function effective_velocity(transport, velocity, from_midi)
  if from_midi and velocity then
    return velocity
  end
  if transport.keyboard_velocity_enabled then
    return transport.keyboard_velocity
  end
  return 127
end

---@param song renoise.Song
---@param track_index integer
---@return RecordState state, renoise.PatternTrack pattern_track, integer sequence
local function record_context(song, track_index)
  local transport = song.transport
  local sequence, line
  if transport.playing then
    local pos = transport.playback_pos
    sequence, line = pos.sequence, pos.line
  else
    sequence, line = song.selected_sequence_index, song.selected_line_index
  end
  local pattern = song:pattern(song.sequencer:pattern(sequence))
  local track = song.tracks[track_index]
  local state = {
    edit_mode = transport.edit_mode,
    playing = transport.playing,
    line = line,
    column = song.selected_note_column_index,
    visible_columns = track.visible_note_columns,
    max_columns = track.max_note_columns,
    pattern_lines = pattern.number_of_lines,
    edit_step = transport.edit_step,
    wrap = transport.wrapped_pattern_edit,
    has_next_sequence = sequence < #song.sequencer.pattern_sequence,
  }
  return state, pattern:track(track_index), sequence
end

---Trigger a pad: audition it and, in edit mode, record it.
---@param index integer Pad index 1-16.
---@param pad Pad
---@param velocity integer? 0-127 (MIDI); nil for mouse/QWERTY.
---@param from_midi boolean?
function M.press(index, pad, velocity, from_midi)
  local song = renoise.song()
  if not song or pads_mod.is_empty(pad) then
    return
  end
  if M.held[index] then
    M.release(index)
  end
  local instrument = song.selected_instrument_index
  local track_index = song.selected_track_index
  local notes = pads_mod.notes(pad)
  local vel = effective_velocity(song.transport, velocity, from_midi)
  song:trigger_instrument_note_on(instrument, track_index, notes, vel / 127)
  ---@type HeldPad
  local held = { instrument = instrument, track = track_index, notes = notes }
  M.held[index] = held

  if song.tracks[track_index].type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    if song.transport.edit_mode then
      renoise.app():show_status "ChordSlop: select a sequencer track to record chords"
    end
    return
  end
  local state, pattern_track, sequence = record_context(song, track_index)
  local plan = record.plan_note_on(state, notes, vel)
  if not plan then
    return
  end
  if state.playing then
    song:describe_batch_undo(M.UNDO, M.UNDO_BATCH_MS)
  else
    song:describe_undo(M.UNDO)
  end
  local track = song.tracks[track_index]
  if plan.visible_columns > track.visible_note_columns then
    track.visible_note_columns = plan.visible_columns
  end
  if plan.volume ~= record.EMPTY_VOLUME and not track.volume_column_visible then
    track.volume_column_visible = true
  end
  local line = pattern_track:line(plan.line)
  for i, note in ipairs(plan.notes) do
    local column = line:note_column(plan.first_column + i - 1)
    column.note_value = note
    column.instrument_value = instrument - 1
    column.volume_value = plan.volume
  end
  if plan.advance then
    if plan.advance.sequence_delta ~= 0 then
      song.selected_sequence_index = sequence + plan.advance.sequence_delta
      song.selected_line_index = math.min(plan.advance.line, song.selected_pattern.number_of_lines)
    elseif plan.advance.line ~= song.selected_line_index then
      song.selected_line_index = plan.advance.line
    end
  else
    held.rec = {
      sequence = sequence,
      line = plan.line,
      first_column = plan.first_column,
      count = #plan.notes,
    }
  end
end

---@param song renoise.Song
---@param held HeldPad
local function write_note_offs(song, held)
  local rec = held.rec
  local transport = song.transport
  if not rec or not transport.playing or not transport.edit_mode then
    return
  end
  local pos = transport.playback_pos
  if pos.sequence ~= rec.sequence or rec.sequence > #song.sequencer.pattern_sequence then
    return
  end
  if held.track > song.sequencer_track_count then
    return
  end
  local pattern = song:pattern(song.sequencer:pattern(rec.sequence))
  local off = record.plan_note_off(rec, pos.line, pattern.number_of_lines)
  if not off then
    return
  end
  song:describe_batch_undo(M.UNDO, M.UNDO_BATCH_MS)
  local line = pattern:track(held.track):line(off.line)
  for c = off.first_column, off.first_column + off.count - 1 do
    local column = line:note_column(c)
    if column.note_value == renoise.PatternLine.EMPTY_NOTE then
      column.note_value = renoise.PatternLine.NOTE_OFF
    end
  end
end

---Release a pad: stop its notes and finish any live recording.
---@param index integer
function M.release(index)
  local held = M.held[index]
  if not held then
    return
  end
  M.held[index] = nil
  local song = renoise.song()
  if not song then
    return
  end
  if held.instrument <= #song.instruments and held.track <= #song.tracks then
    pcall(song.trigger_instrument_note_off, song, held.instrument, held.track, held.notes)
  end
  write_note_offs(song, held)
end

---Release every held pad (dialog closed, focus lost, tool stopping).
function M.release_all()
  for index in pairs(M.held) do
    M.release(index)
  end
end

---Forget held pads without sending note-offs (the song they belong to is gone).
function M.clear()
  M.held = {}
end

return M
