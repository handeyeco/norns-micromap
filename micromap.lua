-- micromap
--
-- by handeyeco

-- list of virtual MIDI ports
midi_devices = {}
-- MIDI in connection
in_midi = nil
-- MIDI out connection
out_midi = nil

pressed = false

-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS

-- called when script loads
function init()
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
  screen.move(10, 10)
  if pressed then
    screen.text("Key pressed")
  else
    screen.text("Key not pressed")
  end
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
    pressed = true

    local middlePitchBend = 8192
    local lPitch = middlePitchBend - 200
    local hPitch = middlePitchBend + 200
    out_midi:pitchbend(math.random(lPitch, hPitch), 1)
    out_midi:pitchbend(math.random(lPitch, hPitch), 2)
    out_midi:pitchbend(math.random(lPitch, hPitch), 3)
    out_midi:pitchbend(math.random(lPitch, hPitch), 4)
    out_midi:note_on(60, 100, 1)
    out_midi:note_on(64, 100, 2)
    out_midi:note_on(67, 100, 3)
    out_midi:note_on(71, 100, 4)
  elseif message.type == "note_off" and pressed then
    pressed = false

    stop_all_notes()
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