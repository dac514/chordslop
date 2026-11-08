--[[
  Tween for the circle of fifths: the rotation of the labels and the angle of
  the in-key wedge move together over roughly 300 ms on a tool timer, each
  step handed to an `apply` callback that redraws the canvas and moves the
  labels. The timer is registered through `App.reg.timer`, so `App.stop()`
  always finds it.
]]

local circle = require "src.circle"

local M = {}

M.FRAMES = 12
M.INTERVAL_MS = 25

---@class AnimState
---@field app table? The application module.
---@field apply fun(rotation_deg: number, wedge_deg: number)?
---@field rotation number
---@field wedge number
---@field from_rotation number
---@field to_rotation number
---@field from_wedge number
---@field to_wedge number
---@field frame integer

---@type AnimState
local state = {
  rotation = 0,
  wedge = 0,
  from_rotation = 0,
  to_rotation = 0,
  from_wedge = 0,
  to_wedge = 0,
  frame = 0,
}

---@type function?
local guarded_tick

local function tick()
  if not state.apply or not state.app then
    return
  end
  state.frame = state.frame + 1
  if state.frame >= M.FRAMES then
    state.rotation = state.to_rotation % 360
    state.wedge = state.to_wedge % 360
    state.apply(state.rotation, state.wedge)
    M.stop_timer()
    return
  end
  state.rotation = circle.tween(state.from_rotation, state.to_rotation, state.frame, M.FRAMES)
  state.wedge = circle.tween(state.from_wedge, state.to_wedge, state.frame, M.FRAMES)
  state.apply(state.rotation, state.wedge)
end

function M.stop_timer()
  if guarded_tick and state.app then
    state.app.reg.untimer(guarded_tick)
  end
end

---Bind the animation to a dialog and apply the starting angles at once.
---@param app table
---@param apply fun(rotation_deg: number, wedge_deg: number)
---@param rotation_deg number
---@param wedge_deg number
function M.init(app, apply, rotation_deg, wedge_deg)
  M.stop_timer()
  state.app = app
  state.apply = apply
  state.rotation = rotation_deg % 360
  state.wedge = wedge_deg % 360
  guarded_tick = app.guard(tick)
  apply(state.rotation, state.wedge)
end

---@return number rotation_deg, number wedge_deg
function M.angles()
  return state.rotation, state.wedge
end

---Move both angles to their targets the short way round, animated or not.
---@param rotation_deg number
---@param wedge_deg number
---@param animate boolean
function M.go(rotation_deg, wedge_deg, animate)
  if not state.apply or not state.app then
    return
  end
  local dr = circle.shortest_delta(state.rotation, rotation_deg)
  local dw = circle.shortest_delta(state.wedge, wedge_deg)
  if not animate or (dr == 0 and dw == 0) then
    M.stop_timer()
    state.rotation = rotation_deg % 360
    state.wedge = wedge_deg % 360
    state.apply(state.rotation, state.wedge)
    return
  end
  state.from_rotation, state.to_rotation = state.rotation, state.rotation + dr
  state.from_wedge, state.to_wedge = state.wedge, state.wedge + dw
  state.frame = 0
  state.app.reg.timer(guarded_tick, M.INTERVAL_MS)
end

---Detach from the dialog (closing); stops any running tween.
function M.stop()
  M.stop_timer()
  state.apply = nil
end

return M
