FProfiler = {}
FProfiler.Internal = {}
FProfiler.UI = {}

AddCSLuaFile()
AddCSLuaFile("fprofiler/cami.lua")
AddCSLuaFile("fprofiler/gather.lua")
AddCSLuaFile("fprofiler/report.lua")
AddCSLuaFile("fprofiler/util.lua")
AddCSLuaFile("fprofiler/prettyprint.lua")

AddCSLuaFile("fprofiler/ui/model.lua")
AddCSLuaFile("fprofiler/ui/frame.lua")
AddCSLuaFile("fprofiler/ui/clientcontrol.lua")
AddCSLuaFile("fprofiler/ui/servercontrol.lua")

include("fprofiler/cami.lua")

CAMI.RegisterPrivilege{
    Name = "FProfiler",
    MinAccess = "superadmin"
}


include("fprofiler/prettyprint.lua")
include("fprofiler/util.lua")
include("fprofiler/gather.lua")
include("fprofiler/report.lua")


if CLIENT then
    include("fprofiler/ui/model.lua")
    include("fprofiler/ui/frame.lua")
    include("fprofiler/ui/clientcontrol.lua")
    include("fprofiler/ui/servercontrol.lua")
else
    include("fprofiler/ui/server.lua")
end
