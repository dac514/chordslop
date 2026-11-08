local t = require "tests.helper"
local record = require "src.record"

local function list(xs)
  return table.concat(xs, ",")
end

-- volume
t.eq(record.volume_value(nil), 255, "nil velocity is empty")
t.eq(record.volume_value(127), 255, "full velocity is empty")
t.eq(record.volume_value(100), 100, "velocity kept")
t.eq(record.volume_value(-3), 0, "negative clamps to 0")

-- next_line
local function nl(line, step, lines, wrap, has_next)
  local l, d = record.next_line(line, step, lines, wrap, has_next)
  return l .. "/" .. d
end
t.eq(nl(1, 0, 64, false, true), "1/0", "step 0 stays")
t.eq(nl(1, 4, 64, false, true), "5/0", "plain advance")
t.eq(nl(63, 4, 64, true, true), "3/0", "wrap on wraps")
t.eq(nl(64, 1, 64, true, true), "1/0", "wrap from last line")
t.eq(nl(63, 4, 64, false, true), "3/1", "wrap off moves to next pattern")
t.eq(nl(63, 4, 64, false, false), "64/0", "no next pattern clamps")

local function state(over)
  local s = {
    edit_mode = true,
    playing = false,
    line = 10,
    column = 1,
    visible_columns = 1,
    max_columns = 12,
    pattern_lines = 64,
    edit_step = 1,
    wrap = true,
    has_next_sequence = false,
  }
  for k, v in pairs(over or {}) do
    s[k] = v
  end
  return s
end
local triad = { 48, 52, 55 }

---@return RecordPlan
local function plan(...)
  return assert(record.plan_note_on(...))
end
---@return { line: integer, first_column: integer, count: integer }
local function off_plan(...)
  return assert(record.plan_note_off(...))
end

t.eq(record.plan_note_on(state { edit_mode = false }, triad, 127), nil, "edit mode off: no plan")
t.eq(
  record.plan_note_on(state { max_columns = 0 }, triad, 127),
  nil,
  "non-sequencer track: no plan"
)
t.eq(record.plan_note_on(state(), {}, 127), nil, "no notes: no plan")

local p = plan(state(), triad, 127)
t.eq(p.line, 10, "step: writes at cursor line")
t.eq(p.first_column, 1, "step: first column")
t.eq(list(p.notes), "48,52,55", "step: notes")
t.eq(p.volume, 255, "step: full velocity empty")
t.eq(p.visible_columns, 3, "step: expands visible columns")
t.eq(p.advance.line, 11, "step: advances by edit step")
t.eq(p.advance.sequence_delta, 0, "step: same pattern")

local p0 = plan(state { column = 0 }, triad, 100)
t.eq(p0.first_column, 1, "effect column selected -> column 1")
t.eq(p0.volume, 100, "velocity recorded")

local p11 = plan(state { column = 11, visible_columns = 12 }, triad, 127)
t.eq(p11.first_column, 10, "shifts left to fit")
t.eq(p11.visible_columns, 12, "visible columns unchanged when already wide")

local wide = {}
for i = 1, 14 do
  wide[i] = 40 + i
end
local pw = plan(state { column = 3 }, wide, 127)
t.eq(#pw.notes, 12, "truncates to 12 columns")
t.eq(pw.first_column, 1, "wide chord starts at 1")

local pl = plan(state { playing = true, line = 33 }, triad, 90)
t.eq(pl.line, 33, "live: playhead line")
t.eq(pl.advance, nil, "live: no cursor advance")

local pe =
  plan(state { line = 63, edit_step = 4, wrap = false, has_next_sequence = true }, triad, 127)
t.eq(pe.advance.line, 3, "end of pattern spills into next")
t.eq(pe.advance.sequence_delta, 1, "end of pattern moves sequence")

-- note off
local held = { sequence = 1, line = 10, first_column = 2, count = 3 }
local off = off_plan(held, 14, 64)
t.eq(off.line, 14, "off at playhead line")
t.eq(off.first_column, 2, "off same columns")
t.eq(off.count, 3, "off count")
t.eq(off_plan(held, 10, 64).line, 11, "same line -> next line")
t.eq(
  record.plan_note_off({ sequence = 1, line = 64, first_column = 1, count = 3 }, 64, 64),
  nil,
  "last line tap -> nothing"
)

t.done()
