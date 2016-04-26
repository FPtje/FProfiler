local function getData()
    local callCounts = FProfiler.getCallCounts()
    local inclusiveTimes = FProfiler.getInclusiveTimes()
    local funcNames = FProfiler.getFunctionNames()

    local data = {}
    for func, called in pairs(callCounts) do
        local row = {}
        row.func = func
        row.info = debug.getinfo(func, "nfS")
        row.total_called = called
        row.total_time = inclusiveTimes[func] or 0
        row.average_time = row.total_time / row.total_called

        row.name, row.namewhat = nil, nil

        row.names = {}
        for name, namedata in pairs(funcNames[func]) do
            table.insert(row.names, {name = name, namewhat = namedata.namewhat, nparams = namedata.nparams})
        end

        table.insert(data, row)
    end

    return data
end

local function cull(data, count)
    if not count then return data end

    for i = count + 1, #data do
        data[i] = nil
    end

    return data
end

--[[-------------------------------------------------------------------------
The functions that are called most often
Their implementations are O(n lg n),
which is probably suboptimal but not worth my time optimising.
---------------------------------------------------------------------------]]
function FProfiler.mostOftenCalled(count)
    local sorted = getData()

    table.SortByMember(sorted, "total_called")

    return cull(sorted, count)
end

--[[-------------------------------------------------------------------------
The functions that take the longest time in total
---------------------------------------------------------------------------]]
function FProfiler.mostTimeInclusive(count)
    local sorted = getData()

    table.SortByMember(sorted, "total_time")

    return cull(sorted, count)
end

--[[-------------------------------------------------------------------------
The functions that take the longest average time
---------------------------------------------------------------------------]]
function FProfiler.mostTimeInclusiveAverage(count)
    local sorted = getData()

    table.SortByMember(sorted, "average_time")

    return cull(sorted, count)
end
