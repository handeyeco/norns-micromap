-- micromap
--
-- by handeyeco

max_bend = 16383
bend_center = 8192
max_midi_byte = 127

-- list of virtual MIDI ports
midi_devices = {}
-- MIDI in connection
in_midi = nil
-- MIDI out connection
out_midi = nil

editing = 60
pressed = nil

-- midi note number to note name/octave
key_map = {}

-- used to move the keyboard left/right (x-position offset)
keyboard_offset = -57

-- notes_map = { 60: [ { base: 60, bend: 8000, velocity: 100 }, { base: 42, bend: 9456, velocity: 120 } ] }
notes_map = {}

-- which note in a mapping we're editing
note_index = 1
-- which parameter on the note we're editing
param_index = 1

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

function get_base_map(note)
  return {
    base=note,
    bend=bend_center,
    velocity=max_midi_byte,
  }
end

function get_base_arr(note)
  local arr = {}
  arr[1] = get_base_map(note)
  return arr
end

function get_mapped_or_base(note)
  if notes_map[note] then
    return notes_map[note]
  end

  return get_base_arr(note)
end

function handle_edit_param_enc(delta)
  if not editing then
    return
  end

  local note_arr = notes_map[editing]
  if note_arr == nil then
    note_arr = get_base_arr(editing)
    note_arr[editing] = note_map
  end

  -- edit note index
  if param_index == 1 then
    -- don't go above number of notes + 1
    note_index = util.clamp(note_index + delta, 1, #note_arr + 1)
    -- don't go above 16 (max number of MPE notes)
    note_index = util.clamp(note_index, 1, 16)
    return
  end

  local note_settings = note_arr[note_index]
  if note_settings == nil then
    return
  end

  -- edit base note
  if param_index == 2 then
    note_settings["base"] = util.clamp(note_settings["base"] + delta, 0, max_midi_byte)
  
  -- edit bend
  elseif param_index == 3 then
    note_settings["bend"] = util.clamp(note_settings["bend"] + delta, 0, max_bend)

  -- edit velocity
  elseif param_index == 4 then
    note_settings["velocity"] = util.clamp(note_settings["velocity"] + delta, 0, max_midi_byte)

  end

  note_arr[note_index] = note_settings
  notes_map[editing] = note_arr
end

-- encoder callback
function enc(n,d)
  if n == 1 then
    return
  end

  if editing then
    if n == 2 then
      local max_param_index = (notes_map[editing] == nil and 4 or 5)
      param_index = util.clamp(param_index + d, 1, max_param_index)
    elseif n == 3 then
      handle_edit_param_enc(d)
    end
  end

  redraw()
end

-- key callback
function key(n,z)
  -- release actions
  if z == 1 then
    if editing and n == 2 then
      local note_arr = get_mapped_or_base(editing)

      -- add a new note
      if note_index > #note_arr then
        note_arr[note_index] = get_base_map(editing)
        notes_map[editing] = note_arr

      -- delete
      elseif param_index == 5 then
        -- delete whole map
        if note_index == 1 then
          notes_map[editing] = nil
          param_index = 1

        -- delete one note
        else
          table.remove(note_arr, note_index)
          notes_map[editing] = note_arr
          note_index = 1
          param_index = 1

        end
      end
    end
  end

  redraw()
end

-- update screen
function redraw()
  screen.clear()
  screen.fill()
  screen.level(15)

  local notes_to_highlight = {}
  if editing then
    notes_to_highlight[editing] = editing

    local base_map = get_base_arr(editing)
    local base_note_settings = base_map[1]

    local note_arr = notes_map[editing]
    if note_arr == nil then
      note_arr = base_map
    end

    local note_settings = note_arr[note_index]

    -- edit note index
    local base_yOff = 10
    set_active_level(param_index, 1)
    screen.move(10, base_yOff)
    local next_note_index = util.clamp(#note_arr + 1, 1, 16)
    screen.text("Note index: "..note_index.."/"..next_note_index)

    if note_index > #note_arr then
      screen.move(10, 26)
      screen.level(1)
      screen.text("Press k2 to add note")
      screen.update()
      return
    end

    -- edit base note
    local base_yOff = 18
    set_active_level(param_index, 2)
    screen.move(10, base_yOff)
    screen.text("Base note: "..key_map[note_settings["base"]])
    mark_dirty(base_yOff, note_settings["base"] ~= base_note_settings["base"])

    -- edit pitch offset
    local bend_yOff = 26
    set_active_level(param_index, 3)
    screen.move(10, bend_yOff)
    screen.text("Bend: "..note_settings["bend"])
    mark_dirty(bend_yOff, note_settings["bend"] ~= base_note_settings["bend"])

    -- edit velocity
    local velocity_yOff = 34
    set_active_level(param_index, 4)
    screen.move(10, velocity_yOff)
    screen.text("Velocity: "..note_settings["velocity"])
    mark_dirty(velocity_yOff, note_settings["velocity"] ~= base_note_settings["velocity"])

    -- delete
    if notes_map[editing] ~= nil then
      local delete_yOff = 42
      set_active_level(param_index, 5)
      screen.move(10, delete_yOff)
      local delete_text = (note_index == 1 and "Delete full mapping" or "Delete note")
      if param_index == 5 then
        delete_text = delete_text.." (k2)"
      end
      screen.text(delete_text)
    end
  end

  local notes_to_fill = {}
  for k,_ in pairs(notes_map) do
    notes_to_fill[k] = k
  end
  draw_keyboard(60, notes_to_highlight, notes_to_fill, false)

  screen.update()
end

function mark_dirty(yOff, isDirty)
  if not isDirty then
    return
  end

  screen.move(2, yOff)
  screen.level(2)
  screen.text("-")
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
  local message = midi.to_msg(data)

  if message.type == "note_on" and not pressed then
    if editing ~= message.note then
      note_index = 1
      param_index = 1
    end

    pressed = message.note
    editing = message.note

    local notes_arr = get_mapped_or_base(pressed)
    local note_settings = notes_arr[1]

    out_midi:pitchbend(note_settings["bend"], 1)
    out_midi:note_on(note_settings["base"], note_settings["velocity"], 1)
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

function set_active_level(actual, active)
  if actual == active then
    screen.level(14)
  else
    screen.level(1)
  end
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