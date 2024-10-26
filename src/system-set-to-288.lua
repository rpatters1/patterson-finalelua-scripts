local region = finenv.Region()
local systems = finale.FCStaffSystems()
systems:LoadAll()

local start_measure = region:GetStartMeasure()
local end_measure = region:GetEndMeasure()
local system = systems:FindMeasureNumber(start_measure)
local last_system = systems:FindMeasureNumber(end_measure)
local system_number = system:GetItemNo()
local last_system_number = last_system:GetItemNo()

for i = system_number, last_system_number, 1 do
    local system = systems:GetItemAt(i - 1)
    system.SpaceAbove = 288
    system:Save()
end
