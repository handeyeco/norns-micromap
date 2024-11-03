-- micromap
--
-- by handeyeco

textentry = require('textentry')

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
-- change trigger note
PARAM_INDEX_TRIGGER = 1
-- change mapped note index
PARAM_INDEX_NOTE = 2
-- change base note
PARAM_INDEX_BASE = 3
-- change pitch bend
PARAM_INDEX_BEND = 4
-- change velocity
PARAM_INDEX_VELOCITY = 5
-- delete option
PARAM_INDEX_DELETE = 6

shift_pressed = false

-- paths for presets
loaded_preset_name = nil
loaded_preset_filename = nil
preset_dir = _path.data.."micromap/presets"
user_preset_dir = preset_dir.."/user"

-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS
-- NORNS LIFECYCLE CALLBACKS

-- called when script loads
function init()
  generate_key_map()
  build_midi_device_list()

  -- make sure there's a dir for presets
  os.execute("mkdir -p "..user_preset_dir)

  params:add{type = "option", id = "midi_in_device", name = "midi in device",
    options = midi_devices, default = 1,
    action = setup_midi_callback}

  params:add{type = "number", id = "midi_in_channel", name = "midi in channel",
    min = 1, max = 16, default = 1,
    action = setup_midi_callback}

  params:add{type = "option", id = "midi_out_device", name = "midi out device",
    options = midi_devices, default = 2,
    action = setup_midi_callback}

  params:add_file("preset_path", "preset path", preset_dir)
  params:set_action("preset_path", function(file) load_preset(file) end)

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

    -- edit trigger note
    if param_index == PARAM_INDEX_TRIGGER then
      editing = util.clamp(editing + delta, 0, max_midi_byte)
      return
    end

  -- edit note index
  if param_index == PARAM_INDEX_NOTE then
    -- don't go above number of notes + 1
    note_index = util.clamp(note_index + delta, 1, #note_arr + 1)
    -- don't go above 15 (max number of MPE notes)
    note_index = util.clamp(note_index, 1, 15)
    return
  end

  local note_settings = note_arr[note_index]
  if note_settings == nil then
    return
  end

  -- edit base note
  if param_index == PARAM_INDEX_BASE then
    out_midi:note_off(note_settings["base"], 0, note_index+1)
    local mapped_delta = (shift_pressed and delta * 12 or delta)
    note_settings["base"] = util.clamp(note_settings["base"] + mapped_delta, 0, max_midi_byte)
    out_midi:note_on(note_settings["base"], note_settings["velocity"], note_index+1)
  
  -- edit bend
  elseif param_index == PARAM_INDEX_BEND then
    local mapped_delta = (shift_pressed and delta * 100 or delta)
    note_settings["bend"] = util.clamp(note_settings["bend"] + mapped_delta, 0, max_bend)
    out_midi:pitchbend(note_settings["bend"], note_index+1)

  -- edit velocity
  elseif param_index == PARAM_INDEX_VELOCITY then
    local mapped_delta = (shift_pressed and delta * 10 or delta)
    note_settings["velocity"] = util.clamp(note_settings["velocity"] + mapped_delta, 1, max_midi_byte)

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
      -- TODO prevent scrolling on new note page
      local max_param_index = (notes_map[editing] == nil and 5 or 6)
      param_index = util.clamp(param_index + d, 1, max_param_index)
    elseif n == 3 then
      handle_edit_param_enc(d)
    end
  end

  redraw()
end

-- key callback
function key(n,z)
  -- press actions
  if z == 1 then
    if editing and n == 2 then
      local note_arr = get_mapped_or_base(editing)

      -- add a new note
      if note_index > #note_arr then
        note_arr[note_index] = get_base_map(editing)
        notes_map[editing] = note_arr

      -- delete
      elseif param_index == PARAM_INDEX_DELETE then
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
    elseif n == 3 then
      shift_pressed = true
    end

  -- release actions
  elseif z == 0 then
    if n == 3 then
      shift_pressed = false
    elseif shift_pressed and n == 2 then
      get_saving_preset_name()
      return
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
  notes_to_highlight[editing] = editing

  local base_map = get_base_arr(editing)
  local base_note_settings = base_map[1]

  local note_arr = notes_map[editing]
  if note_arr == nil then
    note_arr = base_map
  end

  local note_settings = note_arr[note_index]

  local col1_xoff = 10
  local col2_xOff = 66
  local row_stride = 10
  -- row 1
  local yOff = 6

  if loaded_preset_name then
    screen.level(1)
    screen.move(2, yOff)
    screen.text(loaded_preset_name)
  end

  -- row 2
  yOff = yOff + row_stride

  -- edit trigger note
  set_active_level(param_index, PARAM_INDEX_TRIGGER)
  screen.move(col1_xoff, yOff)
  screen.text("Trig: "..key_map[editing])

  -- edit note index
  set_active_level(param_index, PARAM_INDEX_NOTE)
  screen.move(col2_xOff, yOff)
  local next_note_index = util.clamp(#note_arr + 1, 1, 15)
  screen.text("Note: "..note_index.."/"..next_note_index)

  -- row 3
  yOff = yOff + row_stride

  if note_index > #note_arr then
    screen.move(col1_xoff, yOff)
    screen.level(1)
    screen.text("Press k2 to add note")
    screen.update()
    return
  end

  -- edit base note
  set_active_level(param_index, PARAM_INDEX_BASE)
  screen.move(col1_xoff, yOff)
  screen.text("Base: "..key_map[note_settings["base"]])
  mark_dirty(col1_xoff, yOff, note_settings["base"] ~= base_note_settings["base"])

  -- edit pitch offset
  set_active_level(param_index, PARAM_INDEX_BEND)
  screen.move(col2_xOff, yOff)
  screen.text("Bend: "..note_settings["bend"])
  mark_dirty(col2_xOff, yOff, note_settings["bend"] ~= base_note_settings["bend"])

  -- row 4
  yOff = yOff + row_stride

  -- edit velocity
  set_active_level(param_index, PARAM_INDEX_VELOCITY)
  screen.move(10, yOff)
  screen.text("Velo: "..note_settings["velocity"])
  mark_dirty(col1_xoff, yOff, note_settings["velocity"] ~= base_note_settings["velocity"])

  -- row 5
  yOff = yOff + row_stride

  -- delete
  if notes_map[editing] ~= nil then
    set_active_level(param_index, PARAM_INDEX_DELETE)
    screen.move(10, yOff)
    local delete_text = (note_index == 1 and "Delete key map" or "Delete note")
    if param_index == PARAM_INDEX_DELETE then
      delete_text = delete_text.." (k2)"
    end
    screen.text(delete_text)
  end

  local notes_to_fill = {}
  for k,_ in pairs(notes_map) do
    notes_to_fill[k] = k
  end
  draw_keyboard(59, notes_to_highlight, notes_to_fill, false, note_settings["base"])

  screen.update()
end

function mark_dirty(xOff, yOff, isDirty)
  if not isDirty then
    return
  end

  screen.move(xOff - 8, yOff)
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
    -- TODO add a lock? This is annoying as-is
    -- if editing ~= message.note then
    --   editing = message.note
    --   note_index = 1
    --   param_index = 1
    -- end

    pressed = message.note

    local notes_arr = get_mapped_or_base(pressed)
    local note_settings = notes_arr[1]

    for i, note_settings in pairs(notes_arr) do
      out_midi:pitchbend(note_settings["bend"], i+1)
      out_midi:note_on(note_settings["base"], note_settings["velocity"], i+1)
    end

  elseif message.type == "note_off" and message.note == pressed then
    local notes_arr = get_mapped_or_base(pressed)
    local note_settings = notes_arr[1]

    for i, note_settings in pairs(notes_arr) do
      out_midi:note_off(note_settings["base"], 0, i+1)
    end
    
    pressed = nil
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

function draw_base(xPos, yPos, is_base)
  if not is_base then return end
  screen.level(2)
  screen.pixel(xPos, yPos + 4)
  screen.fill()
end

-- draw a full keyboard
function draw_keyboard(yPos, notesToHighlight, notesToFill, hideFilteredNotes, base)
  local sorted_keys = tab.sort(key_map)

  -- handle moving the keyboard left/right
  local xPos = 10 + keyboard_offset

  for _, note in pairs(sorted_keys) do
    local name = key_map[note]
    local highlight = notesToHighlight[note]
    local fill = notesToFill[note]
    local is_base = note == base

    -- local filter = hideFilteredNotes and isFilteredNote(note)
    local filter = false

    -- check if it's a white or black key by name
    if string.len(name) == 2 then
      -- white keys
      draw_key(xPos, yPos, highlight, fill, filter)
      draw_base(xPos, yPos, is_base)

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
      draw_base(xPos, yPos, is_base)
      xPos = xPos + 2
    end
  end
end

function linear_map(x, in_min, in_max, out_min, out_max)
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

-- PRESETS
-- PRESETS
-- PRESETS

-- parse a Micromap preset (.mmap)
-- TODO: make this more resilient to poorly formatted files
function parse_preset(path)
  local preset_name = nil
  local trigger = nil
  local note_arr = {}
  local mapping = {}

  -- iterate over each line of the file looking for data
  for line in io.lines(path) do
    -- look for preset name
    if not preset_name then
      preset_name = string.match(line, 'name="([^"]+)')

    -- look for trigger
    elseif trigger == nil then
      trigger = string.match(line, 'note="([0-9]+)"')

    -- look for end of trigger
    elseif string.match(line, '</trigger>') then
      if trigger and #note_arr then
        mapping[tonumber(trigger)] = note_arr
        trigger = nil
        note_arr = {}
      end

    -- look for notes
    else
      local base = string.match(line, 'base="([0-9]+)"')
      local bend = string.match(line, 'bend="([0-9]+)"')
      local velocity = string.match(line, 'velocity="([0-9]+)"')

      if (base ~= nil and bend ~= nil and velocity ~= nil) then
        local note = {
          base = tonumber(base),
          bend = tonumber(bend),
          velocity = tonumber(velocity)
        }
        table.insert(note_arr, note)
      end
    end
  end

  return { preset_name = preset_name, mapping = mapping }
end

function get_file_name(file)
  local file_name = file:match("[^/]*.mmap$")
  return file_name:sub(0, #file_name - 5)
end


-- load a Micromap preset (.mmap)
function load_preset(path)
  if (
    not path
    or path == "cancel"
    or not string.sub(path, -5) == ".mmap"
  ) then
    print("Load preset cancelled or invalid path")
    return
  end

  -- check if the file exists
  local f = io.open(path,"r")
  if f == nil then
    print("file not found: "..path)
    return
  else
    f:close()
    parse_rv = parse_preset(path)
    loaded_preset_name = parse_rv["preset_name"]
    -- TODO this just needs to be the file name
    loaded_preset_filename = get_file_name(path)
  end

  redraw()
end

function clear_preset()
  notes_map = {}
  redraw()
end

-- convert in-memory mapping to a Micromap preset (.mmap) which is XML
function stringify_preset(name)
  local start_str = '<?xml version="1.0" encoding="UTF-8"?>\n<micromap>\n  <preset name="'..name..'">\n'
  local end_str = '  </preset>\n</micromap>'

  local output = start_str
  for trigger, note_arr in pairs(notes_map) do
    output = output..'    <trigger note="'..trigger..'">\n'
    for _, note in pairs(note_arr) do
      output = output..'      <note base="'..note["base"]..'" bend="'..note["bend"]..'" velocity="'..note["velocity"]..'"/>\n'
    end
    output = output..'    </trigger>\n'
  end

  return output..end_str
end

function get_saving_preset_name()
  textentry.enter(get_saving_preset_filename, loaded_preset_name, "display name")
end

function get_saving_preset_filename(preset_name)
  print(preset_name)
  if (
    preset_name == nil
    or preset_name == ""
  ) then
    return
  end

  textentry.enter(
    function (preset_filename) save_preset(preset_name, preset_filename) end,
    loaded_preset_filename,
    "file name (user/*.mmap)"
  )
end

-- save a Micromap preset (.mmap) which is XML
function save_preset(preset_name, preset_filename)
  print(preset_filename)
  -- need a file name
  if (
    preset_filename == nil
    or preset_filename == ""
  ) then
    return
  end

  -- make sure the user preset dir exists
  os.execute("mkdir -p "..user_preset_dir)

  -- write the file
  local path = user_preset_dir.."/"..preset_filename..".mmap"
  local file = io.open(path, "w")
  file:write(stringify_preset(preset_name))
  file:close()

  loaded_preset_name = preset_name
  loaded_preset_filename = preset_filename

  redraw()
end