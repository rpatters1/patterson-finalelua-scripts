for entry in eachentrysaved(finenv.Region()) do
	if entry.GraceNote then
		entry.Duration = 0
	end
end

finenv.Region():RebeamMusic()
