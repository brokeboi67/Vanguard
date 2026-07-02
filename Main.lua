local repo = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/"

local function Get(file)
	return loadstring(game:HttpGet(repo .. file))()
end

local isTransferLoad = _G.VG_FROM_TRANSFER == true
_G.VG_FROM_TRANSFER = nil

local Core = Get("Core.lua")
if Core.isActive() then
	if isTransferLoad then
		pcall(Core.unload)
		_G.VANGUARD = nil
	else
		Core.showDuplicateWarning()
		return
	end
end
Core.begin()

local Stealth = Get("Stealth.lua")
local AntiBypass = Get("AntiBypass.lua")
Stealth.Init(AntiBypass)

local Settings = Get("Settings.lua")
local Config = Get("Config.lua")
pcall(function()
	Config.Autoload(Settings)
end)

Settings.Unloaded = false

local Teleport = Get("Teleport.lua")
if not isTransferLoad then
	Teleport.clearQueue()
	Teleport.markManualLeave()
end
Teleport.init(Settings, Core)

local Session = Get("Session.lua")
Settings.RejoinGame = function()
	return Session.rejoin(Settings.MarkManualLeave)
end
Settings.ServerHop = function()
	return Session.serverHop(Settings.MarkManualLeave)
end

local Util = Get("Util.lua")
local ESP = Get("ESP.lua")
local TeamFriends = Get("TeamFriends.lua")
local Aim = Get("Aim.lua")
local Rage = Get("Rage.lua")
local Movement = Get("Movement.lua")
local Misc = Get("Misc.lua")
local Features = Get("Features.lua")
local Animations = Get("Animations.lua")
local World = Get("World.lua")
local Effects = Get("Effects.lua")
local UI = Get("UI.lua")
local Menus = Get("Menus.lua")
local GameSupport = Get("GameSupport.lua")

local CG = AntiBypass.getGuiRoot()
pcall(function()
	for _, name in ipairs({ "VanguardESP", "VanguardHUD", "VanguardFriendPopup" }) do
		local old = CG:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end)

local GUI = Stealth.create("ScreenGui", {
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
	DisplayOrder = 999999,
	Parent = CG,
})

Core.registerGui(GUI)

ESP.Init(Settings, GUI, TeamFriends, Util)
Aim.Init(Settings, GUI, TeamFriends, Util)
Rage.Init(Settings, GUI, TeamFriends, Util)
Movement.Init(Settings)
Misc.Init(Settings, TeamFriends, Util)
Features.Init(Settings, GUI, AntiBypass)
Effects.Init(Settings, Util)
Animations.Init(Settings)
World.Init(Settings)
UI.Init(Settings, GUI, Config, TeamFriends, Animations, World, Menus, GameSupport)

Settings.Unload = function()
	Settings.Unloaded = true
	Core.unload()
end

AntiBypass.concealGui(GUI)
AntiBypass.Init(Settings)

if Settings.TransferScript and Settings.ApplyTransferScript then
	pcall(Settings.ApplyTransferScript)
end

Stealth.silentPrint(isTransferLoad and "VANGUARD: Loaded (transfer)" or "VANGUARD: Loaded")
