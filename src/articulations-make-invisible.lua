for entry in eachentry(finenv.Region()) do
    local articulations = entry:CreateArticulations()
    for articulation in each(articulations) do
        articulation.Visible = false
        articulation:Save()
    end
end
