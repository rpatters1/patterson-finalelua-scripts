local measures = finale.FCMeasures()
measures:LoadRegion(finenv.Region())
for measure in each(measures) do
    if measure.PageBreak then
        measure.PageBreak = false
        measure:Save()
    end
end