-- Criminality.lua  v2.43.11
-- Game-specific features for Criminality (Universe 1494262959)
-- Covers lobby (4588604953) and Casual (8343259840) via game.GameId.

local Criminality = {}
Criminality.GAME_ID = 1494262959

function Criminality.IsCriminality()
	return game.GameId == Criminality.GAME_ID
end

local RS    = game:GetService("RunService")
local Plrs  = game:GetService("Players")
local RepSt = game:GetService("ReplicatedStorage")

local function getLP()    return Plrs.LocalPlayer end
local function getChar()  local lp=getLP(); return lp and lp.Character end
local function getHum()   local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid"),c end
local function getHRP()   local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart"),c end

-- ── VirtualInputManager ───────────────────────────────────────────────────────
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ────────────────────────────────────────────────────────────────────────────
-- INFINITE STAMINA
-- ────────────────────────────────────────────────────────────────────────────
-- Strategy:
--   1. Search CharStats once (fast, no GetDescendants on PlayerGui).
--   2. Cache result; if not found, retry only every 5 s (not every frame).
--   3. WalkSpeed guard: if stamina depletion slows the humanoid, restore speed.

local staminaConn     = nil
local staminaObjs     = {}
local staminaLastScan = 0
local STAMINA_SCAN_CD = 5   -- seconds between re-scan attempts if nothing found

local STAMINA_NAMES = {
	"Stamina","stamina","STAMINA",
	"Sprint","sprint","SPRINT",
	"Energy","energy","Endurance",
}

local function isStaminaName(n)
	n = n:lower()
	for _, s in ipairs(STAMINA_NAMES) do
		if n:find(s:lower(), 1, true) then return true end
	end
	return false
end

local function scanStamina()
	local found = {}
	local lp = getLP(); if not lp then return found end

	-- ── CharStats (Criminality stores player stats here) ──────────────────
	local cs = RepSt:FindFirstChild("CharStats")
	if cs then
		local ms = cs:FindFirstChild(lp.Name)
		if ms then
			for _, v in ipairs(ms:GetChildren()) do
				if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
					table.insert(found, v)
				end
			end
		end
	end

	-- ── Character children only (NOT GetDescendants — too slow) ──────────
	local c = getChar()
	if c then
		for _, v in ipairs(c:GetChildren()) do
			if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
				table.insert(found, v)
			end
		end
	end

	-- ── LP children ───────────────────────────────────────────────────────
	for _, v in ipairs(lp:GetChildren()) do
		if (v:IsA("NumberValue") or v:IsA("IntValue")) and isStaminaName(v.Name) then
			table.insert(found, v)
		end
	end

	return found
end

local origWalkSpeed = nil

local function refillStamina()
	local now = os.clock()

	-- Re-scan if nothing cached AND cooldown elapsed
	if #staminaObjs == 0 and (now - staminaLastScan) > STAMINA_SCAN_CD then
		staminaLastScan = now
		staminaObjs     = scanStamina()
	end

	-- Max-out found NumberValues
	for i = #staminaObjs, 1, -1 do
		local v = staminaObjs[i]
		if not v or not v.Parent then
			table.remove(staminaObjs, i)
		else
			local max = (v.MaxValue and v.MaxValue > 0) and v.MaxValue or 100
			if v.Value < max then
				pcall(function() v.Value = max end)
			end
		end
	end

	-- ── WalkSpeed guard: counteract any stamina-drain slowdown ────────────
	local hum = getHum()
	if hum then
		if not origWalkSpeed then origWalkSpeed = hum.WalkSpeed end
		-- If game reduced WalkSpeed below the original (stamina drain), restore it
		if origWalkSpeed and hum.WalkSpeed < origWalkSpeed - 0.5 then
			pcall(function() hum.WalkSpeed = origWalkSpeed end)
		end
	end
end

local function startInfStamina()
	if staminaConn then return end
	origWalkSpeed   = nil
	staminaObjs     = scanStamina()
	staminaLastScan = os.clock()
	staminaConn = RS.Heartbeat:Connect(refillStamina)
end

local function stopInfStamina()
	if staminaConn then staminaConn:Disconnect(); staminaConn = nil end
	staminaObjs, origWalkSpeed = {}, nil
end

-- ────────────────────────────────────────────────────────────────────────────
-- NO FALL DAMAGE  (hidden ForceField — starlight method)
-- ────────────────────────────────────────────────────────────────────────────
local noFallConns = {}

local function addForceField(char)
	if not char then return end
	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("ForceField") and not o.Visible then o:Destroy() end
	end
	local ff = Instance.new("ForceField"); ff.Visible = false; ff.Parent = char
	local c = char.ChildAdded:Connect(function(ch)
		if ch:IsA("ForceField") and not ch.Visible then
			task.wait(0.1); if ch and ch.Parent then ch.Visible = false end
		end
	end)
	table.insert(noFallConns, c)
end

local function startNoFall()
	local c = getChar(); if c then addForceField(c) end
	local cc = getLP().CharacterAdded:Connect(function(chr)
		task.wait(0.5)
		if _G.__VG_S and _G.__VG_S.CrimNoFall then addForceField(chr) end
	end)
	table.insert(noFallConns, cc)
end

local function stopNoFall()
	for _, c in ipairs(noFallConns) do pcall(c.Disconnect, c) end
	noFallConns = {}
	local c = getChar()
	if c then
		for _, o in ipairs(c:GetChildren()) do
			if o:IsA("ForceField") and not o.Visible then o:Destroy() end
		end
	end
end

-- ────────────────────────────────────────────────────────────────────────────
-- NO SPIKE DAMAGE
-- ────────────────────────────────────────────────────────────────────────────
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
	if workspace:FindFirstChild("Filter") then disableSpikeParts()
	else
		local c; c = workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "Filter" then task.wait(0.3); disableSpikeParts(); c:Disconnect() end
		end)
	end
end

local function stopNoSpike()
	if noSpikeConn then noSpikeConn:Disconnect(); noSpikeConn = nil end
	local fp = workspace:FindFirstChild("Filter") and
	           workspace.Filter:FindFirstChild("Parts") and
	           workspace.Filter.Parts:FindFirstChild("F_Parts")
	if fp then
		for _, d in ipairs(fp:GetDescendants()) do
			if d:IsA("BasePart") then pcall(function() d.CanTouch = true end) end
		end
	end
end

-- ────────────────────────────────────────────────────────────────────────────
-- INSTANT RELOAD
-- ────────────────────────────────────────────────────────────────────────────
local instReloadConn = nil
local AMMO_NAMES    = {"Ammo","ammo","Magazine","Mag","Bullets","CurrentAmmo","Clip"}
local MAXAMMO_NAMES = {"MaxAmmo","MagSize","MaxMag","MaxBullets","MaxMagazine","MaxClip"}

local function refillAmmo()
	local c = getChar(); if not c then return end
	local tool = c:FindFirstChildOfClass("Tool"); if not tool then return end
	for _, n in ipairs(AMMO_NAMES) do
		local v = tool:FindFirstChild(n)
		if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
			local maxV = 0
			for _, mn in ipairs(MAXAMMO_NAMES) do
				local mv = tool:FindFirstChild(mn)
				if mv and mv:IsA("NumberValue") then maxV = mv.Value; break end
			end
			if maxV <= 0 then maxV = 30 end
			if v.Value < maxV then pcall(function() v.Value = maxV end) end
		end
	end
end

local function startInstReload()
	if instReloadConn then return end
	instReloadConn = RS.Heartbeat:Connect(refillAmmo)
end

local function stopInstReload()
	if instReloadConn then instReloadConn:Disconnect(); instReloadConn = nil end
end

-- ────────────────────────────────────────────────────────────────────────────
-- MELEE AURA
-- ────────────────────────────────────────────────────────────────────────────
-- Uses VirtualInputManager left-click to trigger Tool.Activated naturally.
-- Also faces the target with the camera (not HRP CFrame) to avoid detection.
-- Note: Criminality's melee punch range is ~4-5 studs — set AuraRange ≤ 5
-- for guaranteed hits. Larger ranges show who to focus on.

local meleeConn     = nil
local meleeCooldown = false
local MELEE_CD      = 0.5   -- seconds

local function getClosestInRange(range)
	local hrp = getHRP(); if not hrp then return nil end
	local myPos = hrp.Position
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
	return best
end

local function doMeleeAttack(target)
	if not target or not target.Character then return end
	local eHRP  = target.Character:FindFirstChild("HumanoidRootPart")
	local hrp   = getHRP()
	if not eHRP or not hrp then return end

	-- Face the target (camera-based, less detectable than moving HRP)
	local cam = workspace.CurrentCamera
	pcall(function()
		local dir = eHRP.Position - cam.CFrame.Position
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + dir)
	end)
	-- Also face HRP toward target so hitbox cast hits
	pcall(function()
		hrp.CFrame = CFrame.lookAt(hrp.Position,
			Vector3.new(eHRP.Position.X, hrp.Position.Y, eHRP.Position.Z))
	end)

	-- Simulate left click via VIM (triggers Tool.Activated naturally)
	if VIM then
		pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 0) end)
		task.wait(0.04)
		pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
	else
		-- Fallback: direct Activate
		local c = getChar()
		local tool = c and c:FindFirstChildOfClass("Tool")
		if tool then pcall(function() tool:Activate() end) end
	end
end

local function startMeleeAura(S)
	if meleeConn then return end
	meleeConn = RS.Heartbeat:Connect(function()
		if meleeCooldown or not S.CrimMeleeAura then return end
		local target = getClosestInRange(S.CrimMeleeRange or 5)
		if not target then return end
		meleeCooldown = true
		task.spawn(function()
			pcall(doMeleeAttack, target)
			task.wait(MELEE_CD)
			meleeCooldown = false
		end)
	end)
end

local function stopMeleeAura()
	if meleeConn then meleeConn:Disconnect(); meleeConn = nil end
	meleeCooldown = false
end

-- ────────────────────────────────────────────────────────────────────────────
-- SAFE / DEALER ESP
-- ────────────────────────────────────────────────────────────────────────────
-- Persistent Highlights — created ONCE, NEVER destroyed mid-session.
-- Per-frame: only reads pre-cached BasePart positions + toggles .Enabled.
-- Starts as Enabled=false to prevent the "1-frame flash" bug.

local ESP_ENTRIES   = { safes = {}, dealers = {} }
local espBuilt      = { safes = false, dealers = false }
local espVisConn    = nil

-- Entry format: { highlight=Highlight, billboard=BillboardGui, label=TextLabel,
--                 part=BasePart, broken=BoolValue|nil }

local function getParentGui()
	local lp = getLP()
	return lp and lp:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
end

local function makeEntry(model, fillColor, outlineColor, labelText)
	-- Find a representative BasePart once and cache it
	local part = model:FindFirstChildOfClass("BasePart")
	               or model:FindFirstChildWhichIsA("BasePart")
	if not part then return nil end

	local h = Instance.new("Highlight")
	h.FillColor           = fillColor
	h.OutlineColor        = outlineColor
	h.FillTransparency    = 0.55
	h.OutlineTransparency = 0
	h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee             = model
	h.Enabled             = false   -- start disabled; visibility check will enable
	pcall(function() h.Parent = getParentGui() end)

	local bg, lbl
	local ok = pcall(function()
		bg = Instance.new("BillboardGui")
		bg.Name         = "VG_CrimLbl"
		bg.Size         = UDim2.new(0, 64, 0, 16)
		bg.StudsOffset  = Vector3.new(0, 4, 0)
		bg.AlwaysOnTop  = true
		bg.Enabled      = false
		bg.Adornee      = part
		bg.Parent       = getParentGui()

		lbl = Instance.new("TextLabel")
		lbl.Size                   = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                   = labelText
		lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		lbl.TextSize               = 10
		lbl.Font                   = Enum.Font.GothamBold
		lbl.TextStrokeTransparency = 0.35
		lbl.Parent                 = bg
	end)
	if not ok then bg, lbl = nil, nil end

	return { highlight = h, billboard = bg, label = lbl, part = part }
end

local function clearEntries(tbl)
	for _, e in ipairs(tbl) do
		pcall(function() if e.highlight then e.highlight:Destroy() end end)
		pcall(function() if e.billboard then e.billboard:Destroy() end end)
	end
	table.clear(tbl)
end

local function buildSafeESP(S)
	if espBuilt.safes then return end
	local map   = workspace:FindFirstChild("Map"); if not map then return end
	local safes = map:FindFirstChild("BredMakurz"); if not safes then return end
	local color = S.CrimSafeColor or Color3.fromRGB(255, 220, 50)
	for _, safe in ipairs(safes:GetChildren()) do
		local ok, entry = pcall(makeEntry, safe, color, Color3.fromRGB(255,255,255), "SAFE")
		if ok and entry then
			entry.broken = safe:FindFirstChild("Broken")
			table.insert(ESP_ENTRIES.safes, entry)
		end
	end
	espBuilt.safes = true
end

local function buildDealerESP(S)
	if espBuilt.dealers then return end
	local map   = workspace:FindFirstChild("Map"); if not map then return end
	local shops = map:FindFirstChild("Shopz"); if not shops then return end
	local color = S.CrimDealerColor or Color3.fromRGB(100, 200, 255)
	for _, shop in ipairs(shops:GetChildren()) do
		local ok, entry = pcall(makeEntry, shop, color, Color3.fromRGB(255,255,255), "DEALER")
		if ok and entry then
			table.insert(ESP_ENTRIES.dealers, entry)
		end
	end
	espBuilt.dealers = true
end

-- Per-frame: only distance check + toggle .Enabled (no allocations)
local function updateESPVisibility(S)
	local hrp = getHRP()
	local myPos   = hrp and hrp.Position
	local maxDist = S.CrimESPMaxDist or 300
	local camPos  = workspace.CurrentCamera.CFrame.Position

	-- Safes
	if S.CrimSafeESP then
		for _, e in ipairs(ESP_ENTRIES.safes) do
			local visible = false
			if myPos and e.part and e.part.Parent then
				visible = (camPos - e.part.Position).Magnitude <= maxDist
				-- Dynamic colour for open/closed safes
				if e.broken then
					local open = e.broken.Value
					local fc   = open and Color3.fromRGB(100,255,100)
					             or (S.CrimSafeColor or Color3.fromRGB(255,220,50))
					if e.highlight then
						pcall(function() e.highlight.FillColor = fc end)
					end
					if e.label then
						pcall(function() e.label.Text = open and "OPEN" or "SAFE" end)
					end
				end
			end
			if e.highlight then pcall(function() e.highlight.Enabled = visible end) end
			if e.billboard then pcall(function() e.billboard.Enabled = visible end) end
		end
	else
		for _, e in ipairs(ESP_ENTRIES.safes) do
			if e.highlight then pcall(function() e.highlight.Enabled = false end) end
			if e.billboard then pcall(function() e.billboard.Enabled = false end) end
		end
	end

	-- Dealers
	if S.CrimDealerESP then
		for _, e in ipairs(ESP_ENTRIES.dealers) do
			local visible = false
			if myPos and e.part and e.part.Parent then
				visible = (camPos - e.part.Position).Magnitude <= maxDist
			end
			if e.highlight then pcall(function() e.highlight.Enabled = visible end) end
			if e.billboard then pcall(function() e.billboard.Enabled = visible end) end
		end
	else
		for _, e in ipairs(ESP_ENTRIES.dealers) do
			if e.highlight then pcall(function() e.highlight.Enabled = false end) end
			if e.billboard then pcall(function() e.billboard.Enabled = false end) end
		end
	end
end

local function startObjectESP(S)
	if S.CrimSafeESP   then pcall(buildSafeESP,   S) end
	if S.CrimDealerESP then pcall(buildDealerESP,  S) end
	if espVisConn then return end
	espVisConn = RS.Heartbeat:Connect(function()
		pcall(updateESPVisibility, S)
	end)
end

local function stopObjectESP()
	if espVisConn then espVisConn:Disconnect(); espVisConn = nil end
	clearEntries(ESP_ENTRIES.safes);  espBuilt.safes   = false
	clearEntries(ESP_ENTRIES.dealers); espBuilt.dealers = false
end

-- ────────────────────────────────────────────────────────────────────────────
-- INIT
-- ────────────────────────────────────────────────────────────────────────────
function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S

	local running = {
		infStamina = false, noFall = false, noSpike = false,
		instReload = false, meleeAura = false, objectESP = false,
	}

	-- Lightweight flag-watcher (just compares booleans — zero allocations)
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
			if running.objectESP then pcall(startObjectESP, S) else stopObjectESP() end
		elseif running.objectESP then
			-- Build newly-enabled layer if it wasn't built yet (toggle Safe/Dealer independently)
			if S.CrimSafeESP   and not espBuilt.safes   then pcall(buildSafeESP,   S) end
			if S.CrimDealerESP and not espBuilt.dealers then pcall(buildDealerESP,  S) end
		end
	end)

	-- Apply already-enabled features immediately
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
