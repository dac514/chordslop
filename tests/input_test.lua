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
