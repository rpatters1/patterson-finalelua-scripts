-- the selected expression that will replace ledger lines should be designed so that
-- a horizontal position of zero is the correct offset.

local exp_id, exp_is_shape = finenv.UI():DisplayExpressionDialog(0)
if exp_id == 0 then
    return
end

local center_offset = 0 -- not used for now (the offset should be built into the shape)
local horz_offset = -3 -- personal preference

for entry in eachentrysaved(finenv.Region()) do
    if not entry.GraceNote then
        local ledger_lines_above = 0
        local ledger_lines_below = 0
        for note in each(entry) do
            local num_ledger_lines = note:CalcNumberOfLedgerLines()
            if num_ledger_lines > 0  and num_ledger_lines > ledger_lines_above then
                ledger_lines_above = num_ledger_lines
            end
            if num_ledger_lines < 0 and num_ledger_lines < ledger_lines_below then
                ledger_lines_below = num_ledger_lines
            end
        end
        local function place_exp(ledger_line, staff_offset)
            local exp_assign = finale.FCExpression()
            exp_assign:SetStaff(entry.Staff)
            exp_assign:SetMeasurePos(entry.MeasurePos)
            exp_assign:SetID(exp_id)
            exp_assign:SetShape(exp_is_shape)
            exp_assign:SetHorizontalPos(horz_offset)
            exp_assign:SetVerticalPos(24*ledger_line + 12*staff_offset - center_offset)
            exp_assign:SaveNewToCell(finale.FCCell(entry.Measure, entry.Staff))
        end
        if ledger_lines_above ~= 0 or ledger_lines_below ~= 0 then
            local staff_spec = finale.FCCurrentStaffSpec()
            staff_spec:LoadForEntry(entry)
            entry.LedgerLines = false
            for ledger_line = 1, ledger_lines_above do
                place_exp(ledger_line, staff_spec:CalcTopStaffLinePosition(true))
            end
            for ledger_line = -1, ledger_lines_below, -1 do
                place_exp(ledger_line, staff_spec:CalcBottomStaffLinePosition(true))
            end
        end
    end
end

