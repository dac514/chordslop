local t = require "tests.helper"
local colors = require "src.colors"

local function list(xs)
  return table.concat(xs, ",")
end

t.eq(list(colors.blend({ 0, 0, 0 }, { 255, 255, 255 }, 0)), "0,0,0", "blend t=0")
t.eq(list(colors.blend({ 0, 0, 0 }, { 255, 255, 255 }, 1)), "255,255,255", "blend t=1")
t.eq(list(colors.blend({ 0, 100, 200 }, { 100, 100, 100 }, 0.5)), "50,100,150", "blend midway")

local pal = colors.palette(nil)
t.eq(list(pal.out), "0,0,0", "out is theme default")
t.check(pal.in_key[2] > pal.in_key[1], "in_key is greenish")
t.check(pal.borrowed[1] > pal.borrowed[3], "borrowed is warm")
t.eq(list(colors.for_function(pal, "in_key")), list(pal.in_key), "for_function in_key")
t.eq(list(colors.for_function(pal, "empty")), "0,0,0", "for_function empty")
t.eq(list(colors.for_function(pal, "borrowed")), "0,0,0", "borrowed pads keep the theme colour")
local hl = pal.highlight(pal.in_key)
t.check(hl[1] > pal.in_key[1] and hl[3] > pal.in_key[3], "highlight brightens")
local hl0 = pal.highlight { 0, 0, 0 }
t.check(hl0[1] > 0, "highlight of theme default uses base")

local pal2 = colors.palette { 200, 200, 200 }
t.check(pal2.in_key[1] > pal.in_key[1], "palette follows base brightness")

t.done()
