# ChordSlop

Sixteen pads full of chords that belong together, a circle of fifths that
shows you why, and a straight line into the pattern editor. Hit a pad with the
mouse, a controller or the keyboard; hear it; with edit mode on, it is written
down.

Open it from *Tools > ChordSlop...*, or bind *Global > Tools > Show ChordSlop*
to a key.

## The circle

Twelve major chords around the outside, their relative minors inside. Walk
clockwise and each chord is a fifth up from the last: C, G, D, A. Neighbours
share two of their three notes, so moving between them sounds smooth; jump
across the circle and it sounds like a jump. The shaded wedge covers the seven
chords that live in the current key, and the key itself sits at the top.
Change the key and the whole thing turns.

So the circle is a map. Green is home. Next door is a safe step. Far side is
drama. Click any chord to hear it, click the centre for the tonic, and while a
pad sounds its chord lights up on the circle, so you can see where your
progression is wandering.

Switch *Play* to *Assign to pad* and every chord you click lands on the
selected pad and moves on to the next. A progression in four clicks.

## The pads

A 4x4 grid. Green pads are in the key, grey ones are not, same as the circle.
Under each pad: its roman numeral and the keyboard key that plays it. Clicking
a pad selects it; the editor below sets its root, chord type, inversion and
octave and shows the exact notes.

**Key and mode** are the frame everything hangs in. Pick a root and one of
seven modes. *Transpose pads with key* moves every pad along when you change
key; untick it and the pads stay put while the colours tell you how they fit.

**Presets** are sixteen-chord palettes: pop loops, doo-wop, Pachelbel, jazz
turnarounds, bossa, gospel, lo-fi, four flavours of minor, Dorian, Phrygian,
Lydian, Mixolydian, power chords, ambient sus pads. Every one of them stays in
the key, so whatever you pick, nothing on the grid is a wrong note. They are
written as scale degrees, so they follow the key, and most set the mode they
were made for. Change the mode afterwards and the preset is re-rendered in it:
the jazz ii V I becomes a minor ii V i. Hover the list for a one-line
description. Once you edit a pad the list shows the preset's name with an
asterisk; pick it again to get it back. *Save* keeps your own layout under a
name, also relative to the key and mode, so it transposes and re-renders like
the rest. *Delete* removes it again.

## Playing

**Mouse.** Press a pad or a circle chord. Release to stop.

**MIDI.** Choose the device, then how its sixteen notes map onto the grid:
*MPK mini banks* (default) puts bank A on the top two rows and bank B below,
laid out like the controller; *Rows top to bottom* and *Rows bottom to top*
do what they say. The *Low note* is the lowest pad note (C-3, MIDI 36, on an
MPK mini); press *Learn* and hit that pad to set it. Velocity is recorded.

Take the controller out of Renoise's own MIDI inputs (*Preferences > MIDI >
In Device A/B*). ChordSlop reads it directly; if Renoise also listens, edit
mode records the raw pad note on top of the chord.

**QWERTY.** With the ChordSlop window focused, Renoise's piano keys play the
pads: `z s x d c v g b h n j m` for 1 to 12, `q 2 w 3` for 13 to 16. Untick
*QWERTY pads* to let every key through to Renoise.

## Recording

The footer tells you what a press will do.

- **Edit mode off**: just plays.
- **Edit mode on, stopped**: the chord is written across note columns at the
  cursor and the cursor advances by the edit step, like typing notes. Columns
  are added as needed, up to twelve.
- **Edit mode on, playing**: the chord goes in at the playhead when you press,
  note-offs where you release.

One chord, one undo step. Pads always play through the selected instrument on
the selected track; recording wants a sequencer track.

*Animate* turns the circle smoothly when the key or mode changes. Untick it
for an instant jump.

## Install

Drag `com.dac514.ChordSlop.xrnx` onto Renoise. Needs Renoise 3.5 or newer.
Source and issues: https://github.com/dac514/chordslop
