-- Baza modułów (folder main/) — NIE dodawaj Main.lua na końcu
local REPO_BASE = "https://raw.githubusercontent.com/brokeboi67/Vanguard/main/"

_G.__VG_LOADING = true

-- File logger: capture full console to Vanguard/logs/vanguard.log
do
	local LOG_ROOT = "Vanguard/logs"
	local LOG_PATH = LOG_ROOT .. "/vanguard.log"
	local function ensureLogDirs()
		if typeof(makefolder) == "function" then
			pcall(makefolder, "Vanguard")
			pcall(makefolder, LOG_ROOT)
		end
	end
	local function bootFmt(...)
		local n = select("#", ...)
		local parts = {}
		for i = 1, n do
			parts[i] = tostring(select(i, ...))
		end
		return table.concat(parts, "\t")
	end
	local function bootWriteFile(level, text)
		local line = string.format("[%s] [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, text)
		ensureLogDirs()
		if typeof(isfile) == "function" and typeof(writefile) == "function" and not isfile(LOG_PATH) then
			pcall(writefile, LOG_PATH, "")
		end
		local fileOk = false
		if typeof(appendfile) == "function" then
			fileOk = pcall(appendfile, LOG_PATH, line)
		end
		if not fileOk and typeof(writefile) == "function" then
			local prev = ""
			if typeof(isfile) == "function" and isfile(LOG_PATH) and typeof(readfile) == "function" then
				pcall(function() prev = readfile(LOG_PATH) end)
			end
			fileOk = pcall(writefile, LOG_PATH, prev .. line)
		end
		return fileOk
	end
	local function bootWrite(level, ...)
		local text = bootFmt(...)
		bootWriteFile(level, text)
		local out = (level == "WARN" or level == "ERROR") and (_G.__VG_OLD_WARN or warn) or (_G.__VG_OLD_PRINT or print)
		pcall(out, text)
	end
	_G.__VG_LOG_PATH = LOG_PATH
	_G.__VG_LOG = bootWrite
	_G.__VG_LOG_FILE = bootWriteFile
	if not _G.__VG_OLD_PRINT then _G.__VG_OLD_PRINT = print end
	if not _G.__VG_OLD_WARN then _G.__VG_OLD_WARN = warn end
	pcall(function()
		if _G.__VG_LOG_SERVICE then return end
		_G.__VG_LOG_SERVICE = true
		local LogService = game:GetService("LogService")
		local ScriptContext = game:GetService("ScriptContext")
		LogService.MessageOut:Connect(function(message, messageType)
			local level = "OUT"
			if messageType == Enum.MessageType.MessageWarning then level = "WARN"
			elseif messageType == Enum.MessageType.MessageError then level = "ERROR"
			elseif messageType == Enum.MessageType.MessageInfo then level = "INFO" end
			bootWriteFile(level, tostring(message))
		end)
		ScriptContext.Error:Connect(function(message, stack)
			bootWriteFile("ERROR", tostring(message) .. "\n" .. tostring(stack))
		end)
	end)
	if not _G.__VG_LOG_HOOKED then
		_G.__VG_LOG_HOOKED = true
		print = function(...)
			if _G.__VG_LOG_SERVICE then pcall(_G.__VG_OLD_PRINT, ...) else bootWrite("INFO", ...) end
		end
		warn = function(...)
			if _G.__VG_LOG_SERVICE then pcall(_G.__VG_OLD_WARN, ...) else bootWrite("WARN", ...) end
		end
	end
	bootWrite("INFO", "Vanguard bootstrap")
end

-- Block Adonis CoreGui scan via PreloadAsync
pcall(function()
	if typeof(hookfunction) ~= "function" then return end
	local CoreGui = game:GetService("CoreGui")
	local function isCoreScan(assets)
		if typeof(assets) ~= "table" then
			return false
		end
		for _, item in ipairs(assets) do
			if item == CoreGui or item == game.CoreGui then
				return true
			end
			if typeof(item) == "Instance" and item:IsDescendantOf(CoreGui) then
				return true
			end
		end
		return false
	end
	local oldPreload
	local preloadWrap
	if typeof(newcclosure) == "function" then
		preloadWrap = newcclosure(function(self, assets, ...)
			if self == Content and isCoreScan(assets) then
				return
			end
			return oldPreload(self, assets, ...)
		end)
	else
		preloadWrap = function(self, assets, ...)
			if self == Content and isCoreScan(assets) then
				return
			end
			return oldPreload(self, assets, ...)
		end
	end
	oldPreload = hookfunction(Content.PreloadAsync, preloadWrap)
end)

local function resolveBootstrapRoot(cr)
	local function try(fn)
		if typeof(fn) ~= "function" then
			return nil
		end
		local ok, h = pcall(fn)
		if ok and h then
			return cr(h), true
		end
		return nil
	end
	local root, hidden = try(gethui)
	if root then
		return root, hidden
	end
	root, hidden = try(get_hidden_gui)
	if root then
		return root, hidden
	end
	root, hidden = try(gethiddengui)
	if root then
		return root, hidden
	end
	if typeof(getgenv) == "function" then
		local g = getgenv()
		if g then
			root, hidden = try(g.gethui)
			if root then
				return root, hidden
			end
			if typeof(g.HiddenUI) == "Instance" then
				return cr(g.HiddenUI), true
			end
		end
	end
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		local ok, cg = pcall(function()
			return cr(game:GetService("CoreGui"))
		end)
		if ok and cg then
			return cg, false
		end
	end
	return nil, false
end

local function randomBootstrapName()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local n = math.random(12, 18)
	local out = {}
	for i = 1, n do
		local idx = math.random(1, #chars)
		out[i] = chars:sub(idx, idx)
	end
	return table.concat(out)
end

do
	local TS = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local cr = typeof(cloneref) == "function" and cloneref or function(i) return i end
	local rootGui, hasHidden = resolveBootstrapRoot(cr)
	if not rootGui then
		rootGui = cr(LP:WaitForChild("PlayerGui", 30))
	end

	local bootName = randomBootstrapName()
	if rootGui and not rootGui:FindFirstChild(bootName) then
		local ACC = Color3.fromRGB(29, 185, 84)
		local gui = Instance.new("ScreenGui")
		gui.Name = bootName
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 8
		if typeof(protectgui) == "function" then
			pcall(protectgui, gui)
		end
		if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
			pcall(syn.protect_gui, gui)
		end
		gui.Parent = rootGui
		if typeof(cloneref) == "function" then
			pcall(cloneref, gui)
		end

		local card = Instance.new("Frame")
		card.Name = "Card"
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, -20)
		card.Size = UDim2.new(0, 340, 0, 108)
		card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
		card.BackgroundTransparency = 0.04
		card.BorderSizePixel = 0
		card.Parent = gui
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(42, 42, 52)
		stroke.Thickness = 1
		stroke.Transparency = 0.35
		stroke.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -24, 0, 18)
		title.Position = UDim2.new(0, 14, 0, 12)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 13
		title.TextColor3 = Color3.fromRGB(240, 240, 245)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "VANGUARD"
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -24, 0, 14)
		sub.Position = UDim2.new(0, 14, 0, 30)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 10
		sub.TextColor3 = Color3.fromRGB(110, 110, 122)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		sub.Text = "Uruchamianie..."
		sub.Parent = card

		local modLbl = Instance.new("TextLabel")
		modLbl.Size = UDim2.new(1, -70, 0, 14)
		modLbl.Position = UDim2.new(0, 14, 0, 48)
		modLbl.BackgroundTransparency = 1
		modLbl.Font = Enum.Font.GothamMedium
		modLbl.TextSize = 10
		modLbl.TextColor3 = Color3.fromRGB(190, 190, 200)
		modLbl.TextXAlignment = Enum.TextXAlignment.Left
		modLbl.TextTruncate = Enum.TextTruncate.AtEnd
		modLbl.Text = "Core"
		modLbl.Parent = card

		local pctLbl = Instance.new("TextLabel")
		pctLbl.Size = UDim2.new(0, 44, 0, 14)
		pctLbl.Position = UDim2.new(1, -54, 0, 48)
		pctLbl.BackgroundTransparency = 1
		pctLbl.Font = Enum.Font.GothamBold
		pctLbl.TextSize = 10
		pctLbl.TextColor3 = ACC
		pctLbl.TextXAlignment = Enum.TextXAlignment.Right
		pctLbl.Text = "0%"
		pctLbl.Parent = card

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -28, 0, 4)
		track.Position = UDim2.new(0, 14, 1, -22)
		track.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		track.BorderSizePixel = 0
		track.Parent = card
		Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = ACC
		fill.BorderSizePixel = 0
		fill.Parent = track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		local countLbl = Instance.new("TextLabel")
		countLbl.Size = UDim2.new(1, -28, 0, 12)
		countLbl.Position = UDim2.new(0, 14, 1, -14)
		countLbl.BackgroundTransparency = 1
		countLbl.Font = Enum.Font.Gotham
		countLbl.TextSize = 8
		countLbl.TextColor3 = Color3.fromRGB(90, 90, 100)
		countLbl.TextXAlignment = Enum.TextXAlignment.Left
		countLbl.Text = ""
		countLbl.Parent = card

		card.BackgroundTransparency = 1
		title.TextTransparency = 1
		sub.TextTransparency = 1
		modLbl.TextTransparency = 1
		pctLbl.TextTransparency = 1
		countLbl.TextTransparency = 1
		TS:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.04,
		}):Play()
		TS:Create(title, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
		TS:Create(sub, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
		TS:Create(modLbl, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
		TS:Create(pctLbl, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
		TS:Create(countLbl, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()

		local lastPct = 0
		local activeCreep = nil
		local function setFillPct(pct, animate)
			pct = math.clamp(pct or 0, 0, 1)
			if animate then
				TS:Create(fill, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = UDim2.new(pct, 0, 1, 0),
				}):Play()
			else
				fill.Size = UDim2.new(pct, 0, 1, 0)
			end
			lastPct = pct
		end
		_G.VG_BOOT = {
			gui = gui,
			bootName = bootName,
			update = function(label, pct, countText, animate)
				pct = math.clamp(pct or 0, 0, 1)
				activeCreep = nil
				modLbl.Text = tostring(label or "...")
				pctLbl.Text = math.floor(pct * 100) .. "%"
				if countText then
					countLbl.Text = countText
				end
				if pct >= lastPct - 0.001 then
					setFillPct(pct, animate == true)
				end
			end,
			startDownloadCreep = function(fromPct, toPct)
				activeCreep = {}
				local token = activeCreep
				task.spawn(function()
					setFillPct(fromPct, false)
					while activeCreep == token and fill.Parent do
						local p = fill.Size.X.Scale
						if p >= toPct then
							break
						end
						local nextP = math.min(p + 0.006, toPct)
						fill.Size = UDim2.new(nextP, 0, 1, 0)
						pctLbl.Text = math.floor(nextP * 100) .. "%"
						task.wait(0.05)
					end
				end)
			end,
			destroy = function()
				if not gui.Parent then
					return
				end
				TS:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 1, 40),
					BackgroundTransparency = 1,
				}):Play()
				TS:Create(title, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
				TS:Create(sub, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
				TS:Create(modLbl, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
				TS:Create(pctLbl, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
				TS:Create(countLbl, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
				task.delay(0.22, function()
					pcall(function()
						gui:Destroy()
					end)
				end)
			end,
		}
		_G.VG_BOOT.update("Start", 0.01)
	end
end

_G.VG_MODULE_CACHE = _G.VG_MODULE_CACHE or {}

local LOAD_TOTAL = 27
local loadStep = 0

local function bootProgress(label, pct, countText, animate)
	if _G.VG_BOOT and _G.VG_BOOT.update then
		_G.VG_BOOT.update(label, pct, countText, animate)
	end
end

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
		loadStep += 1
		bootProgress(file:gsub("%.lua$", ""), loadStep / LOAD_TOTAL * 0.68, loadStep .. " / " .. LOAD_TOTAL .. " modułów", true)
		task.wait()
		return _G.VG_MODULE_CACHE[file]
	end

	local fromPct = (loadStep + 0.08) / LOAD_TOTAL * 0.68
	local toPct = (loadStep + 0.92) / LOAD_TOTAL * 0.68
	bootProgress(
		"Pobieranie · " .. file:gsub("%.lua$", ""),
		fromPct,
		(loadStep + 1) .. " / " .. LOAD_TOTAL .. " modułów",
		false
	)
	if _G.VG_BOOT and _G.VG_BOOT.startDownloadCreep then
		_G.VG_BOOT.startDownloadCreep(fromPct, toPct)
	end

	local url = REPO_BASE .. file
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
		if _G.__VG_LOG then
			_G.__VG_LOG("ERROR", "HttpGet failed", file, tostring(lastErr))
		end
		error("[Vanguard] HttpGet failed: " .. file .. " (" .. tostring(lastErr) .. ")", 2)
	end

	local compile = loadstring or load
	if not compile then
		error("[Vanguard] Executor missing loadstring/load", 2)
	end
	local fn, err = compile(src)
	if not fn then
		if _G.__VG_LOG then
			_G.__VG_LOG("ERROR", "Compile", file, tostring(err))
		end
		error("[Vanguard] Compile " .. file .. ": " .. tostring(err), 2)
	end
	local ok, res = pcall(fn)
	if not ok then
		if _G.__VG_LOG then
			_G.__VG_LOG("ERROR", "Run", file, tostring(res))
		end
		error("[Vanguard] Run " .. file .. ": " .. tostring(res), 2)
	end
	if res == nil then
		if _G.__VG_LOG then
			_G.__VG_LOG("ERROR", "Module nil", file)
		end
		error("[Vanguard] Module returned nil: " .. file, 2)
	end
	_G.VG_MODULE_CACHE[file] = res
	loadStep += 1
	bootProgress(file:gsub("%.lua$", ""), loadStep / LOAD_TOTAL * 0.68, loadStep .. " / " .. LOAD_TOTAL .. " modułów", true)
	task.wait()
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
		if _G.VG_BOOT and _G.VG_BOOT.destroy then
			pcall(_G.VG_BOOT.destroy)
			_G.VG_BOOT = nil
		end
		Core.showDuplicateWarning()
		return
	end
end
Core.begin()
bootProgress("Inicjalizacja", 0.70)

local Stealth = Get("Stealth.lua")
local AntiBypass = Get("AntiBypass.lua")
pcall(function()
	AntiBypass.installShield({ AntiBypass = true })
end)
Stealth.Init(AntiBypass)

local Settings = Get("Settings.lua")
local Logger = Get("Logger.lua")
pcall(function()
	Logger.Init(Settings)
end)

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

_G.__VG_LOADING = false
if AntiBypass.onLoadComplete then
	pcall(AntiBypass.onLoadComplete)
end

bootProgress("Moduły gry", 0.74)

AntiBypass.installShield(Settings)

local CG = AntiBypass.getGuiRoot()
if not CG then
	local LP = game:GetService("Players").LocalPlayer
	CG = LP and LP:FindFirstChildOfClass("PlayerGui")
end
if not CG then
	error("[Vanguard] Brak PlayerGui — reinject w grze", 0)
end
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
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8,
	Parent = CG,
})

AntiBypass.concealGui(GUI)
Core.registerGui(GUI)
AntiBypass.Init(Settings)

bootProgress("ESP & HUD", 0.78)

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
if isTransferLoad and Music.ApplyTransferSettings then
	pcall(Music.ApplyTransferSettings)
elseif isTransferLoad and Music.ApplyTransferVolume then
	pcall(Music.ApplyTransferVolume)
end
if isTransferLoad and Music.RestoreFromTransfer then
	task.defer(function()
		task.wait(0.65)
		if Settings.TransferScript then
			pcall(Music.RestoreFromTransfer)
		end
	end)
end
bootProgress("Interfejs", 0.86)
task.spawn(function()
	if Settings.AntiBypass ~= false then
		AntiBypass.waitForAdonis(3)
		AntiBypass.logAdonisDiagnostics("pre-UI", Settings)
	end
	AntiBypass.setUiBuilding(true)
	task.wait()
	UI.Init(Settings, GUI, Config, TeamFriends, Animations, World, Menus, GameSupport, UIColorPicker, UIConfigMenus, Music, UIMusic, I18n, AntiBypass)
	AntiBypass.setUiBuilding(false)
	AntiBypass.logAdonisDiagnostics("post-UI", Settings)

	Settings.Unload = function()
		Settings.Unloaded = true
		Core.unload()
	end

	if Settings.TransferScript and Settings.ApplyTransferScript then
		pcall(Settings.ApplyTransferScript)
	end

	Stealth.silentPrint(isTransferLoad and "VANGUARD: Loaded (transfer)" or "VANGUARD: Loaded")
end)
