# Cover and thumbnail

These scripts draw the renoise.com images: `cover.png` (600x350) and
`thumbnail.png` (120x45). They need Python 3 and Pillow, and they work on
Linux, Windows and macOS.

With Renoise running and the tool installed, run:

```
just cover
```

It does three things:

1. `just eval @scripts/cover/setup.lua` opens the dialog and sets it up: C
   major, the first preset, the Open voicing, and pad 16 selected, so that no
   pad in the first row is highlighted. This changes your pads.
2. `capture.py dist/cover/window.png` captures only the ChordSlop window.
   - Linux: it finds the window with `xprop` and grabs it with ImageMagick's
     `import`. Renoise is an X11 program, so this also works under Wayland.
   - Windows: it finds the window by its title and grabs it with Pillow.
   - macOS: it asks System Events for the window position, so the terminal
     needs the Accessibility permission. It grabs it with `screencapture`.
   - WSL cannot see Windows windows. Run the scripts with Windows Python.
3. `compose.py dist/cover/window.png dist/cover` draws both images.

Check both images in `dist/cover`, then copy them to the bundle root.

`compose.py` reads `CIRCLE_SIZE` from `src/ui.lua`. It finds the circle of
fifths from the green tonic marker, and the first pad row from its green
pads. It reads the three colours from the circle buttons C, D and Eb. If the
pad row is not found, pass its position with `--pads x,y,w,h`. `just views`
shows the sizes of the views.
