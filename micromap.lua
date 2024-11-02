-- micromap
--
-- by handeyeco

-- list of virtual MIDI ports
midi_devices = {}
-- MIDI in connection
in_midi = nil
-- MIDI out connection
out_midi = nil

editing = nil
pressed = nil

-- midi note number to note name/octave
key_map = {}

-- used to move the keyboard left/right (x-position offset)
keyboard_offset = -57

-- note_mapping = { 60: [ { base: 60, bend: 8000, velocity: 100 }, { base: 42, bend: 9456, velocity: 120 } ] }
note_mapping = {}

-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS

-- called when script loads
function init()
  generate_key_map()
  build_midi_device_list()

  params:add{type = "option", id = "midi_in_device", name = "midi in device",
    options = midi_devices, default = 1,
    action = setup_midi_callback}

  params:add{type = "number", id = "midi_in_channel", name = "midi in channel",
    min = 1, max = 16, default = 1,
    action = setup_midi_callback}

  params:add{type = "option", id = "midi_out_device", name = "midi out device",
    options = midi_devices, default = 2,
    action = setup_midi_callback}

  params:add{type = "number", id = "midi_out_channel", name = "midi out channel",
    min = 1, max = 16, default = 1,
    action = setup_midi_callback}

  setup_midi_callback()
end

-- encoder callback
function enc(n,d)
end

-- key callback
function key(n,z)
end

-- update screen
function redraw()
  screen.clear()
  screen.fill()
  screen.level(15)

  local notes_to_highlight = {}
  if editing then
    notes_to_highlight[editing] = editing

    screen.move(0, 14)
    screen.text("Base note: "..key_map[editing])
    draw_setting_line(24, "P", 16384/2, 16384)
    draw_setting_line(35, "V", 128, 128)
  end

  draw_keyboard(60, notes_to_highlight, {}, false)

  screen.update()
end

-- called when script unloads
function cleanup()
end

-- MIDI
-- MIDI
-- MIDI

function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, short_name)
  end
end

-- stop all notes on the MIDI output
-- so we don't have hanging notes when changing output
function stop_all_notes()
  if out_midi then
    for note=21,108 do
      for ch=1,16 do
        out_midi:note_off(note, 100, ch)
      end
    end
  end
end

function handle_midi_event(data)
  print("Handling MIDI event")
  local message = midi.to_msg(data)
  tab.print(message)

  if message.type == "note_on" and not pressed then
    pressed = message.note
    editing = message.note

    local middlePitchBend = 8192
    local lPitch = middlePitchBend - 200
    local hPitch = middlePitchBend + 200
    out_midi:pitchbend(math.random(lPitch, hPitch), 1)
    out_midi:note_on(message.note, 100, 1)
  elseif message.type == "note_off" and message.note == pressed then
    pressed = nil

    out_midi:note_off(message.note, 0, 1)
  end

  redraw()
end

-- listen for MIDI events and do things
function setup_midi_callback()
  stop_all_notes()

  for i = 1, 16 do
    midi.vports[i].event = nil
  end

  -- make new connections
  in_midi = midi.connect(params:get("midi_in_device"))
  out_midi = midi.connect(params:get("midi_out_device"))

  in_midi.event = handle_midi_event
end

-- generate the key_map lookup table
function generate_key_map()
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  -- start at -2, but it immediately gets bumped to -1
  local octave = -2
  for i = 0, 127 do
    if (i % 12 == 0) then
      octave = octave + 1
    end
    local name = note_names[(i % 12) + 1]
    key_map[i] = name..octave
  end
end

function draw_setting_line(yOff, label, currVal, totalVal)
  screen.move(0, yOff+1)
  screen.text(label)

  local line_offset = linear_map(currVal, 0, totalVal, 8, 128)

  screen.move(8, yOff)
  screen.line(128, yOff)
  screen.move(line_offset, yOff-2)
  screen.line(line_offset, yOff+1)
end

-- draw an individual key on the keyboard
function draw_key(xPos, yPos, highlighted, filled, filtered)
  -- don't draw outside of set bounds
  if xPos < 8 or xPos > 118 then
    return
  end

  if filtered then
    screen.level(1)
    screen.pixel(xPos, yPos)
    screen.fill()
    return
  end

  if highlighted then
    screen.level(15)
  else
    screen.level(2)
  end

  if filled then
    screen.rect(xPos - 1, yPos - 1, 3, 3)
    screen.fill()
  else
    screen.rect(xPos, yPos, 2, 2)
    screen.stroke()
  end
end

-- draw a full keyboard
function draw_keyboard(yPos, notesToHighlight, notesToFill, hideFilteredNotes)
  local sorted_keys = tab.sort(key_map)

  -- handle moving the keyboard left/right
  local xPos = 10 + keyboard_offset

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = notesToHighlight[note]
    local fill = notesToFill[note]

    -- local filter = hideFilteredNotes and isFilteredNote(note)
    local filter = false

    -- check if it's a white or black key by name
    if string.len(name) == 2 then
      -- white keys
      draw_key(xPos, yPos, highlight, fill, filter)

      -- mark middle c
      if note == 60 then
        screen.level(0)
        screen.pixel(xPos - 1, yPos + 1)
        screen.pixel(xPos + 1, yPos + 1)
        screen.pixel(xPos - 1, yPos - 1)
        screen.pixel(xPos + 1, yPos - 1)
        screen.fill()
      end

      xPos = xPos + 4
    else
      -- black keys
      xPos = xPos - 2
      draw_key(xPos, yPos - 4, highlight, fill, filter)
      xPos = xPos + 2
    end
  end
end

function linear_map(x, in_min, in_max, out_min, out_max)
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end