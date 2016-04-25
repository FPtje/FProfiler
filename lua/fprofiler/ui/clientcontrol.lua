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

    update({"client", "bottlenecks"}, FProfiler.mostTimeInclusive())
    update({"client", "topLagSpikes"}, FProfiler.getMostExpensiveSingleCalls())

    local newTime = get({"client", "recordTime"}) + CurTime() - (get({"client", "sessionStart"}) or 0)
    update({"client", "recordTime"}, newTime)
    update({"client", "sessionStart"}, nil)
end

--[[-------------------------------------------------------------------------
Start/stop recording when the recording status is changed
---------------------------------------------------------------------------]]
onUpdate({"client", "status"}, function(new)
    (new == "Started" and restartProfiling or stopProfiling)()
end)
