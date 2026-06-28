local repo = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/"

local function Get(file)
    return loadstring(game:HttpGet(repo .. file))()
end

local Settings = Get("Settings.lua")
local Config   = Get("Config.lua")
pcall(function()
	Config.Autoload(Settings)
end)

local Util         = Get("Util.lua")
local AntiBypass   = Get("AntiBypass.lua")
local ESP          = Get("ESP.lua")
local TeamFriends = Get("TeamFriends.lua")
local Aim      = Get("Aim.lua")
local Rage     = Get("Rage.lua")
local Movement = Get("Movement.lua")
local Misc     = Get("Misc.lua")
local Features = Get("Features.lua")
local Animations = Get("Animations.lua")
local World    = Get("World.lua")
local Effects  = Get("Effects.lua")
local UI       = Get("UI.lua")

-- Głowne GUI (podobnie jak w poprzednim loaderze)
local CG = AntiBypass.getGuiRoot()
pcall(function() CG.VanguardESP:Destroy() end)

pcall(function() CG.VanguardHUD:Destroy() end)
pcall(function() CG.VanguardFriendPopup:Destroy() end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "VG_" .. string.sub(game:GetService("HttpService"):GenerateGUID(false), 1, 8)
GUI.IgnoreGuiInset = true
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
GUI.DisplayOrder = 999999
GUI.Parent = CG

-- Start
ESP.Init(Settings, GUI, TeamFriends, Util)
Aim.Init(Settings, GUI, TeamFriends, Util)
Rage.Init(Settings, GUI, TeamFriends, Util)
Movement.Init(Settings)
Misc.Init(Settings, TeamFriends, Util)
Features.Init(Settings, GUI, AntiBypass)
Effects.Init(Settings, Util)
Animations.Init(Settings)
World.Init(Settings)
UI.Init(Settings, GUI, Config, TeamFriends, Animations, World)
AntiBypass.concealGui(GUI)
AntiBypass.Init(Settings)

print("VANGUARD: Loaded from GitHub!")