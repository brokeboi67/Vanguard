-- Baza modułów (folder main/) — NIE dodawaj Main.lua na końcu
local REPO_BASE = "https://raw.githubusercontent.com/brokeboi67/Vanguard/main/"

pcall(function()
	if typeof(hookfunction) ~= "function" then
		return
	end
	local Content = game:GetService("ContentProvider")
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

	local Players = game:GetService("Players")
	local LP = Players.LocalPlayer
	if LP then
		local oldKick
		local kickWrap
		if typeof(newcclosure) == "function" then
			kickWrap = newcclosure(function(self, ...)
				if self == LP then
					return
				end
				return oldKick(self, ...)
			end)
		else
			kickWrap = function(self, ...)
				if self == LP then
					return
				end
				return oldKick(self, ...)
			end
		end
		oldKick = hookfunction(LP.Kick, kickWrap)
	end
end)

local function earlyAdonisShield()
	if typeof(getgc) ~= "function" then
		return
	end

	local function makeC(fn)
		if typeof(newcclosure) == "function" then
			local ok, w = pcall(newcclosure, fn)
			if ok and w then
				return w
			end
		end
		return fn
	end

	local hookedD, hookedK, hookedP = {}, {}, {}
	local detStub = makeC(function(_a, _b, _c)
		return true
	end)
	local killStub = makeC(function(_info) end)
	local procStub = makeC(function(...)
		return true
	end)

	local function replace(tbl, key, val)
		pcall(function()
			rawset(tbl, key, val)
		end)
	end

	local function hookTable(v, depth)
		if typeof(v) ~= "table" or depth > 3 then
			return
		end
		local hasVars = rawget(v, "Variables") ~= nil or rawget(v, "Logs") ~= nil
		local hasRemote = typeof(rawget(v, "Remote")) == "Instance"

		for _, key in ipairs({ "Detected", "Detect", "detect" }) do
			local det = rawget(v, key)
			if typeof(det) == "function" and not hookedD[det] then
				hookedD[det] = true
				if typeof(hookfunction) == "function" then
					pcall(hookfunction, det, detStub)
				end
				replace(v, key, detStub)
			end
		end

		for _, key in ipairs({ "checkClient", "CheckClient", "Check" }) do
			local chk = rawget(v, key)
			if typeof(chk) == "function" and not hookedD[chk] then
				hookedD[chk] = true
				if typeof(hookfunction) == "function" then
					pcall(hookfunction, chk, detStub)
				end
				replace(v, key, detStub)
			end
		end

		local kill = rawget(v, "Kill")
		if typeof(kill) == "function" and (hasVars or hasRemote) and not hookedK[kill] then
			hookedK[kill] = true
			if typeof(hookfunction) == "function" then
				pcall(hookfunction, kill, killStub)
			end
			replace(v, "Kill", killStub)
		end

		local proc = rawget(v, "Process")
		if typeof(proc) == "function" and not hookedP[proc] then
			local det = rawget(v, "Detected") or rawget(v, "Detect")
			if typeof(det) == "function" then
				hookedP[proc] = true
				if typeof(hookfunction) == "function" then
					pcall(hookfunction, proc, procStub)
				end
				replace(v, "Process", procStub)
			end
		end

		for _, key in ipairs({ "Anti", "Client", "AC", "Module", "Main", "Core" }) do
			local sub = rawget(v, key)
			if typeof(sub) == "table" then
				hookTable(sub, depth + 1)
			end
		end
	end

	local function run()
		for _, v in getgc(true) do
			hookTable(v, 0)
		end
		local ok, loose = pcall(getgc, false)
		if ok and typeof(loose) == "table" then
			for _, v in loose do
				hookTable(v, 0)
			end
		end
	end

	local function scan()
		if typeof(setthreadidentity) == "function" then
			pcall(function()
				setthreadidentity(2)
				run()
				setthreadidentity(7)
			end)
		else
			run()
		end
	end

	scan()
	task.spawn(function()
		for _ = 1, 120 do
			scan()
			task.wait(1)
		end
	end)
end
earlyAdonisShield()

local function resolveBootstrapRoot(cr)
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then
			return cr(h), true
		end
	end
	if typeof(get_hidden_gui) == "function" then
		local ok, h = pcall(get_hidden_gui)
		if ok and h then
			return cr(h), true
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

local LOAD_TOTAL = 26
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
	loadStep += 1
	bootProgress(file:gsub("%.lua$", ""), loadStep / LOAD_TOTAL * 0.68, loadStep .. " / " .. LOAD_TOTAL .. " modułów", true)
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

bootProgress("Moduły gry", 0.74)

AntiBypass.installShield(Settings)
bootProgress("Anti-Cheat", 0.755)
if Settings.AntiBypass ~= false then
	AntiBypass.waitForAdonis(14)
end

local CG = AntiBypass.getGuiRoot()
if not CG then
	error("[Vanguard] Brak gethui/protect_gui — włącz hidden UI w executorze (Potassium)", 0)
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
	AntiBypass.scanAdonis()
	task.wait(0.35)
	UI.Init(Settings, GUI, Config, TeamFriends, Animations, World, Menus, GameSupport, UIColorPicker, UIConfigMenus, Music, UIMusic, I18n, AntiBypass)

	Settings.Unload = function()
		Settings.Unloaded = true
		Core.unload()
	end

	if Settings.TransferScript and Settings.ApplyTransferScript then
		pcall(Settings.ApplyTransferScript)
	end

	Stealth.silentPrint(isTransferLoad and "VANGUARD: Loaded (transfer)" or "VANGUARD: Loaded")
end)
