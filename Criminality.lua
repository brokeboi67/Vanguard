-- Criminality.lua
-- Game-specific features for Criminality (PlaceId 4588604953)
-- Only initialised when the script detects the correct game.

local Criminality = {}

Criminality.PLACE_ID = 4588604953

function Criminality.IsCriminality()
	return game.PlaceId == Criminality.PLACE_ID
end

-- ── helpers ──────────────────────────────────────────────────────────────────

local function getLP()   return game:GetService("Players").LocalPlayer end
local function getRS()   return game:GetService("RunService") end
local function getRepSt() return game:GetService("ReplicatedStorage") end

local function getChar()
	local lp = getLP(); return lp and lp.Character
end
local function getHum()
	local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid"), c
end
local function getHRP()
	local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart"), c
end

-- ── Infinite Stamina ─────────────────────────────────────────────────────────
-- Criminality stores stamina in RepSt.CharStats.[PlayerName] as a NumberValue.
-- We keep it at its MaxValue each RenderStepped frame.

local staminaConn = nil
local staminaObj  = nil

local STAMINA_NAMES = { "Stamina", "stamina", "Sprint", "Energy" }

local function findStaminaObject()
	local lp = getLP(); if not lp then return nil end
	local cs = getRepSt():FindFirstChild("CharStats")
	if cs then
		local ms = cs:FindFirstChild(lp.Name)
		if ms then
			for _, n in ipairs(STAMINA_NAMES) do
				local v = ms:FindFirstChild(n)
				if v and v:IsA("NumberValue") then return v end
			end
		end
	end
	local c = getChar()
	if c then
		for _, n in ipairs(STAMINA_NAMES) do
			local v = c:FindFirstChild(n)
			if v and v:IsA("NumberValue") then return v end
		end
	end
	return nil
end

local function refillStamina()
	if not staminaObj or not staminaObj.Parent then
		staminaObj = findStaminaObject()
	end
	if staminaObj then
		local max = staminaObj.MaxValue > 0 and staminaObj.MaxValue or 100
		if staminaObj.Value < max then
			pcall(function() staminaObj.Value = max end)
		end
	end
	-- Also try LP/char attributes as fallback
	local lp = getLP()
	if lp then
		for _, k in ipairs(STAMINA_NAMES) do
			pcall(function()
				local v = lp:GetAttribute(k)
				if type(v) == "number" and v < 100 then lp:SetAttribute(k, 100) end
			end)
		end
	end
end

local function startInfStamina()
	if staminaConn then return end
	staminaObj = findStaminaObject()
	staminaConn = getRS().Heartbeat:Connect(refillStamina)
end

local function stopInfStamina()
	if staminaConn then staminaConn:Disconnect(); staminaConn = nil end
	staminaObj = nil
end

-- ── No Fall Damage (ForceField method — same as starlight) ───────────────────
-- A hidden (Visible=false) ForceField on the character prevents fall damage.

local noFallConns = {}

local function addForceField(char)
	if not char then return end
	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("ForceField") and not o.Visible then o:Destroy() end
	end
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = char
	-- Keep it hidden if the game tries to remove/show it
	local c = char.ChildAdded:Connect(function(ch)
		if ch:IsA("ForceField") and not ch.Visible then
			task.wait(0.1)
			if ch and ch.Parent then ch.Visible = false end
		end
	end)
	table.insert(noFallConns, c)
end

local function startNoFall()
	if getChar() then addForceField(getChar()) end
	local c = getLP().CharacterAdded:Connect(function(c)
		task.wait(0.5)
		if _G.__VG_S and _G.__VG_S.CrimNoFall then addForceField(c) end
	end)
	table.insert(noFallConns, c)
end

local function stopNoFall()
	for _, c in ipairs(noFallConns) do if c then pcall(c.Disconnect, c) end end
	noFallConns = {}
	local c = getChar()
	if c then
		for _, o in ipairs(c:GetChildren()) do
			if o:IsA("ForceField") and not o.Visible then o:Destroy() end
		end
	end
end

-- ── No Spike Damage ──────────────────────────────────────────────────────────
-- Disables CanTouch on workspace.Filter.Parts.F_Parts so spike traps can't
-- deal damage. Mirrors the toggleNoSpike logic from starlight.

local noSpikeConn = nil

local function disableSpikeParts()
	local ws = workspace
	local ff = ws:FindFirstChild("Filter"); if not ff then return end
	local pf = ff:FindFirstChild("Parts");  if not pf then return end
	local fp = pf:FindFirstChild("F_Parts"); if not fp then return end
	for _, d in ipairs(fp:GetDescendants()) do
		if d:IsA("BasePart") then pcall(function() d.CanTouch = false end) end
	end
	if noSpikeConn then noSpikeConn:Disconnect() end
	noSpikeConn = fp.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then pcall(function() d.CanTouch = false end) end
	end)
end

local function startNoSpike()
	local ws = workspace
	if ws:FindFirstChild("Filter") then
		disableSpikeParts()
	else
		local c; c = ws.ChildAdded:Connect(function(ch)
			if ch.Name == "Filter" then
				task.wait(0.3)
				disableSpikeParts()
				if c then c:Disconnect() end
			end
		end)
	end
end

local function stopNoSpike()
	if noSpikeConn then noSpikeConn:Disconnect(); noSpikeConn = nil end
	local ws = workspace
	local ff = ws:FindFirstChild("Filter")
	if ff then
		local pf = ff:FindFirstChild("Parts")
		if pf then
			local fp = pf:FindFirstChild("F_Parts")
			if fp then
				for _, d in ipairs(fp:GetDescendants()) do
					if d:IsA("BasePart") then pcall(function() d.CanTouch = true end) end
				end
			end
		end
	end
end

-- ── Instant Reload ───────────────────────────────────────────────────────────
-- Criminality weapons store current ammo as a NumberValue or attribute.
-- We keep the active tool's ammo value at its max every Heartbeat.

local instReloadConn = nil

local AMMO_NAMES   = { "Ammo", "ammo", "Magazine", "Mag", "Bullets", "CurrentAmmo" }
local MAXAMMO_NAMES = { "MaxAmmo", "MagSize", "MaxMag", "MaxBullets", "MaxMagazine" }

local function refillAmmo()
	local c = getChar(); if not c then return end
	local tool = c:FindFirstChildOfClass("Tool"); if not tool then return end
	for _, n in ipairs(AMMO_NAMES) do
		local v = tool:FindFirstChild(n)
		if v and v:IsA("NumberValue") then
			local maxV = 0
			for _, mn in ipairs(MAXAMMO_NAMES) do
				local mv = tool:FindFirstChild(mn)
				if mv and mv:IsA("NumberValue") then maxV = mv.Value; break end
			end
			if maxV <= 0 then maxV = 30 end
			if v.Value < maxV then
				pcall(function() v.Value = maxV end)
			end
		end
		-- attribute-based ammo
		pcall(function()
			local av = tool:GetAttribute(n)
			if type(av) == "number" and av < 30 then
				local max = tool:GetAttribute("MaxAmmo") or tool:GetAttribute("MagSize") or 30
				tool:SetAttribute(n, max)
			end
		end)
	end
end

local function startInstReload()
	if instReloadConn then return end
	instReloadConn = getRS().Heartbeat:Connect(refillAmmo)
end

local function stopInstReload()
	if instReloadConn then instReloadConn:Disconnect(); instReloadConn = nil end
end

-- ── Melee Aura ───────────────────────────────────────────────────────────────
-- Finds the melee damage remote (Criminality uses a RemoteEvent in RepSt.Events)
-- and fires it for any player within CrimMeleeRange studs.
-- Falls back to touch-triggering the melee hitbox part if no remote is found.

local meleeConn    = nil
local meleeCooldown = false

local MELEE_REMOTE_NAMES = { "GNX_S", "GNX", "MeleeHit", "Melee", "Punch", "Hit" }

local function findMeleeRemote()
	local ev = getRepSt():FindFirstChild("Events")
	if ev then
		for _, n in ipairs(MELEE_REMOTE_NAMES) do
			local r = ev:FindFirstChild(n)
			if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
				return r
			end
		end
	end
	return nil
end

local function tryMeleeHit(targetChar, range)
	local hrp, myChar = getHRP()
	if not hrp or not myChar then return end
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	local dist = (hrp.Position - targetHRP.Position).Magnitude
	if dist > range then return end

	-- Try remote event first
	local remote = findMeleeRemote()
	if remote and remote:IsA("RemoteEvent") then
		pcall(function() remote:FireServer(targetHRP.Position) end)
		return
	end

	-- Fallback: trigger the tool's activation
	local tool = myChar:FindFirstChildOfClass("Tool")
	if tool then
		local activate = tool:FindFirstChild("Activate") or tool:FindFirstChildOfClass("LocalScript")
		pcall(function()
			tool:Activate()
		end)
	end
end

local function startMeleeAura(S)
	if meleeConn then return end
	meleeConn = getRS().Heartbeat:Connect(function()
		if meleeCooldown then return end
		if not S.CrimMeleeAura then return end
		local range = S.CrimMeleeRange or 12
		local hrp = getHRP()
		if not hrp then return end
		meleeCooldown = true
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			if p ~= getLP() and p.Character then
				local h = p.Character:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					pcall(tryMeleeHit, p.Character, range)
				end
			end
		end
		task.wait(0.15)
		meleeCooldown = false
	end)
end

local function stopMeleeAura()
	if meleeConn then meleeConn:Disconnect(); meleeConn = nil end
end

-- ── Safe / Dealer ESP ────────────────────────────────────────────────────────
-- Highlights safes (workspace.Map.BredMakurz) and dealers (workspace.Map.Shopz)
-- using Roblox Highlight instances, with optional BillboardGui labels.

local safeHighlights   = {}
local dealerHighlights = {}

local function clearHighlights(tbl)
	for _, h in ipairs(tbl) do pcall(function() h:Destroy() end) end
	table.clear(tbl)
end

local function makeHighlight(parent, fillColor, outlineColor, label)
	local h = Instance.new("Highlight")
	h.FillColor       = fillColor or Color3.fromRGB(255, 220, 50)
	h.OutlineColor    = outlineColor or Color3.fromRGB(255, 255, 255)
	h.FillTransparency    = 0.45
	h.OutlineTransparency = 0
	h.DepthMode       = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee         = parent
	h.Parent          = game:GetService("CoreGui") -- avoids game filtering
	pcall(function() h.Parent = game:GetService("Players").LocalPlayer.PlayerGui end)

	if label then
		local bg = Instance.new("BillboardGui")
		bg.Size            = UDim2.new(0, 80, 0, 24)
		bg.StudsOffset     = Vector3.new(0, 4, 0)
		bg.AlwaysOnTop     = true
		bg.Adornee         = parent:FindFirstChildOfClass("BasePart") or parent
		bg.Parent          = h
		local lbl = Instance.new("TextLabel")
		lbl.Size            = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text            = label
		lbl.TextColor3      = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled      = true
		lbl.Font            = Enum.Font.GothamBold
		lbl.Parent          = bg
	end
	return h
end

local function applySafeESP(S)
	clearHighlights(safeHighlights)
	if not S.CrimSafeESP then return end
	local map = workspace:FindFirstChild("Map"); if not map then return end
	local safes = map:FindFirstChild("BredMakurz"); if not safes then return end
	for _, safe in ipairs(safes:GetChildren()) do
		local broken = safe:FindFirstChild("Broken")
		local label  = broken and broken.Value and "OPEN" or "SAFE"
		local color  = broken and broken.Value
			and Color3.fromRGB(100, 255, 100)
			or  (S.CrimSafeColor or Color3.fromRGB(255, 220, 50))
		local h = pcall(makeHighlight, safe, color, Color3.fromRGB(255, 255, 255), label)
		if not h then -- pcall returns bool, actual result is 2nd arg
			local _, hl = pcall(makeHighlight, safe, color, Color3.fromRGB(255, 255, 255), label)
			if hl then table.insert(safeHighlights, hl) end
		end
	end
end

local function applyDealerESP(S)
	clearHighlights(dealerHighlights)
	if not S.CrimDealerESP then return end
	local map = workspace:FindFirstChild("Map"); if not map then return end
	local shops = map:FindFirstChild("Shopz"); if not shops then return end
	for _, shop in ipairs(shops:GetChildren()) do
		local color = S.CrimDealerColor or Color3.fromRGB(100, 200, 255)
		local _, hl = pcall(makeHighlight, shop, color, Color3.fromRGB(255, 255, 255), "DEALER")
		if hl then table.insert(dealerHighlights, hl) end
	end
end

-- Safe/Dealer ESP re-applies every 3 s since safes can be opened/changed
local espUpdateConn = nil

local function startObjectESP(S)
	if espUpdateConn then espUpdateConn:Disconnect() end
	local t = 0
	espUpdateConn = getRS().Heartbeat:Connect(function(dt)
		t = t + dt
		if t < 3 then return end
		t = 0
		if S.CrimSafeESP   then pcall(applySafeESP,   S) end
		if S.CrimDealerESP then pcall(applyDealerESP, S) end
	end)
	pcall(applySafeESP,   S)
	pcall(applyDealerESP, S)
end

local function stopObjectESP()
	if espUpdateConn then espUpdateConn:Disconnect(); espUpdateConn = nil end
	clearHighlights(safeHighlights)
	clearHighlights(dealerHighlights)
end

-- ── Public Init ──────────────────────────────────────────────────────────────
-- Called once from Main.lua after the rest of the script loads.
-- S = the Settings table (live reference).

function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S   -- shared reference used inside callbacks

	local RS = getRS()

	-- Poll each feature every Heartbeat based on the Settings flags.
	-- This keeps things reactive to toggles without needing explicit start/stop calls
	-- from the UI (though the UI can call them too).
	local running = {
		infStamina  = false,
		noFall      = false,
		instReload  = false,
		meleeAura   = false,
		objectESP   = false,
	}

	RS.Heartbeat:Connect(function()
		-- Inf Stamina
		if S.CrimInfStamina and not running.infStamina then
			running.infStamina = true; startInfStamina()
		elseif not S.CrimInfStamina and running.infStamina then
			running.infStamina = false; stopInfStamina()
		end

		-- No Fall Damage
		if S.CrimNoFall and not running.noFall then
			running.noFall = true; pcall(startNoFall)
		elseif not S.CrimNoFall and running.noFall then
			running.noFall = false; pcall(stopNoFall)
		end

		-- No Spike
		if S.CrimNoSpike and not running.noSpike then
			running.noSpike = true; pcall(startNoSpike)
		elseif not S.CrimNoSpike and running.noSpike then
			running.noSpike = false; pcall(stopNoSpike)
		end

		-- Instant Reload
		if S.CrimInstReload and not running.instReload then
			running.instReload = true; startInstReload()
		elseif not S.CrimInstReload and running.instReload then
			running.instReload = false; stopInstReload()
		end

		-- Melee Aura
		if S.CrimMeleeAura and not running.meleeAura then
			running.meleeAura = true; startMeleeAura(S)
		elseif not S.CrimMeleeAura and running.meleeAura then
			running.meleeAura = false; stopMeleeAura()
		end

		-- Object ESP (Safe + Dealer)
		local needESP = S.CrimSafeESP or S.CrimDealerESP
		if needESP and not running.objectESP then
			running.objectESP = true; pcall(startObjectESP, S)
		elseif not needESP and running.objectESP then
			running.objectESP = false; stopObjectESP()
		end
	end)

	-- Apply safe/dealer ESP once immediately if already enabled
	if S.CrimSafeESP or S.CrimDealerESP then
		pcall(startObjectESP, S)
	end
end

return Criminality
