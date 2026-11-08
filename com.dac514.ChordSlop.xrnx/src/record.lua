--[[
  Recording placement. Pure Lua: the player reads the song into a plain
  `RecordState`, this module decides where the chord goes (or that it goes
  nowhere), and the player applies the returned plan to the pattern.

  Step mode (edit mode on, transport stopped): write at the cursor line, then
  advance the cursor by the edit step the way Renoise does. Live mode (edit
  mode on, playing): write note-ons at the playhead line and, on release, note
  offs where the playhead is then.
]]

local M = {}

M.NOTE_OFF = 120
M.EMPTY_NOTE = 121
M.EMPTY_VOLUME = 255
M.MAX_COLUMNS = 12

---@class RecordState
---@field edit_mode boolean
---@field playing boolean
---@field line integer Line to write at: the cursor line (step) or the playhead line (live).
---@field column integer Selected note column; 0 when an effect column is selected.
---@field visible_columns integer Visible note columns of the track.
---@field max_columns integer 12 for sequencer tracks, 0 for others.
---@field pattern_lines integer
---@field edit_step integer 0-64
---@field wrap boolean `transport.wrapped_pattern_edit`
---@field has_next_sequence boolean Whether a next pattern exists in the sequence.

---@class RecordAdvance
---@field line integer New cursor line.
---@field sequence_delta integer 0, or 1 to move to the next pattern in the sequence.

---@class RecordPlan
---@field line integer
---@field first_column integer
---@field notes integer[] Notes to write, one per column from `first_column`.
---@field volume integer 0-127 or EMPTY_VOLUME.
---@field visible_columns integer Note columns the track must show (>= current).
---@field advance RecordAdvance? Cursor move after writing; nil in live mode.

---@class HeldRecord
---@field sequence integer
---@field line integer
---@field first_column integer
---@field count integer

---Volume column value for a velocity. Full velocity leaves the column empty,
---like Renoise does.
---@param velocity integer? 0-127
---@return integer
function M.volume_value(velocity)
  if velocity == nil or velocity >= 127 then
    return M.EMPTY_VOLUME
  end
  return math.max(0, math.floor(velocity))
end

---Where the cursor goes after writing at `line`.
---@param line integer
---@param step integer
---@param pattern_lines integer
---@param wrap boolean
---@param has_next boolean
---@return integer line, integer sequence_delta
function M.next_line(line, step, pattern_lines, wrap, has_next)
  if step <= 0 then
    return line, 0
  end
  local target = line + step
  if target <= pattern_lines then
    return target, 0
  end
  if wrap then
    return ((target - 1) % pattern_lines) + 1, 0
  end
  if has_next then
    return target - pattern_lines, 1
  end
  return pattern_lines, 0
end

---Plan a chord write, or nil when the chord should only be auditioned.
---@param state RecordState
---@param notes integer[]
---@param velocity integer? 0-127
---@return RecordPlan?
function M.plan_note_on(state, notes, velocity)
  if not state.edit_mode or state.max_columns <= 0 or #notes == 0 then
    return nil
  end
  local max_columns = math.min(state.max_columns, M.MAX_COLUMNS)
  local column = state.column
  if column < 1 then
    column = 1
  end
  local count = math.min(#notes, max_columns)
  local first = math.min(column, max_columns - count + 1)
  local plan_notes = {}
  for i = 1, count do
    plan_notes[i] = notes[i]
  end
  local plan = {
    line = state.line,
    first_column = first,
    notes = plan_notes,
    volume = M.volume_value(velocity),
    visible_columns = math.max(state.visible_columns, first + count - 1),
  }
  if not state.playing then
    local line, delta = M.next_line(
      state.line,
      state.edit_step,
      state.pattern_lines,
      state.wrap,
      state.has_next_sequence
    )
    plan.advance = { line = line, sequence_delta = delta }
  end
  return plan
end

---Where the note-offs of a live-recorded chord go when the pad is released.
---A tap that releases on the same line it started moves the offs one line
---down; at the very last line there is no room and nothing is written.
---@param held HeldRecord
---@param current_line integer Playhead line at release.
---@param pattern_lines integer
---@return { line: integer, first_column: integer, count: integer }?
function M.plan_note_off(held, current_line, pattern_lines)
  local line = current_line
  if line == held.line then
    if line + 1 > pattern_lines then
      return nil
    end
    line = line + 1
  end
  return { line = line, first_column = held.first_column, count = held.count }
end

return M
