-- Plik: workspace/Vanguard/AntiBypass.lua

local AntiBypass = {}

local concealed = setmetatable({}, { __mode = "k" })
local protected = setmetatable({}, { __mode = "k" })
local cachedGuiRoot = nil
local usingHiddenGui = false
local shieldInstalled = false
local adonisDetectedRef = nil
local adonisScanTask = nil
local hookedDetectedFns = {}
local hookedKillFns = {}
local hookedProcessFns = {}
local adonisHookCount = 0
local adonisDetectedHooked = 0
local adonisKillHooked = 0
local adonisLastDeepScanAt = 0
local ADONIS_DEEP_SCAN_COOLDOWN = 4
local adonisWatcherStop = false
local debugInfoHooked = false
local uiBuilding = false
local adonisKillAttempts = 0
local adonisKillGraceEnd = 0
local playerKickAttempts = 0
local playerKickGraceEnd = 0

local ADONIS_KILL_MAX_BLOCK = 4
local ADONIS_KILL_GRACE_SEC = 2.5
local PLAYER_KICK_MAX_BLOCK = 5
local PLAYER_KICK_GRACE_SEC = 3.0

local function isLoadPhase()
	return _G.__VG_LOADING == true
end

local function makeCclosure(fn)
	if typeof(newcclosure) == "function" then
		local ok, wrapped = pcall(newcclosure, fn)
		if ok and wrapped then
			return wrapped
		end
	end
	return fn
end

local blankDetected = makeCclosure(function(_action, _info, _noCrash)
	return true
end)

local function shouldAllowAdonisKill()
	adonisKillAttempts += 1
	if adonisKillAttempts > ADONIS_KILL_MAX_BLOCK then
		return true
	end
	if adonisKillGraceEnd <= 0 then
		adonisKillGraceEnd = os.clock() + ADONIS_KILL_GRACE_SEC
	end
	return os.clock() >= adonisKillGraceEnd
end

local function makeSoftKill(oldKill)
	return makeCclosure(function(info)
		if shouldAllowAdonisKill() then
			if typeof(oldKill) == "function" then
				pcall(oldKill, info)
			end
			return
		end
	end)
end

local blankKill = makeCclosure(function(_info) end)

local blankProcess = makeCclosure(function(...)
	return true
end)

local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local CoreGuiService = game:GetService("CoreGui")

local function cr(inst)
	if typeof(cloneref) == "function" then
		local ok, ref = pcall(cloneref, inst)
		if ok and ref then
			return ref
		end
	end
	return inst
end

local function tryHiddenGui(fn)
	if typeof(fn) ~= "function" then
		return nil
	end
	local ok, hui = pcall(fn)
	if ok and hui and typeof(hui) == "Instance" then
		return cr(hui)
	end
	return nil
end

local function randomGuiName()
	local n = math.random(10, 18)
	local out = {}
	for _ = 1, n do
		local pick = math.random(1, 62)
		if pick <= 26 then
			out[#out + 1] = string.char(64 + pick)
		elseif pick <= 52 then
			out[#out + 1] = string.char(96 + pick - 26)
		else
			out[#out + 1] = tostring(math.random(0, 9))
		end
	end
	return table.concat(out)
end

local function isCoreGuiScan(assets)
	if typeof(assets) ~= "table" then
		return false
	end
	for _, item in ipairs(assets) do
		if item == CoreGuiService or item == game.CoreGui then
			return true
		end
		if typeof(item) == "Instance" and item:IsDescendantOf(CoreGuiService) then
			return true
		end
	end
	return false
end

function AntiBypass.randomName()
	return randomGuiName()
end

function AntiBypass.hasHiddenGui()
	return usingHiddenGui == true
end

function AntiBypass.setStealth(_mod)
end

function AntiBypass.getGuiRoot()
	if cachedGuiRoot and cachedGuiRoot.Parent then
		return cachedGuiRoot
	end

	usingHiddenGui = false
	local root = tryHiddenGui(gethui)
		or tryHiddenGui(get_hidden_gui)
		or tryHiddenGui(gethiddengui)
		or tryHiddenGui(get_hidden_ui)

	if not root and typeof(getgenv) == "function" then
		local g = getgenv()
		if g then
			root = tryHiddenGui(g.gethui)
				or tryHiddenGui(g.get_hidden_gui)
				or tryHiddenGui(g.gethiddengui)
			if typeof(g.HiddenUI) == "Instance" then
				root = root or cr(g.HiddenUI)
			end
		end
	end

	if not root and typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		local okCore, coreGui = pcall(function()
			return cr(CoreGuiService)
		end)
		if okCore and coreGui then
			root = coreGui
		end
	end

	if not root then
		local okLP, lp = pcall(function()
			return cr(game:GetService("Players").LocalPlayer)
		end)
		if okLP and lp then
			root = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
		end
	end

	if root then
		usingHiddenGui = tryHiddenGui(gethui) ~= nil
			or tryHiddenGui(get_hidden_gui) ~= nil
			or tryHiddenGui(gethiddengui) ~= nil
			or tryHiddenGui(get_hidden_ui) ~= nil
		cachedGuiRoot = root
	end
	return root
end

function AntiBypass.bringToFront(gui)
	if not gui then
		return
	end
	pcall(function()
		if gui:IsA("ScreenGui") then
			gui.DisplayOrder = 8
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = true
		end
	end)
end

function AntiBypass.protectInstance(gui)
	if not gui or protected[gui] then
		return false
	end
	protected[gui] = true

	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
	end
	if typeof(protectgui) == "function" then
		pcall(protectgui, gui)
	end

	local root = AntiBypass.getGuiRoot()
	if not root then
		return false
	end

	pcall(function()
		gui.Parent = root
	end)

	if typeof(cloneref) == "function" then
		pcall(cloneref, gui)
	end
	return gui.Parent ~= nil
end

function AntiBypass.concealGui(gui)
	if not gui or not gui:IsA("GuiObject") then
		return false
	end
	concealed[gui] = true
	local ok = AntiBypass.protectInstance(gui)
	AntiBypass.bringToFront(gui)
	return ok
end

function AntiBypass.isVanguardGui(gui)
	return gui and concealed[gui] == true
end

local function isFullyHooked()
	return adonisDetectedHooked > 0 and adonisKillHooked > 0 and debugInfoHooked
end

local function isBlockedRemoteArg(arg)
	if typeof(arg) ~= "string" then
		return false
	end
	local lower = string.lower(arg)
	return lower == "detected" or lower:find("clientcheck", 1, true) ~= nil
end

local function shouldCheckRemote(self)
	if typeof(self) ~= "userdata" and typeof(self) ~= "Instance" then
		return false
	end
	local ok, isRemote = pcall(function()
		return self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
	end)
	return ok and isRemote
end

local function installNamecallShield()
	if _G.__VG_NAMECALL_SHIELD or typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		return
	end
	local oldNC
	local wrap = makeCclosure(function(self, ...)
		local method = getnamecallmethod()
		if method == "FireServer" or method == "InvokeServer" then
			if shouldCheckRemote(self) then
				for i = 1, select("#", ...) do
					if isBlockedRemoteArg(select(i, ...)) then
						if _G.__VG_LOG_FILE then
							_G.__VG_LOG_FILE("BLOCK", "ab namecall " .. method .. " " .. tostring(select(i, ...)))
						end
						return nil
					end
				end
			end
		end
		return oldNC(self, ...)
	end)
	oldNC = hookmetamethod(game, "__namecall", wrap)
	_G.__VG_NAMECALL_SHIELD = true
end

local function installIndexKickBypass()
	if typeof(getgc) ~= "function" then
		return
	end
	for _, v in getgc(false) do
		if typeof(v) == "table" then
			local idx = rawget(v, "indexInstance")
			if typeof(idx) == "table" and idx[1] == "kick" then
				pcall(function()
					rawset(v, "tvk", { "kick", function()
						return workspace:WaitForChild("")
					end })
				end)
			end
		end
	end
end

local function installAdonisLogTrigger()
	if _G.__VG_ADONIS_LOG_TRIGGER then
		return
	end
	_G.__VG_ADONIS_LOG_TRIGGER = true
	pcall(function()
		local LogService = game:GetService("LogService")
		LogService.MessageOut:Connect(function(message)
			if typeof(message) ~= "string" or not message:find("Adonis", 1, true) then
				return
			end
			if message:find("Anti", 1, true)
				or message:find("FINISHED LOADING", 1, true)
				or message:find("Start ClientCheck", 1, true)
				or message:find("Loading Core Module", 1, true) then
				task.defer(function()
					AntiBypass.scanAdonis({ deep = false })
					ensureDebugInfoHook()
					if not isLoadPhase() and not uiBuilding then
						task.delay(1.5, function()
							AntiBypass.scanAdonis({ deep = true })
							ensureDebugInfoHook()
						end)
					end
				end)
			end
		end)
	end)
end

local function withScanIdentity(fn)
	if typeof(setthreadidentity) == "function" then
		local ok = pcall(function()
			setthreadidentity(2)
			fn()
			setthreadidentity(7)
		end)
		if ok then
			return
		end
	end
	if typeof(syn) == "table" and typeof(syn.set_thread_identity) == "function" then
		local ok = pcall(function()
			syn.set_thread_identity(2)
			fn()
			syn.set_thread_identity(7)
		end)
		if ok then
			return
		end
	end
	fn()
end

local function ensureDebugInfoHook()
	if debugInfoHooked or not adonisDetectedRef or typeof(hookfunction) ~= "function" then
		return false
	end
	local renv = typeof(getrenv) == "function" and getrenv() or nil
	if not renv or typeof(renv.debug) ~= "table" or typeof(renv.debug.info) ~= "function" then
		return false
	end
	local oldInfo = renv.debug.info
	local wrap = makeCclosure(function(levelOrFunc, what, ...)
		if levelOrFunc == adonisDetectedRef then
			if what == "n" then
				return "Adonis"
			end
			if what == "s" or what == "l" then
				return "=[C]"
			end
			return nil
		end
		return oldInfo(levelOrFunc, what, ...)
	end)
	local ok = pcall(function()
		hookfunction(renv.debug.info, wrap)
	end)
	if ok then
		debugInfoHooked = true
	end
	return ok
end

local function replaceTableFn(tbl, key, replacement)
	if typeof(tbl) ~= "table" or typeof(key) ~= "string" then
		return
	end
	pcall(function()
		rawset(tbl, key, replacement)
	end)
end

local function hookDetectedFn(fn, tbl, key)
	if typeof(fn) ~= "function" or hookedDetectedFns[fn] then
		return false
	end
	hookedDetectedFns[fn] = true
	if not adonisDetectedRef then
		adonisDetectedRef = fn
	end
	if typeof(hookfunction) == "function" then
		pcall(hookfunction, fn, blankDetected)
	end
	if tbl and key then
		replaceTableFn(tbl, key, blankDetected)
	end
	adonisHookCount += 1
	adonisDetectedHooked += 1
	ensureDebugInfoHook()
	return true
end

local function hookKillFn(fn)
	if typeof(fn) ~= "function" or hookedKillFns[fn] then
		return false
	end
	hookedKillFns[fn] = true
	local softKill = makeSoftKill(fn)
	blankKill = softKill
	if typeof(hookfunction) == "function" then
		pcall(hookfunction, fn, softKill)
	end
	adonisHookCount += 1
	adonisKillHooked += 1
	return true
end

local function hookProcessFn(fn)
	if typeof(fn) ~= "function" or hookedProcessFns[fn] then
		return false
	end
	hookedProcessFns[fn] = true
	if typeof(hookfunction) == "function" then
		pcall(hookfunction, fn, blankProcess)
	end
	adonisHookCount += 1
	return true
end

local function isAdonisClientTable(v)
	if typeof(v) ~= "table" then
		return false
	end
	if typeof(rawget(v, "Detected")) == "function" then
		return true
	end
	if typeof(rawget(v, "RLocked")) ~= "nil" and typeof(rawget(v, "Detected")) == "function" then
		return true
	end
	if typeof(rawget(v, "Kill")) == "function" and rawget(v, "Variables") and rawget(v, "Process") then
		return true
	end
	if typeof(rawget(v, "Anti")) == "table" then
		return true
	end
	return false
end

local function isAdonisCandidate(v)
	return isAdonisClientTable(v)
end

local function tryHookAdonisTable(v, depth)
	if typeof(v) ~= "table" or depth > 3 then
		return false
	end
	if depth == 0 and not isAdonisCandidate(v) then
		return false
	end

	local hooked = false
	local hasVars = rawget(v, "Variables") ~= nil
	local hasProcess = typeof(rawget(v, "Process")) == "function"

	for _, key in ipairs({ "Detected", "Detect", "detect" }) do
		local det = rawget(v, key)
		if typeof(det) == "function" then
			if hookDetectedFn(det, v, key) then
				hooked = true
			end
		end
	end

	for _, key in ipairs({ "checkClient", "CheckClient", "Check" }) do
		local chk = rawget(v, key)
		if typeof(chk) == "function" then
			if hookDetectedFn(chk, v, key) then
				hooked = true
			end
		end
	end

	local kill = rawget(v, "Kill")
	if typeof(kill) == "function" and hasVars and hasProcess then
		if hookKillFn(kill) then
			replaceTableFn(v, "Kill", blankKill)
			hooked = true
		end
	end

	local proc = rawget(v, "Process")
	if typeof(proc) == "function" and hasVars then
		if hookProcessFn(proc) then
			replaceTableFn(v, "Process", blankProcess)
			hooked = true
		end
	end

	local send = rawget(v, "Send")
	if typeof(send) == "function" and (hasVars or hasRemote or typeof(rawget(v, "Detected")) == "function") then
		if typeof(hookfunction) == "function" then
			pcall(function()
				local oldSend
				local sendWrap = makeCclosure(function(evt, ...)
					if evt == "Detected" or tostring(evt):find("Detected", 1, true) then
						return nil
					end
					return oldSend(evt, ...)
				end)
				oldSend = hookfunction(send, sendWrap)
			end)
		end
		hooked = true
	end

	for _, key in ipairs({ "Anti", "Client", "Core", "Remote" }) do
		local sub = rawget(v, key)
		if typeof(sub) == "table" and tryHookAdonisTable(sub, depth + 1) then
			hooked = true
		end
	end

	return hooked
end

local function scanAdonisList(list)
	local hooked = false
	for _, v in list do
		if tryHookAdonisTable(v, 0) then
			hooked = true
		end
	end
	return hooked
end

local function runLightScan()
	local hooked = false
	local ok, loose = pcall(getgc, false)
	if ok and typeof(loose) == "table" then
		hooked = scanAdonisList(loose) or hooked
	end
	return hooked
end

local function runDeepScanBatched()
	if typeof(getgc) ~= "function" then
		return false
	end
	if isLoadPhase() then
		return false
	end
	if uiBuilding then
		return false
	end
	if adonisHookCount > 0 and isFullyHooked() then
		return false
	end
	local now = os.clock()
	if now - adonisLastDeepScanAt < ADONIS_DEEP_SCAN_COOLDOWN then
		return false
	end
	adonisLastDeepScanAt = now
	local hooked = false
	local scanned = 0
	withScanIdentity(function()
		for _, v in getgc(true) do
			scanned += 1
			if isAdonisClientTable(v) and tryHookAdonisTable(v, 0) then
				hooked = true
			end
			if scanned % 250 == 0 then
				task.wait()
			end
			if adonisHookCount > 0 and isFullyHooked() then
				break
			end
		end
	end)
	ensureDebugInfoHook()
	return hooked
end

local function scheduleDeepScan(delaySec)
	task.delay(delaySec or 2, function()
		if adonisWatcherStop or isLoadPhase() then
			return
		end
		if isFullyHooked() then
			return
		end
		AntiBypass.scanAdonis({ deep = true })
		ensureDebugInfoHook()
		if adonisHookCount <= 0 or not isFullyHooked() then
			scheduleDeepScan(ADONIS_DEEP_SCAN_COOLDOWN)
		end
	end)
end

function AntiBypass.scanAdonis(opts)
	if typeof(getgc) ~= "function" then
		return adonisHookCount > 0
	end
	opts = opts or {}
	local hooked = runLightScan()
	local allowDeep = opts.deep == true and not isLoadPhase() and not uiBuilding
	if not hooked and allowDeep then
		hooked = runDeepScanBatched()
	end
	ensureDebugInfoHook()
	return hooked or adonisHookCount > 0
end

function AntiBypass.isAdonisHooked()
	return adonisHookCount > 0
end

function AntiBypass.getAdonisStatus()
	return {
		hooked = adonisHookCount > 0,
		count = adonisHookCount,
		detected = adonisDetectedHooked,
		kill = adonisKillHooked,
		namecallShield = _G.__VG_NAMECALL_SHIELD == true,
		hasGetgc = typeof(getgc) == "function",
		hasHookfunction = typeof(hookfunction) == "function",
		hasHiddenGui = usingHiddenGui,
		debugInfoHooked = debugInfoHooked,
	}
end

function AntiBypass.startAdonisWatcher()
	if adonisScanTask then
		return
	end
	adonisScanTask = task.spawn(function()
		task.wait(0.5)
		for i = 1, 8 do
			if adonisWatcherStop then
				return
			end
			local allowDeep = not isLoadPhase() and i >= 6 and not uiBuilding
			AntiBypass.scanAdonis({ deep = allowDeep })
			ensureDebugInfoHook()
			if isFullyHooked() then
				return
			end
			task.wait(i <= 3 and 1.5 or 5)
		end
		if not isLoadPhase() then
			scheduleDeepScan(1)
		end
		while not adonisWatcherStop do
			if isFullyHooked() then
				task.wait(30)
			else
				AntiBypass.scanAdonis({ deep = false })
				ensureDebugInfoHook()
				task.wait(12)
			end
		end
	end)
end

function AntiBypass.onLoadComplete()
	if isLoadPhase() then
		return
	end
	task.defer(function()
		task.wait(0.3)
		if isLoadPhase() or adonisWatcherStop then
			return
		end
		AntiBypass.scanAdonis({ deep = true })
		ensureDebugInfoHook()
		if not isFullyHooked() then
			scheduleDeepScan(1.5)
		end
	end)
end

function AntiBypass.waitForAdonis(timeoutSec)
	timeoutSec = math.min(timeoutSec or 2, 2)
	local deadline = os.clock() + timeoutSec
	repeat
		AntiBypass.scanAdonis({ deep = false })
		ensureDebugInfoHook()
		installIndexKickBypass()
		if isFullyHooked() then
			return true
		end
		task.wait(0.35)
	until os.clock() >= deadline
	if not isLoadPhase() and not isFullyHooked() then
		scheduleDeepScan(0.5)
	end
	return adonisHookCount > 0
end

function AntiBypass.setUiBuilding(active)
	uiBuilding = active == true
end

function AntiBypass.logAdonisDiagnostics(tag, S)
	if not (_G.VG_DEBUG_ADONIS or (S and S.DebugAdonis) or (S and S.LogToFile ~= false)) then
		return
	end
	local st = AntiBypass.getAdonisStatus()
	local early = _G.__VG_EARLY_ADONIS
	local msg = string.format(
		"[VG:%s] hooked=%s count=%d det=%d kill=%d debugInfo=%s namecall=%s hidden=%s uiBuilding=%s loading=%s",
		tostring(tag or "?"),
		tostring(st.hooked),
		st.count,
		st.detected or 0,
		st.kill or 0,
		tostring(st.debugInfoHooked),
		tostring(st.namecallShield),
		tostring(st.hasHiddenGui),
		tostring(uiBuilding),
		tostring(isLoadPhase())
	)
	if early then
		msg ..= string.format(
			" early={det=%d,kill=%d,dbg=%s}",
			early.detected or 0,
			early.kill or 0,
			tostring(early.debugInfo)
		)
	end
	print(msg)
end

local function shouldAllowPlayerKick()
	playerKickAttempts += 1
	if playerKickAttempts > PLAYER_KICK_MAX_BLOCK then
		return true
	end
	if playerKickGraceEnd <= 0 then
		playerKickGraceEnd = os.clock() + PLAYER_KICK_GRACE_SEC
	end
	return os.clock() >= playerKickGraceEnd
end

function AntiBypass.installShield(S)
	if S and S.AntiBypass == false then
		return false
	end

	if not shieldInstalled then
		installNamecallShield()
		installIndexKickBypass()
		installAdonisLogTrigger()

		if typeof(hookfunction) == "function" then
			pcall(function()
				local oldPreload
				local preloadWrap = makeCclosure(function(self, assets, ...)
					if self == ContentProvider and isCoreGuiScan(assets) then
						return
					end
					return oldPreload(self, assets, ...)
				end)
				oldPreload = hookfunction(ContentProvider.PreloadAsync, preloadWrap)
			end)

			local Players = game:GetService("Players")
			local function hookPlayerKick(player)
				if not player or typeof(player.Kick) ~= "function" then
					return
				end
				pcall(function()
					local oldKick
					local kickWrap = makeCclosure(function(self, ...)
						if self == player then
							if shouldAllowPlayerKick() then
								return oldKick(self, ...)
							end
							return
						end
						return oldKick(self, ...)
					end)
					oldKick = hookfunction(player.Kick, kickWrap)
				end)
			end
			local LP = Players.LocalPlayer
			if LP then
				hookPlayerKick(LP)
			end
			Players.PlayerAdded:Connect(hookPlayerKick)
		end

		shieldInstalled = true
	end

	AntiBypass.scanAdonis({ deep = false })
	ensureDebugInfoHook()
	AntiBypass.startAdonisWatcher()
	return true
end

function AntiBypass.Init(S)
	if S.AntiBypass == false then
		return
	end

	if not shieldInstalled then
		AntiBypass.installShield(S)
	end

	local root = AntiBypass.getGuiRoot()
	if not root then
		warn("[Vanguard] Brak gethui — GUI w PlayerGui (wyższe ryzyko kicka 267)")
		return
	end

	if not usingHiddenGui then
		warn("[Vanguard] Brak gethui/protect_gui — w Potassium włącz Hidden UI / filesystem")
	end

	local function sweep(parent)
		for _, ch in ipairs(parent:GetChildren()) do
			if concealed[ch] then
				AntiBypass.bringToFront(ch)
			end
		end
	end

	sweep(root)
	root.ChildAdded:Connect(function(ch)
		task.defer(function()
			if concealed[ch] then
				AntiBypass.bringToFront(ch)
			end
		end)
	end)

	task.spawn(function()
		while S.AntiBypass ~= false and not S.Unloaded do
			if _G.VANGUARD and not _G.VANGUARD.Active then
				break
			end
			if root.Parent then
				sweep(root)
			end
			task.wait(8)
		end
		adonisWatcherStop = true
	end)
end

return AntiBypass
