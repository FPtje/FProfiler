-- Based on MDave's thing
-- https://gist.github.com/mentlerd/d56ad9e6361f4b86af84
if SERVER then AddCSLuaFile() end

local type_weight = {
    [TYPE_FUNCTION] = 1,
    [TYPE_TABLE]    = 2,
}

local type_colors = {
    [TYPE_BOOL]     = Color(175, 130, 255),
    [TYPE_NUMBER]   = Color(175, 130, 255),
    [TYPE_STRING]   = Color(230, 220, 115),
    [TYPE_FUNCTION] = Color(100, 220, 240)
}

local color_neutral   = Color(220, 220, 220)
local color_name      = Color(260, 150,  30)

local color_reference = Color(150, 230,  50)
local color_comment   = Color( 30, 210,  30)

-- 'nil' value
local NIL = {}

-- Localise for faster access
local pcall         = pcall

local string_len    = string.len
local string_sub    = string.sub
local string_find   = string.find

local table_concat  = table.concat
local table_insert  = table.insert
local table_sort    = table.sort


-- Stream interface
local gMsgF -- Print fragment
local gMsgN -- Print newline
local gMsgC -- Set print color

local PrintLocals, gBegin, gFinish, PrintTableGrep

do
    local grep_color   = Color(235, 70, 70)

    -- Grep parameters (static between gBegin/gEnd)
    local grep
    local grep_raw

    local grep_proximity


    -- Current line parameters
    local buffer
    local colors
    local markers

    local baseColor
    local currColor

    local length

    -- History
    local history
    local remain


    -- Actual printing
    local function gCheckMatch( buffer )
        local raw = table_concat(buffer)

        return raw, string_find(raw, grep, 0, grep_raw)
    end

    local function gFlushEx( raw, markers, colors, baseColor )

        -- Print entire buffer
        local len = string_len(raw)

        -- Keep track of the current line properties
        local index  = 1
        local marker = 1

        local currColor = baseColor

        -- Method to print to a preset area
        local function printToIndex( limit, color )
            local mark = markers and markers[marker]

            -- Print all marker areas until we would overshoot
            while mark and mark < limit do

                -- Catch up to the marker
                MsgC(color or currColor or color_neutral, string_sub(raw, index, mark))
                index = mark +1

                -- Set new color
                currColor = colors[marker]

                -- Select next marker
                marker = marker +1
                mark   = markers[marker]

            end

            -- Print the remaining between the last marker and the limit
            MsgC(color or currColor or color_neutral, string_sub(raw, index, limit))
            index = limit +1
        end

        -- Grep!
        local match, last = 1
        local from, to = string_find(raw, grep, 0, grep_raw)

        while from do
            printToIndex(from -1)
            printToIndex(to, grep_color)

            last     = to +1
            from, to = string_find(raw, grep, last, grep_raw)
        end

        printToIndex(len)
        MsgN()
    end


    local function gCommit()
        if grep_proximity then
            -- Check if the line has at least one match
            local raw, match = gCheckMatch(buffer)

            if match then

                -- Divide matches
                if history[grep_proximity] then
                    MsgN("...")
                end

                -- Flush history
                if grep_proximity ~= 0 then
                    local len = #history

                    for index = len -1, 1, -1 do
                        local entry = history[index]
                            history[index] = nil

                        gFlushEx( entry[1], entry[2], entry[3], entry[4] )
                    end

                    history[len] = nil
                end

                -- Flush line, allow next X lines to get printed
                gFlushEx( raw, markers, colors, baseColor )
                remain = grep_proximity -1

                history[grep_proximity +1] = nil
            elseif remain > 0 then
                -- Flush immediately
                gFlushEx( raw, markers, colors, baseColor )
                remain = remain -1
            else
                -- Store in history
                table_insert(history, 1, {raw, markers, colors, baseColor})
                history[grep_proximity +1] = nil
            end
        else
            -- Flush anyway
            gFlushEx( table_concat(buffer), markers, colors, baseColor )
        end

        -- Reset state
        length = 0
        buffer = {}

        markers = nil
        colors  = nil

        baseColor = nil
        currColor = nil
    end

    -- State machine
    function gBegin( new, prox )
        grep = isstring(new) and new

        if grep then
            grep_raw       = not pcall(string_find, ' ', grep)
            grep_proximity = isnumber(prox) and prox

            -- Reset everything
            buffer  = {}
            history = {}
        end

        length = 0
        remain = 0

        baseColor = nil
        currColor = nil
    end

    function gFinish()
        if grep_proximity and history and history[1] then
            MsgN("...")
        end

        -- Free memory
        buffer  = nil
        markers = nil
        colors  = nil

        history = nil
    end


    function gMsgC( color )
        if grep then

            -- Try to save some memory by not immediately allocating colors
            if length == 0 then
                baseColor = color
                return
            end

            -- Record color change
            if color ~= currColor then
                if not markers then
                    markers = {}
                    colors  = {}
                end

                -- Record color change
                table_insert(markers, length)
                table_insert(colors,  color)
            end
        end

        currColor = color
    end

    function gMsgF( str )
        if grep then

            -- Split multiline fragments to separate ones
            local fragColor = currColor or baseColor

            local last = 1
            local from, to = string_find(str, '\n')

            while from do
                local frag = string_sub(str, last, from -1)
                local len  = from - last

                -- Merge fragment to the line
                length = length + len
                table_insert(buffer, frag)

                -- Print finished line
                gCommit()

                -- Assign base color as previous fragColor
                baseColor = fragColor

                -- Look for more
                last     = to +1
                from, to = string_find(str, '\n', last)
            end

            -- Push last fragment
            local frag = string_sub(str, last)
            local len  = string_len(str) - last +1

            length = length + len
            table_insert(buffer, frag)
        else
            -- Push immediately
            MsgC(currColor or baseColor or color_neutral, str)
        end
    end

    function gMsgN()
        -- Print everything in the buffer
        if grep then
            gCommit()
        else
            MsgN()
        end

        baseColor = nil
        currColor = nil
    end
end


local function InternalPrintValue( value )

    -- 'nil' values can also be printed
    if value == NIL then
        gMsgC(color_comment)
        gMsgF("nil")
        return
    end

    local color = type_colors[ TypeID(value) ]

    -- For strings, place quotes
    if isstring(value) then
        if string_len(value) <= 1 then
            value = string.format([['%s']], value)
        else
            value = string.format([["%s"]], value)
        end

        gMsgC(color)
        gMsgF(value)
        return
    end

    -- Workaround for userdata not using MetaName
    if string_sub(tostring(value), 0, 8) == "userdata" then
        local meta = getmetatable(value)

        if meta and meta.MetaName then
            value = string.format("%s: %p", meta.MetaName, value)
        end
    end

    -- General print
    gMsgC(color)
    gMsgF(tostring(value))

    -- For functions append source info
    if isfunction(value) then
        local info = debug.getinfo(value, 'S')
        local aux

        if info.what == 'C' then
            aux = "\t-- [C]: -1"
        else
            if info.linedefined ~= info.lastlinedefined then
                aux = string.format("\t-- [%s]: %i-%i", info.short_src, info.linedefined, info.lastlinedefined)
            else
                aux = string.format("\t-- [%s]: %i", info.short_src, info.linedefined)
            end
        end

        gMsgC(color_comment)
        gMsgF(aux)
    end
end


-- Associated to object keys
local objID

local function isprimitive( value )
    local id = TypeID(value)

    return id <= TYPE_FUNCTION and id ~= TYPE_TABLE
end

local function InternalPrintTable( table, path, prefix, names, todo )

    -- Collect keys and some info about them
    local keyList  = {}
    local keyStr   = {}

    local keyCount = 0

    for key, value in pairs( table ) do
        -- Add to key list for later sorting
        table_insert(keyList, key)

        -- Describe key as string
        if isprimitive(key) then
            keyStr[key] = tostring(key)
        else
            -- Lookup already known name
            local name = names[key]

            -- Assign a new unique identifier
            if not name then
                objID = objID +1
                name  = string.format("%s: obj #%i", tostring(key), objID)

                names[key] = name
                todo[key]  = true
            end

            -- Substitute object with name
            keyStr[key] = name
        end

        keyCount = keyCount +1
    end


    -- Exit early for empty tables
    if keyCount == 0 then
        return
    end


    -- Determine max key length
    local keyLen = 4

    for key, str in pairs(keyStr) do
        keyLen = math.max(keyLen, string.len(str))
    end

    -- Sort table keys
    if keyCount > 1 then
        table_sort( keyList, function( A, B )

            -- Sort numbers numerically correct
            if isnumber(A) and isnumber(B) then
                return A < B
            end

            -- Weight types
            local wA = type_weight[ TypeID( table[A] ) ] or 0
            local wB = type_weight[ TypeID( table[B] ) ] or 0

            if wA ~= wB then
                return wA < wB
            end

            -- Order by string representation
            return keyStr[A] < keyStr[B]

        end )
    end

    -- Determine the next level ident
    local new_prefix = string.format( "%s║%s", prefix, string.rep(' ', keyLen) )

    -- Mark object as done
    todo[table] = nil

    -- Start describing table
    for index, key in ipairs(keyList) do
        local value = table[key]

        -- Assign names to already described keys/values
        local kName = names[key]
        local vName = names[value]

        -- Decide to either fully describe, or print the value
        local describe = not isprimitive(value) and ( not vName or todo[value] )

        -- Ident
        gMsgF(prefix)

        -- Fancy table guides
        local moreLines = (index ~= keyCount) or describe

        if index == 1 then
            gMsgF(moreLines and '╦ ' or '═ ')
        else
            gMsgF(moreLines and '╠ ' or '╚ ')
        end

        -- Print key
        local sKey = kName or keyStr[key]

        gMsgC(kName and color_reference or color_name)
        gMsgF(sKey)

        -- Describe non primitives
        describe = istable(value) and ( not names[value] or todo[value] ) and value ~= NIL

        -- Print key postfix
        local padding = keyLen - string.len(sKey)
        local postfix = string.format(describe and ":%s" or "%s = ", string.rep(' ', padding))

        gMsgC(color_neutral)
        gMsgF(postfix)

        -- Print the value
        if describe then
            gMsgN()

            -- Expand access path
            local new_path = sKey

            if isnumber(key) or kName then
                new_path = string.format("%s[%s]", path or '', key)
            elseif path then
                new_path = string.format("%s.%s", path, new_path)
            end

            -- Name the object to mark it done
            names[value] = names[value] or new_path

            -- Describe
            InternalPrintTable(value, new_path, new_prefix, names, todo)
        else
            -- Print the value (or the reference name)
            if vName and not todo[value] then
                gMsgC(color_reference)
                gMsgF(string.format("ref: %s",vName))
            else
                InternalPrintValue(value)
            end

            gMsgN()
        end
    end

end

function PrintTableGrep( table, grep, proximity )
    local base = {
        [_G]    = "_G",
        [table] = "root"
    }

    gBegin(grep, proximity)
        objID = 0
        InternalPrintTable(table, nil, "", base, {})
    gFinish()
end

function PrintLocals( level )
    local level = level or 2
    local hash  = {}

    for index = 1, 255 do
        local name, value = debug.getlocal(2, index)

        if not name then
            break
        end

        if value == nil then
            value = NIL
        end

        hash[name] = value
    end

    PrintTableGrep( hash )
end

function show(...)
    local n = select('#', ...)
    local tbl = {...}

    for i = 1, n do
        if istable(tbl[i]) then MsgN(tostring(tbl[i])) PrintTableGrep(tbl[i])
        else InternalPrintValue(tbl[i]) MsgN() end
    end
end

-- Hacky way of creating a pretty string from the above code
-- because I don't feel like refactoring the entire thing
local strResult
local toStringMsgF = function(txt)
    table.insert(strResult, txt)
end

local toStringMsgN = function()
    table.insert(strResult, "\n")
end

local toStringMsgC = function(_, txt)
    table.insert(strResult, txt)
end

function showStr(...)
    local oldF, oldN, oldMsgC, oldMsgN = gMsgF, gMsgN, MsgC, MsgN
    gMsgF, gMsgN, MsgC, MsgN = toStringMsgF, toStringMsgN, toStringMsgC, toStringMsgN

    strResult = {}
    show(...)

    gMsgF, gMsgN, MsgC, MsgN = oldF, oldN, oldMsgC, oldMsgN

    return table.concat(strResult, "")
end
