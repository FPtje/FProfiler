
-- Try to find the function represented by a string
function FProfiler.funcNameToObj(str)
    if isfunction(str) then return str end

    local times = FProfiler.getInclusiveTimes()
    for func, _ in pairs(times) do
        if tostring(func) == str then return func end
    end

    local tbl = _G
    local exploded = string.Explode(".", str, false)
    if not exploded or not exploded[1] then return end

    for i = 1, #exploded - 1 do
        tbl = (tbl or {})[exploded[i]]
    end

    local func = (tbl or {})[exploded[#exploded]]

    if not isfunction(func) then return end

    return func
end
