local mixin = require("library.mixin")

GLOBAL_TIMER = 1
global_dialog = nil
hires_timer = 0
original_document = finale.FCDocument()

if not global_dialog then
    local y_off = 20
    local curr_y = 0
    global_dialog = mixin.FCXCustomLuaWindow()
        :SetTitle("Current document")
    global_dialog:CreateStatic(0, curr_y, "curr_doc")
        :SetWidth(800)
    curr_y = curr_y + y_off
    global_dialog:CreateStatic(0, curr_y, "org_doc")
        :SetWidth(800)
    curr_y = curr_y + y_off
    global_dialog:CreateStatic(0, curr_y, "time")
        :SetWidth(100)
    curr_y = curr_y + y_off
    global_dialog:CreateCancelButton()
    global_dialog:RegisterHandleTimer(function(self, timer)
        if timer ~= GLOBAL_TIMER then
            return
        end
        local document = finale.FCDocument()
        local path = finale.FCString()
        document:GetPath(path)
        self:GetControl("curr_doc"):SetText(path)
        original_document:GetPath(path)
        self:GetControl("org_doc"):SetText(path)
        local proc_time = finale.FCUI.GetHiResTimer() - hires_timer
        self:GetControl("time"):SetText("Time: " .. string.format("%.3f", proc_time) .. " s")
    end)
    global_dialog:RegisterInitWindow(function(self)
        hires_timer = finale.FCUI.GetHiResTimer()
        self:GetControl("time"):SetText("")
        self:SetTimer(GLOBAL_TIMER, 100)
    end)
    global_dialog:RegisterCloseWindow(function(self)
        self:StopTimer(GLOBAL_TIMER)
    end)
end

global_dialog:RunModeless()
