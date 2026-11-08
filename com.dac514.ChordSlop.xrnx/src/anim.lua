--[[
  Rotation tween for the circle of fifths. A tool timer advances the angle a
  dozen times over roughly 300 ms and hands every step to an `apply` callback
  that redraws the canvas and moves the labels. The timer is registered
  through `App.reg.timer`, so `App.stop()` always finds it.
]]

local circle = require "src.circle"

local M = {}

M.FRAMES = 12
M.INTERVAL_MS = 25

---@class AnimState
---@field app table? The application module.
---@field apply fun(rotation_deg: number)?
---@field rotation number
---@field from number
---@field to number
---@field frame integer

---@type AnimState
local state = { rotation = 0, from = 0, to = 0, frame = 0 }

---@type function?
local guarded_tick

local function tick()
  if not state.apply or not state.app then
    return
  end
  state.frame = state.frame + 1
  if state.frame >= M.FRAMES then
    state.rotation = state.to % 360
    state.apply(state.rotation)
    M.stop_timer()
    return
  end
  state.rotation = circle.tween(state.from, state.to, state.frame, M.FRAMES)
  state.apply(state.rotation)
end

function M.stop_timer()
  if guarded_tick and state.app then
    state.app.reg.untimer(guarded_tick)
  end
end

---Bind the animation to a dialog. `apply` receives the rotation in degrees.
---@param app table
---@param apply fun(rotation_deg: number)
---@param rotation_deg number Starting rotation (applied immediately).
function M.init(app, apply, rotation_deg)
  M.stop_timer()
  state.app = app
  state.apply = apply
  state.rotation = rotation_deg % 360
  guarded_tick = app.guard(tick)
  apply(state.rotation)
end

---Current rotation in degrees.
---@return number
function M.rotation()
  return state.rotation
end

---Turn to `target_deg` the short way round, animated or not.
---@param target_deg number
---@param animate boolean
function M.rotate_to(target_deg, animate)
  if not state.apply or not state.app then
    return
  end
  local delta = circle.shortest_delta(state.rotation, target_deg)
  if not animate or delta == 0 then
    M.stop_timer()
    state.rotation = target_deg % 360
    state.apply(state.rotation)
    return
  end
  state.from = state.rotation
  state.to = state.rotation + delta
  state.frame = 0
  state.app.reg.timer(guarded_tick, M.INTERVAL_MS)
end

---Detach from the dialog (closing); stops any running tween.
function M.stop()
  M.stop_timer()
  state.apply = nil
end

return M
