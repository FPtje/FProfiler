FProfiler = {}
FProfiler.UI = {}

AddCSLuaFile()
AddCSLuaFile("fprofiler/gather.lua")
AddCSLuaFile("fprofiler/report.lua")

AddCSLuaFile("fprofiler/ui/model.lua")
AddCSLuaFile("fprofiler/ui/frame.lua")
AddCSLuaFile("fprofiler/ui/clientcontrol.lua")

include("fprofiler/gather.lua")
include("fprofiler/report.lua")

if CLIENT then
    include("fprofiler/ui/model.lua")
    include("fprofiler/ui/frame.lua")
    include("fprofiler/ui/clientcontrol.lua")
end
