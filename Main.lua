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

-- EARLY Adonis shield: "Disallowed Services Detected" (MainDetection)
-- Adonis: if FindService(ServerStorage|ServerScriptService) then Detected("crash", ...)
-- Executors often expose these to the client; must return nil BEFORE Adonis MainDetection runs.
-- Safe at boot (no getgc / no yield / no Detected hook).
do
	local BLOCKED = {
		ServerStorage = true,
		ServerScriptService = true,
	}
	local function isBlockedName(v)
		return typeof(v) == "string" and BLOCKED[v] == true
	end

	local function makeCC(f)
		if typeof(newcclosure) == "function" then
			local ok, w = pcall(newcclosure, f)
			if ok and w then
				return w
			end
		end
		return f
	end

	local hooked = false
	if typeof(hookfunction) == "function" then
		pcall(function()
			local oldFS = game.FindService
			if typeof(oldFS) ~= "function" then
				return
			end
			-- Adonis calls unbound: FindService("ServerStorage", DataModel) AND normal :FindService(name)
			hookfunction(oldFS, makeCC(function(a, b, ...)
				if isBlockedName(a) or isBlockedName(b) then
					return nil
				end
				return oldFS(a, b, ...)
			end))
			hooked = true
		end)
	end

	if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
		pcall(function()
			local oldNc
			oldNc = hookmetamethod(game, "__namecall", makeCC(function(self, ...)
				local method = getnamecallmethod()
				if method == "FindService" or method == "findService" then
					local name = ...
					if isBlockedName(name) then
						return nil
					end
				end
				return oldNc(self, ...)
			end))
			hooked = true
		end)
	end

	if typeof(_G.__VG_LOG_FILE) == "function" then
		_G.__VG_LOG_FILE("INFO", "[VG:bypass] FindService shield=" .. tostring(hooked) .. " (ServerStorage/SSS)")
	end
end

-- ADONIS BYPASS — based on Anti.luau source analysis:
-- Anti runs: debug.info(Detected,"slanf") → if closure≠Detected → "while true do end"
-- hookfunction(Detected) changes closure identity → freeze. DO NOT hookfunction Detected.
-- Yield suspends Anti — but yielding from a non-yieldable engine context = native AV (c0000005).
-- CRITICAL: defer ALL getgc/hooks until AFTER UI ready. Boot-time Adonis hooks crash Adonis games.
-- Sources: github.com/Epix-Incorporated/Adonis Anti.luau
do
	local function makeCC(f)
		if typeof(newcclosure) == "function" then
			local ok, w = pcall(newcclosure, f); if ok and w then return w end
		end
		return f
	end

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
				-- Only yield when safe — otherwise pass-through (freeze risk, not native crash).
				local canYield = true
				pcall(function()
					if typeof(coroutine.isyieldable) == "function" then
						canYield = coroutine.isyieldable()
					end
				end)
				if canYield then
					return coroutine.yield(coroutine.running())
				end
			end
			return _bypassOldDbgInfo(fn, ...)
		end)
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
		local i = 0
		for _, v in getgc(deep) do
			i = i + 1
			if i % 400 == 0 then
				task.wait()
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
		local dbgHooked = installDebugInfoHook(Detected)
		-- NEVER hookfunction(Detected) — breaks Anti identity check → freeze/crash.
		-- Yield on debug.info(Detected) suspends the Anti loop instead.
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

	-- Registered starter — Main calls this AFTER UI ready (never at bootstrap).
	_G.__VG_START_ADONIS_BYPASS = function()
		if _G.__VG_ADONIS_BYPASS_STARTED then
			return
		end
		_G.__VG_ADONIS_BYPASS_STARTED = true
		if typeof(getgc) ~= "function" or typeof(hookfunction) ~= "function" then
			return
		end
		task.spawn(function()
			if typeof(_G.__VG_LOG_FILE) == "function" then
				_G.__VG_LOG_FILE("INFO", "[VG:bypass] post-UI Adonis scan start")
			end
			pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(2) end end)

			local function timedBypassScan(deep)
				local perf = _G.__VG_PERF
				local wrap = perf and perf.wrap or function(_, fn) return fn end
				return wrap("Main.BypassScan", scanForAdonis)(deep)
			end

			-- Light scan only at first — getgc(true) during lobby boot caused native AV.
			local Detected, Kill = timedBypassScan(false)
			local installed = applyBypass(Detected, Kill)

			pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(7) end end)

			if not installed then
				if typeof(_G.__VG_LOG_FILE) == "function" then
					_G.__VG_LOG_FILE("WARN", "[VG:bypass] Det not found — light retry watcher")
				end
				task.spawn(function()
					for _ = 1, 12 do
						task.wait(3)
						if _G.__VG_DBG_HOOKED then break end
						pcall(function() if typeof(setthreadidentity) == "function" then setthreadidentity(2) end end)
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

	if typeof(_G.__VG_LOG_FILE) == "function" then
		_G.__VG_LOG_FILE("INFO", "[VG:bypass] early Adonis hooks DEFERRED until UI ready")
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
		card.Size = UDim2.new(0, 340, 0, 132)
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
		track.Position = UDim2.new(0, 14, 0, 72)
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
		countLbl.Size = UDim2.new(1, -100, 0, 12)
		countLbl.Position = UDim2.new(0, 14, 0, 82)
		countLbl.BackgroundTransparency = 1
		countLbl.Font = Enum.Font.Gotham
		countLbl.TextSize = 8
		countLbl.TextColor3 = Color3.fromRGB(90, 90, 100)
		countLbl.TextXAlignment = Enum.TextXAlignment.Left
		countLbl.Text = ""
		countLbl.Parent = card

		local retryBtn = Instance.new("TextButton")
		retryBtn.Name = "Retry"
		retryBtn.Size = UDim2.new(0, 72, 0, 22)
		retryBtn.Position = UDim2.new(1, -86, 1, -30)
		retryBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 42)
		retryBtn.BorderSizePixel = 0
		retryBtn.Font = Enum.Font.GothamBold
		retryBtn.TextSize = 10
		retryBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
		retryBtn.Text = "Retry"
		retryBtn.Visible = false
		retryBtn.AutoButtonColor = true
		retryBtn.Parent = card
		Instance.new("UICorner", retryBtn).CornerRadius = UDim.new(0, 6)
		local retryStroke = Instance.new("UIStroke")
		retryStroke.Color = ACC
		retryStroke.Thickness = 1
		retryStroke.Transparency = 0.45
		retryStroke.Parent = retryBtn

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
		local retryWaiters = {}
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
			setStatus = function(text)
				sub.Text = tostring(text or "Uruchamianie...")
			end,
			showRetry = function(visible, statusText)
				retryBtn.Visible = visible == true
				if statusText then
					sub.Text = tostring(statusText)
				elseif not visible then
					sub.Text = "Uruchamianie..."
				end
			end,
			waitRetry = function()
				local done = false
				local waiter = function()
					done = true
				end
				table.insert(retryWaiters, waiter)
				retryBtn.Visible = true
				while not done and gui.Parent do
					task.wait()
				end
				for i = #retryWaiters, 1, -1 do
					if retryWaiters[i] == waiter then
						table.remove(retryWaiters, i)
						break
					end
				end
				retryBtn.Visible = #retryWaiters > 0
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
				for _, w in ipairs(retryWaiters) do
					pcall(w)
				end
				table.clear(retryWaiters)
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
		retryBtn.MouseButton1Click:Connect(function()
			local copy = {}
			for i, w in ipairs(retryWaiters) do
				copy[i] = w
			end
			table.clear(retryWaiters)
			retryBtn.Visible = false
			sub.Text = "Ponawiam..."
			for _, w in ipairs(copy) do
				pcall(w)
			end
		end)
		_G.VG_BOOT.update("Start", 0.01)
	end
end

_G.VG_MODULE_CACHE = _G.VG_MODULE_CACHE or {}

-- Criminality-only modules are skipped outside that universe (faster boot elsewhere).
local CRIM_GAME_ID = 1494262959
local isCriminality = game.GameId == CRIM_GAME_ID

-- Base modules always fetched (Core → GameSupport). +4 Criminality modules when needed.
local LOAD_TOTAL = 29 + (isCriminality and 4 or 0)
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

-- Don't hang forever on a single HttpGet (common cause of stuck 28/29).
local function fetchUrlTimed(url, timeoutSec)
	timeoutSec = timeoutSec or 8
	local result = nil
	local done = false
	task.spawn(function()
		local ok, body = pcall(fetchUrl, url)
		if ok then
			result = body
		end
		done = true
	end)
	local t0 = tick()
	while not done and (tick() - t0) < timeoutSec do
		task.wait()
	end
	if not done then
		return nil
	end
	if typeof(result) == "string" and result ~= "" then
		return result
	end
	return nil
end

-- Fetch independent module sources concurrently. Execution remains ordered below,
-- but network latency no longer stacks across 29–33 sequential GitHub requests.
local MODULE_FILES = {
	"Core.lua", "Stealth.lua", "AntiBypass.lua", "Settings.lua", "Logger.lua", "Perf.lua",
	"Config.lua", "I18n.lua", "Teleport.lua", "Session.lua", "Util.lua", "ESP.lua",
	"TeamFriends.lua", "Aim.lua", "Rage.lua", "Movement.lua", "Invisibility.lua", "Misc.lua",
	"Features.lua", "Animations.lua", "World.lua", "Effects.lua", "Music.lua", "UIColorPicker.lua",
	"UIConfigMenus.lua", "UIMusic.lua", "UI.lua", "Menus.lua", "GameSupport.lua",
}
if isCriminality then
	table.insert(MODULE_FILES, "Criminality.lua")
	table.insert(MODULE_FILES, "PathDisplay.lua")
	table.insert(MODULE_FILES, "ClientBuild.lua")
	table.insert(MODULE_FILES, "BountyTracker.lua")
end

local MODULE_SOURCES = {}

local function listMissingModules()
	local missing = {}
	for _, file in ipairs(MODULE_FILES) do
		if not _G.VG_MODULE_CACHE[file] and (not MODULE_SOURCES[file] or MODULE_SOURCES[file] == "") then
			table.insert(missing, file)
		end
	end
	return missing
end

local function prefetchRound(files)
	if #files == 0 then
		return
	end
	bootProgress("Pobieranie modułów", 0.03, "0 / " .. LOAD_TOTAL .. " modułów", false)
	local nextIndex = 1
	local completed = 0
	local lastProgressAt = tick()
	local workers = math.min(8, #files)
	for _ = 1, workers do
		task.spawn(function()
			while true do
				local index = nextIndex
				nextIndex += 1
				local file = files[index]
				if not file then
					break
				end
				if not _G.VG_MODULE_CACHE[file] and not MODULE_SOURCES[file] then
					local body = fetchUrlTimed(REPO_BASE .. file, 8)
					if (not body or body == "") then
						body = fetchUrlTimed(REPO_BASE .. file, 10)
					end
					if body and body ~= "" then
						MODULE_SOURCES[file] = body
					end
				end
				completed += 1
				lastProgressAt = tick()
				local have = LOAD_TOTAL - #listMissingModules()
				bootProgress(
					"Pobieranie modułów",
					math.max(0.03, have / LOAD_TOTAL * 0.62),
					have .. " / " .. LOAD_TOTAL .. " modułów",
					true
				)
			end
		end)
	end
	while completed < #files do
		-- Stall watchdog: if no progress for 12s, stop waiting this round
		if (tick() - lastProgressAt) > 12 and completed > 0 then
			break
		end
		task.wait()
	end
end

local function prefetchModuleSources()
	local round = 0
	while true do
		local missing = listMissingModules()
		if #missing == 0 then
			if _G.VG_BOOT and _G.VG_BOOT.showRetry then
				_G.VG_BOOT.showRetry(false, "Uruchamianie...")
			end
			return
		end
		round += 1
		if _G.VG_BOOT and _G.VG_BOOT.setStatus then
			_G.VG_BOOT.setStatus(round == 1 and "Uruchamianie..." or ("Retry #" .. tostring(round - 1)))
		end
		prefetchRound(missing)
		missing = listMissingModules()
		if #missing == 0 then
			if _G.VG_BOOT and _G.VG_BOOT.showRetry then
				_G.VG_BOOT.showRetry(false, "Uruchamianie...")
			end
			return
		end
		-- Auto-retry once silently, then ask user
		if round == 1 then
			task.wait(0.35)
		else
			local msg = "Zacięte · brakuje " .. tostring(#missing) .. " · kliknij Retry"
			bootProgress("Czeka na Retry", math.max(0.03, (LOAD_TOTAL - #missing) / LOAD_TOTAL * 0.62), (LOAD_TOTAL - #missing) .. " / " .. LOAD_TOTAL .. " modułów", false)
			if _G.VG_BOOT and _G.VG_BOOT.showRetry then
				_G.VG_BOOT.showRetry(true, msg)
			end
			if _G.VG_BOOT and _G.VG_BOOT.waitRetry then
				_G.VG_BOOT.waitRetry()
			else
				task.wait(1.2)
			end
			if _G.VG_BOOT and _G.VG_BOOT.showRetry then
				_G.VG_BOOT.showRetry(false, "Ponawiam...")
			end
		end
	end
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
	local src = MODULE_SOURCES[file]
	MODULE_SOURCES[file] = nil
	local lastErr = "empty response"
	if not src then
		for attempt = 1, 5 do
			local body = fetchUrlTimed(url, 8 + attempt)
			if body and body ~= "" then
				src = body
				break
			end
			lastErr = "timeout/empty"
			if attempt < 5 then
				if _G.VG_BOOT and _G.VG_BOOT.setStatus then
					_G.VG_BOOT.setStatus("Retry " .. file:gsub("%.lua$", "") .. " #" .. attempt)
				end
				task.wait(0.2 * attempt)
			end
		end
	end
	-- Still missing after timed retries — offer manual Retry instead of hard crash loop
	while not src or src == "" do
		if _G.VG_BOOT and _G.VG_BOOT.showRetry then
			_G.VG_BOOT.showRetry(true, "Brak " .. file:gsub("%.lua$", "") .. " · Retry")
		end
		if _G.VG_BOOT and _G.VG_BOOT.waitRetry then
			_G.VG_BOOT.waitRetry()
		else
			task.wait(1)
		end
		if _G.VG_BOOT and _G.VG_BOOT.showRetry then
			_G.VG_BOOT.showRetry(false, "Ponawiam " .. file:gsub("%.lua$", "") .. "...")
		end
		src = fetchUrlTimed(url, 12)
		if not src or src == "" then
			lastErr = "timeout/empty after retry"
		end
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
	return res
end

local isTransferLoad = _G.VG_FROM_TRANSFER == true
_G.VG_FROM_TRANSFER = nil

prefetchModuleSources()

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

-- Helper: log phase start/end to file (with elapsed ms for Criminality crash bisect)
local function phase(name, fn, ...)
	_kickPhase = name
	local t0 = os.clock()
	if typeof(_G.__VG_LOG_FILE) == "function" then
		_G.__VG_LOG_FILE("INFO", "[VG:phase] >>> " .. name)
	end
	local args = { ... }
	local ok, err = pcall(function()
		fn(table.unpack(args))
	end)
	local ms = math.floor((os.clock() - t0) * 1000)
	if typeof(_G.__VG_LOG_FILE) == "function" then
		if ok then
			_G.__VG_LOG_FILE("INFO", string.format("[VG:phase] <<< %s OK (%dms)", name, ms))
		else
			_G.__VG_LOG_FILE("ERROR", string.format("[VG:phase] <<< %s ERR (%dms): %s", name, ms, tostring(err)))
		end
	end
	if not ok then
		warn("[Vanguard] phase failed:", name, err)
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
	if typeof(_G.__VG_LOG_FILE) == "function" then
		_G.__VG_LOG_FILE(
			"INFO",
			string.format(
				"[VG:crim] universe boot place=%s job=%s",
				tostring(game.PlaceId),
				tostring(game.JobId)
			)
		)
	end
	phase("Criminality.Init", Criminality.Init, Settings)
	-- Defer heavy Crim addons until UI signals ready (or timeout) — recent lobby freezes
	task.defer(function()
		local deadline = os.clock() + 8
		while os.clock() < deadline do
			if Settings._vgUiReady or Settings.Unloaded then
				break
			end
			task.wait(0.2)
		end
		if Settings.Unloaded then
			return
		end
		if Settings.CrimLiteBoot == true then
			if typeof(_G.__VG_LOG_FILE) == "function" then
				_G.__VG_LOG_FILE("WARN", "[VG:crim] skip Path/ClientBuild/Bounty (CrimLiteBoot)")
			end
			return
		end
		if typeof(_G.__VG_LOG_FILE) == "function" then
			_G.__VG_LOG_FILE(
				"INFO",
				string.format(
					"[VG:crim] addon init uiReady=%s",
					tostring(Settings._vgUiReady == true)
				)
			)
		end
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
	end)
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

-- Adonis getgc/hooks ONLY after UI ready — boot-time hooks crash Adonis clients (native AV).
if Settings.AntiBypass ~= false then
	task.spawn(function()
		local deadline = os.clock() + 20
		while os.clock() < deadline do
			if Settings._vgUiReady or Settings.Unloaded then
				break
			end
			task.wait(0.25)
		end
		if Settings.Unloaded then
			return
		end
		-- Extra settle time after loader teardown (Adonis Anti may still be initializing).
		task.wait(isCriminality and 2.5 or 1.0)
		if Settings.Unloaded then
			return
		end
		if typeof(_G.__VG_LOG_FILE) == "function" then
			_G.__VG_LOG_FILE("INFO", "[VG:bypass] starting deferred Adonis bypass")
		end
		if typeof(_G.__VG_START_ADONIS_BYPASS) == "function" then
			pcall(_G.__VG_START_ADONIS_BYPASS)
		end
		pcall(AntiBypass.unlockAdonisHooks, Settings)
		task.wait(0.5)
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
