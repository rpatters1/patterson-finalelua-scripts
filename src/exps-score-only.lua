exps = finale.FCExpressions()
exps:LoadAllForRegion(finenv.Region())
for exp in each(exps) do
    exp.PartAssignment = false
    exp.ScoreAssignment = true
    exp:Save()
end