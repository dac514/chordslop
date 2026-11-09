# ChordSlop

ChordSlop gives you 16 chord pads and a circle of fifths. The circle shows
how each chord relates to the key. You can play the pads with the mouse, a
MIDI controller or the computer keyboard. When edit mode is on, ChordSlop
writes each chord into the pattern editor.

To open ChordSlop, choose *Tools > ChordSlop...*. You can also assign a key
to *Global > Tools > Show ChordSlop*.

## The circle

The circle shows how far each chord is from the current key.

Twelve major chords sit on the outer ring. The inner ring holds the relative
minor of each one. Clockwise, each chord is a fifth above the one before it:
C, G, D, A. Neighbouring chords share notes, so a change between them sounds
smooth. A change to the other side of the circle sounds like a big step.

The colours show the distance from the key:

- Green chords are the seven chords of the key. They fill three neighbouring
  columns, and the diminished chord sits next to them on the inner ring. In C
  major, the green chords are F, C, G, Dm, Am, Em and B°.
- Blue chords are one column outside the green ones. Each blue chord changes
  one note of the key. In C major, the blue chords are Bb, Gm and D.
- Gray chords are further away from the key.

In a minor key, the major chord on the fifth degree is green as well. Most
music in a minor key uses this chord. In C minor, it is G major.

The tonic chord sits at the top, under the marker, and its name is bold. When
you change the key or the mode, the circle turns. Point the mouse at a chord
to see its roman numeral and the notes that are not in the key. Point at the
centre of the circle to read a short explanation of the colours.

Click a chord to hear it. Click the centre to hear the tonic chord. While a
pad plays, its chord is lit on the circle. This shows you where your chord
progression goes.

Under the circle, switch from *Play* to *Assign to pad*. Each chord that you
click then goes to the selected pad, and ChordSlop selects the next pad. Four
clicks give you a progression of four chords.

## The pads

The grid has four rows of four pads. Each pad has the same colour as the chord
that it lights on the circle. Under each pad, you see its roman numeral and
the computer key that plays it. Click a pad to select it. The editor under the
grid sets the root, chord type, inversion and octave of the selected pad. It
also shows the notes of the chord.

Power chords and suspended chords have no third. Such a chord lights the major
or the minor chord on its root, whichever one is closer to the key. A pad that
changes a note of the key is blue, even when it lights a green chord. While
the pad plays, that chord turns blue as well.

**Key and mode.** Choose a root note and one of seven modes. Together they set
the key for the circle, the colours and the presets. When *Transpose pads with
key* is on, every pad moves with the key when you change it. When it is off,
the pads keep their chords, and the colours show how those chords fit the new
key.

**Presets.** A preset fills all 16 pads with chords that belong together.
There are presets for pop progressions, 1950s progressions, Pachelbel's Canon,
jazz, bossa nova, gospel, neo-soul, lo-fi hip hop and five kinds of minor.
Others are for Dorian, Phrygian, Lydian and Mixolydian, for power chords and
for suspended chords. In the mode that a preset was written for, all of its
pads are green.

Presets are written as scale degrees, so they follow the key. Most presets
also set the mode that they were written for. If you change the mode later,
ChordSlop builds the preset again in the new mode. For example, the jazz
ii V I becomes a minor ii V i. Point the mouse at the list to read a short
description of each preset.

After you edit a pad, the list shows the name of the preset with an asterisk.
Choose the preset again to restore it. *Save* stores your own layout under a
name. ChordSlop stores it relative to the key and mode, so it follows the key
like the factory presets. *Delete* removes a saved layout.

## Playing

**Mouse.** Press a pad or a chord on the circle to play it. Release the mouse
button to stop it.

**MIDI.** Choose your MIDI device. Then choose how its 16 notes map to the
grid:

- *MPK mini banks* is the default. Bank A plays the top two rows and bank B
  plays the bottom two rows. Each bank has the same layout as on the
  controller.
- *Rows top to bottom* puts the lowest note at the top left.
- *Rows bottom to top* puts the lowest note at the bottom left, as on a drum
  machine.

*Low note* is the lowest note of the controller pads. On an MPK mini, it is
C-3, which is MIDI note 36. To set it, press *Learn* and then hit that pad on
the controller. ChordSlop records the velocity of each pad hit.

Remove the controller from the MIDI inputs of Renoise, in
*Preferences > MIDI > In Device A/B*. ChordSlop reads the controller directly. If Renoise also
reads it, edit mode records the note of the pad together with the chord.

**Computer keyboard.** When the ChordSlop window has the focus, the piano keys
of Renoise play the pads. The keys `z s x d c v g b h n j m` play pads 1 to
12, and the keys `q 2 w 3` play pads 13 to 16. Clear *QWERTY pads* to send
every key to Renoise.

## Recording

The text at the bottom of the window tells you what a pad press will do.

- When edit mode is off, the chord only plays.
- When edit mode is on and the song is stopped, ChordSlop writes the chord at
  the cursor, one note in each note column. Then the cursor moves by the edit
  step, as when you type notes. ChordSlop adds note columns when it needs
  them, up to 12.
- When edit mode is on and the song plays, ChordSlop writes the chord at the
  playhead when you press. It writes the note-offs where you release.

Each chord is one undo step. The pads always play the selected instrument on
the selected track. To record, select a sequencer track.

*Animate* makes the circle turn smoothly when you change the key or the mode.
Clear it to make the circle change at once.

## Install

Drag `com.dac514.ChordSlop.xrnx` onto Renoise. ChordSlop needs Renoise 3.5 or
newer. The source code and the issue tracker are at
https://github.com/dac514/chordslop.
