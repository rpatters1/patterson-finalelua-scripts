function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.Author = "OpenAI Codex"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "2026-05-10"
    finaleplugin.CategoryTags = "Key Signatures, Pitch, Microtonal"
    finaleplugin.MinJWLuaVersion = 0.72
    finaleplugin.Notes = [[
Creates or reuses a linear 31-EDO nonstandard key mode, applies it to the document's
global and independent key signature assignments, and doubles all FCNote RaiseLower values.
Uses Finale Maestro SMuFL accidental glyphs for the custom key mode symbol list.
    ]]
    return "Convert To 31-EDO", "Convert To 31-EDO", "Convert the current document to a 31-EDO key mode and double all note RaiseLower values."
end

local smufl_glyphs = require("library.smufl_glyphs")

local KEYSIG_NAME = "31-EDO"
local MAESTRO_FONT_NAME = "Finale Maestro"
local MIDDLE_C_MIDI = 60
local MAX_ALLOWED_RAISELOWER = 7

local DIATONIC_STEPS_31EDO = {0, 5, 10, 13, 18, 23, 28}

local function copy_table(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function tables_equal(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function maps_equal(a, b)
    for key = -7, 7 do
        if (a[key] or "") ~= (b[key] or "") then
            return false
        end
    end
    return true
end

local function get_smufl_string(glyph_name)
    local _, info = smufl_glyphs.get_glyph_info(glyph_name, MAESTRO_FONT_NAME)
    assert(info and info.codepoint, "Missing SMuFL glyph " .. glyph_name)
    return utf8.char(info.codepoint)
end

local function build_symbol_list()
    local list = {}
    local quarter_flat = get_smufl_string("accidentalKomaFlat")
    local flat = get_smufl_string("accidentalFlat")
    local three_quarter_flat = get_smufl_string("accidentalThreeQuarterTonesFlatZimmermann")
    local quarter_sharp = get_smufl_string("accidentalKomaSharp")
    local sharp = get_smufl_string("accidentalSharp")
    local three_quarter_sharp = get_smufl_string("accidentalThreeQuarterTonesSharpStein")
    list[0] = get_smufl_string("accidentalNatural")
    list[-1] = quarter_flat
    list[-2] = flat
    list[-3] = three_quarter_flat
    list[-4] = get_smufl_string("accidentalDoubleFlat")
    list[-5] = quarter_flat .. flat
    list[-6] = get_smufl_string("accidentalTripleFlat")
    list[-7] = three_quarter_flat .. flat
    list[1] = quarter_sharp
    list[2] = sharp
    list[3] = three_quarter_sharp
    list[4] = get_smufl_string("accidentalDoubleSharp")
    list[5] = sharp .. quarter_sharp
    list[6] = get_smufl_string("accidentalTripleSharp")
    list[7] = sharp .. three_quarter_sharp
    return list
end

local function find_or_create_symbol_list()
    local wanted_list = build_symbol_list()
    local lists = finale.FCCustomKeyModeSymbolLists()
    lists:LoadAll()

    for list in each(lists) do
        if maps_equal(list.List, wanted_list) then
            return list.ItemNo
        end
    end

    local list = finale.FCCustomKeyModeSymbolList()
    list.List = wanted_list
    assert(list:Save(), "unable to save 31-EDO symbol list")
    return list.ItemNo
end

local function create_maestro_font_info()
    return finale.FCFontInfo(MAESTRO_FONT_NAME, 24)
end

local function make_linear_accidental_amounts()
    local accidental_amounts = {}
    for index = -7, -1 do
        accidental_amounts[index] = -2
    end
    for index = 1, 7 do
        accidental_amounts[index] = 2
    end
    return accidental_amounts
end

local function is_target_key_mode(def)
    if not def:IsLinear() then
        return false
    end
    if def.TotalChromaticSteps ~= 31 then
        return false
    end
    if not tables_equal(def.DiatonicStepsMap or {}, DIATONIC_STEPS_31EDO) then
        return false
    end
    local accidental_amounts = def.AccidentalAmounts or {}
    local wanted_amounts = make_linear_accidental_amounts()
    for index = -7, 7 do
        if (accidental_amounts[index] or 0) ~= (wanted_amounts[index] or 0) then
            return false
        end
    end
    return true
end

local function ensure_31edo_key_mode()
    local key_modes = finale.FCCustomKeyModeDefs()
    key_modes:LoadAll()
    local symbol_list_id = find_or_create_symbol_list()
    local font_info = create_maestro_font_info()

    for def in each(key_modes) do
        if is_target_key_mode(def) then
            local changed = false
            if def.MiddleKeyNumber ~= MIDDLE_C_MIDI then
                def.MiddleKeyNumber = MIDDLE_C_MIDI
                changed = true
            end
            if def.SymbolListID ~= symbol_list_id then
                def.SymbolListID = symbol_list_id
                changed = true
            end
            if def.AccidentalFontID ~= font_info.FontID then
                def.AccidentalFontID = font_info.FontID
                changed = true
            end
            if changed then
                assert(def:Save(), "unable to update existing 31-EDO key mode")
            end
            return def
        end
    end

    local def = finale.FCCustomKeyModeDef()
    def.MiddleKeyNumber = MIDDLE_C_MIDI
    def.BaseTonalCenter = 0
    def.SymbolListID = symbol_list_id
    def.AccidentalFontID = font_info.FontID
    def.TotalChromaticSteps = 31
    def.DiatonicStepsMap = copy_table(DIATONIC_STEPS_31EDO)
    def.AccidentalOrder = finale.FCCustomKeyModeDef.GetDefaultAccidentalOrder()
    def.AccidentalAmounts = make_linear_accidental_amounts()
    def.ClefAccidentalPlacements = {}
    def.HasClefAccidentalPlacements = false
    assert(def:SaveNewLinear(), "unable to create 31-EDO key mode")
    return def
end

local function assign_31edo_key_signature(key_sig, key_mode_def)
    if key_sig:CalcTotalChromaticSteps() == 31 and key_sig:IsLinear() and key_sig.KeyMode == key_mode_def.ItemNo then
        return true, nil
    end
    if not key_sig:IsLinear() then
        return false, "encountered a nonlinear key signature assignment"
    end

    local alteration = key_sig.Alteration
    local new_key_sig = key_mode_def:CreateKeySignature()
    new_key_sig:SetTransposeAlteration(alteration)
    new_key_sig:SetTransposeSimplify(false)
    key_sig:SetID(new_key_sig:GetIDWithTransposition())
    key_sig:SetTransposeAlteration(0)
    key_sig.TransposeSimplify = false
    return true, nil
end

local function convert_measure_key_signatures(full_region, key_mode_def)
    local converted_measures = 0
    local converted_cells = 0
    local issues = {}

    local measure = finale.FCMeasure()
    for measure_number = full_region.StartMeasure, full_region.EndMeasure do
        assert(measure:Load(measure_number), "unable to load measure " .. measure_number)
        local ok, err = assign_31edo_key_signature(measure:GetKeySignature(), key_mode_def)
        if ok then
            assert(measure:Save(), "unable to save measure " .. measure_number)
            converted_measures = converted_measures + 1
        else
            table.insert(issues, string.format("Measure %d: %s", measure_number, err))
        end
    end

    for staff_number = full_region.StartStaff, full_region.EndStaff do
        for measure_number = full_region.StartMeasure, full_region.EndMeasure do
            local cell = finale.FCCell(measure_number, staff_number)
            if cell:HasIndependentKeySig() then
                local ok, err = assign_31edo_key_signature(cell:GetKeySignature(), key_mode_def)
                if ok then
                    assert(cell:Save(), string.format("unable to save independent key signature at measure %d staff %d", measure_number, staff_number))
                    converted_cells = converted_cells + 1
                else
                    table.insert(issues, string.format("Measure %d Staff %d: %s", measure_number, staff_number, err))
                end
            end
        end
    end

    return converted_measures, converted_cells, issues
end

local function double_raise_lower_values(full_region)
    local changed_notes = 0
    local overflow_notes = {}

    for entry in eachentrysaved(full_region) do
        if entry:IsNote() then
            for note in each(entry) do
                local original = note.RaiseLower
                if original ~= 0 then
                    local doubled = original * 2
                    if math.abs(doubled) > MAX_ALLOWED_RAISELOWER then
                        table.insert(overflow_notes,
                            string.format("Measure %d Staff %d Layer %d Pos %d NoteIndex %d: RaiseLower %d would exceed Finale's limit at %d",
                                entry.Measure, entry.Staff, entry.LayerNumber, entry.MeasurePos, note.NoteIndex, original, doubled))
                    else
                        note.RaiseLower = doubled
                        changed_notes = changed_notes + 1
                    end
                end
            end
        end
    end

    return changed_notes, overflow_notes
end

local function summarize_issues(title, items)
    if #items == 0 then
        return nil
    end
    local lines = {title}
    local max_lines = math.min(#items, 20)
    for i = 1, max_lines do
        table.insert(lines, items[i])
    end
    if #items > max_lines then
        table.insert(lines, string.format("... %d more", #items - max_lines))
    end
    return table.concat(lines, "\n")
end

local function convert_to_31edo()
    local full_region = finale.FCMusicRegion()
    full_region:SetFullDocument()

    finenv.StartNewUndoBlock("Convert To 31-EDO", false)

    local success, err = pcall(function()
        local key_mode_def = ensure_31edo_key_mode()
        local converted_measures, converted_cells, key_issues = convert_measure_key_signatures(full_region, key_mode_def)
        local changed_notes, overflow_notes = double_raise_lower_values(full_region)

        finenv.EndUndoBlock(true)
        finenv.UI():RedrawDocument()

        local summary = {
            string.format("Key mode: %s [%d]", KEYSIG_NAME, key_mode_def.ItemNo),
            string.format("Global measure key signatures processed: %d", converted_measures),
            string.format("Independent cell key signatures processed: %d", converted_cells),
            string.format("Notes with doubled RaiseLower values: %d", changed_notes),
        }

        local issue_text = summarize_issues("Key signature issues:", key_issues)
        if issue_text then
            table.insert(summary, "")
            table.insert(summary, issue_text)
        end

        local overflow_text = summarize_issues("RaiseLower overflows left unchanged:", overflow_notes)
        if overflow_text then
            table.insert(summary, "")
            table.insert(summary, overflow_text)
        end

        finenv.UI():AlertInfo(table.concat(summary, "\n"), "Convert To 31-EDO")
    end)

    if not success then
        finenv.EndUndoBlock(false)
        error(err)
    end
end

convert_to_31edo()
