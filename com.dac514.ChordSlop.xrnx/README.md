# ChordSlop

Chord pads for Renoise, with a circle of fifths that turns to whatever key you
are in. Sixteen pads hold chords. Hit them with the mouse, a MIDI controller or
the computer keyboard, hear them through the selected instrument, and, with edit
mode on, write them straight into the pattern.

Made for people who think in patterns and note columns, not piano rolls.

## Open it

*Tools > ChordSlop...* in the main menu, or bind *Global > Tools > Show ChordSlop*
to a key.

## The window

**Key and mode.** Pick the root and one of the seven modes. With *Transpose pads
with key* on, changing the key moves every pad with it (C major pads become G
major pads). With it off, the pads stay and only the roman numerals and colours
update, which is handy when you have laid out chords by hand and want to see how
they relate to a key.

**Circle of fifths.** Majors on the outer ring, relative minors on the inner
ring, the current key at the top. The shaded wedge covers the seven chords that
belong to the key; those buttons are coloured. Click any chord to hear it. The
centre button plays the tonic. Switch *Play* to *Assign to pad* and each chord
you click lands on the selected pad, then the selection moves to the next pad,
so you can lay out a progression in a few clicks.

**Pads.** A 4x4 grid. Green pads are in the key, amber pads are borrowed from the
parallel major or minor (or sit on a scale root with an outside note), grey pads
are outside. Under each pad: its roman numeral and the computer key that plays
it. Click a pad to select it and hear it.

**Pad editor.** Root, chord type, inversion and octave of the selected pad, and
the exact notes it will play. *Clear* empties the pad.

**Presets.** Factory presets are written as scale degrees, so they render into
the current key (and switch the mode when they need one, like the minor and
Dorian sets). Save the current pads under a name of your own; those are stored
as written and survive restarts. *Delete* removes the selected preset of yours.

**MIDI.** Pick an input device. Pads 1 to 16 answer to sixteen chromatic notes
starting at the *Pad 1* note (C-3, MIDI note 36, by default: pad 1 of an AKAI
MPK mini in bank A, with bank B landing on pads 9 to 16). Press *Learn*, then
hit the controller pad you want as pad 1. Velocity is recorded when the
instrument's velocity column is in use.

**QWERTY.** While the ChordSlop window has focus, Renoise's piano keys play the
pads: `z s x d c v g b h n j m` for pads 1 to 12 and `q 2 w 3` for 13 to 16.
Untick *QWERTY pads* to let every key through to Renoise.

**Animate.** Turns the circle smoothly when the key changes. Untick it for an
instant jump.

## Recording

The status line in the footer tells you what a pad press will do.

- **Edit mode off**: the pad only plays.
- **Edit mode on, stopped**: the chord is written across note columns at the
  cursor line of the selected track, and the cursor advances by the edit step,
  like typing notes. Note columns are added as needed, up to twelve.
- **Edit mode on, playing**: the chord goes in at the playhead when you press
  and note-offs go in where you release.

Every chord is one undo step. Pads always audition through the selected
instrument on the selected track; recording needs a sequencer track.

## Install

Drag `com.dac514.ChordSlop.xrnx` onto Renoise, or copy this folder into the
`Scripts/Tools` folder of your Renoise preferences directory.

Needs Renoise 3.5 or newer. Source and issues: https://github.com/dac514/chordslop
