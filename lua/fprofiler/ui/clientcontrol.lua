local get, update, onUpdate = FProfiler.UI.getModelValue, FProfiler.UI.updateModel, FProfiler.UI.onModelUpdate

--[[-------------------------------------------------------------------------
(Re)start clientside profiling
---------------------------------------------------------------------------]]
local function restartProfiling()
    if get({"client", "shouldReset"}) then
        FProfiler.Internal.reset()
        update({"client", "recordTime"}, 0)
    end

    local focus = get({"client", "focusObj"})

    update({"client", "sessionStart"}, CurTime())
    update({"client", "sessionStartSysTime"}, SysTime())
    FProfiler.Internal.start(focus)
end

--[[-------------------------------------------------------------------------
Stop profiling
---------------------------------------------------------------------------]]
local function stopProfiling()
    FProfiler.Internal.stop()

    local newTime = get({"client", "recordTime"}) + SysTime() - (get({"client", "sessionStartSysTime"}) or 0)

    -- Get the aggregated data
    local mostTime = FProfiler.Internal.getAggregatedResults(100)

    update({"client", "bottlenecks"}, mostTime)
    update({"client", "topLagSpikes"}, FProfiler.Internal.getMostExpensiveSingleCalls())

    update({"client", "recordTime"}, newTime)
    update({"client", "sessionStart"}, nil)
    update({"client", "sessionStartSysTime"}, nil)
end

--[[-------------------------------------------------------------------------
Start/stop recording when the recording status is changed
---------------------------------------------------------------------------]]
onUpdate({"client", "status"}, function(new, old)
    if new == old then return end
    (new == "Started" and restartProfiling or stopProfiling)()
end)

--[[-------------------------------------------------------------------------
Update the current selected focus object when data is entered
---------------------------------------------------------------------------]]
onUpdate({"client", "focusStr"}, function(new)
    update({"client", "focusObj"}, FProfiler.funcNameToObj(new))
end)

--[[-------------------------------------------------------------------------
Update info when a different line is selected
---------------------------------------------------------------------------]]
onUpdate({"client", "currentSelected"}, function(new)
    if not new or not new.info or not new.info.linedefined or not new.info.lastlinedefined or not new.info.short_src then return end

    update({"client", "sourceText"}, FProfiler.readSource(new.info.short_src, new.info.linedefined, new.info.lastlinedefined))
end)

--[[-------------------------------------------------------------------------
When a function is to be printed to console
---------------------------------------------------------------------------]]
onUpdate({"client", "toConsole"}, function(data)
    if not data then return end

    update({"client", "toConsole"}, nil)
    show(data)

    file.CreateDir("fprofiler")
    file.Write("fprofiler/profiledata.txt", showStr(data))
    MsgC(Color(200, 200, 200), "-----", Color(120, 120, 255), "NOTE", Color(200, 200, 200), "---------------\n")
    MsgC(Color(200, 200, 200), "If the above function does not fit in console, you can find it in data/fprofiler/profiledata.txt\n\n")
end)

--[[-------------------------------------------------------------------------
API function: start profiling
---------------------------------------------------------------------------]]
function FProfiler.start(focus)
    update({"client", "focusStr"}, tostring(focus))
    update({"client", "focusObj"}, focus)
    update({"client", "shouldReset"}, true)
    update({"client", "status"}, "Started")
end

--[[-------------------------------------------------------------------------
API function: stop profiling
---------------------------------------------------------------------------]]
function FProfiler.stop()
    update({"client", "status"}, "Stopped")
end

--[[-------------------------------------------------------------------------
API function: continue profiling
---------------------------------------------------------------------------]]
function FProfiler.continueProfiling()
    update({"client", "shouldReset"}, false)
    update({"client", "status"}, "Started")
end
