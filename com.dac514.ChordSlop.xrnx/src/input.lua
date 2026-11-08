--[[
  Input decoding: raw MIDI messages and dialog key events to pad indices.
  Pure Lua so it can be unit-tested.
]]

local M = {}

M.PAD_COUNT = 16

---Renoise's virtual piano keys, in the order of their `KeyEvent.note` index
---(0 = z). Used for tooltips and the QWERTY checkbox label.
---@type string[]
M.PAD_KEYS = { "z", "s", "x", "d", "c", "v", "g", "b", "h", "n", "j", "m", "q", "2", "w", "3" }

---@class MidiNoteEvent
---@field kind "note_on"|"note_off"
---@field channel integer 1-16
---@field note integer 0-127
---@field velocity integer 0-127

---Decode a raw MIDI message. Note-on with velocity 0 counts as note-off.
---@param message integer[] The 3-byte table Renoise hands to MIDI input callbacks.
---@return MidiNoteEvent?
function M.decode(message)
  if type(message) ~= "table" or #message < 3 then
    return nil
  end
  local status, data1, data2 = message[1], message[2], message[3]
  local kind = math.floor(status / 16)
  local channel = (status % 16) + 1
  if kind == 9 and data2 > 0 then
    return { kind = "note_on", channel = channel, note = data1, velocity = data2 }
  elseif kind == 8 or kind == 9 then
    return { kind = "note_off", channel = channel, note = data1, velocity = data2 }
  end
  return nil
end

---Pad index for a MIDI note, given the note of pad 1.
---@param note integer
---@param base integer
---@return integer? 1-16
function M.midi_pad(note, base)
  local index = note - base + 1
  if index >= 1 and index <= M.PAD_COUNT then
    return index
  end
  return nil
end

---Pad index for a dialog key event's virtual piano key.
---@param note integer? `KeyEvent.note`, 0 = z
---@return integer? 1-16
function M.qwerty_pad(note)
  if type(note) == "number" and note >= 0 and note < M.PAD_COUNT then
    return note + 1
  end
  return nil
end

---@class KeyEventLike
---@field name string
---@field note integer?
---@field modifier_flags { shift: boolean?, control: boolean?, alt: boolean?, meta: boolean? }?

---Should the dialog treat this key as a pad trigger? Piano keys without
---control/alt/meta only, so shortcuts keep working.
---@param key KeyEventLike|KeyEvent
---@return boolean
function M.qwerty_handles(key)
  local flags = key.modifier_flags or {}
  if flags.control or flags.alt or flags.meta then
    return false
  end
  return M.qwerty_pad(key.note) ~= nil
end

return M
