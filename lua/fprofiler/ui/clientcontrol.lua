local get, update, onUpdate = FProfiler.UI.getModelValue, FProfiler.UI.updateModel, FProfiler.UI.onModelUpdate

--[[-------------------------------------------------------------------------
(Re)start clientside profiling
---------------------------------------------------------------------------]]
local function restartProfiling()
    if get({"client", "shouldReset"}) then
        FProfiler.reset()
        update({"client", "recordTime"}, 0)
    end

    local focus = get({"client", "focus"})

    update({"client", "sessionStart"}, CurTime())
    FProfiler.start(focus)
end

--[[-------------------------------------------------------------------------
Stop profiling
---------------------------------------------------------------------------]]
local function stopProfiling()
    FProfiler.stop()

    local newTime = get({"client", "recordTime"}) + CurTime() - (get({"client", "sessionStart"}) or 0)

    -- Prevent the model from getting too many things
    local dict = {}
    local mostTime = FProfiler.mostTimeInclusive(100)
    for i = 1, #mostTime do dict[mostTime[i].func] = true end

    local mostAvg = FProfiler.mostTimeInclusiveAverage(100)

    for i = 1, #mostAvg do
        if dict[mostAvg[i].func] then continue end
        dict[mostAvg[i].func] = true
        table.insert(mostTime, mostAvg[i])
    end

    local mostCalled = FProfiler.mostOftenCalled(100)

    for i = 1, #mostCalled do
        if dict[mostCalled[i].func] then continue end
        dict[mostCalled[i].func] = true
        table.insert(mostTime, mostCalled[i])
    end

    update({"client", "bottlenecks"}, mostTime)
    update({"client", "topLagSpikes"}, FProfiler.getMostExpensiveSingleCalls())

    update({"client", "recordTime"}, newTime)
    update({"client", "sessionStart"}, nil)
end

--[[-------------------------------------------------------------------------
Start/stop recording when the recording status is changed
---------------------------------------------------------------------------]]
onUpdate({"client", "status"}, function(new, old)
    if new == old then return end
    (new == "Started" and restartProfiling or stopProfiling)()
end)
