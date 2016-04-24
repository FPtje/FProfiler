FProfiler = {}

AddCSLuaFile()
AddCSLuaFile("fprofiler/gather.lua")
AddCSLuaFile("fprofiler/report.lua")

include("fprofiler/gather.lua")
include("fprofiler/report.lua")
