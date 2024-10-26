function plugindef()
    finaleplugin.RequireSelection = true
    return "", "", "Shifts all grace notes left 6 evpu. With Opt key, shifts all grace notes right 6 evpu unless the main note has an accidental."
end

local shift_value = -6
local check_accidental = false

if finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_ALT) then
    shift_value = -shift_value
    check_accidental = not finenv.QueryInvokedModifierKeys(finale.CMDMODKEY_SHIFT)
end

local function get_next_same_v(entry)
    local next_entry = entry:Next()
    if next_entry then
        if entry.Voice2 then
            if next_entry.Voice2 then
                return next_entry
            end
            return nil
        end
        if entry.Voice2Launch then
            while next_entry.Voice2 do
                next_entry = next_entry:Next()
            end
        end
    end
    return next_entry
end

local function get_main_entry(entry)
    local next_entry = entry
    while next_entry and next_entry.GraceNote do
        next_entry = get_next_same_v(next_entry)
    end
    return next_entry
end

local function main_has_accidental(entry)
    local main_entry = get_main_entry(entry)
    if not main_entry then
        return false
    end
    for note in each(main_entry) do
        if note:CalcAccidental() then
            return true
        end
    end
    return false
end

local cells_modified = {}
local modified = false

for entry in eachentrysaved(finenv.Region()) do
	if entry.GraceNote then
        if not check_accidental or not main_has_accidental(entry) then
            entry.ManualPosition = entry.ManualPosition + shift_value
            if not cells_modified[entry.Measure] then
                cells_modified[entry.Measure] = {}
            end
            cells_modified[entry.Measure][entry.Staff] = true
            modified = true
        end
    end
end

local function make_visible_in_current_part(exp_assign)
    local current_part = finale.FCPart(finale.PARTID_CURRENT)
    current_part:Load(current_part.ID)
    if current_part:IsScore() and not exp_assign.ScoreAssignment then
        exp_assign.ScoreAssignment = true
        return true
    elseif current_part:IsPart() and not exp_assign.PartAssignment then
        exp_assign.PartAssignment = true
        return true
    end
    return false
end


if modified then
    local igrc_def = (function()
        local text_exps = finale.FCTextExpressionDefs()
        text_exps:LoadAll()
        for exp_def in each(text_exps) do
            local desc = exp_def:CreateDescription()
            if desc and desc.LuaString == "NoteSpacing: ignore grace notes" then
                return exp_def
            end
        end
        return nil
    end)()
    if igrc_def then
        for meas_num, meas_table in pairs(cells_modified) do
            for staff_num, _ in pairs(meas_table) do
                local cell = finale.FCCell(meas_num, staff_num)
                local assignment_needed = (function()
                    local exps = finale.FCExpressions()
                    exps:LoadAllInCell(cell)
                    for exp in each(exps) do
                        if exp.ID == igrc_def.ItemNo then
                            local save_needed = make_visible_in_current_part(exp)
                            if save_needed then
                                exp:Save()
                            end
                            return false
                        end
                    end
                    return true
                end)()
                if assignment_needed then
                    local igrc_exp = finale.FCExpression()
                    igrc_exp.ID = igrc_def.ItemNo
                    igrc_exp:SaveNewToCell(cell)
                end
            end
        end
    end
end

    