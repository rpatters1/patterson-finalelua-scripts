for system = 108, 144 do
    local baselines = finale.FCBaselines()
    baselines:LoadAllForSystem(finale.BASELINEMODE_LYRICSVERSE, system)
    for baseline in each(baselines) do
        baseline.LyricNumber = baseline.LyricNumber + 9
        baseline:Save()
    end
end
