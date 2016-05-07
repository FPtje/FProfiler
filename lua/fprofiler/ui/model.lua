--[[-------------------------------------------------------------------------
The model describes the data that the drives the UI
Loosely based on the Elm architecture
---------------------------------------------------------------------------]]

local model =
    {
        realm = "client", -- "client" or "server"
        serverAccess = false, -- Whether the player has access to profile the server
        frameVisible = false, -- Whether the frame is visible

        client = {
            status = "Stopped", -- Started or Stopped
            shouldReset = true, -- Whether profiling should start anew
            recordTime = 0, -- Total time spent on the last full profiling session
            sessionStart = nil, -- When the last profiling session was started
            sessionStartSysTime = nil, -- When the last profiling session was started, measured in SysTime
            bottlenecks = {}, -- The list of bottleneck functions
            topLagSpikes = {}, -- Top of lagging functions
            currentSelected = nil, -- Currently selected function

            focusObj = nil, -- The current function being focussed upon in profiling
            focusStr = "", -- The current function name being entered

            toConsole = nil, -- Any functions that should be printed to console

            sourceText = "", -- The text of the source function (if available)
        },

        server = {
            status = "Stopped", -- Started or Stopped
            shouldReset = true, -- Whether profiling should start anew
            bottlenecks = {}, -- The list of bottleneck functions
            recordTime = 0, -- Total time spent on the last full profiling session
            sessionStart = nil, -- When the last profiling session was started
            topLagSpikes = {}, -- Top of lagging functions
            currentSelected = nil, -- Currently selected function

            focusObj = nil, -- The current function being focussed upon in profiling
            focusStr = "", -- The current function name

            toConsole = nil, -- Any functions that should be printed to console

            sourceText = "", -- The text of the source function (if available)
            fromServer = false, -- Whether a change of the model came from the server.
        },
    }


local updaters = {}


--[[-------------------------------------------------------------------------
Update the model.
Automatically calls the registered update hook functions

e.g. updating the realm would be:
FProfiler.UI.updateModel("realm", "server")
---------------------------------------------------------------------------]]
function FProfiler.UI.updateModel(path, value)
    path = istable(path) and path or {path}

    local updTbl = updaters
    local mdlTbl = model
    local key = path[#path]

    for i = 1, #path - 1 do
        mdlTbl = mdlTbl[path[i]]
        updTbl = updTbl and updTbl[path[i]]
    end

    local oldValue = mdlTbl[key]
    mdlTbl[key] = value

    for _, updFunc in ipairs(updTbl and updTbl[key] or {}) do
        updFunc(value, oldValue)
    end
end

--[[-------------------------------------------------------------------------
Update the model of the current realm
---------------------------------------------------------------------------]]
function FProfiler.UI.updateCurrentRealm(path, value)
    path = istable(path) and path or {path}

    table.insert(path, 1, model.realm)

    FProfiler.UI.updateModel(path, value)
end

--[[-------------------------------------------------------------------------
Retrieve a value of the model
---------------------------------------------------------------------------]]
function FProfiler.UI.getModelValue(path)
    path = istable(path) and path or {path}

    local mdlTbl = model
    local key = path[#path]

    for i = 1, #path - 1 do
        mdlTbl = mdlTbl[path[i]]
    end

    return mdlTbl[key]
end

--[[-------------------------------------------------------------------------
Retrieve a value of the model regardless of realm
---------------------------------------------------------------------------]]
function FProfiler.UI.getCurrentRealmValue(path)
    path = istable(path) and path or {path}

    table.insert(path, 1, model.realm)

    return FProfiler.UI.getModelValue(path)
end

--[[-------------------------------------------------------------------------
Registers a hook that gets triggered when a certain part of the model is updated
e.g. FProfiler.UI.onModelUpdate("realm", print) prints when the realm is changed
---------------------------------------------------------------------------]]
function FProfiler.UI.onModelUpdate(path, func)
    path = istable(path) and path or {path}

    local updTbl = updaters
    local mdlTbl = model
    local key = path[#path]

    for i = 1, #path - 1 do
        mdlTbl = mdlTbl[path[i]]
        updTbl[path[i]] = updTbl[path[i]] or {}
        updTbl = updTbl[path[i]]
    end

    updTbl[key] = updTbl[key] or {}

    table.insert(updTbl[key], func)

    -- Call update with the initial value
    if mdlTbl[key] ~= nil then
        func(mdlTbl[key], mdlTbl[key])
    end
end

--[[-------------------------------------------------------------------------
Registers a hook to both realms
---------------------------------------------------------------------------]]
function FProfiler.UI.onCurrentRealmUpdate(path, func)
    path = istable(path) and path or {path}

    table.insert(path, 1, "client")
    FProfiler.UI.onModelUpdate(path, function(...)
        if FProfiler.UI.getModelValue("realm") == "server" then return end

        func(...)
    end)

    path[1] = "server"
    FProfiler.UI.onModelUpdate(path, function(...)
        if FProfiler.UI.getModelValue("realm") == "client" then return end

        func(...)
    end)
end

--[[-------------------------------------------------------------------------
When the realm is changed, all update functions of the new realm are to be called
---------------------------------------------------------------------------]]
FProfiler.UI.onModelUpdate("realm", function(new, old)
    if not updaters[new] then return end

    for k, funcTbl in pairs(updaters[new]) do
        for _, func in ipairs(funcTbl) do
            func(model[new][k], model[new][k])
        end
    end
end)

