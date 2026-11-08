local t = require "tests.helper"
local input = require "src.input"

---@return MidiNoteEvent
local function dec(message)
  return assert(input.decode(message))
end

local on = dec { 0x90, 60, 100 }
t.eq(on.kind, "note_on", "note on kind")
t.eq(on.channel, 1, "channel 1")
t.eq(on.note, 60, "note")
t.eq(on.velocity, 100, "velocity")

local off = dec { 0x80, 60, 64 }
t.eq(off.kind, "note_off", "note off kind")
local off0 = dec { 0x9A, 60, 0 }
t.eq(off0.kind, "note_off", "note on with velocity 0 is off")
t.eq(off0.channel, 11, "channel from low nibble")

t.eq(input.decode { 0xB0, 1, 64 }, nil, "control change ignored")
t.eq(input.decode { 0xFE }, nil, "short messages ignored")
---@type any
local not_a_table = "nope"
t.eq(input.decode(not_a_table), nil, "non-table ignored")

t.eq(input.midi_pad(36, 36), 1, "base note is pad 1")
t.eq(input.midi_pad(51, 36), 16, "base + 15 is pad 16")
t.eq(input.midi_pad(52, 36), nil, "above range")
t.eq(input.midi_pad(35, 36), nil, "below range")

-- layouts
t.eq(#input.LAYOUTS, 3, "three layouts")
for layout = 1, #input.LAYOUTS do
  local seen = {}
  for offset = 0, 15 do
    local pad = input.layout_pad(offset, layout)
    t.check(
      pad >= 1 and pad <= 16 and not seen[pad],
      ("layout %d offset %d maps to a unique pad"):format(layout, offset)
    )
    seen[pad] = true
    t.eq(
      input.layout_offset(pad, layout),
      offset,
      ("layout %d inverse of offset %d"):format(layout, offset)
    )
  end
end
t.eq(input.layout_pad(0, 1), 1, "rows: first note is pad 1 (top-left)")
t.eq(input.layout_pad(0, 2), 13, "bottom: first note is pad 13 (bottom-left)")
t.eq(input.layout_pad(15, 2), 4, "bottom: last note is pad 4 (top-right)")
t.eq(input.layout_pad(0, 3), 5, "banks: bank A pad 1 is the second tool row")
t.eq(input.layout_pad(4, 3), 1, "banks: bank A pad 5 is the top tool row")
t.eq(input.layout_pad(8, 3), 13, "banks: bank B pad 1 is the bottom tool row")
t.eq(input.layout_pad(12, 3), 9, "banks: bank B pad 5 is the third tool row")
t.eq(input.midi_pad(36, 36, 3), 5, "midi_pad honours the layout")
t.eq(input.pad_note(1, 36, 3), 40, "pad_note is the inverse")
t.eq(input.pad_note(1, 36), 36, "pad_note defaults to rows")

t.eq(input.qwerty_pad(0), 1, "z is pad 1")
t.eq(input.qwerty_pad(15), 16, "3 is pad 16")
t.eq(input.qwerty_pad(16), nil, "beyond pads")
t.eq(input.qwerty_pad(nil), nil, "no note")

t.eq(input.qwerty_handles { name = "z", note = 0 }, true, "plain piano key handled")
t.eq(
  input.qwerty_handles { name = "z", note = 0, modifier_flags = { shift = true } },
  true,
  "shift still handled"
)
t.eq(
  input.qwerty_handles { name = "z", note = 0, modifier_flags = { control = true } },
  false,
  "ctrl passes through"
)
t.eq(input.qwerty_handles { name = "space" }, false, "non-piano key passes through")
t.eq(#input.PAD_KEYS, 16, "sixteen key labels")

t.done()
