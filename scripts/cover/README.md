# Cover and thumbnail

`compose.py` draws the renoise.com images: `cover.png` (600x350) and
`thumbnail.png` (120x45). It needs Python 3 and Pillow, and it works on every
platform.

1. Open the ChordSlop dialog in C major, with the first preset loaded. Select
   a pad outside the first row, so that no pad in that row is highlighted:
   `just eval 'APP.ctl.selected = 16; APP.ctl.refresh_all()'`.
2. Capture the dialog. On Linux, `just screenshot` writes one PNG for each
   Renoise window, and the dialog is the file that ends in `-2.png`. On
   Windows, run
   `powershell -ExecutionPolicy Bypass -File scripts/cover/capture.ps1 dist\cover`,
   which writes `dist\cover\window.png`.
3. Run `python3 scripts/cover/compose.py <capture.png> dist/cover`.
4. Check both images, then copy them to the bundle root.

The script finds the circle of fifths from the green tonic marker. It also
reads the three colours from the circle buttons C, D and Eb. The first pad
row sits at `446,65,504,61` in the capture. If the layout changes, pass the
new position with `--pads x,y,w,h`. `just views` shows the sizes of the views.
