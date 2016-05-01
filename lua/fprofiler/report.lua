local function getData()
    local callCounts = FProfiler.Internal.getCallCounts()
    local inclusiveTimes = FProfiler.Internal.getInclusiveTimes()
    local funcNames = FProfiler.Internal.getFunctionNames()

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
function FProfiler.Internal.mostOftenCalled(count)
    local sorted = getData()

    table.SortByMember(sorted, "total_called")

    return cull(sorted, count)
end

--[[-------------------------------------------------------------------------
The functions that take the longest time in total
---------------------------------------------------------------------------]]
function FProfiler.Internal.mostTimeInclusive(count)
    local sorted = getData()

    table.SortByMember(sorted, "total_time")

    return cull(sorted, count)
end

--[[-------------------------------------------------------------------------
The functions that take the longest average time
---------------------------------------------------------------------------]]
function FProfiler.Internal.mostTimeInclusiveAverage(count)
    local sorted = getData()

    table.SortByMember(sorted, "average_time")

    return cull(sorted, count)
end

--[[-------------------------------------------------------------------------
Get the top <count> of most often called, time inclusive and average
NOTE: This will almost definitely return more than <count> results.
Up to three times <count> is possible.
---------------------------------------------------------------------------]]
function FProfiler.Internal.getAggregatedResults(count)
    count = count or 100

    local dict = {}
    local mostTime = FProfiler.Internal.mostTimeInclusive(count)
    for i = 1, #mostTime do dict[mostTime[i].func] = true end

    local mostAvg = FProfiler.Internal.mostTimeInclusiveAverage(count)

    for i = 1, #mostAvg do
        if dict[mostAvg[i].func] then continue end
        dict[mostAvg[i].func] = true
        table.insert(mostTime, mostAvg[i])
    end

    local mostCalled = FProfiler.Internal.mostOftenCalled(count)

    for i = 1, #mostCalled do
        if dict[mostCalled[i].func] then continue end
        dict[mostCalled[i].func] = true
        table.insert(mostTime, mostCalled[i])
    end

    table.SortByMember(mostTime, "total_time")

    return mostTime
end
