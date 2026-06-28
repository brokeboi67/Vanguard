local repo = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/"

local function Get(file)
    return loadstring(game:HttpGet(repo .. file))()
end

local Settings = Get("Settings.lua")
local Config   = Get("Config.lua")
pcall(function()
	Config.Autoload(Settings)
end)

local ESP      = Get("ESP.lua")
local Aim      = Get("Aim.lua")
local Movement = Get("Movement.lua")
local Features = Get("Features.lua")
local UI       = Get("UI.lua")

-- Głowne GUI (podobnie jak w poprzednim loaderze)
local CG = pcall(function() return game:GetService("CoreGui").Name end) and game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
pcall(function() CG.VanguardESP:Destroy() end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "VanguardESP"
GUI.IgnoreGuiInset = true
GUI.ResetOnSpawn = false
GUI.Parent = CG

-- Start
ESP.Init(Settings, GUI)
Aim.Init(Settings, GUI)
Movement.Init(Settings)
Features.Init(Settings, GUI)
UI.Init(Settings, GUI, Config)

print("VANGUARD: Loaded from GitHub!")