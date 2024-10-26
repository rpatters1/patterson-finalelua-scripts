for entry in eachentrysaved(finenv.Region()) do
    entry.Playback = true
    for note in each(entry) do
        note.Playback = true
    end
end