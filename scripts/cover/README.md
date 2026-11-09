# Cover and thumbnail

Windows only (PowerShell + System.Drawing). With the ChordSlop dialog open in
Renoise, in C major with the first preset loaded:

```
powershell -ExecutionPolicy Bypass -File scripts/cover/capture.ps1 dist\cover
powershell -ExecutionPolicy Bypass -File scripts/cover/compose.ps1 -dir dist\cover -cx 21 -cy 71 -csize 400 -gx 446 -gy 65 -gw 506 -gh 64
```

`capture.ps1` grabs the dialog window into `window.png`. `compose.ps1` cuts the
circle of fifths out of it as a disc and draws the 600x350 `cover.png` and the
120x45 `thumbnail.png`; the numbers are the circle stack and the first pad row
inside `window.png` (check with `just views`). Copy both PNGs to the bundle root.
