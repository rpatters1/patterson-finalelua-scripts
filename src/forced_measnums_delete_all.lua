local sep_nums = finale.FCSeparateMeasureNumbers()
sep_nums:LoadAllForRegion(finenv.Region())
for sep_num in each(sep_nums) do
    sep_num:DeleteData()
end

