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
    update({"client", "focusObj"}, net.ReadBool() and get({"server", "focusStr"}) or nil)
end)
