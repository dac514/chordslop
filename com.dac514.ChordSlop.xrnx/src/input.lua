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

---@class PadLayout
---@field id "rows"|"bottom"|"banks"
---@field name string

---How the 16 chromatic controller notes land on the 4x4 grid (pads are
---numbered in reading order, top-left first).
---@type PadLayout[]
M.LAYOUTS = {
  { id = "rows", name = "Rows top to bottom" },
  { id = "bottom", name = "Rows bottom to top" },
  { id = "banks", name = "MPK mini banks" },
}

local ROW = 4

---Grid pad for a controller note offset (0 = the base note).
---@param offset integer 0-15
---@param layout integer Index into M.LAYOUTS.
---@return integer pad 1-16
function M.layout_pad(offset, layout)
  local id = (M.LAYOUTS[layout] or M.LAYOUTS[1]).id
  if id == "bottom" then
    -- lowest notes on the bottom row, like a drum machine
    local row, col = math.floor(offset / ROW), offset % ROW
    return (3 - row) * ROW + col + 1
  elseif id == "banks" then
    -- two rows per bank: the lower four notes of a bank are its bottom row
    local bank, within = math.floor(offset / (2 * ROW)), offset % (2 * ROW)
    local flipped = within < ROW and within + ROW or within - ROW
    return bank * 2 * ROW + flipped + 1
  end
  return offset + 1
end

---Controller note offset that plays a grid pad (inverse of `layout_pad`).
---@param pad integer 1-16
---@param layout integer
---@return integer offset 0-15
function M.layout_offset(pad, layout)
  for offset = 0, M.PAD_COUNT - 1 do
    if M.layout_pad(offset, layout) == pad then
      return offset
    end
  end
  return pad - 1
end

---Pad index for a MIDI note, given the note of pad 1 and the layout.
---@param note integer
---@param base integer
---@param layout integer? Index into M.LAYOUTS (default 1).
---@return integer? 1-16
function M.midi_pad(note, base, layout)
  local offset = note - base
  if offset >= 0 and offset < M.PAD_COUNT then
    return M.layout_pad(offset, layout or 1)
  end
  return nil
end

---MIDI note that plays a pad, given the base note and the layout.
---@param pad integer 1-16
---@param base integer
---@param layout integer?
---@return integer
function M.pad_note(pad, base, layout)
  return base + M.layout_offset(pad, layout or 1)
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
