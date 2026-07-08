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

	if root then
		usingHiddenGui = tryHiddenGui(gethui) ~= nil
			or tryHiddenGui(get_hidden_gui) ~= nil
			or tryHiddenGui(gethiddengui) ~= nil
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

local function hookDetectedFn(fn)
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
	adonisHookCount += 1
	return true
end

local function hookKillFn(fn)
	if typeof(fn) ~= "function" or hookedKillFns[fn] then
		return false
	end
	hookedKillFns[fn] = true
	if typeof(hookfunction) == "function" then
		pcall(hookfunction, fn, blankKill)
	end
	adonisHookCount += 1
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

local function replaceTableFn(tbl, key, replacement)
	if typeof(tbl) ~= "table" or typeof(key) ~= "string" then
		return
	end
	pcall(function()
		rawset(tbl, key, replacement)
	end)
end

local function tryHookAdonisTable(v, depth)
	if typeof(v) ~= "table" or depth > 3 then
		return false
	end

	local hooked = false
	local hasVars = rawget(v, "Variables") ~= nil or rawget(v, "Logs") ~= nil
	local hasRemote = typeof(rawget(v, "Remote")) == "Instance"

	for _, key in ipairs({ "Detected", "Detect", "detect" }) do
		local det = rawget(v, key)
		if typeof(det) == "function" then
			if hookDetectedFn(det) then
				replaceTableFn(v, key, blankDetected)
				hooked = true
			end
		end
	end

	for _, key in ipairs({ "checkClient", "CheckClient", "Check" }) do
		local chk = rawget(v, key)
		if typeof(chk) == "function" then
			if hookDetectedFn(chk) then
				replaceTableFn(v, key, blankDetected)
				hooked = true
			end
		end
	end

	local kill = rawget(v, "Kill")
	if typeof(kill) == "function" and (hasVars or hasRemote) then
		if hookKillFn(kill) then
			replaceTableFn(v, "Kill", blankKill)
			hooked = true
		end
	end

	local proc = rawget(v, "Process")
	if typeof(proc) == "function" then
		local det = rawget(v, "Detected") or rawget(v, "Detect")
		if typeof(det) == "function" then
			if hookProcessFn(proc) then
				replaceTableFn(v, "Process", blankProcess)
				hooked = true
			end
		end
	end

	for _, key in ipairs({ "Anti", "Client", "AC", "Module", "Main", "Core" }) do
		local sub = rawget(v, key)
		if typeof(sub) == "table" and tryHookAdonisTable(sub, depth + 1) then
			hooked = true
		end
	end

	return hooked
end

local function hookDebugInfoSanity()
	if not adonisDetectedRef or typeof(hookfunction) ~= "function" then
		return
	end
	local renv = typeof(getrenv) == "function" and getrenv() or nil
	if not renv or typeof(renv.debug) ~= "table" or typeof(renv.debug.info) ~= "function" then
		return
	end
	local oldInfo = renv.debug.info
	local wrap = function(levelOrFunc, ...)
		if levelOrFunc == adonisDetectedRef then
			return coroutine.yield(coroutine.running())
		end
		return oldInfo(levelOrFunc, ...)
	end
	if typeof(newcclosure) == "function" then
		wrap = newcclosure(wrap)
	end
	pcall(function()
		hookfunction(renv.debug.info, wrap)
	end)
end

function AntiBypass.scanAdonis()
	if typeof(getgc) ~= "function" then
		return false
	end

	local hooked = false

	withScanIdentity(function()
		for _, v in getgc(true) do
			if tryHookAdonisTable(v, 0) then
				hooked = true
			end
		end
		local ok, loose = pcall(getgc, false)
		if ok and typeof(loose) == "table" then
			for _, v in loose do
				if tryHookAdonisTable(v, 0) then
					hooked = true
				end
			end
		end
	end)

	if hooked and adonisDetectedRef then
		hookDebugInfoSanity()
	end
	return hooked or adonisHookCount > 0
end

function AntiBypass.isAdonisHooked()
	return adonisHookCount > 0
end

function AntiBypass.getAdonisStatus()
	return {
		hooked = adonisHookCount > 0,
		count = adonisHookCount,
		hasGetgc = typeof(getgc) == "function",
		hasHookfunction = typeof(hookfunction) == "function",
		hasHiddenGui = usingHiddenGui,
	}
end

function AntiBypass.startAdonisWatcher()
	if adonisScanTask then
		return
	end
	adonisScanTask = task.spawn(function()
		for _ = 1, 45 do
			if AntiBypass.scanAdonis() then
				break
			end
			task.wait(1)
		end
		while true do
			AntiBypass.scanAdonis()
			task.wait(3)
		end
	end)
end

function AntiBypass.waitForAdonis(timeoutSec)
	timeoutSec = timeoutSec or 12
	local deadline = os.clock() + timeoutSec
	repeat
		if AntiBypass.scanAdonis() then
			return true
		end
		task.wait(0.5)
	until os.clock() >= deadline
	return AntiBypass.scanAdonis()
end

function AntiBypass.installShield(S)
	if S and S.AntiBypass == false then
		return false
	end

	if not shieldInstalled then
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
			local LP = Players.LocalPlayer
			if LP then
				pcall(function()
					local oldKick
					local kickWrap = makeCclosure(function(self, ...)
						if self == LP then
							return
						end
						return oldKick(self, ...)
					end)
					oldKick = hookfunction(LP.Kick, kickWrap)
				end)
			end
		end

		if typeof(hookmetamethod) == "function" then
			pcall(function()
				local LP = game:GetService("Players").LocalPlayer
				local oldNC
				local namecallWrap = makeCclosure(function(self, ...)
					local method = getnamecallmethod and getnamecallmethod() or ""
					if self == ContentProvider and method == "PreloadAsync" then
						local args = { ... }
						if isCoreGuiScan(args[1]) then
							return
						end
					end
					if method == "Kick" and LP and self == LP then
						return
					end
					return oldNC(self, ...)
				end)
				oldNC = hookmetamethod(game, "__namecall", namecallWrap)
			end)
		end

		shieldInstalled = true
	end

	AntiBypass.scanAdonis()
	AntiBypass.startAdonisWatcher()
	return true
end

function AntiBypass.Init(S)
	if S.AntiBypass == false then
		return
	end

	AntiBypass.installShield(S)

	local root = AntiBypass.getGuiRoot()
	if not root then
		warn("[Vanguard] Brak gethui/protect_gui — wysokie ryzyko kicka 267")
		return
	end

	if not usingHiddenGui then
		warn("[Vanguard] gethui niedostępne — używam protect_gui + CoreGui (gorsza ochrona)")
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
			task.wait(2)
		end
	end)
end

return AntiBypass
