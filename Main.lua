local repo = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/"

_G.VG_MODULE_CACHE = _G.VG_MODULE_CACHE or {}

local function fetchUrl(url)
	local req = request or (syn and syn.request) or (http and http.request)
	if req then
		local ok, res = pcall(function()
			return req({
				Url = url,
				Method = "GET",
			})
		end)
		if ok and typeof(res) == "table" and res.Body and res.Body ~= "" then
			if not res.StatusCode or res.StatusCode >= 200 and res.StatusCode < 300 then
				return res.Body
			end
		end
	end
	if typeof(game.HttpGetAsync) == "function" then
		local ok, body = pcall(game.HttpGetAsync, game, url)
		if ok and body and body ~= "" then
			return body
		end
	end
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and body and body ~= "" then
			return body
		end
	end
	return nil
end

local function Get(file)
	if _G.VG_MODULE_CACHE[file] then
		return _G.VG_MODULE_CACHE[file]
	end

	local url = repo .. file
	local src
	local lastErr = "empty response"
	for attempt = 1, 4 do
		local ok, body = pcall(fetchUrl, url)
		if ok and body and body ~= "" then
			src = body
			break
		end
		lastErr = ok and "empty response" or tostring(body)
		if attempt < 4 then
			task.wait(0.25 * attempt)
		end
	end
	if not src or src == "" then
		error("[Vanguard] HttpGet failed: " .. file .. " (" .. tostring(lastErr) .. ")", 2)
	end

	local compile = loadstring or load
	if not compile then
		error("[Vanguard] Executor missing loadstring/load", 2)
	end
	local fn, err = compile(src)
	if not fn then
		error("[Vanguard] Compile " .. file .. ": " .. tostring(err), 2)
	end
	local ok, res = pcall(fn)
	if not ok then
		error("[Vanguard] Run " .. file .. ": " .. tostring(res), 2)
	end
	if res == nil then
		error("[Vanguard] Module returned nil: " .. file, 2)
	end
	_G.VG_MODULE_CACHE[file] = res
	return res
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

local I18n = Get("I18n.lua")
I18n.Init(Settings)

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
local Music = Get("Music.lua")
local UIColorPicker = Get("UIColorPicker.lua")
local UIConfigMenus = Get("UIConfigMenus.lua")
local UIMusic = Get("UIMusic.lua")
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
Music.Init(Settings, I18n)
if isTransferLoad and Music.RestoreFromTransfer then
	task.defer(function()
		task.wait(0.65)
		if Settings.TransferScript then
			pcall(Music.RestoreFromTransfer)
		end
	end)
end
UI.Init(Settings, GUI, Config, TeamFriends, Animations, World, Menus, GameSupport, UIColorPicker, UIConfigMenus, Music, UIMusic, I18n)

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
