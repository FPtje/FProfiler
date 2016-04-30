local get, update, onUpdate = FProfiler.UI.getModelValue, FProfiler.UI.updateModel, FProfiler.UI.onModelUpdate

--[[-------------------------------------------------------------------------
Update the current selected focus object when data is entered
---------------------------------------------------------------------------]]
onUpdate({"server", "focusStr"}, function(new)
    if not new then return end

    net.Start("FProfile_focusObj")
        net.WriteString(new)
    net.SendToServer()
end)

net.Receive("FProfile_focusObj", function()
    update({"server", "focusObj"}, net.ReadBool() and get({"server", "focusStr"}) or nil)
end)


--[[-------------------------------------------------------------------------
(Re)start profiling
---------------------------------------------------------------------------]]
local function restartProfiling()
    local shouldReset = get({"server", "shouldReset"})

    net.Start("FProfile_startProfiling")
        net.WriteBool(shouldReset)
    net.SendToServer()
end

net.Receive("FProfile_startProfiling", function()
    update({"server", "recordTime"}, net.ReadDouble())
    update({"server", "sessionStart"}, net.ReadDouble())
end)

--[[-------------------------------------------------------------------------
Stop profiling
---------------------------------------------------------------------------]]
local function stopProfiling()
    net.Start("FProfile_stopProfiling")
    net.SendToServer()
end

-- Read a row from a net message
local function readDataRow(countSize, readSpecific)
    local res = {}

    local count = net.ReadUInt(countSize)

    for i = 1, count do
        local row = {}
        row.info = {}

        row.func = net.ReadString()
        row.info.short_src = net.ReadString()
        row.info.linedefined = net.ReadUInt(16)
        row.info.lastlinedefined = net.ReadUInt(16)

        readSpecific(row)

        table.insert(res, row)
    end

    return res
end

-- Read a bottleneck row
local function readBottleneckRow(row)
    local nameCount = net.ReadUInt(8)

    row.names = {}
    for i = 1, nameCount do
        table.insert(row.names, {
            name = net.ReadString(),
            namewhat = net.ReadString()
        })
    end

    row.total_called = net.ReadUInt(32)
    row.total_time = net.ReadDouble()
    row.average_time = net.ReadDouble()
end

-- Read the top n row
local function readTopNRow(row)
    row.info.name = net.ReadString()
    row.info.namewhat = net.ReadString()
    row.runtime = net.ReadDouble()
end

net.Receive("FProfile_stopProfiling", function()
    update({"server", "sessionStart"}, nil)
    update({"server", "recordTime"}, net.ReadDouble())

    update({"server", "bottlenecks"}, readDataRow(16, readBottleneckRow))
    update({"server", "topLagSpikes"}, readDataRow(8, readTopNRow))
end)

--[[-------------------------------------------------------------------------
Start/stop recording when the recording status is changed
---------------------------------------------------------------------------]]
onUpdate({"server", "status"}, function(new, old)
    if new == old then return end
    (new == "Started" and restartProfiling or stopProfiling)()
end)

--[[-------------------------------------------------------------------------
Update info when a different line is selected
---------------------------------------------------------------------------]]
FProfiler.UI.onModelUpdate({"server", "currentSelected"}, function(new)
    if not new or not new.info or not new.info.linedefined or not new.info.lastlinedefined or not new.info.short_src then return end

    net.Start("FProfile_getSource")
        net.WriteString(tostring(new.func))
    net.SendToServer()
end)

net.Receive("FProfile_getSource", function()
    FProfiler.UI.updateModel({"server", "sourceText"}, net.ReadString())
end)

--[[-------------------------------------------------------------------------
When a function is to be printed to console
---------------------------------------------------------------------------]]
onUpdate({"server", "toConsole"}, function(data)
    if not data then return end

    update({"server", "toConsole"}, nil)

    net.Start("FProfile_printFunction")
        net.WriteBool(data.total_called and true or false) -- true for bottleneck function, false for top-n function
        net.WriteString(tostring(data.func))
    net.SendToServer()
end)

net.Receive("FProfile_printFunction", function(len)
    local data = net.ReadData(len)
    local decompressed = util.Decompress(data)

    -- Print the text line by line, otherwise big parts of big data will not be printed
    local split = string.Explode("\n", decompressed, false)
    for _, line in ipairs(split) do
        MsgN(line)
    end

    -- Write the thing to a file
    file.CreateDir("fprofiler")
    file.Write("fprofiler/profiledata.txt", showStr(data))
    MsgC(Color(200, 200, 200), "-----", Color(120, 120, 255), "NOTE", Color(200, 200, 200), "---------------\n")
    MsgC(Color(200, 200, 200), "In the server's console you can find a colour coded version of the above output.\nIf the above function does not fit in console, you can find it in data/fprofiler/profiledata.txt\n\n")
end)
