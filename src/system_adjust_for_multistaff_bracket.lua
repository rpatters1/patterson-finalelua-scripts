local library = require("library.general_library")

local evpus_to_shift = 12

local is_staff_visible = function(staff)    
    local hidden_value = staff.HideMode
    if (hidden_value == finale.STAFFHIDE_SCORE_AND_PARTS) or (hidden_value == finale.STAFFHIDE_CUTAWAY) then
       return false
    end
    if hidden_value == finale.STAFFHIDE_SCORE then
        local current_part = library.get_current_part()
        if current_part:IsScore() then
          return false
        end
    end
    return true   
end

local system_is_multistaff_at_beginning = function(system_staves, system)
    if system_staves.Count <= 1 then
        return false
    end
    local visible_staff_count = 0
    for system_staff in each(system_staves) do
        local staff = finale.FCCurrentStaffSpec()
        staff:LoadForCell(finale.FCCell(system.FirstMeasure, system_staff.Staff), 0)
        if is_staff_visible(staff) then
            visible_staff_count = visible_staff_count + 1
            if visible_staff_count > 1 then
                return true
            end
        end
    end
    return false
end

local region = library.get_selected_region_or_whole_doc()
local page_format_prefs = library.get_page_format_prefs()

local systems = finale.FCStaffSystems()
systems:LoadAll()
local start_system = systems:FindMeasureNumber(region.StartMeasure)
local end_system = systems:FindMeasureNumber(region.EndMeasure)
local meas_num_regions = finale.FCMeasureNumberRegions()
meas_num_regions:LoadAll()
for system_number = start_system.ItemNo, end_system.ItemNo do
    local system = finale.FCStaffSystem()
    system:Load(system_number)
    local system_staves = finale.FCSystemStaves()
    system_staves:LoadAllForItem(system_number)
    local shift_amount = 0
    if system_is_multistaff_at_beginning(system_staves, system) then
        shift_amount = evpus_to_shift
    end
    local is_first_system = (system.FirstMeasure == 1)
    local first_meas = finale.FCMeasure()
    if (not is_first_system) and first_meas:Load(system.FirstMeasure) then
        if first_meas.ShowFullNames then
            is_first_system = true
        end
    end
    if is_first_system and page_format_prefs.UseFirstSystemMargins then
        system.LeftMargin = page_format_prefs.FirstSystemLeft + shift_amount
    else
        system.LeftMargin = page_format_prefs.SystemLeft + shift_amount
    end
    system:Save()
    local meas_num_region = meas_num_regions:FindMeasure(system.FirstMeasure)
    multimeasure_rest = finale.FCMultiMeasureRest()
    local is_for_multimeasure_rest = multimeasure_rest:Load(system.FirstMeasure)
    for system_staff in each(system_staves) do
        local cell = finale.FCCell(system.FirstMeasure, system_staff.Staff)
        if library.is_default_number_visible_and_left_aligned(meas_num_region, cell, system, current_is_part, is_for_multimeasure_rest) then
            local sep_nums = finale.FCSeparateMeasureNumbers()
            sep_nums:LoadAllInCell(cell)
            if (sep_nums.Count > 0) then
                for sep_num in each(sep_nums) do
                    sep_num.HorizontalPosition = -shift_amount
                    sep_num:Save()
                end
            elseif (0 ~= shift_amount) then
                local sep_num = finale.FCSeparateMeasureNumber()
                sep_num:ConnectCell(cell)
                sep_num:AssignMeasureNumberRegion(meas_num_region)
                sep_num.HorizontalPosition = -shift_amount
                if sep_num:SaveNew() then
                    local measure = finale.FCMeasure()
                    measure:Load(cell.Measure)
                    measure:SetContainsManualMeasureNumbers(true)
                    measure:Save()
                end
            end
        end
    end
end

library.update_layout()
