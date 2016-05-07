local timeMeasurementFunc = SysTime

-- Helper function, created by some ancient Lua dev
-- Retrieves the local variables and their values of a function
local function getupvalues(f)
    local t, i, k, v = {}, 1, debug.getupvalue(f, 1)
    while k do
        t[k] = v
        i = i + 1
        k,v = debug.getupvalue(f, i)
    end
    return t
end

-- Helper function
-- Get all local variables
local NIL = {}
setmetatable(NIL, {__tostring = function() return "nil" end})
local function getlocals(level)
    local i = 1
    local name, value
    local vars = {}

    while true do
        name, value = debug.getlocal(level, i)

        if not name then break end

        value = value == nil and NIL or value
        vars[name] = value
        i = i + 1
    end

    return vars
end

--[[-------------------------------------------------------------------------
Call counts:

registers how often function have been called
---------------------------------------------------------------------------]]
local callcounts = {}


-- Gets the call counts
FProfiler.Internal.getCallCounts = function() return callcounts end


-- Resets the call counts
function FProfiler.Internal.resetCallCounts()
    callcounts = {}
end

--[[-------------------------------------------------------------------------
Inclusive function times

Keeps track of how long functions take in total
i.e. average time between the start and return of a function * times called

This includes the time that any function called by this function takes
(that's what the "inclusive" refers to).
Note: recursive calls are not counted double
---------------------------------------------------------------------------]]

local inclusiveTimes = {}

-- Gets the inclusive times
FProfiler.Internal.getInclusiveTimes = function() return inclusiveTimes end

-- Resets the inclusive times
function FProfiler.Internal.resetInclusiveTimes()
    inclusiveTimes = {}
end

--[[-------------------------------------------------------------------------
Top n most expensive single function calls
Keeps track of the functions that took the longest time to run
Note: functions can appear in this list at most once
---------------------------------------------------------------------------]]
local mostExpensiveSingleCalls = {}

-- Gets most expensive single calls
FProfiler.Internal.getMostExpensiveSingleCalls = function() return mostExpensiveSingleCalls end

-- Dictionary to make sure the same function doesn't appear multiple times
-- in the top n
local mostExpensiveSingleDict = {}

function FProfiler.Internal.resetMostExpensiveSingleCalls()
    for i = 1, 50 do mostExpensiveSingleCalls[i] = {runtime = 0} end
    mostExpensiveSingleDict = {}
end

-- Initial empty list
FProfiler.Internal.resetMostExpensiveSingleCalls()

--[[-------------------------------------------------------------------------
Function information
Using debug.getinfo on a function object won't give you any function names
that's because functions can have multiple names.
Luckily, when the functions are called, debug.getinfo(level) gives the
function name and scope
---------------------------------------------------------------------------]]
local functionNames = {}

FProfiler.Internal.getFunctionNames = function() return functionNames end

--[[-------------------------------------------------------------------------
Recursion depth

Used internally to make sure recursive functions' times aren't counted
multiple times
---------------------------------------------------------------------------]]
local recursiveCount = {}

--[[-------------------------------------------------------------------------
Function start times

Used internally to keep track of when functions were called
---------------------------------------------------------------------------]]
local startTimes = {}

--[[-------------------------------------------------------------------------
Lua code event handlers
---------------------------------------------------------------------------]]

-- The recursion depth of the function that is in focus.
-- Only applies when profiling a specific function (i.e. laying focus upon)
local focusDepth = 0

-- Called when a function in the code is called
local function registerFunctionCall(funcInfo)
    local func = funcInfo.func

    -- Update call counts
    callcounts[func] = (callcounts[func] or 0) + 1

    -- Increase recursion depth for this function
    recursiveCount[func] = (recursiveCount[func] or 0) + 1

    -- Store function info
    local funcname = funcInfo.name or ""
    functionNames[func] = functionNames[func] or {}
    functionNames[func][funcname] = functionNames[func][funcname] or
        { namewhat = funcInfo.namewhat,
          nparams = funcInfo.nparams
        }

    local time = timeMeasurementFunc()

    -- Update inclusive function times,
    -- only when we're on the first recursive call
    if recursiveCount[func] == 1 then
        startTimes[func] = time
    end
end


-- Called when a function returns
local function registerReturn(funcInfo)
    local time = timeMeasurementFunc()
    local func = funcInfo.func
    local runtime = time - startTimes[func]

    -- Update inclusive function time
    -- Only update on the topmost call, to prevent recursive
    -- calls for being counted multiple times.
    if recursiveCount[func] == 1 then
        inclusiveTimes[func] = (inclusiveTimes[func] or 0) + runtime
    end

    -- Maintain recursion depth
    recursiveCount[func] = recursiveCount[func] - 1

    -- Update top n list
    -- This path will be taken most often: the function isn't special
    -- Also only counts the top recursion
    if runtime <= mostExpensiveSingleCalls[50].runtime or recursiveCount[func] > 1 then return end

    -- If the function already appears in the top 10, replace it or discard the result
    if mostExpensiveSingleDict[func] then
        local i = mostExpensiveSingleDict[func]

        -- Discard this info
        if runtime < mostExpensiveSingleCalls[i].runtime then return end

        -- Update the entry
        mostExpensiveSingleCalls[i].runtime = runtime
        mostExpensiveSingleCalls[i].upvalues = getupvalues(func)
        mostExpensiveSingleCalls[i].locals = getlocals(5)
        mostExpensiveSingleCalls[i].info = funcInfo
        mostExpensiveSingleCalls[i].func = func

        -- Move the updated entry up the top 10 list if applicable
        while i > 1 and runtime > mostExpensiveSingleCalls[i - 1].runtime do
            mostExpensiveSingleDict[mostExpensiveSingleCalls[i - 1].func] = i
            mostExpensiveSingleCalls[i - 1], mostExpensiveSingleCalls[i] = mostExpensiveSingleCalls[i], mostExpensiveSingleCalls[i - 1]
            i = i - 1
        end

        mostExpensiveSingleDict[func] = i

        return
    end

    -- Knowing that the function belongs in the top n, find its position
    local i = 50
    while i >= 1 and runtime > mostExpensiveSingleCalls[i].runtime do
        -- Update the dictionary
        -- All functions faster than the current one move down the list
        if not mostExpensiveSingleCalls[i].func then i = i - 1 continue end
        mostExpensiveSingleDict[mostExpensiveSingleCalls[i].func] = i + 1

        i = i - 1
    end

    -- Insert the expensive call in the top n
    mostExpensiveSingleDict[func] = i + 1
    table.insert(mostExpensiveSingleCalls, i + 1,
        {
            func = func,
            runtime = runtime,
            info = funcInfo,
            upvalues = getupvalues(func),
            locals = getlocals(5)
        })


    -- What was previously the 50th most expensive function
    -- is now kicked out of the top 10
    if mostExpensiveSingleCalls[51].func then
        mostExpensiveSingleDict[mostExpensiveSingleCalls[51].func] = nil
    end
    mostExpensiveSingleCalls[51] = nil
end


-- Called on any Lua event
local function onLuaEvent(event, focus)
    local info = debug.getinfo(3)
    local func = info.func

    if event == "call" or event == "tail call" then
        -- Only track the focussed function and the functions
        -- called by the focussed function
        if focus == func then focusDepth = focusDepth + 1 end
        if focus and focusDepth == 0 then return end

        registerFunctionCall(info)
    else
        -- Functions that return right after the call to FProfiler.Internal.start()
        -- are not to be counted
        if not recursiveCount[func] or recursiveCount[func] == 0 then return end

        if focus == func then focusDepth = focusDepth - 1 end
        if focus and focusDepth == 0 then return end

        registerReturn(info)
    end
end

--[[-------------------------------------------------------------------------
Profiling control
---------------------------------------------------------------------------]]

-- Start profiling
-- focus: only measure data of everything that happens within a certain function
function FProfiler.Internal.start(focus)
    -- Empty start times, so unfinished functions aren't
    -- registered as returns on a second profiling session
    -- local time = SysTime()
    -- for k,v in pairs(startTimes) do startTimes[k] = time end
    table.Empty(startTimes)
    table.Empty(recursiveCount)

    debug.sethook(function(event) onLuaEvent(event, focus) end, "cr")
end


-- Stop profiling
function FProfiler.Internal.stop()
    debug.sethook()
end

-- Reset all profiling data
function FProfiler.Internal.reset()
    FProfiler.Internal.resetCallCounts()
    FProfiler.Internal.resetInclusiveTimes()
    FProfiler.Internal.resetMostExpensiveSingleCalls()
end
