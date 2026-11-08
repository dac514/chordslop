--[[
  Circle of fifths geometry. Pure Lua: positions on the circle, where the
  labels sit for a given rotation, which seven positions are in key, and the
  easing used when the circle turns to a new tonic.

  Positions `k` run 0-11 clockwise from 12 o'clock: C G D A E B F# C# G# D# A# F.
  Angles are degrees clockwise from 12 o'clock; `rotation` is added to every
  position, so a rotation of -30 moves position 1 (G) to the top.
]]

local theory = require "src.theory"

local M = {}

---Pitch class at each position, position 0 first.
---@type integer[]
M.FIFTHS = { 0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5 }

M.POSITIONS = 12
M.STEP_DEG = 30

---@param pc integer 0-11
---@return integer k 0-11
function M.position_of(pc)
  pc = pc % 12
  for k = 0, M.POSITIONS - 1 do
    if M.FIFTHS[k + 1] == pc then
      return k
    end
  end
  error "unreachable"
end

---Major chord root on the outer ring at position k.
---@param k integer
---@return integer pc
function M.major_at(k)
  return M.FIFTHS[(k % M.POSITIONS) + 1]
end

---Relative minor root on the inner ring at position k.
---@param k integer
---@return integer pc
function M.minor_at(k)
  return (M.major_at(k) + 9) % 12
end

---@class CircleLayout
---@field size integer Square canvas side.
---@field cx number
---@field cy number
---@field r_outer number Radius of the outer label ring.
---@field r_inner number Radius of the inner label ring.
---@field r_edge number Outer edge of the disc.
---@field r_hole number Radius of the empty centre.
---@field btn_w integer Outer label width.
---@field btn_h integer
---@field btn_w_inner integer
---@field btn_h_inner integer
---@field center_w integer
---@field center_h integer

---@param size integer
---@return CircleLayout
function M.layout(size)
  return {
    size = size,
    cx = size / 2,
    cy = size / 2,
    r_outer = size * 0.42,
    r_inner = size * 0.27,
    r_edge = size * 0.49,
    r_hole = size * 0.15,
    btn_w = math.floor(size * 0.135),
    btn_h = 22,
    btn_w_inner = math.floor(size * 0.115),
    btn_h_inner = 20,
    center_w = math.floor(size * 0.19),
    center_h = 26,
  }
end

---@param k integer position
---@param rotation_deg number
---@return number degrees clockwise from 12 o'clock
function M.angle_deg(k, rotation_deg)
  return k * M.STEP_DEG + rotation_deg
end

---Top-left corner of a label button so that it is centred on its position.
---@param layout CircleLayout
---@param k integer
---@param ring "outer"|"inner"
---@param rotation_deg number
---@return { x: integer, y: integer }
function M.origin(layout, k, ring, rotation_deg)
  local r, w, h
  if ring == "outer" then
    r, w, h = layout.r_outer, layout.btn_w, layout.btn_h
  else
    r, w, h = layout.r_inner, layout.btn_w_inner, layout.btn_h_inner
  end
  local a = math.rad(M.angle_deg(k, rotation_deg))
  local x = layout.cx + r * math.sin(a) - w / 2
  local y = layout.cy - r * math.cos(a) - h / 2
  return { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

---Top-left corner of the centre button.
---@param layout CircleLayout
---@return { x: integer, y: integer }
function M.center_origin(layout)
  return {
    x = math.floor(layout.cx - layout.center_w / 2 + 0.5),
    y = math.floor(layout.cy - layout.center_h / 2 + 0.5),
  }
end

---Rotation that puts `key_pc` at 12 o'clock.
---@param key_pc integer
---@return number degrees
function M.target_rotation(key_pc)
  return -M.STEP_DEG * M.position_of(key_pc)
end

---Signed shortest way round from one rotation to another.
---@param from_deg number
---@param to_deg number
---@return number degrees in (-180, 180]
function M.shortest_delta(from_deg, to_deg)
  local d = (to_deg - from_deg) % 360
  if d > 180 then
    d = d - 360
  end
  return d
end

---Cubic ease in-out.
---@param t number 0-1
---@return number 0-1
function M.ease(t)
  if t <= 0 then
    return 0
  elseif t >= 1 then
    return 1
  elseif t < 0.5 then
    return 4 * t * t * t
  end
  local u = -2 * t + 2
  return 1 - (u * u * u) / 2
end

---Rotation at `frame` of `frames`.
---@param from_deg number
---@param to_deg number
---@param frame integer
---@param frames integer
---@return number degrees
function M.tween(from_deg, to_deg, frame, frames)
  if frames <= 0 or frame >= frames then
    return to_deg
  end
  return from_deg + (to_deg - from_deg) * M.ease(frame / frames)
end

---First of the seven consecutive in-key positions (clockwise) for a key/mode.
---@param key integer 0-11
---@param mode integer 1-7
---@return integer k_start 0-11
function M.diatonic_span(key, mode)
  return (M.position_of(key) - theory.MODES[mode].brightness) % 12
end

---Angle (degrees, circle space) of the first in-key position for a key/mode.
---This is the value the wedge animation tweens.
---@param key integer 0-11
---@param mode integer 1-7
---@return number degrees
function M.wedge_deg(key, mode)
  return M.diatonic_span(key, mode) * M.STEP_DEG
end

---Angles bounding a seven-position wedge that starts at `start_deg`.
---@param start_deg number Angle of the first position, circle space.
---@return number start_deg, number end_deg (clockwise from 12 o'clock)
function M.wedge_arc_deg(start_deg)
  return start_deg - M.STEP_DEG / 2, start_deg + 6 * M.STEP_DEG + M.STEP_DEG / 2
end

---Angles bounding the in-key wedge, in unrotated circle space.
---@param k_start integer
---@return number start_deg, number end_deg (clockwise from 12 o'clock)
function M.span_arc_deg(k_start)
  return M.wedge_arc_deg(k_start * M.STEP_DEG)
end

---Which ring button a pad chord corresponds to: major-flavoured chords sit
---on the outer ring at the root position, minor and diminished ones on the
---inner ring where that root is the relative minor.
---@param pad Pad
---@return "outer"|"inner" ring, integer k
function M.ring_for_pad(pad)
  local third = theory.CHORD_TYPES[pad.type].intervals[2]
  if third == 3 then
    return "inner", M.position_of((pad.root + 3) % 12)
  end
  return "outer", M.position_of(pad.root)
end

---@class RingChord
---@field root integer
---@field type integer index into theory.CHORD_TYPES
---@field numeral string? Roman numeral when the chord is diatonic.
---@field in_key boolean
---@field flats boolean Spell the root with a flat (the flat side of the circle from the tonic).

---The chord shown at each ring position for a key/mode: majors outside,
---relative minors inside. Diatonic chords carry their numeral; the diminished
---degree replaces the minor on the inner ring.
---@param key integer
---@param mode integer
---@return RingChord[] outer, RingChord[] inner (index k + 1)
function M.ring_chords(key, mode)
  local maj = assert(theory.type_index "maj")
  local min = assert(theory.type_index "min")
  ---@type table<integer, { type: integer, numeral: string }>
  local diatonic = {}
  for degree = 1, 7 do
    local root, type_index = theory.diatonic_chord(key, mode, degree, false)
    diatonic[root] =
      { type = type_index, numeral = theory.analyze(root, type_index, key, mode).numeral }
  end
  local tonic = M.position_of(key)
  local key_flats = theory.prefers_flats(key, mode)
  local outer, inner = {}, {}
  for k = 0, M.POSITIONS - 1 do
    local opc, ipc = M.major_at(k), M.minor_at(k)
    local od, id = diatonic[opc], diatonic[ipc]
    -- Positions 1-5 clockwise from the tonic are the sharp side, 7-11 the flat
    -- side; the tritone follows the key's own preference.
    local steps = (k - tonic) % M.POSITIONS
    local flats = steps >= 7 or (steps == 6 and key_flats)
    outer[k + 1] = {
      root = opc,
      type = maj,
      numeral = (od and od.type == maj) and od.numeral or nil,
      in_key = od ~= nil and od.type == maj,
      flats = flats,
    }
    local inner_type = min
    if id and id.type ~= maj then
      inner_type = id.type
    end
    inner[k + 1] = {
      root = ipc,
      type = inner_type,
      numeral = (id and id.type ~= maj) and id.numeral or nil,
      in_key = id ~= nil and id.type ~= maj,
      flats = flats,
    }
  end
  return outer, inner
end

return M
