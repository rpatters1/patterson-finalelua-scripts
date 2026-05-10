function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "OpenAI Codex"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "2026-05-10"
    finaleplugin.CategoryTags = "Pitch, MIDI, Microtonal"
    finaleplugin.MinJWLuaVersion = 0.70
    finaleplugin.Notes = [[
Prints 31-EDO pitch-class numbers (0-30 from C) and octaves for each note in the selected region.
Middle C is octave 4.
    ]]
    return "Export 31-EDO MIDI", "Export 31-EDO MIDI", "Print 31-EDO pitch classes and octaves for the selected notes."
end

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

    return {
        note_string = note_string,
        pitch_class = pitch_class,
        octave = normalized_octave,
    }
end

local function export_31edo_midi()
    local count = 0
    print("31-EDO export:")

    for entry in eachentrysaved(finenv.Region()) do
        if entry:IsNote() then
            for note in each(entry) do
                local result, err = calc_31edo_pitch(note)
                count = count + 1
                if result then
                    print(string.format(
                        "Measure %d, Staff %d, Pos %d, Layer %d: %s -> pc %d, octave %d",
                        entry.Measure,
                        entry.Staff,
                        entry.MeasurePos,
                        entry.LayerNumber,
                        result.note_string,
                        result.pitch_class,
                        result.octave
                    ))
                else
                    print(string.format(
                        "Measure %d, Staff %d, Pos %d, Layer %d: %s",
                        entry.Measure,
                        entry.Staff,
                        entry.MeasurePos,
                        entry.LayerNumber,
                        err
                    ))
                end
            end
        end
    end

    print(string.format("Processed %d note%s.", count, count == 1 and "" or "s"))
end

export_31edo_midi()
