exps = finale.FCExpressions()
exps:LoadAllForRegion(finenv.Region())
for exp in each(exps) do
    exp.LayerAssignment = 0
    exp:Save()
end