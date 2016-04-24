--[[-------------------------------------------------------------------------
The model describes the data that the drives the UI
Loosely based on the Elm architecture
---------------------------------------------------------------------------]]

local model =
    {
        realm = "client", -- "client" or "server"
        focus = nil,

        client = {
            status = "Stopped", -- Started or Stopped
            focus = nil, -- Any function in focus
            bottlenecks = {}, -- The list of bottleneck functions
            topLagSpikes = {}, -- Top of lagging functions
        },

        server = {
            status = "Stopped", -- Started or Stopped
            focus = nil, -- Any function in focus
            bottlenecks = {}, -- The list of bottleneck functions
            topLagSpikes = {}, -- Top of lagging functions
        },
    }


local updaters = {}

a, b = model, updaters

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
    if mdlTbl[key] then
        func(mdlTbl[key], mdlTbl[key])
    end
end

--[[-------------------------------------------------------------------------
Registers a hook to both realms
---------------------------------------------------------------------------]]
function FProfiler.UI.onCurrentRealmUpdate(path, func)
    path = istable(path) and path or {path}

    table.insert(path, 1, "client")
    FProfiler.UI.onModelUpdate(path, func)

    path[1] = "server"
    FProfiler.UI.onModelUpdate(path, func)
end

function FProfiler.UI.clearUpdaters()
    table.Empty(updaters)

    FProfiler.UI.onModelUpdate("realm", function(new, old)
        if not updaters[new] then return end

        for k, funcTbl in pairs(updaters[new]) do
            for _, func in ipairs(funcTbl) do
                func(model[new][k], model[new][k])
            end
        end
    end)
end
