local REALMPANEL = {}

function REALMPANEL:Init()
    self:DockPadding(0, 5, 0, 5)
    self:DockMargin(5, 0, 5, 0)

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

    self.realmbox.OnSelect = function(_, _, value) FProfiler.UI.updateModel("realm", string.lower(value)) end
end

function REALMPANEL:PerformLayout()
    self.realmLabel:SizeToContents()
end

derma.DefineControl("FProfileRealmPanel", "", REALMPANEL, "Panel")

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
        FProfiler.UI.updateCurrentRealm("status", "Started")
    end

    FProfiler.UI.onCurrentRealmUpdate("status", function(new)
        self.restartProfiling:SetDisabled(new == "Started")
    end)

    -- Stop profiling
    self.stopProfiling = vgui.Create("DButton", self)
    self.stopProfiling:SetText("      Stop\n    Profiling")
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
    self.continueProfiling:SetText("    Continue\n    Profiling")
    self.continueProfiling:DockMargin(0, 0, 5, 0)
    self.continueProfiling:Dock(LEFT)

    self.continueProfiling.DoClick = function()
        FProfiler.UI.updateCurrentRealm("status", "Started")
    end

    FProfiler.UI.onCurrentRealmUpdate("status", function(new)
        self.continueProfiling:SetDisabled(new == "Started")
    end)

    self.realmpanel:Dock(LEFT)
end

function MAGICBAR:PerformLayout()
    self.realmpanel:SizeToChildren(true, false)
end


derma.DefineControl("FProfileMagicBar", "", MAGICBAR, "DPanel")

--[[-------------------------------------------------------------------------
The Bottlenecks tab's contents
---------------------------------------------------------------------------]]
local BOTTLENECKTAB = {}

function BOTTLENECKTAB:Init()

end

derma.DefineControl("FProfileBottleNecks", "", BOTTLENECKTAB, "DListView")

--[[-------------------------------------------------------------------------
The Top 10 lag spikes tab's contents
---------------------------------------------------------------------------]]
local TOPTENTAB = {}

function TOPTENTAB:Init()

end

derma.DefineControl("FProfileTopTen", "", TOPTENTAB, "DListView")

--[[-------------------------------------------------------------------------
The Tab panel of the bottlenecks and top 10 lag spikes
---------------------------------------------------------------------------]]
local RESULTSHEET = {}

function RESULTSHEET:Init()
    self:DockMargin(0, 10, 0, 0)
    self:SetPadding(0)

    self.bottlenecksTab = vgui.Create("FProfileBottleNecks")
    self:AddSheet("Bottlenecks", self.bottlenecksTab)

    self.toptenTab = vgui.Create("FProfileTopTen")
    self:AddSheet("Top 10 most expensive function calls", self.toptenTab)

end


derma.DefineControl("FProfileResultSheet", "", RESULTSHEET, "DPropertySheet")

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
    self.magicbar:SetTall(self:GetTall() * 0.07)
    self.magicbar:Dock(TOP)

    self.resultsheet = vgui.Create("FProfileResultSheet", self)
    self.resultsheet:Dock(FILL)
end


derma.DefineControl("FProfileFrame", "", FRAME, "DFrame")

concommand.Add("FProfiler",
    function()
        FProfiler.UI.clearUpdaters()
        frameInstance = frameInstance or vgui.Create("FProfileFrame")
        frameInstance:SetVisible(true)
    end,
    nil, "Starts FProfiler")
concommand.Add("RemoveFProfiler", function() frameInstance:Remove() frameInstance = nil end)
