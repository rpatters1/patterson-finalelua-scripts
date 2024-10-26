for entry in eachentry(finenv.Region()) do
    finenv.UI():MoveToMeasure(entry.Measure, entry.Staff)
    return
end
finenv.UI():AlertInfo("not found", "info")
