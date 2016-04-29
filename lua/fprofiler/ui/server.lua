--[[-------------------------------------------------------------------------
The server is involved in the ui in the sense that it sends and receives data
---------------------------------------------------------------------------]]

--[[-------------------------------------------------------------------------
Simplified version of the model
---------------------------------------------------------------------------]]
local model =
{
    focusObj = nil
}

util.AddNetworkString("FProfile_focusObj")

net.Receive("FProfile_focusObj", function(_, ply)
    if not ply:IsSuperAdmin() then return end

    local funcStr = net.ReadString()

    model.focusObj = FProfiler.funcNameToObj(funcStr)

    net.Start("FProfile_focusObj")
        net.WriteBool(model.focusObj and true or false)
    net.Send(ply)
end)
