for entry in eachentry(finenv.Region()) do
    if entry.Voice2 then
        finenv.UI():MoveToMeasure(entry.Measure, entry.Staff)
        return
    end
end
finenv.UI():AlertInfo("not found", "info")
