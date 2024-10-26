for entry in eachentrysaved(finenv.Region()) do
    local mod = finale.FCBrokenBeamMod()
    mod:SetNoteEntry(entry)
    local loaded = mod:LoadFirst()
    mod.LeftDirection = true
    if loaded then
        mod:Save()
    else
        mod:SaveNew()
    end
end
