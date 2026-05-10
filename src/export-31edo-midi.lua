function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.Author = "OpenAI Codex"
    finaleplugin.Version = "1.1"
    finaleplugin.Date = "2026-05-10"
    finaleplugin.CategoryTags = "Pitch, MIDI, Microtonal"
    finaleplugin.MinJWLuaVersion = 0.70
    finaleplugin.Notes = [[
Stage 1 score-side event extraction for 31-EDO MIDI export.
Processes the whole document and prints one tab-separated playback event row per note attack.
Middle C is octave 4 and remapped MIDI 60.
    ]]
    return "Export 31-EDO MIDI", "Export 31-EDO MIDI", "Print a full-document score-side note event table for later 31-EDO MIDI remapping."
end

local tie = require("library.tie")

local NATURAL_31EDO_PCS = {
    C = 0,
    D = 5,
    E = 10,
    F = 13,
    G = 18,
    A = 23,
    B = 28,
}

local NATURAL_12EDO_PCS = {
    C = 0,
    D = 2,
    E = 4,
    F = 5,
    G = 7,
    A = 9,
    B = 11,
}

local MIDI_CENTER_C = 60
local MIDI_MIN = 0
local MIDI_MAX = 127

local function create_full_document_region()
    local region = finale.FCMusicRegion()
    region:SetFullDocument()
    return region
end

local function get_note_string(note)
    local pitch_string = finale.FCString()
    local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
    local key_signature = cell:GetKeySignature()
    note:GetString(pitch_string, key_signature, false, false)
    return pitch_string.LuaString
end

local function mod_floor(value, modulus)
    return ((value % modulus) + modulus) % modulus
end

local function normalize_pitch_char(pitch_char)
    if type(pitch_char) == "number" then
        if pitch_char >= string.byte("A") and pitch_char <= string.byte("G") then
            return string.char(pitch_char)
        end
        local zero_based_letters = { "C", "D", "E", "F", "G", "A", "B" }
        return zero_based_letters[pitch_char + 1]
    end
    if type(pitch_char) == "string" and #pitch_char > 0 then
        local letter = string.upper(pitch_char:sub(1, 1))
        if NATURAL_31EDO_PCS[letter] then
            return letter
        end
    end
    return nil
end

local function calc_31edo_pitch(note)
    local note_string = get_note_string(note)
    local letter = normalize_pitch_char(note:CalcPitchChar())
    if not letter then
        return nil, "unsupported pitch letter for spelling: " .. note_string
    end

    local semitone_adjust = note:CalcPitchRaiseLower()
    local written_midi = note:CalcMIDIKey()
    local natural_12edo_pc = NATURAL_12EDO_PCS[letter]
    local natural_31edo_pc = NATURAL_31EDO_PCS[letter]
    local octave = math.floor((written_midi - semitone_adjust - natural_12edo_pc) / 12) - 1
    local absolute_31edo = (octave * 31) + natural_31edo_pc + (semitone_adjust * 2)
    local pitch_class = mod_floor(absolute_31edo, 31)
    local normalized_octave = math.floor((absolute_31edo - pitch_class) / 31)
    local remapped_midi = MIDI_CENTER_C + ((normalized_octave - 4) * 31) + pitch_class

    return {
        note_string = note_string,
        pitch_class = pitch_class,
        octave = normalized_octave,
        remapped_midi = remapped_midi,
        midi_reachable = remapped_midi >= MIDI_MIN and remapped_midi <= MIDI_MAX,
    }
end

local function get_measure_start_edu(region)
    local starts = {}
    local running_total = 0
    local measure = finale.FCMeasure()

    for measure_number = region.StartMeasure, region.EndMeasure do
        starts[measure_number] = running_total
        if measure:Load(measure_number) then
            running_total = running_total + measure:GetDuration()
        end
    end

    return starts
end

local function calc_note_event_duration(note, full_region)
    local total_duration = note.Entry.Duration
    if not note.Tie then
        return total_duration
    end

    local note_layer = finale.FCNoteEntryLayer(
        note.Entry.LayerNumber - 1,
        note.Entry.Staff,
        note.Entry.Measure,
        full_region.EndMeasure
    )
    note_layer:Load()

    local same_entry
    for layer_entry in each(note_layer) do
        if layer_entry.EntryNumber == note.Entry.EntryNumber then
            same_entry = layer_entry
            break
        end
    end

    if not same_entry then
        return total_duration
    end

    local current_note = same_entry:GetItemAt(note.NoteIndex)
    while current_note and current_note.Tie do
        local tied_to_note = tie.calc_tied_to(current_note, true)
        if not tied_to_note then
            break
        end
        total_duration = total_duration + tied_to_note.Entry.Duration
        current_note = tied_to_note
    end

    return total_duration
end

local function calc_event_id(entry, note)
    return string.format(
        "M%d-S%d-L%d-E%d-N%d",
        entry.Measure,
        entry.Staff,
        entry.LayerNumber,
        entry.EntryNumber,
        note.NoteIndex
    )
end

local function print_event_header()
    print(table.concat({
        "event_id",
        "measure",
        "staff",
        "layer",
        "entry_number",
        "measure_pos",
        "note_index",
        "written_pitch",
        "source_midi",
        "pc31",
        "octave31",
        "midi31",
        "midi31_reachable",
        "onset_edu",
        "duration_edu",
        "end_edu",
        "tie_start",
        "tie_stop",
    }, "\t"))
end

local function print_event_row(event)
    print(table.concat({
        tostring(event.event_id),
        tostring(event.measure),
        tostring(event.staff),
        tostring(event.layer),
        tostring(event.entry_number),
        tostring(event.measure_pos),
        tostring(event.note_index),
        tostring(event.written_pitch),
        tostring(event.source_midi),
        tostring(event.pitch_class),
        tostring(event.octave),
        tostring(event.remapped_midi),
        event.midi_reachable and "true" or "false",
        tostring(event.onset_edu),
        tostring(event.duration_edu),
        tostring(event.end_edu),
        event.tie_start and "true" or "false",
        event.tie_stop and "true" or "false",
    }, "\t"))
end

local function export_31edo_midi()
    local full_region = create_full_document_region()
    local measure_start_edu = get_measure_start_edu(full_region)
    local count = 0

    print("31-EDO score-side note events:")
    print_event_header()

    for entry in eachentrysaved(full_region) do
        if entry:IsNote() then
            for note in each(entry) do
                if not note.TieBackwards then
                    local result, err = calc_31edo_pitch(note)
                    count = count + 1
                    if result then
                        local onset_edu = measure_start_edu[entry.Measure] + entry.MeasurePos
                        local duration_edu = calc_note_event_duration(note, full_region)
                        local event = {
                            event_id = calc_event_id(entry, note),
                            measure = entry.Measure,
                            staff = entry.Staff,
                            layer = entry.LayerNumber,
                            entry_number = entry.EntryNumber,
                            measure_pos = entry.MeasurePos,
                            note_index = note.NoteIndex,
                            written_pitch = result.note_string,
                            source_midi = note:CalcMIDIKey(),
                            pitch_class = result.pitch_class,
                            octave = result.octave,
                            remapped_midi = result.remapped_midi,
                            midi_reachable = result.midi_reachable,
                            onset_edu = onset_edu,
                            duration_edu = duration_edu,
                            end_edu = onset_edu + duration_edu,
                            tie_start = note.Tie,
                            tie_stop = note.TieBackwards,
                        }
                        print_event_row(event)
                    else
                        print(table.concat({
                            calc_event_id(entry, note),
                            tostring(entry.Measure),
                            tostring(entry.Staff),
                            tostring(entry.LayerNumber),
                            tostring(entry.EntryNumber),
                            tostring(entry.MeasurePos),
                            tostring(note.NoteIndex),
                            "ERROR: " .. err,
                        }, "\t"))
                    end
                end
            end
        end
    end

    print(string.format("Processed %d note attack%s.", count, count == 1 and "" or "s"))
end

export_31edo_midi()
