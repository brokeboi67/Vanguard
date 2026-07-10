-- Criminality.lua
-- Game-specific features for Criminality (GameId/Universe 1494262959)
-- Matches ALL places in the Criminality universe: lobby (4588604953),
-- Casual server (8343259840), and any future sub-places.

local Criminality = {}

Criminality.GAME_ID = 1494262959   -- Universe ID — same in lobby AND Casual

function Criminality.IsCriminality()
	return game.GameId == Criminality.GAME_ID
end

-- ── services ──────────────────────────────────────────────────────────────────

local RS     = game:GetService("RunService")
local UIS    = game:GetService("UserInputService")
local Plrs   = game:GetService("Players")
local RepSt  = game:GetService("ReplicatedStorage")

local function getLP()   return Plrs.LocalPlayer end
local function getChar() local lp = getLP(); return lp and lp.Character end
local function getHum()  local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid"), c end
local function getHRP()  local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart"), c end

-- ── VirtualInputManager (for simulating input) ────────────────────────────────
local VIM = pcall(function()
	return game:GetService("VirtualInputManager")
end) and game:GetService("VirtualInputManager")

-- ── Infinite Stamina ─────────────────────────────────────────────────────────
-- Multi-path approach: CharStats (primary) → character descendants → attributes → GC scan

local staminaConn = nil
local staminaObjs = {}   -- list of all found stamina-like NumberValues to keep maxed

local STAMINA_NAMES = { "Stamina", "stamina", "Sprint", "sprint", "Energy", "energy",
                        "Endurance", "Run", "Stam", "Spd", "STAMINA", "SPRINT" }

local function isStaminaName(name)
	local low = name:lower()
	for _, n in ipairs(STAMINA_NAMES) do
		if low:find(n:lower(), 1, true) then return true end
	end
	return false
end

local function collectStaminaObjects()
	local found = {}
	local lp = getLP()
	if not lp then return found end

	-- 1. RepSt.CharStats.[PlayerName] — all NumberValues / IntValues
	local cs = RepSt:FindFirstChild("CharStats")
	if cs then
		local ms = cs:FindFirstChild(lp.Name)
		if ms then
			for _, v in ipairs(ms:GetDescendants()) do
				if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
					table.insert(found, v)
				end
			end
			-- Also grab anything between 0-100 whose name suggests stamina
			for _, v in ipairs(ms:GetChildren()) do
				if (v:IsA("NumberValue") or v:IsA("IntValue"))
				   and v.Value >= 0 and v.Value <= 100
				   and isStaminaName(v.Name) then
					table.insert(found, v)
				end
			end
		end
	end

	-- 2. Character descendants
	local c = getChar()
	if c then
		for _, v in ipairs(c:GetDescendants()) do
			if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
				table.insert(found, v)
			end
		end
	end

	-- 3. PlayerGui — some games bind stamina to a UI value
	local pg = lp:FindFirstChild("PlayerGui")
	if pg then
		for _, v in ipairs(pg:GetDescendants()) do
			if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
				table.insert(found, v)
			end
		end
	end

	-- 4. LP itself
	for _, v in ipairs(lp:GetChildren()) do
		if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
			table.insert(found, v)
		end
	end

	-- Deduplicate
	local seen, deduped = {}, {}
	for _, v in ipairs(found) do
		if not seen[v] then seen[v] = true; table.insert(deduped, v) end
	end
	return deduped
end

local function refillStamina()
	-- Re-collect if list is empty or objects got destroyed
	if #staminaObjs == 0 then
		staminaObjs = collectStaminaObjects()
	end

	for i = #staminaObjs, 1, -1 do
		local v = staminaObjs[i]
		if not v or not v.Parent then
			table.remove(staminaObjs, i)
		else
			local max = v.MaxValue ~= 0 and v.MaxValue or 100
			if v.Value < max then
				pcall(function() v.Value = max end)
			end
		end
	end

	-- Also keep LP attributes maxed
	local lp = getLP()
	if lp then
		for _, n in ipairs(STAMINA_NAMES) do
			pcall(function()
				local v = lp:GetAttribute(n)
				if type(v) == "number" and v < 100 then
					lp:SetAttribute(n, 100)
				end
			end)
		end
	end

	-- Keep humanoid WalkSpeed at normal to counteract stamina-drain slowing
	local hum = getHum()
	if hum then
		pcall(function()
			if hum.WalkSpeed < 14 and hum.WalkSpeed > 0 then
				hum.WalkSpeed = 16
			end
		end)
	end
end

local function startInfStamina()
	if staminaConn then return end
	staminaObjs = collectStaminaObjects()
	staminaConn = RS.Heartbeat:Connect(refillStamina)
end

local function stopInfStamina()
	if staminaConn then staminaConn:Disconnect(); staminaConn = nil end
	staminaObjs = {}
end

-- ── No Fall Damage (ForceField method — same as starlight) ───────────────────

local noFallConns = {}

local function addForceField(char)
	if not char then return end
	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("ForceField") and not o.Visible then o:Destroy() end
	end
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = char
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
	if workspace:FindFirstChild("Filter") then
		disableSpikeParts()
	else
		local c; c = workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "Filter" then
				task.wait(0.3); disableSpikeParts(); if c then c:Disconnect() end
			end
		end)
	end
end

local function stopNoSpike()
	if noSpikeConn then noSpikeConn:Disconnect(); noSpikeConn = nil end
	local ff = workspace:FindFirstChild("Filter")
	if ff then
		local pf = ff:FindFirstChild("Parts")
		local fp = pf and pf:FindFirstChild("F_Parts")
		if fp then
			for _, d in ipairs(fp:GetDescendants()) do
				if d:IsA("BasePart") then pcall(function() d.CanTouch = true end) end
			end
		end
	end
end

-- ── Instant Reload ───────────────────────────────────────────────────────────

local instReloadConn = nil
local AMMO_NAMES     = { "Ammo", "ammo", "Magazine", "Mag", "Bullets", "CurrentAmmo", "Clip" }
local MAXAMMO_NAMES  = { "MaxAmmo", "MagSize", "MaxMag", "MaxBullets", "MaxMagazine", "MaxClip" }

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
			if v.Value < maxV then pcall(function() v.Value = maxV end) end
		end
		pcall(function()
			local av = tool:GetAttribute(n)
			if type(av) == "number" then
				local max = tool:GetAttribute("MaxAmmo") or tool:GetAttribute("MagSize") or 30
				if av < max then tool:SetAttribute(n, max) end
			end
		end)
	end
end

local function startInstReload()
	if instReloadConn then return end
	instReloadConn = RS.Heartbeat:Connect(refillAmmo)
end

local function stopInstReload()
	if instReloadConn then instReloadConn:Disconnect(); instReloadConn = nil end
end

-- ── Melee Aura ───────────────────────────────────────────────────────────────
-- Approach:
--   1. Rotate HRP toward the closest target in range.
--   2. Simulate a left-click via VirtualInputManager → triggers Tool.Activated
--      → game's LocalScript fires the melee remote naturally (no hardcoded names).
--   3. Fallback: call Tool:Activate() directly.
-- Cooldown = 0.4 s (typical Criminality punch cooldown).

local meleeConn  = nil
local meleeCooldown = false
local MELEE_CD   = 0.45   -- seconds between auto-punches

local function getClosestInRange(range)
	local hrp = getHRP()
	if not hrp then return nil end
	local myPos  = hrp.Position
	local best, bestDist = nil, range
	for _, p in ipairs(Plrs:GetPlayers()) do
		if p ~= getLP() and p.Character then
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				local eHRP = p.Character:FindFirstChild("HumanoidRootPart")
				if eHRP then
					local d = (myPos - eHRP.Position).Magnitude
					if d < bestDist then bestDist = d; best = p end
				end
			end
		end
	end
	return best, bestDist
end

local function doMeleeAttack(targetChar)
	-- 1. Briefly face the target
	local hrp = getHRP()
	if hrp and targetChar then
		local eHRP = targetChar:FindFirstChild("HumanoidRootPart")
		if eHRP then
			pcall(function()
				hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(eHRP.Position.X, hrp.Position.Y, eHRP.Position.Z))
			end)
		end
	end

	-- 2. Simulate left mouse click (triggers Tool.Activated naturally)
	if VIM then
		pcall(function()
			VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		end)
		task.wait(0.05)
		pcall(function()
			VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
		return
	end

	-- 3. Fallback: Tool:Activate()
	local c = getChar()
	if c then
		local tool = c:FindFirstChildOfClass("Tool")
		if tool then
			pcall(function() tool:Activate() end)
		end
	end
end

local function startMeleeAura(S)
	if meleeConn then return end
	meleeConn = RS.Heartbeat:Connect(function()
		if meleeCooldown or not S.CrimMeleeAura then return end
		local range = S.CrimMeleeRange or 12
		local target, _ = getClosestInRange(range)
		if not target then return end
		meleeCooldown = true
		pcall(doMeleeAttack, target.Character)
		task.delay(MELEE_CD, function() meleeCooldown = false end)
	end)
end

local function stopMeleeAura()
	if meleeConn then meleeConn:Disconnect(); meleeConn = nil end
	meleeCooldown = false
end

-- ── Safe / Dealer ESP ────────────────────────────────────────────────────────
-- Persistent Highlight instances — NEVER destroyed and recreated each tick.
-- Only added/removed when the safe/shop list actually changes.
-- Labels are small fixed-size BillboardGuis, hidden when too far away.

local CRIM_ESP = {
	safes   = {},   -- { model=Model, highlight=Highlight, billboard=BillboardGui, label=TextLabel }
	dealers = {},
}

local function getParentGui()
	local lp = getLP()
	return lp and lp:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
end

local function makePersistentHighlight(model, fillColor, outlineColor, labelText)
	local h = Instance.new("Highlight")
	h.Name               = "VG_CrimESP"
	h.FillColor          = fillColor
	h.OutlineColor       = outlineColor
	h.FillTransparency   = 0.55
	h.OutlineTransparency = 0
	h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee            = model
	pcall(function() h.Parent = getParentGui() end)

	-- Small, non-scaled label
	local adornPart = model:FindFirstChildOfClass("BasePart") or model:FindFirstChildWhichIsA("BasePart")
	local bg, lbl
	if adornPart then
		bg = Instance.new("BillboardGui")
		bg.Name           = "VG_CrimESPLabel"
		bg.Size           = UDim2.new(0, 60, 0, 18)
		bg.StudsOffset    = Vector3.new(0, 3.5, 0)
		bg.AlwaysOnTop    = true
		bg.MaxDistance    = 0   -- we control visibility manually
		bg.Adornee        = adornPart
		pcall(function() bg.Parent = getParentGui() end)

		lbl = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                  = labelText
		lbl.TextColor3            = Color3.fromRGB(255, 255, 255)
		lbl.TextSize              = 10
		lbl.Font                  = Enum.Font.GothamBold
		lbl.TextStrokeTransparency = 0.4
		lbl.Parent                = bg
	end

	return h, bg, lbl
end

local function clearESPTable(tbl)
	for _, entry in ipairs(tbl) do
		pcall(function() if entry.highlight then entry.highlight:Destroy() end end)
		pcall(function() if entry.billboard then entry.billboard:Destroy() end end)
	end
	table.clear(tbl)
end

local function buildSafeESP(S)
	clearESPTable(CRIM_ESP.safes)
	local map = workspace:FindFirstChild("Map"); if not map then return end
	local safes = map:FindFirstChild("BredMakurz"); if not safes then return end
	local color = S.CrimSafeColor or Color3.fromRGB(255, 220, 50)
	for _, safe in ipairs(safes:GetChildren()) do
		local broken = safe:FindFirstChild("Broken")
		local isOpen = broken and broken.Value
		local label  = isOpen and "OPEN" or "SAFE"
		local fc     = isOpen and Color3.fromRGB(100, 255, 100) or color
		local h, bg, lbl = pcall(makePersistentHighlight, safe, fc, Color3.fromRGB(255,255,255), label)
		if not h then
			_, h, bg, lbl = true, pcall(makePersistentHighlight, safe, fc, Color3.fromRGB(255,255,255), label)
		end
		-- pcall returns (ok, ...) — unwrap properly
		local ok1, h2, bg2, lbl2 = pcall(makePersistentHighlight, safe, fc, Color3.fromRGB(255,255,255), label)
		if ok1 then
			table.insert(CRIM_ESP.safes, { model=safe, highlight=h2, billboard=bg2, label=lbl2, broken=broken })
		end
	end
end

local function buildDealerESP(S)
	clearESPTable(CRIM_ESP.dealers)
	local map = workspace:FindFirstChild("Map"); if not map then return end
	local shops = map:FindFirstChild("Shopz"); if not shops then return end
	local color = S.CrimDealerColor or Color3.fromRGB(100, 200, 255)
	for _, shop in ipairs(shops:GetChildren()) do
		local ok, h, bg, lbl = pcall(makePersistentHighlight, shop, color, Color3.fromRGB(255,255,255), "DEALER")
		if ok then
			table.insert(CRIM_ESP.dealers, { model=shop, highlight=h, billboard=bg, label=lbl })
		end
	end
end

-- Called every frame: updates visibility (distance check) + label colours for safes
local function updateESPVisibility(S)
	local hrp = getHRP()
	local myPos = hrp and hrp.Position
	local maxDist = S.CrimESPMaxDist or 300

	-- Safes
	for _, entry in ipairs(CRIM_ESP.safes) do
		local visible = false
		if myPos and entry.model and entry.model.Parent then
			local part = entry.model:FindFirstChildOfClass("BasePart")
			local dist = part and (myPos - part.Position).Magnitude or math.huge
			visible = dist <= maxDist

			-- Update colour dynamically based on Broken state
			if entry.broken then
				local isOpen = entry.broken.Value
				local newColor = isOpen and Color3.fromRGB(100, 255, 100)
				               or (S.CrimSafeColor or Color3.fromRGB(255, 220, 50))
				local newLabel = isOpen and "OPEN" or "SAFE"
				if entry.highlight then
					pcall(function() entry.highlight.FillColor = newColor end)
				end
				if entry.label then
					pcall(function() entry.label.Text = newLabel end)
				end
			end
		end

		if entry.highlight  then pcall(function() entry.highlight.Enabled = visible end) end
		if entry.billboard  then pcall(function() entry.billboard.Enabled = visible end) end
	end

	-- Dealers
	for _, entry in ipairs(CRIM_ESP.dealers) do
		local visible = false
		if myPos and entry.model and entry.model.Parent then
			local part = entry.model:FindFirstChildOfClass("BasePart")
			local dist = part and (myPos - part.Position).Magnitude or math.huge
			visible = dist <= maxDist
		end
		if entry.highlight then pcall(function() entry.highlight.Enabled = visible end) end
		if entry.billboard then pcall(function() entry.billboard.Enabled = visible end) end
	end
end

local espVisConn  = nil   -- per-frame visibility updater
local espBuilt    = false -- whether highlights have been created at least once

local function startObjectESP(S)
	-- Build once (highlights persist — no more destroy+recreate loop!)
	if not espBuilt then
		if S.CrimSafeESP   then pcall(buildSafeESP,   S) end
		if S.CrimDealerESP then pcall(buildDealerESP, S) end
		espBuilt = true
	end
	-- Lightweight per-frame visibility update (just toggles .Enabled, no new instances)
	if not espVisConn then
		espVisConn = RS.Heartbeat:Connect(function()
			if S.CrimSafeESP or S.CrimDealerESP then
				pcall(updateESPVisibility, S)
			end
		end)
	end
end

local function stopObjectESP()
	if espVisConn then espVisConn:Disconnect(); espVisConn = nil end
	clearESPTable(CRIM_ESP.safes)
	clearESPTable(CRIM_ESP.dealers)
	espBuilt = false
end

-- Rebuild ESP when settings toggle (e.g. SafeESP was off, now turned on)
local function refreshESPIfNeeded(S)
	local needSafe   = S.CrimSafeESP
	local needDealer = S.CrimDealerESP
	local hasSafe    = #CRIM_ESP.safes   > 0
	local hasDealer  = #CRIM_ESP.dealers > 0

	if needSafe   and not hasSafe   then pcall(buildSafeESP,   S) end
	if needDealer and not hasDealer then pcall(buildDealerESP, S) end
	if not needSafe   and hasSafe   then clearESPTable(CRIM_ESP.safes) end
	if not needDealer and hasDealer then clearESPTable(CRIM_ESP.dealers) end
end

-- ── Public Init ──────────────────────────────────────────────────────────────

function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S

	local running = {
		infStamina = false,
		noFall     = false,
		noSpike    = false,
		instReload = false,
		meleeAura  = false,
		objectESP  = false,
	}

	-- Lightweight flag-watcher — starts/stops features on toggle
	RS.Heartbeat:Connect(function()
		if S.CrimInfStamina ~= running.infStamina then
			running.infStamina = S.CrimInfStamina
			if running.infStamina then startInfStamina() else stopInfStamina() end
		end

		if S.CrimNoFall ~= running.noFall then
			running.noFall = S.CrimNoFall
			if running.noFall then pcall(startNoFall) else pcall(stopNoFall) end
		end

		if S.CrimNoSpike ~= running.noSpike then
			running.noSpike = S.CrimNoSpike
			if running.noSpike then pcall(startNoSpike) else pcall(stopNoSpike) end
		end

		if S.CrimInstReload ~= running.instReload then
			running.instReload = S.CrimInstReload
			if running.instReload then startInstReload() else stopInstReload() end
		end

		if S.CrimMeleeAura ~= running.meleeAura then
			running.meleeAura = S.CrimMeleeAura
			if running.meleeAura then startMeleeAura(S) else stopMeleeAura() end
		end

		local needESP = S.CrimSafeESP or S.CrimDealerESP
		if needESP ~= running.objectESP then
			running.objectESP = needESP
			if running.objectESP then
				pcall(startObjectESP, S)
			else
				stopObjectESP()
			end
		end

		-- Refresh if individual toggle changed while ESP is running
		if running.objectESP then
			pcall(refreshESPIfNeeded, S)
		end
	end)

	-- Apply immediately for any already-enabled features
	if S.CrimInfStamina then running.infStamina = true; startInfStamina() end
	if S.CrimNoFall     then running.noFall     = true; pcall(startNoFall) end
	if S.CrimNoSpike    then running.noSpike    = true; pcall(startNoSpike) end
	if S.CrimInstReload then running.instReload = true; startInstReload() end
	if S.CrimMeleeAura  then running.meleeAura  = true; startMeleeAura(S) end
	if S.CrimSafeESP or S.CrimDealerESP then
		running.objectESP = true; pcall(startObjectESP, S)
	end
end

return Criminality
