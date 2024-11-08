# Micromap

Micromap is a [Norns](https://monome.org/docs/norns/) script for mapping incoming MIDI notes to a set of outgoing MPE MIDI notes. Each mapped note can include its own base note, pitch bend value, and velocity value.

It's similar to my [Ripchord](https://github.com/handeyeco/norns-ripchord) script except that the chords being sent can be [microtonal](https://en.wikipedia.org/wiki/Microtonality).

> [!WARNING]  
> Project is a WIP and not currently stable

## Usage

Requirements:
- non-MPE MIDI input device
- [MPE](https://en.wikipedia.org/wiki/MIDI#MIDI_Polyphonic_Expression) enabled device to send MIDI MPE to

## Usage

Connect a MIDI controller to Norns so that you can send MIDI notes. Connect MIDI out to a device that supports MPE.

Micromap accepts one MIDI note at a time and maps that note to between 1 and 15 outgoing notes.

### Controls

- **e2**: select parameter
- **e3**: adust parameter
- **k2** + **e3**: fast adjust
- **k2**: select
- **k3**: shift
- **k3** + **k2**: save
- **k3** + **e2**: latch notes on (right) off (left)
- **k3** + **e3**: follow mode on (right) off (left)

### Reading the keyboard

The keyboard helps to reference a few things:
- The lit note is the current trigger note being edited
- Filled notes mean that the note has been edited from the default configuration
- The dot below the keyboard is the base note for the current output note being edited
- The dot above the keyboard is the currently pressed incoming note

### Parameters

- **Trig**: select which incoming note you want to edit
- **Note** (1-15): select which of the outgoing notes you want to edit
  - **Base** (0-127): the base note of the selected output note
  - **Bend** (0-16383): the pitch bend value of the selected output note (8192 is no bend); MPE devices should map this between -24/+24 semitones
  - **Velo** (0-127): the velocity of the selected output note
- **Delete key map** (on the first note): delete the complete mapping for the selected trigger note; only available if the mapping has been changed from the default
- **Delete note** (on notes after the first note): delete selected output note; only available if there are more than one output notes

### Editing a mapping

- Use **Trig** to select the incoming note you'd like to edit
- Use **Base**, **Bend**, and **Velo** to adjust the pitch and velocity of the output note
- Use **Note** to add/edit additional output notes (up to 15) for a trigger note
- Use **Delete note** to remove an output note from a mapping
- Use **Delete key map** to restore mapping to its default state
- Turn on latch notes (**k3** + **e2**) to hold the last played note while you're editing; you'll see a lock on the screen when it's enabled
- Use follow mode (**k3** + **e3**) to change the editing page when receiving a new MIDI in node; you'll see an arrow on the screen when it's enabled

> [!TIP]  
> The standard MPE pitch bend range is ±48 semitones (97 possible semitones: -48, 0, +48). This is mapped in MIDI to 0-16383 (16384 possible values). That means there's ≈168.9 MIDI steps per semitone (16384/97).
> 
> If 8192 is the center (no pitch bend), then 8024 would be one semitone down and 8360 would be one semitone up.
> 
> Just make sure your MPE device uses the ±48 range.

### Save a preset

- Press **k3** + **k2** to open the save prompt
- Select a display name for the preset
- Select a file name for the preset
- Preset will be saved as `data/micromap/presets/user/[NAME].mmap`

### Load a preset

- Go to the Norns `PARAMETERS` menu (**k1** + **e1**)
- Enter the `EDIT` menu (**k3**)
- Scroll down to `preset path` (**e2**)
- Enter with **k3** and use the menu to select a preset

### PSETs

There are global parameters for:

- `midi in device`: which MIDI device to listen to
- `midi in channel`: which MIDI channel to listen to
- `midi out device`: which MIDI device to send MPE data to
- `preset path`: load a preset

## Preset format

Presets are saved as XML in `data/micromap/presets/user`. The format is:

``` XML
<?xml version="1.0" encoding="UTF-8"?>
<micromap>
  <preset name="Base">
    <trigger note="42">
      <!-- remap note to a different note without microtuning -->
      <note base="69" bend="8192" velocity="127"/>
    </trigger>
    <trigger note="60">
      <!-- play one note three times, each with a different microtuning -->
      <note base="60" bend="8092" velocity="127"/>
      <note base="60" bend="8192" velocity="127"/>
      <note base="60" bend="8292" velocity="127"/>
    </trigger>
    <trigger note="69">
      <!-- I don't know if this would sound good or not -->
      <note base="69" bend="8675" velocity="120"/>
      <note base="42" bend="8888" velocity="66"/>
    </trigger>
  </preset>
</micromap>
```

- `preset`
  - `name`: the display name of the preset
- `trigger`
  - `note` (0-127): the note you press to trigger the mapping output
- `note`
  - `base` (0-127): the starting note that will be sent as a MIDI note on message
  - `bend` (0-16383): the pitch offset; MPE devices should map this to -24/+24 semitones
  - `velocity` (0-127): the velocty for the MIDI note on message