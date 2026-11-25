local t = require "tests.helper"
local keyboard = require "src.keyboard"

t.eq(keyboard.is_black(49), true, "C# is black")
t.eq(keyboard.is_black(48), false, "C is white")
t.eq(keyboard.white_count(12, 95), 49, "seven octaves have 49 white keys")

local x, w, black = keyboard.key_x(12, 12, 10, 6)
t.eq(x, 0, "first C at the left edge")
t.eq(w, 10, "white width")
t.eq(black, false, "C is white")
t.eq(keyboard.key_x(24, 12, 10, 6), 70, "next C seven white keys on")
t.eq(keyboard.key_x(23, 12, 10, 6), 60, "B is the seventh white key")
local cs, csw, csb = keyboard.key_x(13, 12, 10, 6)
t.eq(csb, true, "C# is black")
t.eq(csw, 6, "black width")
t.check(cs < 10 and cs + csw > 10, "C# sits on the line between C and D")
local fs = keyboard.key_x(18, 12, 10, 6)
t.check(fs < 40 and fs + 6 > 40, "F# sits on the line between F and G")
-- black keys never overlap each other
for note = 12, 94 do
  if keyboard.is_black(note) then
    for other = note + 1, 95 do
      if keyboard.is_black(other) then
        local a = keyboard.key_x(note, 12, 10, 6)
        local b = keyboard.key_x(other, 12, 10, 6)
        t.check(a + 6 <= b, "black keys " .. note .. " and " .. other .. " do not overlap")
        break
      end
    end
  end
end

t.done()
