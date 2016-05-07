--[[-------------------------------------------------------------------------
The server is involved in the ui in the sense that it interacts with its model
---------------------------------------------------------------------------]]

-- Net messages
util.AddNetworkString("FProfile_startProfiling")
util.AddNetworkString("FProfile_stopProfiling")
util.AddNetworkString("FProfile_focusObj")
util.AddNetworkString("FProfile_getSource")
util.AddNetworkString("FProfile_printFunction")
util.AddNetworkString("FProfile_fullModelUpdate")
util.AddNetworkString("FProfile_focusUpdate")
util.AddNetworkString("FProfile_unsubscribe")

--[[-------------------------------------------------------------------------
Simplified version of the model
Contains only what the server needs to know
---------------------------------------------------------------------------]]
local model =
{
    focusObj = nil, -- the function currently in focus
    sessionStart = nil, -- When the last profiling session was started. Used for the live timer.
    sessionStartSysTime = nil, -- Same as sessionStart, but measured in SysTime. Used to update recordTime
    recordTime = 0, -- Total time spent on the last full profiling session
    bottlenecks = {}, -- The list of bottleneck functions
    topLagSpikes = {}, -- Top of lagging functions
    subscribers = RecipientFilter(), -- The players that get updates of the profiler model
}

--[[-------------------------------------------------------------------------
Helper function: receive a net message
---------------------------------------------------------------------------]]
local function receive(msg, f)
    net.Receive(msg, function(len, ply)
        -- Check access.
        CAMI.PlayerHasAccess(ply, "FProfiler", function(b, _)
            if not b then return end

            f(len, ply)
        end)
    end)
end

--[[-------------------------------------------------------------------------
Helper function:
Write generic row data to a net message
---------------------------------------------------------------------------]]
local function writeRowData(row)
    net.WriteString(tostring(row.func))
    net.WriteString(row.info.short_src)
    net.WriteUInt(row.info.linedefined, 16)
    net.WriteUInt(row.info.lastlinedefined, 16)
end

--[[-------------------------------------------------------------------------
Helper function:
Send the bottlenecks to the client
Only sends the things displayed
---------------------------------------------------------------------------]]
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

--[[-------------------------------------------------------------------------
Helper function:
Sends the top n functions
---------------------------------------------------------------------------]]
local function writeTopN()
    local count = #model.topLagSpikes

    -- All top N f
    for i = count, 0, -1 do
        if model.topLagSpikes and model.topLagSpikes[i] and model.topLagSpikes[i].info then break end -- Entry exists
        count = i
    end

    net.WriteUInt(count, 8)

    for i = 1, count do
        local row = model.topLagSpikes[i]

        if not row.info then break end

        writeRowData(row)

        net.WriteString(row.info.name or "")
        net.WriteString(row.info.namewhat or "")
        net.WriteDouble(row.runtime)
    end
end

-- Start profiling
local function startProfiling()
    model.sessionStart = CurTime()
    model.sessionStartSysTime = SysTime()
    FProfiler.Internal.start(model.focusObj)

    net.Start("FProfile_startProfiling")
        net.WriteDouble(model.recordTime)
        net.WriteDouble(model.sessionStart)
    net.Send(model.subscribers:GetPlayers())
end

-- Stop profiling
local function stopProfiling()
    FProfiler.Internal.stop()

    model.recordTime = model.recordTime + SysTime() - (model.sessionStartSysTime or 0)
    model.sessionStart = nil
    model.sessionStartSysTime = nil

    model.bottlenecks = FProfiler.Internal.getAggregatedResults(100)
    model.topLagSpikes = FProfiler.Internal.getMostExpensiveSingleCalls()

    net.Start("FProfile_stopProfiling")
        net.WriteDouble(model.recordTime)

        writeBottleNecks()
        writeTopN()
    net.Send(model.subscribers:GetPlayers())
end


--[[-------------------------------------------------------------------------
Receive an update of the function to focus on
---------------------------------------------------------------------------]]
receive("FProfile_focusObj", function(_, ply)
    local funcStr = net.ReadString()

    model.focusObj = FProfiler.funcNameToObj(funcStr)

    net.Start("FProfile_focusObj")
        net.WriteBool(model.focusObj and true or false)
    net.Send(ply)

    -- Send a focus update to all other players
    net.Start("FProfile_focusUpdate")
        net.WriteString(funcStr)
        net.WriteBool(model.focusObj and true or false)
    model.subscribers:RemovePlayer(ply)
    net.Send(model.subscribers:GetPlayers())
    model.subscribers:AddPlayer(ply)
end)


--[[-------------------------------------------------------------------------
Receive a "start profiling" signal
---------------------------------------------------------------------------]]
receive("FProfile_startProfiling", function(_, ply)
    local shouldReset = net.ReadBool()
    if shouldReset then
        FProfiler.Internal.reset()
        model.recordTime = 0
    end

    startProfiling()
end)


--[[-------------------------------------------------------------------------
Receive a stop profiling signal
---------------------------------------------------------------------------]]
receive("FProfile_stopProfiling", function(_, ply)
    stopProfiling()
end)


--[[-------------------------------------------------------------------------
Send the source of a function to a client
---------------------------------------------------------------------------]]
receive("FProfile_getSource", function(_, ply)
    local func = FProfiler.funcNameToObj(net.ReadString())

    if not func then return end

    local info = debug.getinfo(func)

    if not info then return end

    net.Start("FProfile_getSource")
        net.WriteString(FProfiler.readSource(info.short_src, info.linedefined, info.lastlinedefined) or "")
    net.Send(ply)
end)


--[[-------------------------------------------------------------------------
Print the details of a function
---------------------------------------------------------------------------]]
receive("FProfile_printFunction", function(_, ply)
    local source = net.ReadBool() -- true is from bottlenecks, false is from Top-N
    local dataSource = source and model.bottlenecks or model.topLagSpikes
    local func = net.ReadString()

    local data

    for _, row in ipairs(dataSource or {}) do
        if tostring(row.func) == func then data = row break end
    end

    if not data then return end

    -- Show the data
    show(data)
    local plaintext = showStr(data)

    -- Write to file if necessary
    file.CreateDir("fprofiler")
    file.Write("fprofiler/profiledata.txt", plaintext)
    MsgC(Color(200, 200, 200), "-----", Color(120, 120, 255), "NOTE", Color(200, 200, 200), "---------------\n")
    MsgC(Color(200, 200, 200), "If the above function does not fit in console, you can find it in data/fprofiler/profiledata.txt\n\n")

    -- Listen server hosts already see the server console
    if ply:IsListenServerHost() then return end

    -- Send a plaintext version to the client
    local binary = util.Compress(plaintext)

    net.Start("FProfile_printFunction")
        net.WriteData(binary, #binary)
    net.Send(ply)
end)


--[[-------------------------------------------------------------------------
Request of a full model update
Particularly useful when someone else has done (or is performing) a profiling session
and the current player wants to see the results
---------------------------------------------------------------------------]]
receive("FProfile_fullModelUpdate", function(_, ply)
    -- This player is now subscribed to the updates
    model.subscribers:AddPlayer(ply)

    net.Start("FProfile_fullModelUpdate")
        net.WriteBool(model.focusObj ~= nil)
        if model.focusObj ~= nil then net.WriteString(tostring(model.focusObj)) end

        -- Bool also indicates whether it's currently profiling
        net.WriteBool(model.sessionStart ~= nil)
        if model.sessionStart ~= nil then net.WriteDouble(model.sessionStart) end

        net.WriteDouble(model.recordTime)

        writeBottleNecks()
        writeTopN()

    net.Send(ply)
end)

--[[-------------------------------------------------------------------------
Unsubscribe from the updates of the profiler
---------------------------------------------------------------------------]]
receive("FProfile_unsubscribe", function(_, ply)
    model.subscribers:RemovePlayer(ply)
end)

--[[-------------------------------------------------------------------------
API function: start profiling
---------------------------------------------------------------------------]]
function FProfiler.start(focus)
    FProfiler.Internal.reset()

    model.recordTime = 0
    model.focusObj = focus

    startProfiling()
end

--[[-------------------------------------------------------------------------
API function: stop profiling
---------------------------------------------------------------------------]]
function FProfiler.stop()
    stopProfiling()
end

--[[-------------------------------------------------------------------------
API function: continue profiling
---------------------------------------------------------------------------]]
function FProfiler.continueProfiling()
    startProfiling()
end
