local spacing_table = {78, 54, 36, 24, 8, 6, 3}

local prefs = finale.FCMusicSpacingPrefs()
prefs:Load(1)
if prefs.ManualPositioning ~= finale.MANUALPOS_INCORPORATE then
    local result = finenv.UI():AlertYesNo("Document Music Spacing Settings do not have Manual Position set to Incorporate. Would you like to change it?", "")
    if result == finale.YESRETURN then
        prefs.ManualPositioning = finale.MANUALPOS_INCORPORATE
        prefs:Save()
    end
end

--require('mobdebug').start()

for measure_num, staff_num in eachcell(finenv.Region()) do
    for layer = 1, finale.FCLayerPrefs.GetMaxLayers() do
        local cell_entries = finale.FCNoteEntryCell(measure_num, staff_num)
        cell_entries.LoadMirrors = false
        cell_entries.LoadLayerMode = layer
        if cell_entries:Load() then
            local min_entry_index = 0
            local max_entry_index = 0
            local got_one = false
            for index = 0, cell_entries.Count-1 do
                local test_entry = cell_entries:GetItemAt(index)
                if finenv.Region():IsEntryPosWithin(test_entry) then
                    if not got_one then
                        min_entry_index = index
                    end
                    if index > max_entry_index then
                        max_entry_index = index
                    end
                    got_one = true
                end
            end
            local entry_count = got_one and max_entry_index - min_entry_index + 1 or 0
            if entry_count > 4 then                
                local initial_spacing_index = #spacing_table - math.min(#spacing_table, math.floor(entry_count / 2)) + 1 -- entry_count - 2) + 1 -- 
                for entry_index = min_entry_index+1, max_entry_index do
                    local spacing_index = entry_index - 1 - min_entry_index + initial_spacing_index
                    local additional_offset = spacing_index <= #spacing_table and spacing_table[spacing_index] or 0
                    local entry = cell_entries:GetItemAt(entry_index)
                    entry.ManualPosition = additional_offset
                end
                cell_entries:Save()                
            end
        end
    end
end
