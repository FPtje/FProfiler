--[[-------------------------------------------------------------------------
The server is involved in the ui in the sense that it interacts with its model
---------------------------------------------------------------------------]]

-- Net messages
util.AddNetworkString("FProfile_startProfiling")
util.AddNetworkString("FProfile_stopProfiling")
util.AddNetworkString("FProfile_focusObj")


--[[-------------------------------------------------------------------------
Helper function: receive a net message
---------------------------------------------------------------------------]]
local function receive(msg, f)
    net.Receive(msg, function(len, ply)
        -- Check access. TODO: CAMI integration?
        if not ply:IsSuperAdmin() then return end

        return f(len, ply)
    end)
end


--[[-------------------------------------------------------------------------
Simplified version of the model
Contains only what the server needs to know
---------------------------------------------------------------------------]]
local model =
{
    focusObj = nil, -- the function currently in focus
    sessionStart = nil, -- When the last profiling session was started
    recordTime = 0, -- Total time spent on the last full profiling session
    bottlenecks = {}, -- The list of bottleneck functions
    topLagSpikes = {}, -- Top of lagging functions
}


--[[-------------------------------------------------------------------------
Receive an update of the function to focus on
---------------------------------------------------------------------------]]
receive("FProfile_focusObj", function(_, ply)
    local funcStr = net.ReadString()

    model.focusObj = FProfiler.funcNameToObj(funcStr)

    net.Start("FProfile_focusObj")
        net.WriteBool(model.focusObj and true or false)
    net.Send(ply)
end)


--[[-------------------------------------------------------------------------
Receive a "start profiling" signal
---------------------------------------------------------------------------]]
receive("FProfile_startProfiling", function(_, ply)
    local shouldReset = net.ReadBool()
    if shouldReset then
        FProfiler.reset()
        model.recordTime = 0
    end

    model.sessionStart = CurTime()
    FProfiler.start(model.focusObj)

    net.Start("FProfile_startProfiling")
        net.WriteDouble(model.recordTime)
        net.WriteDouble(model.sessionStart)
    net.Send(ply)
end)

-- Write generic row data to a net message
local function writeRowData(row)
    net.WriteString(tostring(row.func))
    net.WriteString(row.info.short_src)
    net.WriteUInt(row.info.linedefined, 16)
    net.WriteUInt(row.info.lastlinedefined, 16)
end

-- Send the bottlenecks to the client
-- Only sends the things displayed
local function writeBottleNecks()
    net.WriteUInt(#model.bottlenecks, 16)

    for i, row in ipairs(model.bottlenecks) do
        writeRowData(row)

        net.WriteUInt(#row.names, 8)

        for j, name in ipairs(row.names) do
            net.WriteString(name.name)
            net.WriteString(name.namewhat)
        end

        net.WriteUInt(row.total_called, 32)
        net.WriteDouble(row.total_time)
        net.WriteDouble(row.average_time)
    end
end

-- Sends the top n functions
local function writeTopN()
    net.WriteUInt(#model.topLagSpikes, 8)

    for i, row in ipairs(model.topLagSpikes) do
        writeRowData(row)

        net.WriteString(row.info.name or "")
        net.WriteString(row.info.namewhat or "")
        net.WriteDouble(row.runtime)
    end
end
--[[-------------------------------------------------------------------------
Receive a stop profiling signal
---------------------------------------------------------------------------]]
receive("FProfile_stopProfiling", function(_, ply)
    FProfiler.stop()

    model.recordTime = model.recordTime + CurTime() - (model.sessionStart or 0)
    model.sessionStart = nil

    model.bottlenecks = FProfiler.getAggregatedResults(100)
    model.topLagSpikes = FProfiler.getMostExpensiveSingleCalls()

    net.Start("FProfile_stopProfiling")
        net.WriteDouble(model.recordTime)

        writeBottleNecks()
        writeTopN()
    net.Send(ply)
end)
