-- Put the ChordSlop dialog in the state compose.py expects: C major (the
-- first preset keeps the mode, so set it), the first preset, Open voicing,
-- no pad sounding, and pad 16 selected so that no pad of the first row is
-- highlighted. Run with: just eval @scripts/cover/setup.lua
APP.show_dialog()
dev.set("key", 1)
dev.set("mode", 1)
dev.set("voicing", 2)
APP.ctl.load_preset(1)
for i = 1, 16 do
  APP.ctl.release(i)
end
APP.ctl.selected = 16
APP.ctl.refresh_all()
return "dialog ready for the cover"
