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

-- ADONIS BYPASS — based on Anti.luau source analysis:
-- Anti runs: debug.info(Detected,"slanf") → if closure≠Detected → "while true do end" (line 427)
-- hookfunction(Detected) changes closure identity → freeze. DO NOT hookfunction Detected.
-- CORRECT approach: hook debug.info with coroutine.yield → suspends entire anti-cheat routine.
-- Sources: github.com/Epix-Incorporated/Adonis Anti.luau + scripthub bypass script
do
	local function makeCC(f)
		if typeof(newcclosure) == "function" then
			local ok, w = pcall(newcclosure, f); if ok and w then return w end
		end
		return f
	end

	-- Shared state used by both the initial pass and the retry watcher.
	local _bypassDetected = nil
	local _bypassOldDbgInfo = nil

	local function installDebugInfoHook(Detected)
		if _G.__VG_DBG_HOOKED then return true end
		local renv = typeof(getrenv) == "function" and getrenv() or nil
		if not renv or typeof(renv.debug) ~= "table" then return false end
		local oldInfo = renv.debug.info
		if typeof(oldInfo) ~= "function" then return false end
		_bypassOldDbgInfo = _bypassOldDbgInfo or oldInfo
		local detRef = Detected
		local wrap = makeCC(function(fn, ...)
			if fn == detRef then
				-- Yield Adonis's tamper-check coroutine forever.
				-- This suspends the entire anti-cheat routine — no detectors run.
				return coroutine.yield(coroutine.running())
			end
			return _bypassOldDbgInfo(fn, ...)
		end)
		-- Direct assignment preferred — hookfunction on debug.info fails in Potassium.
		local ok = pcall(function() renv.debug.info = wrap end)
		if not ok then
			ok = pcall(hookfunction, oldInfo, wrap)
		end
		if ok then
			_G.__VG_DBG_HOOKED = true
		end
		return ok
	end

	local function scanForAdonis(deep)
		if typeof(getgc) ~= "function" then return nil, nil end
		local Detected, Kill
		-- Yield every 400 items to prevent blocking the scheduler in large games
		-- (e.g. Rivals with 200k+ concurrent players has a massive GC heap).
		local i = 0
		for _, v in getgc(deep) do
			i = i + 1
			if i % 400 == 0 then
				task.wait()   -- give the scheduler a breath
			end
			if typeof(v) == "table" then
				if not Detected then
					local det = rawget(v, "Detected")
					if typeof(det) == "function" then Detected = det end
				end
				if not Kill then
					local kill = rawget(v, "Kill")
					if typeof(kill) == "function" and rawget(v, "Variables") and rawget(v, "Process") then
						Kill = kill
					end
				end
			end
			if Detected and Kill then break end
		end
		return Detected, Kill
	end

	local function applyBypass(Detected, Kill)
		if not Detected then return false end
		_bypassDetected = Detected
		local dbgHooked = installDebugInfoHook(Detected)
		-- Hook Detected to return true for the sanity check Detected("_","_",true).
		-- Safe to do AFTER debug.info is hooked (tamper-check coroutine is now suspended).
		if dbgHooked then
			pcall(hookfunction, Detected, makeCC(function() return true end))
		end
		if Kill then
			pcall(hookfunction, Kill, makeCC(function() end))
		end
		if typeof(_G.__VG_LOG_FILE) == "function" then
			_G.__VG_LOG_FILE("INFO", string.format(
				"[VG:bypass] Det=true Kill=%s dbgInfo=%s",
				tostring(Kill ~= nil), tostring(dbgHooked)
			))
		end
		return dbgHooked
	end

	if typeof(getgc) == "function" and typeof(hookfunction) == "function" then
		-- Run in task.spawn to avoid blocking the scheduler (no freeze).
		-- Adonis tamper-check fires every 5 s — we have plenty of time to hook.
		task.spawn(function()
			if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
			pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(2) end end)

			local function timedBypassScan(deep)
				local perf = _G.__VG_PERF
				local wrap = perf and perf.wrap or function(_, fn) return fn end
				return wrap("Main.BypassScan", scanForAdonis)(deep)
			end

			-- Fast light scan first (getgc false) — works if Adonis is already loaded.
			local Detected, Kill = timedBypassScan(false)

			-- Deep scan fallback if light scan missed it (Adonis tables may not be in light GC).
			if not Detected then
				Detected, Kill = timedBypassScan(true)
			end

			local installed = applyBypass(Detected, Kill)

			pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(7) end end)

			-- RETRY WATCHER: for games where Adonis loads AFTER our script (e.g. Criminality).
			-- Polls every 3 s for up to 30 s (10 attempts). Stops as soon as hook confirmed.
			-- Uses light scan (getgc false) first to avoid blocking scheduler in big games.
			if not installed then
				if typeof(_G.__VG_LOG_FILE) == "function" then
					_G.__VG_LOG_FILE("WARN", "[VG:bypass] Det not found — starting retry watcher (Adonis may load late)")
				end
				task.spawn(function()
					for _ = 1, 10 do      -- max 10 × 3s = 30 s
						task.wait(3)
						if _G.__VG_DBG_HOOKED then break end
						pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(2) end end)
						-- Light scan only — avoids the heavy getgc(true) causing stutters
						local d, k = timedBypassScan(false)
						pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(7) end end)
						if d then
							applyBypass(d, k)
							break
						end
					end
				end)
			end
		end)
	end
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

-- Criminality-only modules are skipped outside that universe (faster boot elsewhere).
local CRIM_GAME_ID = 1494262959
local isCriminality = game.GameId == CRIM_GAME_ID

-- Base modules always fetched (Core → GameSupport). +Criminality +ClientBuild when needed.
local LOAD_TOTAL = 29 + (isCriminality and 3 or 0)
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
local Perf = Get("Perf.lua")
_G.__VG_PERF = Perf
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
local Invisibility = Get("Invisibility.lua")
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

-- Heavy game-specific module: don't HttpGet/compile outside Criminality
local Criminality = nil
if isCriminality then
	Criminality = Get("Criminality.lua")
	-- Swap Intro.music ASAP (before UI boot) — menu BGM is already playing
	if Criminality and Criminality.StartMenuMusicEarly then
		pcall(Criminality.StartMenuMusicEarly, Settings)
	end
end

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

-- Phase tracker: logs exactly WHAT was active when the kick happened
local _kickPhase = "post-AntiBypass.Init"
do
	local LP = game:GetService("Players").LocalPlayer
	if LP then
		LP.AncestryChanged:Connect(function()
			if LP.Parent then return end
			local st = pcall(AntiBypass.getAdonisStatus) and AntiBypass.getAdonisStatus() or {}
			local msg = string.format(
				"[VG:KICK] phase=%s | bypass hooked=%s count=%d det=%d kill=%d detectors=%d",
				_kickPhase,
				tostring(st.hooked or false), st.count or 0,
				st.detected or 0, st.kill or 0, st.detectors or 0
			)
			if typeof(_G.__VG_LOG_FILE) == "function" then _G.__VG_LOG_FILE("WARN", msg) end
			pcall(warn, msg)
		end)
	end
end

-- Helper: log phase start/end to file
local function phase(name, fn, ...)
	_kickPhase = name
	if typeof(_G.__VG_LOG_FILE) == "function" then _G.__VG_LOG_FILE("INFO", "[VG:phase] >>> " .. name) end
	local args = { ... }
	local ok, err = pcall(function() fn(table.unpack(args)) end)
	if typeof(_G.__VG_LOG_FILE) == "function" then
		if ok then
			_G.__VG_LOG_FILE("INFO", "[VG:phase] <<< " .. name .. " OK")
		else
			_G.__VG_LOG_FILE("ERROR", "[VG:phase] <<< " .. name .. " ERR: " .. tostring(err))
		end
	end
	return ok
end

bootProgress("ESP & HUD", 0.78)

phase("ESP.Init",        ESP.Init,        Settings, GUI, TeamFriends, Util)
phase("Aim.Init",        Aim.Init,        Settings, GUI, TeamFriends, Util)
phase("Rage.Init",       Rage.Init,       Settings, GUI, TeamFriends, Util)
phase("Movement.Init",   Movement.Init,   Settings)
phase("Invisibility.Init", Invisibility.Init, Settings, GUI)
if isCriminality and Criminality then
	phase("Criminality.Init", Criminality.Init, Settings)
	phase("PathDisplay.Init", function(S)
		local mod = Get("PathDisplay.lua")
		if mod and mod.Init then
			mod.Init(S)
		end
	end, Settings)
	phase("ClientBuild.Init", function(S)
		local mod = Get("ClientBuild.lua")
		if mod and mod.Init then
			mod.Init(S)
		end
	end, Settings)
	phase("BountyTracker.Init", function(S)
		local mod = Get("BountyTracker.lua")
		if mod and mod.Init then
			mod.Init(S)
		end
	end, Settings)
end
phase("Misc.Init",       Misc.Init,       Settings, TeamFriends, Util)
phase("Features.Init",   Features.Init,   Settings, GUI, AntiBypass)
phase("Effects.Init",    Effects.Init,    Settings, Util)
phase("Animations.Init", Animations.Init, Settings)
phase("World.Init",      World.Init,      Settings)
phase("Music.Init",      Music.Init,      Settings, I18n)

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

-- Log bypass status after all feature inits, before UI
if typeof(_G.__VG_LOG_FILE) == "function" then
	local st = pcall(AntiBypass.getAdonisStatus) and AntiBypass.getAdonisStatus() or {}
	_G.__VG_LOG_FILE("INFO", string.format(
		"[VG:pre-UI] bypass hooked=%s count=%d det=%d kill=%d detectors=%d",
		tostring(st.hooked or false), st.count or 0, st.detected or 0, st.kill or 0, st.detectors or 0
	))
end

bootProgress("Interfejs", 0.86)

-- Bypass scans in background — do NOT block UI.Init
if Settings.AntiBypass ~= false then
	task.spawn(function()
		task.wait(0.3)
		AntiBypass.waitForAdonis(2)
		AntiBypass.logAdonisDiagnostics("bypass", Settings)
	end)
end

task.spawn(function()
	_kickPhase = "UI.Init-start"
	AntiBypass.setUiBuilding(true)
	task.wait()
	phase("UI.Init", UI.Init, Settings, GUI, Config, TeamFriends, Animations, World, Menus, GameSupport, UIColorPicker, UIConfigMenus, Music, UIMusic, I18n, AntiBypass)
	_kickPhase = "post-UI.Init"
	AntiBypass.setUiBuilding(false)
	AntiBypass.logAdonisDiagnostics("post-UI", Settings)

	Settings.Unload = function()
		Settings.Unloaded = true
		Core.unload()
	end

	if Settings.TransferScript and Settings.ApplyTransferScript then
		pcall(Settings.ApplyTransferScript)
	end

	_kickPhase = "loaded"
	Stealth.silentPrint(isTransferLoad and "VANGUARD: Loaded (transfer)" or "VANGUARD: Loaded")
end)
