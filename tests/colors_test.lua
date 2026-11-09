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
t.check(pal.home[2] > pal.home[1] and pal.home[2] > pal.home[3], "home is green")
t.check(pal.near[3] > pal.near[1] and pal.near[3] > pal.near[2], "near is blue")
t.check(pal.learn[1] > pal.learn[3], "learn accent is warm")
t.eq(list(colors.for_level(pal, "home")), list(pal.home), "for_level home")
t.eq(list(colors.for_level(pal, "near")), list(pal.near), "for_level near")
t.eq(list(colors.for_level(pal, "far")), "0,0,0", "far keeps the theme colour")
t.eq(list(colors.for_level(pal, "empty")), "0,0,0", "empty keeps the theme colour")
local hl = pal.highlight(pal.home)
t.check(hl[1] > pal.home[1] and hl[3] > pal.home[3], "highlight brightens")
local hl0 = pal.highlight { 0, 0, 0 }
t.check(hl0[1] > 0, "highlight of theme default uses base")

local pal2 = colors.palette { 200, 200, 200 }
t.check(pal2.home[1] > pal.home[1], "palette follows base brightness")

t.done()
