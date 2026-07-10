-- Criminality.lua  v2.43.12
-- Game-specific features for Criminality (Universe 1494262959).
-- Architecture: ONE Heartbeat loop for all features + built-in profiler.
-- Profiler writes timing stats to the log file every 30 s.

local Criminality = {}
Criminality.GAME_ID = 1494262959

function Criminality.IsCriminality()
	return game.GameId == Criminality.GAME_ID
end

local RS    = game:GetService("RunService")
local Plrs  = game:GetService("Players")
local RepSt = game:GetService("ReplicatedStorage")

local function getLP()   return Plrs.LocalPlayer end
local function getChar() local lp=getLP(); return lp and lp.Character end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid"),c end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart"),c end

local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ── NO FALL DAMAGE ───────────────────────────────────────────────────────────
local noFallConns = {}

local function addForceField(char)
	if not char then return end
	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("ForceField") and not o.Visible then o:Destroy() end
	end
	local ff = Instance.new("ForceField"); ff.Visible=false; ff.Parent=char
	local c = char.ChildAdded:Connect(function(ch)
		if ch:IsA("ForceField") and not ch.Visible then
			task.wait(0.1); if ch and ch.Parent then ch.Visible=false end
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
	for _, c in ipairs(noFallConns) do pcall(c.Disconnect,c) end; noFallConns={}
	local c=getChar()
	if c then
		for _,o in ipairs(c:GetChildren()) do
			if o:IsA("ForceField") and not o.Visible then o:Destroy() end
		end
	end
end

-- ── NO SPIKE DAMAGE ──────────────────────────────────────────────────────────
local noSpikeConn = nil

local function disableSpikeParts()
	local ff=workspace:FindFirstChild("Filter"); if not ff then return end
	local pf=ff:FindFirstChild("Parts");         if not pf then return end
	local fp=pf:FindFirstChild("F_Parts");        if not fp then return end
	for _,d in ipairs(fp:GetDescendants()) do
		if d:IsA("BasePart") then pcall(function() d.CanTouch=false end) end
	end
	if noSpikeConn then noSpikeConn:Disconnect() end
	noSpikeConn = fp.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then pcall(function() d.CanTouch=false end) end
	end)
end

local function startNoSpike()
	if workspace:FindFirstChild("Filter") then disableSpikeParts()
	else
		local c; c=workspace.ChildAdded:Connect(function(ch)
			if ch.Name=="Filter" then task.wait(0.3); disableSpikeParts(); c:Disconnect() end
		end)
	end
end

local function stopNoSpike()
	if noSpikeConn then noSpikeConn:Disconnect(); noSpikeConn=nil end
	local fp = workspace:FindFirstChild("Filter") and
	           workspace.Filter:FindFirstChild("Parts") and
	           workspace.Filter.Parts:FindFirstChild("F_Parts")
	if fp then
		for _,d in ipairs(fp:GetDescendants()) do
			if d:IsA("BasePart") then pcall(function() d.CanTouch=true end) end
		end
	end
end


-- ── MELEE AURA ───────────────────────────────────────────────────────────────
local meleeCooldown = false
local MELEE_CD      = 0.5

local function getClosestInRange(range)
	local hrp=getHRP(); if not hrp then return nil end
	local myPos=hrp.Position
	local best,bestDist=nil,range
	for _,p in ipairs(Plrs:GetPlayers()) do
		if p~=getLP() and p.Character then
			local h=p.Character:FindFirstChildOfClass("Humanoid")
			if h and h.Health>0 then
				local eHRP=p.Character:FindFirstChild("HumanoidRootPart")
				if eHRP then
					local d=(myPos-eHRP.Position).Magnitude
					if d<bestDist then bestDist=d; best=p end
				end
			end
		end
	end
	return best
end

local function doMeleeAttack(target)
	if not target or not target.Character then return end
	local eHRP=target.Character:FindFirstChild("HumanoidRootPart")
	local hrp=getHRP()
	if not eHRP or not hrp then return end
	-- Face target
	pcall(function()
		hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(eHRP.Position.X,hrp.Position.Y,eHRP.Position.Z))
	end)
	pcall(function()
		local cam=workspace.CurrentCamera
		cam.CFrame=CFrame.lookAt(cam.CFrame.Position,eHRP.Position)
	end)
	-- Simulate click
	if VIM then
		pcall(function() VIM:SendMouseButtonEvent(0,0,0,true, game,0) end)
		task.wait(0.04)
		pcall(function() VIM:SendMouseButtonEvent(0,0,0,false,game,0) end)
	else
		local c=getChar()
		local tool=c and c:FindFirstChildOfClass("Tool")
		if tool then pcall(function() tool:Activate() end) end
	end
end

local function tickMelee(S)
	if meleeCooldown then return end
	local target=getClosestInRange(S.CrimMeleeRange or 5)
	if not target then return end
	meleeCooldown=true
	task.spawn(function()
		pcall(doMeleeAttack,target)
		task.wait(MELEE_CD)
		meleeCooldown=false
	end)
end

-- ── SAFE / DEALER ESP ────────────────────────────────────────────────────────
-- ONE build pass per session. Per-frame: only reads cached .part.Position
-- and sets .Enabled — no allocations, no pcalls on happy path.

local ESP = { safes={}, dealers={} }
local espBuilt = { safes=false, dealers=false }

-- Is the instance still alive? Check Parent without pcall.
local function alive(inst)
	return inst and rawequal(typeof(inst),"Instance") and inst.Parent ~= nil
end

local function getGui()
	local lp=getLP()
	return (lp and lp:FindFirstChild("PlayerGui")) or game:GetService("CoreGui")
end

local function makeEntry(model, fillCol, outlineCol, labelText, brokenVal)
	local part = model:FindFirstChildOfClass("BasePart")
	           or model:FindFirstChildWhichIsA("BasePart")
	if not part then return nil end

	local h = Instance.new("Highlight")
	h.FillColor           = fillCol
	h.OutlineColor        = outlineCol
	h.FillTransparency    = 0.55
	h.OutlineTransparency = 0
	h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee             = model
	h.Enabled             = false   -- start hidden; visibility loop enables
	h.Parent              = getGui()

	local bg  = Instance.new("BillboardGui")
	bg.Size        = UDim2.new(0, 64, 0, 16)
	bg.StudsOffset = Vector3.new(0, 4, 0)
	bg.AlwaysOnTop = true
	bg.Enabled     = false
	bg.Adornee     = part
	bg.Parent      = getGui()

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = labelText
	lbl.TextColor3             = Color3.fromRGB(255,255,255)
	lbl.TextSize               = 10
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.35
	lbl.Parent                 = bg

	return { h=h, bg=bg, lbl=lbl, part=part, model=model, broken=brokenVal,
	         fillCol=fillCol }
end

local function buildSafeESP(S)
	if espBuilt.safes then return end
	local map   = workspace:FindFirstChild("Map"); if not map then return end
	local safes = map:FindFirstChild("BredMakurz"); if not safes then return end
	local color = S.CrimSafeColor or Color3.fromRGB(255,220,50)
	for _, safe in ipairs(safes:GetChildren()) do
		local ok, entry = pcall(makeEntry, safe, color, Color3.fromRGB(255,255,255),
		                        "SAFE", safe:FindFirstChild("Broken"))
		if ok and entry then table.insert(ESP.safes, entry) end
	end
	espBuilt.safes = true
end

local function buildDealerESP(S)
	if espBuilt.dealers then return end
	local map   = workspace:FindFirstChild("Map"); if not map then return end
	local shops = map:FindFirstChild("Shopz"); if not shops then return end
	local color = S.CrimDealerColor or Color3.fromRGB(100,200,255)
	for _, shop in ipairs(shops:GetChildren()) do
		local ok, entry = pcall(makeEntry, shop, color, Color3.fromRGB(255,255,255), "DEALER", nil)
		if ok and entry then table.insert(ESP.dealers, entry) end
	end
	espBuilt.dealers = true
end

local function clearESP(tbl)
	for _,e in ipairs(tbl) do
		if alive(e.h)  then e.h:Destroy()  end
		if alive(e.bg) then e.bg:Destroy() end
	end
	table.clear(tbl)
end

-- Hot path: zero allocations, no pcall on happy path.
local colOpen   = Color3.fromRGB(100,255,100)
local colSafeD  = Color3.fromRGB(255,220,50)

local function tickESP(S)
	local maxDist = S.CrimESPMaxDist or 300
	local camPos  = workspace.CurrentCamera.CFrame.Position

	-- Safes
	local showSafe = S.CrimSafeESP
	for _, e in ipairs(ESP.safes) do
		local vis = false
		if showSafe and alive(e.part) then
			vis = (camPos - e.part.Position).Magnitude <= maxDist
		end
		if alive(e.h) then
			if vis then
				-- Update colour for open/closed state (direct, no pcall)
				local open   = e.broken and e.broken.Value
				local newCol = open and colOpen or (S.CrimSafeColor or colSafeD)
				if e.h.FillColor ~= newCol then e.h.FillColor = newCol end
				local newTxt = open and "OPEN" or "SAFE"
				if e.lbl.Text ~= newTxt then e.lbl.Text = newTxt end
				if not e.h.Enabled  then e.h.Enabled  = true end
				if not e.bg.Enabled then e.bg.Enabled = true end
			else
				if e.h.Enabled  then e.h.Enabled  = false end
				if e.bg.Enabled then e.bg.Enabled = false end
			end
		end
	end

	-- Dealers
	local showDlr = S.CrimDealerESP
	for _, e in ipairs(ESP.dealers) do
		local vis = false
		if showDlr and alive(e.part) then
			vis = (camPos - e.part.Position).Magnitude <= maxDist
		end
		if alive(e.h) then
			if vis then
				if not e.h.Enabled  then e.h.Enabled  = true end
				if not e.bg.Enabled then e.bg.Enabled = true end
			else
				if e.h.Enabled  then e.h.Enabled  = false end
				if e.bg.Enabled then e.bg.Enabled = false end
			end
		end
	end
end

-- ── MASTER HEARTBEAT ─────────────────────────────────────────────────────────
-- Single connection instead of 5 separate ones = less scheduler overhead.

local masterConn = nil
local crimFrame  = 0

local function startMaster(S)
	if masterConn then return end

	local espInitTick = false
	local running = { noFall = false, noSpike = false }

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	masterConn = RS.Heartbeat:Connect(perfWrap("Criminality.Main", function()
		crimFrame = crimFrame + 1

		if S.CrimNoFall ~= running.noFall then
			running.noFall = S.CrimNoFall
			if running.noFall then pcall(startNoFall) else pcall(stopNoFall) end
		end
		if S.CrimNoSpike ~= running.noSpike then
			running.noSpike = S.CrimNoSpike
			if running.noSpike then pcall(startNoSpike) else pcall(stopNoSpike) end
		end
		if S.CrimSafeESP and not espBuilt.safes and workspace:FindFirstChild("Map") then
			pcall(buildSafeESP, S)
		end
		if S.CrimDealerESP and not espBuilt.dealers and workspace:FindFirstChild("Map") then
			pcall(buildDealerESP, S)
		end

		if (S.CrimSafeESP or S.CrimDealerESP) and not espInitTick then
			espInitTick = true
			task.spawn(function()
				local deadline = os.clock() + 10
				while os.clock() < deadline do
					if workspace:FindFirstChild("Map") then break end
					task.wait(0.5)
				end
				if S.CrimSafeESP   then pcall(buildSafeESP,   S) end
				if S.CrimDealerESP then pcall(buildDealerESP,  S) end
			end)
		end

		if S.CrimMeleeAura then
			tickMelee(S)
		end

		if (S.CrimSafeESP or S.CrimDealerESP) and crimFrame % 2 == 0 then
			tickESP(S)
		end
	end))
end

local function stopMaster()
	if masterConn then masterConn:Disconnect(); masterConn=nil end
end

-- ── INIT ─────────────────────────────────────────────────────────────────────
function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S

	startMaster(S)

	if S.CrimNoFall then pcall(startNoFall) end
	if S.CrimNoSpike then pcall(startNoSpike) end
end

return Criminality
