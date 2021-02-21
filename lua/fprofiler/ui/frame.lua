--[[-------------------------------------------------------------------------
The panel that contains the realm switcher
---------------------------------------------------------------------------]]
local REALMPANEL = {}

function REALMPANEL:Init()
    self:DockPadding(0, 0, 0, 0)
    self:DockMargin(0, 0, 5, 0)

    self.realmLabel = vgui.Create("DLabel", self)
    self.realmLabel:SetDark(true)
    self.realmLabel:SetText("Realm:")

    self.realmLabel:SizeToContents()
    self.realmLabel:Dock(TOP)

    self.realmbox = vgui.Create("DComboBox", self)
    self.realmbox:AddChoice("Client")
    self.realmbox:AddChoice("Server")
    self.realmbox:Dock(TOP)

    FProfiler.UI.onModelUpdate("realm", function(new)
        self.realmbox.selected = new == "client" and 1 or 2
        self.realmbox:SetText(new == "client" and "Client" or "Server")
    end)

    FProfiler.UI.onModelUpdate("serverAccess", function(hasAccess)
        self.realmbox:SetDisabled(not hasAccess)

        if not hasAccess and self.realmbox.selected == 2 then
            FProfiler.UI.updateModel("realm", "client")
        end
    end)

    self.realmbox.OnSelect = function(_, _, value) FProfiler.UI.updateModel("realm", string.lower(value)) end
end

function REALMPANEL:PerformLayout()
    self.realmLabel:SizeToContents()
    local top = ( self:GetTall() - self.realmLabel:GetTall() - self.realmbox:GetTall()) * 0.5
    self:DockPadding(0, top, 0, 0)
end

derma.DefineControl("FProfileRealmPanel", "", REALMPANEL, "Panel")

--[[-------------------------------------------------------------------------
The little red or green indicator that indicates whether the focussing
function is correct
---------------------------------------------------------------------------]]
local FUNCINDICATOR = {}

function FUNCINDICATOR:Init()
    self:SetTall(5)
    self.color = Color(0, 0, 0, 0)
end

function FUNCINDICATOR:Paint()
    draw.RoundedBox(0, 0, 0, self:GetWide(), self:GetTall(), self.color)
end

derma.DefineControl("FProfileFuncIndicator", "", FUNCINDICATOR, "DPanel")

--[[-------------------------------------------------------------------------
The panel that contains the focus text entry and the focus indicator
---------------------------------------------------------------------------]]
local FOCUSPANEL = {}

function FOCUSPANEL:Init()
    self:DockPadding(0, 0, 0, 0)
    self:DockMargin(0, 0, 5, 0)

    self.focusLabel = vgui.Create("DLabel", self)
    self.focusLabel:SetDark(true)
    self.focusLabel:SetText("Profiling Focus:")

    self.focusLabel:SizeToContents()
    self.focusLabel:Dock(TOP)

    self.funcIndicator = vgui.Create("FProfileFuncIndicator", self)
    self.funcIndicator:Dock(BOTTOM)

    self.focusBox = vgui.Create("DTextEntry", self)
    self.focusBox:SetText("")
    self.focusBox:SetWidth(150)
    self.focusBox:Dock(BOTTOM)
    self.focusBox:SetTooltip("Focus the profiling on a single function.\nEnter a global function name here (like player.GetAll)\nYou're not allowed to call functions in here (e.g. hook.GetTable() is not allowed)")

    function self.focusBox:OnChange()
        FProfiler.UI.updateCurrentRealm("focusStr", self:GetText())
    end

    FProfiler.UI.onCurrentRealmUpdate("focusObj", function(new)
        self.funcIndicator.color = FProfiler.UI.getCurrentRealmValue("focusStr") == "" and Color(0, 0, 0, 0) or new and Color(80, 255, 80, 255) or Color(255, 80, 80, 255)
    end)

    FProfiler.UI.onCurrentRealmUpdate("focusStr", function(new, old)
        if self.focusBox:GetText() == new then return end

        self.focusBox:SetText(tostring(new))
    end)
end

function FOCUSPANEL:PerformLayout()
    self.focusBox:SetWide(200)
    self.focusLabel:SizeToContents()
end

derma.DefineControl("FProfileFocusPanel", "", FOCUSPANEL, "Panel")

--[[-------------------------------------------------------------------------
The timer that keeps track of for how long the profiling has been going on
---------------------------------------------------------------------------]]
local TIMERPANEL = {}

function TIMERPANEL:Init()
    self:DockPadding(0, 5, 0, 5)
    self:DockMargin(5, 0, 5, 0)

    self.timeLabel = vgui.Create("DLabel", self)
    self.timeLabel:SetDark(true)
    self.timeLabel:SetText("Total profiling time:")

    self.timeLabel:SizeToContents()
    self.timeLabel:Dock(TOP)

    self.counter = vgui.Create("DLabel", self)
    self.counter:SetDark(true)
    self.counter:SetText("00:00:00")
    self.counter:SizeToContents()
    self.counter:Dock(RIGHT)

    function self.counter:Think()
        local recordTime, sessionStart = FProfiler.UI.getCurrentRealmValue("recordTime"), FProfiler.UI.getCurrentRealmValue("sessionStart")

        local totalTime = recordTime + (sessionStart and (CurTime() - sessionStart) or 0)

        self:SetText(string.FormattedTime(totalTime, "%02i:%02i:%02i"))
    end
end

function TIMERPANEL:PerformLayout()
    self.timeLabel:SizeToContents()
    self.counter:SizeToContents()
end

derma.DefineControl("FProfileTimerPanel", "", TIMERPANEL, "Panel")

--[[-------------------------------------------------------------------------
The top bar
---------------------------------------------------------------------------]]
local MAGICBAR = {}

function MAGICBAR:Init()
    self:DockPadding(5, 5, 5, 5)
    self.realmpanel = vgui.Create("FProfileRealmPanel", self)

    -- (Re)Start profiling
    self.restartProfiling = vgui.Create("DButton", self)
    self.restartProfiling:SetText("   (Re)Start\n    Profiling")
    self.restartProfiling:DockMargin(0, 0, 5, 0)
    self.restartProfiling:Dock(LEFT)

    self.restartProfiling.DoClick = function()
        FProfiler.UI.updateCurrentRealm("shouldReset", true)
        FProfiler.UI.updateCurrentRealm("status", "Started")
    end

    FProfiler.UI.onCurrentRealmUpdate("status", function(new)
        self.restartProfiling:SetDisabled(new == "Started")
    end)

    -- Stop profiling
    self.stopProfiling = vgui.Create("DButton", self)
    self.stopProfiling:SetText("     Stop\n  Profiling")
    self.stopProfiling:DockMargin(0, 0, 5, 0)
    self.stopProfiling:Dock(LEFT)

    self.stopProfiling.DoClick = function()
        FProfiler.UI.updateCurrentRealm("status", "Stopped")
    end

    FProfiler.UI.onCurrentRealmUpdate("status", function(new)
        self.stopProfiling:SetDisabled(new == "Stopped")
    end)

    -- Continue profiling
    self.continueProfiling = vgui.Create("DButton", self)
    self.continueProfiling:SetText("    Continue\n     Profiling")
    self.continueProfiling:DockMargin(0, 0, 5, 0)
    self.continueProfiling:Dock(LEFT)

    self.continueProfiling.DoClick = function()
        FProfiler.UI.updateCurrentRealm("shouldReset", false)
        FProfiler.UI.updateCurrentRealm("status", "Started")
    end

    FProfiler.UI.onCurrentRealmUpdate("status", function(new)
        self.continueProfiling:SetDisabled(new == "Started")
    end)

    self.realmpanel:Dock(LEFT)

    self.focuspanel = vgui.Create("FProfileFocusPanel", self)
    self.focuspanel:Dock(LEFT)

    -- Timer
    self.timerpanel = vgui.Create("FProfileTimerPanel", self)
    self.timerpanel:Dock(RIGHT)
end

function MAGICBAR:PerformLayout()
    self.realmpanel:SizeToChildren(true, false)
    self.focuspanel:SizeToChildren(true, false)
    self.timerpanel:SizeToChildren(true, false)
end


derma.DefineControl("FProfileMagicBar", "", MAGICBAR, "DPanel")

--[[-------------------------------------------------------------------------
A custom sort by column function to deal with sorting by numeric value
--------------------------------------------------------------------------]]
local function SortByColumn(self, ColumnID, Desc)
    table.Copy(self.Sorted, self.Lines)

    table.sort(self.Sorted, function(a, b)
        if Desc then
            a, b = b, a
        end

        local aval = a:GetSortValue(ColumnID) or a:GetColumnText(ColumnID)
        local bval = b:GetSortValue(ColumnID) or b:GetColumnText(ColumnID)

        local anum = tonumber(aval)
        local bnum = tonumber(bval)

        if anum and bnum then
            return anum < bnum
        end

        return tostring(aval) < tostring(bval)
    end)

    self:SetDirty(true)
    self:InvalidateLayout()
end

--[[-------------------------------------------------------------------------
The Bottlenecks tab's contents
---------------------------------------------------------------------------]]
local BOTTLENECKTAB = {}

BOTTLENECKTAB.SortByColumn = SortByColumn

function BOTTLENECKTAB:Init()
    self:SetMultiSelect(false)
    self:AddColumn("Name")
    self:AddColumn("Path")
    self:AddColumn("Lines")
    self:AddColumn("Amount of times called")
    self:AddColumn("Total time in ms (inclusive)")
    self:AddColumn("Average time in ms (inclusive)")

    FProfiler.UI.onCurrentRealmUpdate("bottlenecks", function(new)
        self:Clear()

        for _, row in ipairs(new) do
            local names = {}
            local path = row.info.short_src
            local lines = path ~= "[C]" and row.info.linedefined .. " - " .. row.info.lastlinedefined or "N/A"
            local amountCalled = row.total_called
            local totalTime = row.total_time * 100
            local avgTime = row.average_time * 100

            for _, fname in ipairs(row.names or {}) do
                if fname.namewhat == "" and fname.name == "" then continue end
                table.insert(names, fname.namewhat .. " " .. fname.name)
            end

            if #names == 0 then names[1] = "Unknown" end

            local line = self:AddLine(table.concat(names, "/"), path, lines, amountCalled, totalTime, avgTime)
            line.data = row
        end
    end)

    FProfiler.UI.onCurrentRealmUpdate("currentSelected", function(new, old)
        if new == old then return end

        for _, line in pairs(self.Lines) do
            line:SetSelected(line.data.func == new.func)
        end
    end)
end


function BOTTLENECKTAB:OnRowSelected(id, line)
    FProfiler.UI.updateCurrentRealm("currentSelected", line.data)
end


derma.DefineControl("FProfileBottleNecks", "", BOTTLENECKTAB, "DListView")

--[[-------------------------------------------------------------------------
The Top n lag spikes tab's contents
---------------------------------------------------------------------------]]
local TOPTENTAB = {}

TOPTENTAB.SortByColumn = SortByColumn

function TOPTENTAB:Init()
    self:SetMultiSelect(false)
    self:AddColumn("Name")
    self:AddColumn("Path")
    self:AddColumn("Lines")
    self:AddColumn("Runtime in ms")

    FProfiler.UI.onCurrentRealmUpdate("topLagSpikes", function(new)
        self:Clear()

        for _, row in ipairs(new) do
            if not row.func then break end

            local name = row.info.name and row.info.name ~= "" and (row.info.namewhat .. " " .. row.info.name) or "Unknown"
            local path = row.info.short_src
            local lines = path ~= "[C]" and row.info.linedefined .. " - " .. row.info.lastlinedefined or "N/A"
            local runtime = row.runtime * 100

            local line = self:AddLine(name, path, lines, runtime)
            line.data = row
        end
    end)

    FProfiler.UI.onCurrentRealmUpdate("currentSelected", function(new, old)
        if new == old then return end

        for _, line in pairs(self.Lines) do
            line:SetSelected(line.data.func == new.func)
        end
    end)
end

function TOPTENTAB:OnRowSelected(id, line)
    FProfiler.UI.updateCurrentRealm("currentSelected", line.data)
end

derma.DefineControl("FProfileTopTen", "", TOPTENTAB, "DListView")

--[[-------------------------------------------------------------------------
The Tab panel of the bottlenecks and top n lag spikes
---------------------------------------------------------------------------]]
local RESULTSHEET = {}

function RESULTSHEET:Init()
    self:DockMargin(0, 10, 0, 0)
    self:SetPadding(0)

    self.bottlenecksTab = vgui.Create("FProfileBottleNecks")
    self:AddSheet("Bottlenecks", self.bottlenecksTab)

    self.toptenTab = vgui.Create("FProfileTopTen")
    self:AddSheet("Top 50 most expensive function calls", self.toptenTab)

end


derma.DefineControl("FProfileResultSheet", "", RESULTSHEET, "DPropertySheet")

--[[-------------------------------------------------------------------------
The function details panel
---------------------------------------------------------------------------]]
local FUNCDETAILS = {}

function FUNCDETAILS:Init()
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetDark(true)
    self.titleLabel:SetFont("DermaLarge")
    self.titleLabel:SetText("Function Details")
    self.titleLabel:SizeToContents()
    -- self.titleLabel:Dock(TOP)

    self.focus = vgui.Create("DButton", self)
    self.focus:SetText("Focus")
    self.focus:SetTall(50)
    self.focus:SetFont("DermaDefaultBold")
    self.focus:Dock(BOTTOM)

    function self.focus:DoClick()
        local sel = FProfiler.UI.getCurrentRealmValue("currentSelected")
        if not sel then return end

        FProfiler.UI.updateCurrentRealm("focusStr", sel.func)
    end

    self.source = vgui.Create("DTextEntry", self)
    self.source:SetKeyboardInputEnabled(false)
    self.source:DockMargin(0, 40, 0, 0)
    self.source:SetMultiline(true)
    self.source:Dock(FILL)

    FProfiler.UI.onCurrentRealmUpdate("sourceText", function(new)
        self.source:SetText(string.Replace(new, "\t", "    "))
    end)

    self.toConsole = vgui.Create("DButton", self)
    self.toConsole:SetText("Print Details to Console")
    self.toConsole:SetTall(50)
    self.toConsole:SetFont("DermaDefaultBold")
    self.toConsole:Dock(BOTTOM)

    function self.toConsole:DoClick()
        FProfiler.UI.updateCurrentRealm("toConsole", FProfiler.UI.getCurrentRealmValue("currentSelected"))
    end
end

function FUNCDETAILS:PerformLayout()
    self.titleLabel:CenterHorizontal()
end
derma.DefineControl("FProfileFuncDetails", "", FUNCDETAILS, "DPanel")

--[[-------------------------------------------------------------------------
The actual frame
---------------------------------------------------------------------------]]
local FRAME = {}

local frameInstance
function FRAME:Init()
    self:SetTitle("FProfiler profiling tool")
    self:SetSize(ScrW() * 0.8, ScrH() * 0.8)
    self:Center()
    self:SetVisible(true)
    self:MakePopup()
    self:SetDeleteOnClose(false)

    self.magicbar = vgui.Create("FProfileMagicBar", self)
    self.magicbar:SetTall(math.max(self:GetTall() * 0.07, 48))
    self.magicbar:Dock(TOP)

    self.resultsheet = vgui.Create("FProfileResultSheet", self)
    self.resultsheet:SetWide(self:GetWide() * 0.8)
    self.resultsheet:Dock(LEFT)

    self.details = vgui.Create("FProfileFuncDetails", self)
    self.details:SetWide(self:GetWide() * 0.2 - 12)
    self.details:DockMargin(5, 31, 0, 0)
    self.details:Dock(RIGHT)
end

function FRAME:OnClose()
    FProfiler.UI.updateModel("frameVisible", false)
end

derma.DefineControl("FProfileFrame", "", FRAME, "DFrame")

--[[-------------------------------------------------------------------------
The command to start the profiler
---------------------------------------------------------------------------]]
concommand.Add("FProfiler",
    function()
        frameInstance = frameInstance or vgui.Create("FProfileFrame")
        frameInstance:SetVisible(true)

        FProfiler.UI.updateModel("frameVisible", true)
    end,
    nil, "Starts FProfiler")
