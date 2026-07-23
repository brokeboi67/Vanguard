-- Criminality.lua  v2.59.1
-- Game-specific features for Criminality (Universe 1494262959).
-- Architecture: ONE Heartbeat loop for all features + built-in profiler.
-- Profiler writes timing stats to the log file every 30 s.
-- NOTE: many small state vars are packed into shared tables (COLORS, misc,
-- crateWatch, gunWatch, staff, door, melee, moneyPu, cratePu, ...) purely to
-- stay under Luau's 200-local-register limit for the main chunk.
-- v2.59.1: pack Gun ESP helpers into gunWatch (fix 200-local compile blow).

local Criminality = {}
Criminality.GAME_ID = 1494262959

function Criminality.IsCriminality()
	return game.GameId == Criminality.GAME_ID
end

local RS    = game:GetService("RunService")
local Plrs  = game:GetService("Players")
local RepSt = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TS    = game:GetService("TweenService")

local function getLP()   return Plrs.LocalPlayer end
local function getChar() local lp=getLP(); return lp and lp.Character end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid"),c end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart"),c end

local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local UIS; pcall(function() UIS = game:GetService("UserInputService") end)

-- â”€â”€ NO FALL DAMAGE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into one table to stay under Luau's 200-local limit.
local misc = { noFallConns = {}, noSpikeConn = nil, smoke = { conns = {}, active = false, hooked = {}, recent = 0, windowAt = 0, pausedUntil = 0 } }

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
	table.insert(misc.noFallConns, c)
end

local function startNoFall()
	local c = getChar(); if c then addForceField(c) end
	local cc = getLP().CharacterAdded:Connect(function(chr)
		task.wait(0.5)
		if _G.__VG_S and _G.__VG_S.CrimNoFall then addForceField(chr) end
	end)
	table.insert(misc.noFallConns, cc)
end

local function stopNoFall()
	for _, c in ipairs(misc.noFallConns) do pcall(c.Disconnect,c) end; misc.noFallConns={}
	local c=getChar()
	if c then
		for _,o in ipairs(c:GetChildren()) do
			if o:IsA("ForceField") and not o.Visible then o:Destroy() end
		end
	end
end

-- â”€â”€ NO SPIKE DAMAGE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local function disableSpikeParts()
	local ff=workspace:FindFirstChild("Filter"); if not ff then return end
	local pf=ff:FindFirstChild("Parts");         if not pf then return end
	local fp=pf:FindFirstChild("F_Parts");        if not fp then return end
	for _,d in ipairs(fp:GetDescendants()) do
		if d:IsA("BasePart") then pcall(function() d.CanTouch=false end) end
	end
	if misc.noSpikeConn then misc.noSpikeConn:Disconnect() end
	misc.noSpikeConn = fp.DescendantAdded:Connect(function(d)
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
	if misc.noSpikeConn then misc.noSpikeConn:Disconnect(); misc.noSpikeConn=nil end
	local fp = workspace:FindFirstChild("Filter") and
	           workspace.Filter:FindFirstChild("Parts") and
	           workspace.Filter.Parts:FindFirstChild("F_Parts")
	if fp then
		for _,d in ipairs(fp:GetDescendants()) do
			if d:IsA("BasePart") then pcall(function() d.CanTouch=true end) end
		end
	end
end

-- ── REMOVE smoke FX (Debris.SmokeExplosion + PlayerGui SmokeScreenGUI) ───────
-- Opt: shallow GetChildren + ChildAdded only. Rate-limit destroys to avoid recreate storms.
local function smokeClearConns()
	for _, c in ipairs(misc.smoke.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(misc.smoke.conns)
	if misc.smoke.hooked then
		table.clear(misc.smoke.hooked)
	end
end

local function smokeAddConn(conn)
	table.insert(misc.smoke.conns, conn)
end

local function smokeDestroy(inst)
	if not inst or not inst.Parent then
		return
	end
	local sm = misc.smoke
	local now = os.clock()
	if now < (sm.pausedUntil or 0) then
		return
	end
	if now - (sm.windowAt or 0) > 1 then
		sm.windowAt = now
		sm.recent = 0
	end
	sm.recent = (sm.recent or 0) + 1
	-- Game may recreate SmokeScreenGUI every frame — don't fight forever
	if sm.recent > 35 then
		sm.pausedUntil = now + 2.5
		sm.recent = 0
		return
	end
	pcall(function()
		if inst:IsA("ScreenGui") or inst:IsA("LayerCollector") then
			inst.Enabled = false
		end
		inst:Destroy()
	end)
end

local function smokeSweepChildren(folder, name)
	if not folder then
		return
	end
	for _, ch in ipairs(folder:GetChildren()) do
		if ch.Name == name then
			smokeDestroy(ch)
		end
	end
end

local function smokeHookName(folder, name)
	if not folder then
		return
	end
	local sm = misc.smoke
	sm.hooked = sm.hooked or {}
	local key = folder
	if sm.hooked[key] and sm.hooked[key][name] then
		return
	end
	sm.hooked[key] = sm.hooked[key] or {}
	sm.hooked[key][name] = true
	smokeAddConn(folder.ChildAdded:Connect(function(ch)
		if ch.Name == name then
			task.defer(smokeDestroy, ch)
		end
	end))
end

local function smokeHookGui(pg)
	if not pg then
		return
	end
	smokeSweepChildren(pg, "SmokeScreenGUI")
	smokeHookName(pg, "SmokeScreenGUI")
	local core = pg:FindFirstChild("CoreGUI")
	if core then
		smokeSweepChildren(core, "SmokeScreenGUI")
		smokeHookName(core, "SmokeScreenGUI")
	end
	smokeAddConn(pg.ChildAdded:Connect(function(ch)
		if ch.Name == "CoreGUI" then
			smokeSweepChildren(ch, "SmokeScreenGUI")
			smokeHookName(ch, "SmokeScreenGUI")
		end
	end))
end

local function smokeHookDebris(folder)
	smokeSweepChildren(folder, "SmokeExplosion")
	smokeHookName(folder, "SmokeExplosion")
end

local function startRemoveSmokeExplosion()
	if misc.smoke.active then
		return
	end
	misc.smoke.active = true
	misc.smoke.recent = 0
	misc.smoke.windowAt = 0
	misc.smoke.pausedUntil = 0
	smokeClearConns()

	local debris = workspace:FindFirstChild("Debris")
	if debris then
		smokeHookDebris(debris)
	else
		smokeAddConn(workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "Debris" then
				smokeHookDebris(ch)
			end
		end))
	end

	local lp = getLP()
	if lp then
		local pg = lp:FindFirstChild("PlayerGui")
		if pg then
			smokeHookGui(pg)
		else
			smokeAddConn(lp.ChildAdded:Connect(function(ch)
				if ch.Name == "PlayerGui" or ch:IsA("PlayerGui") then
					smokeHookGui(ch)
				end
			end))
		end
	end
end

local function stopRemoveSmokeExplosion()
	smokeClearConns()
	misc.smoke.active = false
end

-- ── NO RAGDOLL (CharStats NoRagdoll/RagdollTime + client PlatformStand cancel) ──
misc.noRagdoll = { conns = {}, charConns = {}, statsConns = {}, saved = {} }

function misc.clearNoRagdollChar()
	for _, c in ipairs(misc.noRagdoll.charConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.noRagdoll.charConns = {}
end

function misc.noRagdoll.clearStatsConns()
	for _, c in ipairs(misc.noRagdoll.statsConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.noRagdoll.statsConns = {}
end

function misc.noRagdoll.getStatsFolder()
	local lp = getLP()
	if not lp then
		return nil
	end
	local root = RepSt:FindFirstChild("CharStats")
	if not root then
		return nil
	end
	return root:FindFirstChild(lp.Name)
end

function misc.noRagdoll.remember(obj)
	if not obj or misc.noRagdoll.saved[obj] ~= nil then
		return
	end
	if obj:IsA("BoolValue") or obj:IsA("NumberValue") or obj:IsA("IntValue") then
		misc.noRagdoll.saved[obj] = obj.Value
	end
end

function misc.noRagdoll.writeVal(obj, want)
	if not obj then
		return
	end
	if obj:IsA("BoolValue") or obj:IsA("NumberValue") or obj:IsA("IntValue") then
		misc.noRagdoll.remember(obj)
		if obj.Value ~= want then
			pcall(function()
				obj.Value = want
			end)
		end
	end
end

function misc.noRagdoll.applyCharStats()
	local folder = misc.noRagdoll.getStatsFolder()
	if not folder then
		return false
	end
	-- Only these two (per user): NoRagdoll=true, RagdollTime=0
	misc.noRagdoll.writeVal(folder:FindFirstChild("NoRagdoll"), true)
	local rt = folder:FindFirstChild("RagdollTime")
	if rt then
		if rt:IsA("NumberValue") or rt:IsA("IntValue") then
			misc.noRagdoll.writeVal(rt, 0)
		else
			-- RagdollTime is a Folder → the timer value is RagdollTime2
			misc.noRagdoll.writeVal(rt:FindFirstChild("RagdollTime2"), 0)
		end
	end
	return true
end

function misc.noRagdoll.restoreCharStats()
	for obj, prev in pairs(misc.noRagdoll.saved) do
		if typeof(obj) == "Instance" and obj.Parent then
			pcall(function()
				obj.Value = prev
			end)
		end
	end
	table.clear(misc.noRagdoll.saved)
end

function misc.noRagdoll.hookCharStats()
	misc.noRagdoll.clearStatsConns()
	misc.noRagdoll.applyCharStats()
	local folder = misc.noRagdoll.getStatsFolder()
	if not folder then
		-- CharStats may spawn later — watch ReplicatedStorage
		local root = RepSt:FindFirstChild("CharStats") or RepSt
		table.insert(
			misc.noRagdoll.statsConns,
			root.ChildAdded:Connect(function()
				if _G.__VG_S and _G.__VG_S.CrimNoRagdoll then
					task.defer(function()
						misc.noRagdoll.hookCharStats()
					end)
				end
			end)
		)
		return
	end
	local function reapply()
		if _G.__VG_S and _G.__VG_S.CrimNoRagdoll then
			misc.noRagdoll.applyCharStats()
		end
	end
	table.insert(misc.noRagdoll.statsConns, folder.DescendantAdded:Connect(function(ch)
		if ch.Name == "NoRagdoll" or ch.Name == "RagdollTime" or ch.Name == "RagdollTime2" then
			task.defer(reapply)
		end
	end))
	local watch = {
		folder:FindFirstChild("NoRagdoll"),
		folder:FindFirstChild("RagdollTime"),
	}
	local rt = folder:FindFirstChild("RagdollTime")
	if rt then
		watch[#watch + 1] = rt:FindFirstChild("RagdollTime2")
	end
	for _, d in ipairs(watch) do
		if d and (d:IsA("BoolValue") or d:IsA("NumberValue") or d:IsA("IntValue")) then
			table.insert(
				misc.noRagdoll.statsConns,
				d:GetPropertyChangedSignal("Value"):Connect(reapply)
			)
		end
	end
end

function misc.unragdollChar(char)
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		if hum.PlatformStand then
			hum.PlatformStand = false
		end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Ragdoll
			or st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.FallingDown
			or st == Enum.HumanoidStateType.PlatformStanding then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BallSocketConstraint") then
			pcall(function()
				d:Destroy()
			end)
		elseif d:IsA("Motor6D") and not d.Enabled then
			pcall(function()
				d.Enabled = true
			end)
		end
	end
end

function misc.hookNoRagdollChar(char)
	misc.clearNoRagdollChar()
	if not char then
		return
	end
	misc.unragdollChar(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		local w
		w = char.ChildAdded:Connect(function(ch)
			if ch:IsA("Humanoid") then
				pcall(function()
					w:Disconnect()
				end)
				misc.hookNoRagdollChar(char)
			end
		end)
		table.insert(misc.noRagdoll.charConns, w)
		return
	end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	end)
	table.insert(
		misc.noRagdoll.charConns,
		hum.StateChanged:Connect(function(_, new)
			if not (_G.__VG_S and _G.__VG_S.CrimNoRagdoll) then
				return
			end
			if misc.ragdollDrag and misc.ragdollDrag.active then
				return
			end
			if new == Enum.HumanoidStateType.Ragdoll
				or new == Enum.HumanoidStateType.Physics
				or new == Enum.HumanoidStateType.FallingDown
				or new == Enum.HumanoidStateType.PlatformStanding then
				task.defer(function()
					misc.unragdollChar(char)
				end)
			end
		end)
	)
	table.insert(
		misc.noRagdoll.charConns,
		hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if misc.ragdollDrag and misc.ragdollDrag.active then
				return
			end
			if _G.__VG_S and _G.__VG_S.CrimNoRagdoll and hum.PlatformStand then
				hum.PlatformStand = false
				task.defer(function()
					misc.unragdollChar(char)
				end)
			end
		end)
	)
	table.insert(
		misc.noRagdoll.charConns,
		char.DescendantAdded:Connect(function(d)
			if not (_G.__VG_S and _G.__VG_S.CrimNoRagdoll) then
				return
			end
			if misc.ragdollDrag and misc.ragdollDrag.active then
				return
			end
			if d:IsA("BallSocketConstraint") then
				task.defer(function()
					pcall(function()
						d:Destroy()
					end)
				end)
			end
		end)
	)
end

local function startNoRagdoll()
	for _, c in ipairs(misc.noRagdoll.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.noRagdoll.conns = {}
	misc.clearNoRagdollChar()
	misc.noRagdoll.hookCharStats()
	local lp = getLP()
	if not lp then
		return
	end
	if lp.Character then
		misc.hookNoRagdollChar(lp.Character)
	end
	table.insert(
		misc.noRagdoll.conns,
		lp.CharacterAdded:Connect(function(char)
			task.defer(function()
				if _G.__VG_S and _G.__VG_S.CrimNoRagdoll then
					misc.noRagdoll.hookCharStats()
					misc.hookNoRagdollChar(char)
				end
			end)
		end)
	)
end

local function stopNoRagdoll()
	for _, c in ipairs(misc.noRagdoll.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.noRagdoll.conns = {}
	misc.clearNoRagdollChar()
	misc.noRagdoll.clearStatsConns()
	misc.noRagdoll.restoreCharStats()
	local hum = getHum()
	if hum then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		end)
	end
end

-- ── SELF RAGDOLL DRAG (real BallSocket ragdoll + grab-part AlignPosition) ──
misc.ragdollDrag = {
	conns = {},
	active = false,
	motors = {},
	created = {},
	grabPart = nil,
	att = nil,
	ap = nil,
	hum = nil,
	char = nil,
	blockNotifyAt = 0,
}

function misc.ragdollDrag.clearForces()
	local rd = misc.ragdollDrag
	for _, obj in ipairs({ rd.ap, rd.att }) do
		if obj then
			pcall(function()
				obj:Destroy()
			end)
		end
	end
	rd.ap, rd.att = nil, nil
	rd.grabPart = nil
end

function misc.ragdollDrag.clearRagdoll()
	local rd = misc.ragdollDrag
	for _, m in ipairs(rd.motors) do
		if m.motor and m.motor.Parent then
			pcall(function()
				m.motor.Enabled = m.enabled ~= false
			end)
		end
	end
	rd.motors = {}
	for _, obj in ipairs(rd.created) do
		if obj then
			pcall(function()
				obj:Destroy()
			end)
		end
	end
	rd.created = {}
end

function misc.ragdollDrag.buildRagdoll(char)
	local rd = misc.ragdollDrag
	misc.ragdollDrag.clearRagdoll()
	if not char then
		return
	end
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "VG_RD_A0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "VG_RD_A1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "VG_RD_Sock"
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.TwistLimitsEnabled = true
			bs.UpperAngle = 85
			bs.TwistLowerAngle = -50
			bs.TwistUpperAngle = 50
			bs.Parent = m.Part0
			table.insert(rd.created, a0)
			table.insert(rd.created, a1)
			table.insert(rd.created, bs)
			table.insert(rd.motors, { motor = m, enabled = m.Enabled })
			m.Enabled = false
		end
	end
end

function misc.ragdollDrag.pickGrabPart(char)
	if not char then
		return nil
	end
	return char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Head")
end

function misc.ragdollDrag.exit()
	local rd = misc.ragdollDrag
	if not rd.active then
		misc.ragdollDrag.clearForces()
		misc.ragdollDrag.clearRagdoll()
		rd.hum, rd.char = nil, nil
		return
	end
	rd.active = false
	local hum = rd.hum
	local char = rd.char
	misc.ragdollDrag.clearForces()
	misc.ragdollDrag.clearRagdoll()
	rd.hum, rd.char = nil, nil
	if hum and hum.Parent then
		pcall(function()
			hum.AutoRotate = true
			hum.PlatformStand = false
			local st = hum:GetState()
			if st == Enum.HumanoidStateType.Physics
				or st == Enum.HumanoidStateType.Ragdoll
				or st == Enum.HumanoidStateType.PlatformStanding
				or st == Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
	if char then
		task.defer(function()
			-- nudge upright after motors restored
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local h = char:FindFirstChildOfClass("Humanoid")
			if hrp and h and h.Health > 0 then
				pcall(function()
					local pos = hrp.Position
					hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
					h:ChangeState(Enum.HumanoidStateType.GettingUp)
				end)
			end
		end)
	end
end

function misc.ragdollDrag.enter()
	local rd = misc.ragdollDrag
	if rd.active then
		return true
	end
	local S = _G.__VG_S
	if S and S.CrimNoRagdoll then
		local now = tick()
		if now - (rd.blockNotifyAt or 0) > 2.5 then
			rd.blockNotifyAt = now
			pcall(crimNotify, "Ragdoll Drag", "Wyłącz No Ragdoll — potrzebny prawdziwy ragdoll", 3)
		end
		return false
	end

	local hrp, char = getHRP()
	if not hrp or not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local grab = misc.ragdollDrag.pickGrabPart(char)
	if not grab then
		return false
	end

	misc.ragdollDrag.clearForces()
	misc.ragdollDrag.clearRagdoll()
	rd.active = true
	rd.char = char
	rd.hum = hum
	rd.grabPart = grab

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		hum.AutoRotate = false
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end)

	misc.ragdollDrag.buildRagdoll(char)

	-- Re-resolve grab after ragdoll (parts still valid)
	grab = misc.ragdollDrag.pickGrabPart(char) or grab
	rd.grabPart = grab

	local att = Instance.new("Attachment")
	att.Name = "VG_RagdollDragAtt"
	att.Parent = grab

	-- Soft "Explorer grab" pull — limbs flop freely (no AlignOrientation)
	local ap = Instance.new("AlignPosition")
	ap.Name = "VG_RagdollDragAP"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.ApplyAtCenterOfMass = true
	ap.RigidityEnabled = false
	ap.MaxForce = 45000
	ap.MaxVelocity = 50
	ap.Responsiveness = 18
	ap.Position = grab.Position
	ap.Parent = grab

	rd.att = att
	rd.ap = ap
	return true
end

function misc.ragdollDrag.keyHeld(S)
	if not UIS then
		return false
	end
	local keyName = S and S.CrimRagdollDragKey or "X"
	if not keyName or keyName == "" or keyName == "None" then
		return false
	end
	if string.match(keyName, "^MouseButton%d+$") then
		local ok, uit = pcall(function()
			return Enum.UserInputType[keyName]
		end)
		if ok and uit then
			return UIS:IsMouseButtonPressed(uit)
		end
		return false
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	if not ok or not key then
		return false
	end
	return UIS:IsKeyDown(key)
end

function misc.ragdollDrag.tick(S)
	local rd = misc.ragdollDrag
	if not S or not S.CrimRagdollDrag then
		if rd.active then
			misc.ragdollDrag.exit()
		end
		return
	end
	if S.CrimNoRagdoll then
		if rd.active then
			misc.ragdollDrag.exit()
		end
		return
	end

	local want = misc.ragdollDrag.keyHeld(S)
	if want and not rd.active then
		misc.ragdollDrag.enter()
	elseif not want and rd.active then
		misc.ragdollDrag.exit()
		return
	end
	if not rd.active then
		return
	end

	local grab = rd.grabPart
	local hum = rd.hum
	local ap = rd.ap
	if not grab or not grab.Parent or not ap or not ap.Parent then
		misc.ragdollDrag.exit()
		return
	end
	if hum and hum.Parent and hum.Health <= 0 then
		misc.ragdollDrag.exit()
		return
	end

	if hum then
		pcall(function()
			hum.AutoRotate = false
			if not hum.PlatformStand then
				hum.PlatformStand = true
			end
			local st = hum:GetState()
			if st ~= Enum.HumanoidStateType.Physics
				and st ~= Enum.HumanoidStateType.Ragdoll
				and st ~= Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Physics)
			end
		end)
	end

	-- Keep limb motors disabled if game re-enables them
	for _, m in ipairs(rd.motors) do
		if m.motor and m.motor.Parent and m.motor.Enabled then
			m.motor.Enabled = false
		end
	end

	local Cam = workspace.CurrentCamera
	if not Cam or not UIS then
		return
	end
	local cf = Cam.CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if look.Magnitude > 0.05 then
		look = look.Unit
	else
		look = Vector3.new(0, 0, -1)
	end
	if right.Magnitude > 0.05 then
		right = right.Unit
	else
		right = Vector3.new(1, 0, 0)
	end

	local speed = math.clamp(tonumber(S.CrimRagdollDragSpeed) or 45, 10, 120)
	ap.MaxVelocity = speed
	-- Soft grab feel — body flops behind the pulled torso
	ap.MaxForce = 32000 + speed * 400
	ap.Responsiveness = 16

	local move = Vector3.zero
	if UIS:IsKeyDown(Enum.KeyCode.W) then
		move = move + look
	end
	if UIS:IsKeyDown(Enum.KeyCode.S) then
		move = move - look
	end
	if UIS:IsKeyDown(Enum.KeyCode.A) then
		move = move - right
	end
	if UIS:IsKeyDown(Enum.KeyCode.D) then
		move = move + right
	end
	if UIS:IsKeyDown(Enum.KeyCode.Space) then
		move = move + Vector3.yAxis
	end
	if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
		move = move - Vector3.yAxis
	end

	if move.Magnitude > 0.05 then
		local dir = move.Unit
		ap.Position = grab.Position + dir * math.max(7, speed * 0.26)
	else
		ap.Position = grab.Position
	end
end

function misc.ragdollDrag.clearConns()
	for _, c in ipairs(misc.ragdollDrag.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.ragdollDrag.conns = {}
end

function misc.ragdollDrag.start()
	misc.ragdollDrag.clearConns()
	local lp = getLP()
	if lp then
		table.insert(
			misc.ragdollDrag.conns,
			lp.CharacterRemoving:Connect(function()
				misc.ragdollDrag.exit()
			end)
		)
	end
end

function misc.ragdollDrag.stop()
	misc.ragdollDrag.clearConns()
	misc.ragdollDrag.exit()
end

-- ── FAST ACCELERATION (CharStats AccelerationModifier / AccelerationModifier2 = 1) ──
misc.fastAccel = { conns = {}, saved = {} }

function misc.fastAccel.clearConns()
	for _, c in ipairs(misc.fastAccel.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.fastAccel.conns = {}
end

function misc.fastAccel.getStatsFolder()
	local lp = getLP()
	if not lp then
		return nil
	end
	local root = RepSt:FindFirstChild("CharStats")
	if not root then
		return nil
	end
	return root:FindFirstChild(lp.Name)
end

function misc.fastAccel.targetValue()
	local S = _G.__VG_S or {}
	local v = tonumber(S.CrimFastAccelValue)
	if not v then
		return 1
	end
	return math.clamp(v, 0.1, 5)
end

function misc.fastAccel.writeVal(obj, want)
	if not obj then
		return
	end
	if obj:IsA("NumberValue") or obj:IsA("IntValue") then
		if misc.fastAccel.saved[obj] == nil then
			misc.fastAccel.saved[obj] = obj.Value
		end
		if obj.Value ~= want then
			pcall(function()
				obj.Value = want
			end)
		end
	end
end

function misc.fastAccel.apply()
	local folder = misc.fastAccel.getStatsFolder()
	if not folder then
		return false
	end
	local want = misc.fastAccel.targetValue()
	misc.fastAccel.writeVal(folder:FindFirstChild("AccelerationModifier"), want)
	misc.fastAccel.writeVal(folder:FindFirstChild("AccelerationModifier2"), want)
	return true
end

function misc.fastAccel.restore()
	for obj, prev in pairs(misc.fastAccel.saved) do
		if typeof(obj) == "Instance" and obj.Parent then
			pcall(function()
				obj.Value = prev
			end)
		end
	end
	table.clear(misc.fastAccel.saved)
end

function misc.fastAccel.start()
	misc.fastAccel.clearConns()
	misc.fastAccel.apply()
	local function reapply()
		if _G.__VG_S and _G.__VG_S.CrimFastAccel then
			misc.fastAccel.apply()
		end
	end
	local folder = misc.fastAccel.getStatsFolder()
	local root = RepSt:FindFirstChild("CharStats") or RepSt
	if not folder then
		table.insert(
			misc.fastAccel.conns,
			root.ChildAdded:Connect(function()
				task.defer(function()
					if _G.__VG_S and _G.__VG_S.CrimFastAccel then
						misc.fastAccel.start()
					end
				end)
			end)
		)
		return
	end
	for _, name in ipairs({ "AccelerationModifier", "AccelerationModifier2" }) do
		local obj = folder:FindFirstChild(name)
		if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
			table.insert(
				misc.fastAccel.conns,
				obj:GetPropertyChangedSignal("Value"):Connect(reapply)
			)
		end
	end
	table.insert(
		misc.fastAccel.conns,
		folder.ChildAdded:Connect(function(ch)
			if ch.Name == "AccelerationModifier" or ch.Name == "AccelerationModifier2" then
				task.defer(reapply)
			end
		end)
	)
	local lp = getLP()
	if lp then
		table.insert(
			misc.fastAccel.conns,
			lp.CharacterAdded:Connect(function()
				task.defer(reapply)
			end)
		)
	end
end

function misc.fastAccel.stop()
	misc.fastAccel.clearConns()
	misc.fastAccel.restore()
end


-- â”€â”€ MELEE AURA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into one table to stay under Luau's 200-local limit.
local melee = { cooldown = false, CD = 0.5 }

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
	if melee.cooldown then return end
	local target=getClosestInRange(S.CrimMeleeRange or 5)
	if not target then return end
	melee.cooldown=true
	task.spawn(function()
		pcall(doMeleeAttack,target)
		task.wait(melee.CD)
		melee.cooldown=false
	end)
end

-- â”€â”€ SAFE / DEALER / CRATE ESP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Safes/dealers: one build pass. Crates: dynamic (SpawnedPiles).
-- Per-frame: only reads cached .part.Position and sets .Enabled.

local ESP = { safes={}, dealers={}, crates={}, guns={}, safeByModel={}, dealerByModel={}, crateScanAt=0, gunScanAt=0 }
local espBuilt = { safes=false, dealers=false }
local crateByModel = {}
-- Packed into one table to stay under Luau's 200-local limit.
local crateWatch = { folderConn = nil, removeConn = nil, folderWatch = nil }

-- Is the instance still alive? Check Parent without pcall.
local function alive(inst)
	return inst and rawequal(typeof(inst),"Instance") and inst.Parent ~= nil
end

local function getGui()
	local lp=getLP()
	return (lp and lp:FindFirstChild("PlayerGui")) or game:GetService("CoreGui")
end

local function getModelPart(model)
	if not model then
		return nil
	end
	local pp = model.PrimaryPart
	if pp and pp:IsA("BasePart") then
		return pp
	end
	local mesh = model:FindFirstChild("MeshPart", true)
	if mesh and mesh:IsA("BasePart") then
		return mesh
	end
	local main = model:FindFirstChild("MainPart", true)
	if main and main:IsA("BasePart") then
		return main
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

crateWatch.MAX_AXIS = 10  -- folded into crateWatch table to save a register

local function isReasonableCratePart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local sz = part.Size
	return sz.X <= crateWatch.MAX_AXIS and sz.Y <= crateWatch.MAX_AXIS and sz.Z <= crateWatch.MAX_AXIS
end

local function getCrateVisualPart(model, allowDeep)
	if not model then
		return nil
	end
	local pp = model.PrimaryPart
	if isReasonableCratePart(pp) then
		return pp
	end
	local best, bestVol = nil, math.huge
	for _, ch in ipairs(model:GetChildren()) do
		if ch:IsA("BasePart") and isReasonableCratePart(ch) then
			local vol = ch.Size.X * ch.Size.Y * ch.Size.Z
			if vol < bestVol then
				bestVol = vol
				best = ch
			end
		elseif ch:IsA("Model") then
			for _, sub in ipairs(ch:GetChildren()) do
				if sub:IsA("BasePart") and isReasonableCratePart(sub) then
					local vol = sub.Size.X * sub.Size.Y * sub.Size.Z
					if vol < bestVol then
						bestVol = vol
						best = sub
					end
				end
			end
		end
	end
	if not best then
		for _, ch in ipairs(model:GetChildren()) do
			if ch:IsA("BasePart") then
				local vol = ch.Size.X * ch.Size.Y * ch.Size.Z
				if vol < bestVol then
					bestVol = vol
					best = ch
				end
			end
		end
	end
	-- Deep GetDescendants only off hot path (syncCrateESP) — freezes tickESP otherwise
	if not best and allowDeep then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and isReasonableCratePart(d) then
				local vol = d.Size.X * d.Size.Y * d.Size.Z
				if vol < bestVol then
					bestVol = vol
					best = d
				end
			end
		end
	end
	return best
end

local function makeEntry(model, fillCol, outlineCol, labelText, brokenVal, highlightAdornee)
	local part = getModelPart(model)
	if not part then return nil end

	local h = Instance.new("Highlight")
	h.Name              = "VG_CrimESP"
	h.FillColor           = fillCol
	h.OutlineColor        = outlineCol
	h.FillTransparency    = 0.55
	h.OutlineTransparency = 0
	h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee             = highlightAdornee or model
	h.Enabled             = false
	h.Parent              = getGui()

	local bg  = Instance.new("BillboardGui")
	bg.Name        = "VG_CrimESP"
	bg.Size        = UDim2.new(0, math.clamp(#labelText * 7 + 22, 58, 130), 0, 20)
	bg.StudsOffset = Vector3.new(0, 4, 0)
	bg.AlwaysOnTop = true
	bg.Enabled     = false
	bg.Adornee     = part
	bg.Parent      = getGui()

	-- Pill-style rounded label (dark bg + colored stroke)
	local pill = Instance.new("Frame")
	pill.Name                   = "Pill"
	pill.Size                   = UDim2.new(1, 0, 1, 0)
	pill.BackgroundColor3       = Color3.fromRGB(12, 12, 16)
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel        = 0
	pill.Parent                 = bg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color        = fillCol
	stroke.Thickness    = 1
	stroke.Transparency = 0.35
	stroke.Parent       = pill

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, -8, 1, 0)
	lbl.Position               = UDim2.new(0, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = labelText
	lbl.TextColor3             = Color3.fromRGB(240, 240, 245)
	lbl.TextSize               = 10
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 1
	lbl.TextTruncate           = Enum.TextTruncate.AtEnd
	lbl.Parent                 = pill

	return { h=h, bg=bg, lbl=lbl, pill=pill, stroke=stroke, part=part,
	         model=model, broken=brokenVal, fillCol=fillCol, visState=false }
end

-- Animated show/hide â€” tween only on state transition (cheap; no per-frame cost).
ESP.FADE_IN = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  -- folded into ESP table to save a register

local function espShow(e)
	if e.visState then return end
	e.visState = true
	if alive(e.h) then
		e.h.Enabled = true
		e.h.FillTransparency = 1
		e.h.OutlineTransparency = 1
		TS:Create(e.h, ESP.FADE_IN, { FillTransparency = 0.55, OutlineTransparency = 0 }):Play()
	end
	if alive(e.bg) then
		e.bg.Enabled = true
		e.bg.StudsOffset = Vector3.new(0, 2.6, 0)
		TS:Create(e.bg, ESP.FADE_IN, { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	end
	if alive(e.pill) then
		e.pill.BackgroundTransparency = 1
		TS:Create(e.pill, ESP.FADE_IN, { BackgroundTransparency = 0.25 }):Play()
	end
	if alive(e.lbl) then
		e.lbl.TextTransparency = 1
		TS:Create(e.lbl, ESP.FADE_IN, { TextTransparency = 0 }):Play()
	end
	if e.stroke and e.stroke.Parent then
		e.stroke.Transparency = 1
		TS:Create(e.stroke, ESP.FADE_IN, { Transparency = 0.35 }):Play()
	end
end

local function espHide(e)
	if not e.visState then
		-- keep hard-off in case instances were re-created visible
		if alive(e.h) and e.h.Enabled then e.h.Enabled = false end
		if alive(e.bg) and e.bg.Enabled then e.bg.Enabled = false end
		return
	end
	e.visState = false
	if alive(e.h) then e.h.Enabled = false end
	if alive(e.bg) then e.bg.Enabled = false end
end

local function clearSafeESP()
	for _, e in ipairs(ESP.safes) do
		if alive(e.h)  then e.h:Destroy()  end
		if alive(e.bg) then e.bg:Destroy() end
	end
	table.clear(ESP.safes)
	table.clear(ESP.safeByModel)
	espBuilt.safes = false
end

local function syncSafeESP(S)
	if not S.CrimSafeESP then
		if #ESP.safes > 0 then
			clearSafeESP()
		end
		return
	end
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("BredMakurz")
	if not folder then
		return
	end

	local maxDist = S.CrimESPMaxDist or 300
	local showBroken = S.CrimSafeShowBroken == true
	local color = S.CrimSafeColor or Color3.fromRGB(255, 220, 50)
	local cam = workspace.CurrentCamera
	local origin = cam and cam.CFrame.Position
	if not origin then
		local hrp = getHRP()
		origin = hrp and hrp.Position
	end
	if not origin then
		return
	end

	-- Roblox soft-caps Highlights (~31). Only keep nearby safes/registers.
	local CAP = 28
	local candidates = {}
	for _, safe in ipairs(folder:GetChildren()) do
		if safe:IsA("Model") or safe:IsA("Folder") or safe:IsA("BasePart") then
			local values = safe:FindFirstChild("Values")
			local broken = (values and values:FindFirstChild("Broken"))
				or safe:FindFirstChild("Broken", true)
			local open = broken and broken:IsA("BoolValue") and broken.Value == true
			if open and not showBroken then
				-- skip opened/destroyed unless Show Broken
			else
				local part = getModelPart(safe)
				if part then
					local dist = (origin - part.Position).Magnitude
					if dist <= maxDist then
						table.insert(candidates, {
							model = safe,
							part = part,
							broken = broken,
							dist = dist,
						})
					end
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)

	local keep = {}
	local n = math.min(#candidates, CAP)
	for i = 1, n do
		keep[candidates[i].model] = candidates[i]
	end

	for i = #ESP.safes, 1, -1 do
		local e = ESP.safes[i]
		local model = e.model
		if not keep[model] or not alive(model) then
			ESP.safeByModel[model] = nil
			if alive(e.h) then e.h:Destroy() end
			if alive(e.bg) then e.bg:Destroy() end
			table.remove(ESP.safes, i)
		end
	end

	for model, info in pairs(keep) do
		if not ESP.safeByModel[model] then
			local label = "SAFE"
			local nm = model.Name
			if type(nm) == "string" then
				if string.sub(nm, 1, 8) == "Register" then
					label = "REGISTER"
				elseif string.sub(nm, 1, 9) == "SmallSafe" then
					label = "SMALL SAFE"
				elseif string.sub(nm, 1, 10) == "MediumSafe" then
					label = "MED SAFE"
				end
			end
			local adornee = info.part
			local main = model:FindFirstChild("MainPart", true)
			if main and main:IsA("BasePart") then
				adornee = main
			end
			local ok, entry = pcall(makeEntry, model, color, Color3.fromRGB(255, 255, 255),
				label, info.broken, adornee)
			if ok and entry then
				entry.baseLabel = label
				entry.part = adornee
				if alive(entry.bg) then entry.bg.Adornee = adornee end
				ESP.safeByModel[model] = entry
				table.insert(ESP.safes, entry)
			end
		else
			local e = ESP.safeByModel[model]
			e.broken = info.broken
		end
	end
	espBuilt.safes = true
end

local function dealerEspMeta(shop, S)
	local name = tostring(shop and shop.Name or "")
	local lower = string.lower(name)
	if string.find(lower, "rebel", 1, true) then
		local col = S.CrimRebelDealerColor or Color3.fromRGB(255, 90, 70)
		-- Map-wide + special label (★); distance ignored in tickESP
		return col, "\u{2605} REBEL DEALER", true
	end
	local col = S.CrimDealerColor or Color3.fromRGB(100, 200, 255)
	return col, "DEALER", false
end

local function styleRebelDealerEntry(entry, fill)
	if not entry then
		return
	end
	entry.rebel = true
	if alive(entry.h) then
		entry.h.FillTransparency = 0.35
		entry.h.OutlineTransparency = 0
		entry.h.FillColor = fill
		entry.h.OutlineColor = Color3.fromRGB(255, 230, 120)
	end
	if alive(entry.bg) then
		entry.bg.Size = UDim2.new(0, 148, 0, 24)
		entry.bg.StudsOffset = Vector3.new(0, 5.2, 0)
	end
	if alive(entry.pill) then
		entry.pill.BackgroundColor3 = Color3.fromRGB(28, 6, 8)
		entry.pill.BackgroundTransparency = 0.12
	end
	if entry.stroke and entry.stroke.Parent then
		entry.stroke.Color = fill
		entry.stroke.Thickness = 2
		entry.stroke.Transparency = 0.1
	end
	if alive(entry.lbl) then
		entry.lbl.TextColor3 = Color3.fromRGB(255, 210, 90)
		entry.lbl.TextSize = 12
	end
end

local function clearDealerESP()
	for _, e in ipairs(ESP.dealers) do
		if alive(e.h) then e.h:Destroy() end
		if alive(e.bg) then e.bg:Destroy() end
	end
	table.clear(ESP.dealers)
	table.clear(ESP.dealerByModel)
	espBuilt.dealers = false
end

local function syncDealerESP(S)
	if not S.CrimDealerESP then
		if #ESP.dealers > 0 then
			clearDealerESP()
		end
		return
	end
	local map = workspace:FindFirstChild("Map")
	if not map then return end
	local shops = map:FindFirstChild("Shopz")
	if not shops then return end

	for i = #ESP.dealers, 1, -1 do
		local e = ESP.dealers[i]
		local model = e.model
		if not alive(model) or model.Parent ~= shops then
			ESP.dealerByModel[model] = nil
			if alive(e.h) then e.h:Destroy() end
			if alive(e.bg) then e.bg:Destroy() end
			table.remove(ESP.dealers, i)
		end
	end

	for _, shop in ipairs(shops:GetChildren()) do
		if not ESP.dealerByModel[shop] then
			local color, label, isRebel = dealerEspMeta(shop, S)
			local outline = isRebel and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(255, 255, 255)
			local ok, entry = pcall(makeEntry, shop, color, outline, label, nil)
			if ok and entry then
				if isRebel then
					styleRebelDealerEntry(entry, color)
				end
				ESP.dealerByModel[shop] = entry
				table.insert(ESP.dealers, entry)
			end
		end
	end
	espBuilt.dealers = #ESP.dealers > 0
end

-- One-shot alias kept for older call sites / init race
local function buildDealerESP(S)
	syncDealerESP(S)
end

local function clearESP(tbl)
	for _,e in ipairs(tbl) do
		if alive(e.h)  then e.h:Destroy()  end
		if alive(e.bg) then e.bg:Destroy() end
	end
	table.clear(tbl)
end

local function destroyCrateEntry(model)
	local e = crateByModel[model]
	if not e then return end
	crateByModel[model] = nil
	if alive(e.h)  then e.h:Destroy()  end
	if alive(e.bg) then e.bg:Destroy() end
	for i, entry in ipairs(ESP.crates) do
		if entry == e then
			table.remove(ESP.crates, i)
			break
		end
	end
end

local function clearCrateESP()
	for model in pairs(crateByModel) do
		destroyCrateEntry(model)
	end
	table.clear(ESP.crates)
	table.clear(crateByModel)
	local gui = getGui()
	local piles = getSpawnedPiles()
	if gui and piles then
		for _, ch in ipairs(gui:GetChildren()) do
			if ch:IsA("Highlight") and ch.Adornee and ch.Adornee:IsA("Instance") then
				local adorn = ch.Adornee
				local model = adorn:IsA("Model") and adorn or adorn:FindFirstAncestorOfClass("Model")
				if model and model:IsDescendantOf(piles) and not crateByModel[model] then
					ch:Destroy()
				end
			end
		end
	end
end

local function getSpawnedPiles()
	local filter = workspace:FindFirstChild("Filter")
	if not filter then
		return nil
	end
	return filter:FindFirstChild("SpawnedPiles")
end

local function isInSpawnedPiles(model)
	local piles = getSpawnedPiles()
	if not piles or not model then
		return false
	end
	return model:IsDescendantOf(piles)
end

local function isCrateModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	-- Workspace.Filter.SpawnedPiles â†’ each child named C1 is a crate.
	return model.Name == "C1" and isInSpawnedPiles(model)
end

local function getCrateRarityValue(model)
	return model:GetAttribute("cot_") or model:GetAttribute("col_")
end

local function getCrateMeshPart(model)
	return getCrateVisualPart(model, true)
end

local function getCrateKind(model)
	-- basic: no cot_/col_ (or other)
	-- rare: 7
	-- airdrop: 10 (map-wide ESP)
	local cot = getCrateRarityValue(model)
	if cot == 10 or cot == "10" then
		return "airdrop"
	end
	if cot == 7 or cot == "7" then
		return "rare"
	end
	return "basic"
end

-- Packed into one table to stay under Luau's 200-local limit.
local COLORS = {
	crateNorm = Color3.fromRGB(255, 190, 60),
	crateRare = Color3.fromRGB(255, 55, 55),
	crateAirdrop = Color3.fromRGB(180, 90, 255),
	gun       = Color3.fromRGB(80, 255, 140),
	melee     = Color3.fromRGB(255, 170, 60),
	nade      = Color3.fromRGB(255, 90, 90),
	tool      = Color3.fromRGB(170, 195, 255),
	open      = Color3.fromRGB(100, 255, 100),
	safeD     = Color3.fromRGB(255, 220, 50),
}

local function shouldShowCrate(S, kind)
	if not S.CrimCrateESP then
		return false
	end
	if kind == "airdrop" then
		return S.CrimCrateAirdrop ~= false
	end
	if kind == "rare" then
		return S.CrimCrateRare ~= false
	end
	return S.CrimCrateBasic ~= false
end

local function playCrateSpawnFx(entry, kind)
	if not entry or not alive(entry.h) then
		return
	end
	local S = _G.__VG_S or {}
	local fill = COLORS.crateNorm
	if kind == "airdrop" then
		fill = S.CrimCrateAirdropColor or COLORS.crateAirdrop
	elseif kind == "rare" then
		fill = S.CrimCrateRareColor or COLORS.crateRare
	else
		fill = S.CrimCrateColor or COLORS.crateNorm
	end
	entry.visState = true  -- mark visible so tickESP doesn't re-run fade-in over the fx
	entry.h.Enabled = true
	entry.h.FillColor = fill
	entry.h.FillTransparency = 1
	entry.h.OutlineTransparency = 1

	if alive(entry.bg) then
		entry.bg.Enabled = true
		entry.bg.StudsOffset = Vector3.new(0, 1.2, 0)
	end

	local popIn = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TS:Create(entry.h, popIn, {
		FillTransparency = 0.4,
		OutlineTransparency = 0,
	}):Play()

	if alive(entry.bg) then
		TS:Create(entry.bg, popIn, {
			StudsOffset = Vector3.new(0, 4.8, 0),
		}):Play()
	end

	if alive(entry.lbl) then
		local finalText = entry.lbl.Text
		local finalSize = alive(entry.bg) and entry.bg.Size or nil
		if kind == "airdrop" then
			entry.lbl.Text = "\u{2726} AIRDROP SPAWN \u{2726}"
		elseif kind == "rare" then
			entry.lbl.Text = "\u{2726} RARE SPAWN \u{2726}"
		else
			entry.lbl.Text = "\u{25B2} CRATE SPAWN \u{25B2}"
		end
		if alive(entry.bg) then
			entry.bg.Size = UDim2.new(0, kind == "airdrop" and 132 or 118, 0, 20)
		end
		task.delay(1.1, function()
			if alive(entry.lbl) and entry.lbl.Text:find("SPAWN") then
				entry.lbl.Text = finalText
				if finalSize and alive(entry.bg) then
					entry.bg.Size = finalSize
				end
			end
		end)
	end

	-- Second pulse ring
	task.delay(0.15, function()
		if not alive(entry.h) then
			return
		end
		local pulse = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)
		TS:Create(entry.h, pulse, { FillTransparency = 0.72 }):Play()
	end)
end

local function addCrateESP(model, S, withSpawnFx)
	if not isCrateModel(model) or crateByModel[model] then
		return false
	end
	local kind = getCrateKind(model)
	if not shouldShowCrate(S, kind) then
		return false
	end
	local fill = COLORS.crateNorm
	local label = "CRATE"
	if kind == "airdrop" then
		fill = S.CrimCrateAirdropColor or COLORS.crateAirdrop
		label = "AIRDROP CRATE"
	elseif kind == "rare" then
		fill = S.CrimCrateRareColor or COLORS.crateRare
		label = "RARE CRATE"
	else
		fill = S.CrimCrateColor or COLORS.crateNorm
	end
	local part = getCrateVisualPart(model, true)
	if not part then
		return false
	end
	local ok, entry = pcall(makeEntry, model, fill, Color3.fromRGB(255, 255, 255), label, nil, part)
	if not ok or not entry then
		return false
	end
	entry.kind = kind
	entry.rare = kind == "rare"
	entry.airdrop = kind == "airdrop"
	crateByModel[model] = entry
	table.insert(ESP.crates, entry)
	if withSpawnFx then
		playCrateSpawnFx(entry, kind)
	end
	return true
end

local function syncCrateESP(S)
	if not S.CrimCrateESP then
		if #ESP.crates > 0 then
			clearCrateESP()
		end
		return
	end

	local piles = getSpawnedPiles()
	if not piles then
		return
	end

	-- Drop dead / filtered-out crates
	for i = #ESP.crates, 1, -1 do
		local e = ESP.crates[i]
		local model = e.model
		local keep = alive(model) and isCrateModel(model) and isInSpawnedPiles(model)
		if keep then
			local kind = getCrateKind(model)
			keep = shouldShowCrate(S, kind)
		end
		if not keep then
			destroyCrateEntry(model)
		else
			-- Refresh rarity label/color if attribute changed
			local kind = getCrateKind(model)
			if e.kind ~= kind then
				e.kind = kind
				e.rare = kind == "rare"
				e.airdrop = kind == "airdrop"
				local fill = COLORS.crateNorm
				local label = "CRATE"
				if kind == "airdrop" then
					fill = S.CrimCrateAirdropColor or COLORS.crateAirdrop
					label = "AIRDROP CRATE"
				elseif kind == "rare" then
					fill = S.CrimCrateRareColor or COLORS.crateRare
					label = "RARE CRATE"
				else
					fill = S.CrimCrateColor or COLORS.crateNorm
				end
				if alive(e.h) then
					e.h.FillColor = fill
					e.h.OutlineColor = Color3.fromRGB(255, 255, 255)
				end
				if alive(e.lbl) then
					e.lbl.Text = label
				end
			end
			-- Rebind visual part if it streamed in late / got replaced
			if not alive(e.part) or not isReasonableCratePart(e.part) then
				e.part = getCrateVisualPart(model, true)
				if alive(e.part) and alive(e.bg) then
					e.bg.Adornee = e.part
				end
			end
		end
	end

	for _, model in ipairs(piles:GetChildren()) do
		addCrateESP(model, S)
	end
end

local function ensureCrateWatch(S)
	local piles = getSpawnedPiles()
	if piles then
		if crateWatch.folderWatch then
			crateWatch.folderWatch:Disconnect()
			crateWatch.folderWatch = nil
		end
		if not crateWatch.folderConn then
			crateWatch.folderConn = piles.ChildAdded:Connect(function(ch)
				-- Crates often spawn empty; retry until visual part exists (~1s)
				task.spawn(function()
					local curS = _G.__VG_S
					if not curS or not curS.CrimCrateESP then
						return
					end
					for attempt = 1, 15 do
						if not alive(ch) then
							return
						end
						local withFx = (attempt == 1)
						if addCrateESP(ch, curS, withFx) then
							pcall(tickESP, curS)
							return
						end
						task.wait(0.07)
					end
					-- last-chance full sync
					pcall(syncCrateESP, curS)
					pcall(tickESP, curS)
				end)
			end)
			crateWatch.removeConn = piles.ChildRemoved:Connect(function(ch)
				destroyCrateEntry(ch)
			end)
		end
		return
	end

	if crateWatch.folderWatch then
		return
	end
	local filter = workspace:FindFirstChild("Filter")
	if filter then
		crateWatch.folderWatch = filter.ChildAdded:Connect(function(ch)
			if ch.Name ~= "SpawnedPiles" then
				return
			end
			task.defer(function()
				local curS = _G.__VG_S
				if curS and curS.CrimCrateESP then
					syncCrateESP(curS)
					ensureCrateWatch(curS)
				end
			end)
		end)
		return
	end
	crateWatch.folderWatch = workspace.ChildAdded:Connect(function(ch)
		if ch.Name ~= "Filter" then
			return
		end
		task.defer(function()
			local curS = _G.__VG_S
			if curS and curS.CrimCrateESP then
				syncCrateESP(curS)
				ensureCrateWatch(curS)
			end
		end)
	end)
end

-- â”€â”€ SPAWNED TOOL / GUN ESP (SpawnedTools) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into gunWatch (methods + state) to stay under Luau's 200-local limit.
local gunWatch = {
	folderConn = nil,
	removeConn = nil,
	folderWatch = nil,
	byModel = {},
	idCache = setmetatable({}, { __mode = "k" }),
	weakLabels = {
		ITEM = true,
		WEAPON = true,
		GUN = true,
		PISTOL = true,
		RIFLE = true,
		ARMOR = true,
		OTHER = true,
	},
}

function gunWatch.hasDeep(model, name)
	return model and model:FindFirstChild(name, true) ~= nil
end

function gunWatch.remember(model, label, kind, solid)
	local entry = { label, kind, solid and true or false }
	gunWatch.idCache[model] = entry
	return label, kind
end

function gunWatch.nameFromSA(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("SurfaceAppearance") then
			local n = d.Name
			local us = string.find(n, "_", 1, true)
			if us and us > 1 then
				return string.sub(n, 1, us - 1)
			end
		end
	end
	return nil
end

function gunWatch.nameFromMesh(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = d.Name
			if string.sub(n, -4) == "Mesh" and #n > 4 then
				return string.sub(n, 1, #n - 4)
			end
		end
	end
	return nil
end

function gunWatch.nameFromKnown(nameSet)
	if typeof(nameSet) ~= "table" then
		return nil
	end
	local weapons = misc.skinChanger and misc.skinChanger.weaponsByLen and misc.skinChanger.weaponsByLen()
	if typeof(weapons) ~= "table" or #weapons == 0 then
		return nil
	end
	for _, gun in ipairs(weapons) do
		if nameSet[gun] or nameSet[gun .. "Mesh"] then
			return gun
		end
	end
	return nil
end

function gunWatch.classifyFromSet(nameSet, label)
	local upper = string.upper(tostring(label or ""))
	if upper:find("GRENADE", 1, true) then
		return "grenade"
	end
	if nameSet.Pin and nameSet.He and not nameSet.MagPart then
		return "grenade"
	end
	if nameSet.MagPart or nameSet.BoltPart or nameSet.SlidePart or nameSet.Slide
		or nameSet.Barrel or nameSet.ActualBoltPart
	then
		return "gun"
	end
	if nameSet.KatanaMesh or nameSet.ClubMesh or nameSet.Crowbar or nameSet.Blade
		or nameSet.WeaponHandle or nameSet.WeaponHandle2
	then
		return "melee"
	end
	return "other"
end

function gunWatch.identify(model)
	local cached = gunWatch.idCache[model]
	if cached and cached[3] == true and cached[1] and not gunWatch.weakLabels[cached[1]] then
		return cached[1], cached[2]
	end
	local rem = gunWatch.remember

	for _, key in ipairs({ "Name", "Item", "ToolName", "GunName", "DisplayName" }) do
		local val = model:GetAttribute(key)
		if val ~= nil and tostring(val) ~= "" then
			local label = tostring(val)
			local nameSet = {}
			for _, d in ipairs(model:GetDescendants()) do
				nameSet[d.Name] = true
			end
			return rem(model, string.upper(label), gunWatch.classifyFromSet(nameSet, label), true)
		end
	end

	-- One GetDescendants pass (old path: many FindFirstChild + listAllWeapons sorts)
	local nameSet = {}
	local fromSa, fromMesh
	local meshMap = misc.skinChanger and misc.skinChanger.meshToGun
	for _, d in ipairs(model:GetDescendants()) do
		nameSet[d.Name] = true
		if d:IsA("SurfaceAppearance") and not fromSa then
			local us = string.find(d.Name, "_", 1, true)
			if us and us > 1 then
				fromSa = string.sub(d.Name, 1, us - 1)
			end
		elseif d:IsA("BasePart") then
			local n = d.Name
			if not fromMesh and string.sub(n, -4) == "Mesh" and #n > 4 then
				fromMesh = string.sub(n, 1, #n - 4)
			end
			if d:IsA("MeshPart") and meshMap then
				local mid = ""
				pcall(function()
					mid = tostring(d.MeshId or "")
				end)
				local g = meshMap[mid]
				if g then
					return rem(model, string.upper(g), gunWatch.classifyFromSet(nameSet, g), true)
				end
			end
		end
	end

	if fromSa then
		return rem(model, string.upper(fromSa), gunWatch.classifyFromSet(nameSet, fromSa), true)
	end
	if fromMesh then
		return rem(model, string.upper(fromMesh), gunWatch.classifyFromSet(nameSet, fromMesh), true)
	end
	local fromKnown = gunWatch.nameFromKnown(nameSet)
	if fromKnown then
		return rem(model, string.upper(fromKnown), gunWatch.classifyFromSet(nameSet, fromKnown), true)
	end

	if nameSet.Crowbar then
		return rem(model, "CROWBAR", "melee", false)
	end
	if nameSet.ClubMesh then
		return rem(model, "CLUB", "melee", true)
	end
	if nameSet.KatanaMesh then
		return rem(model, "KATANA", "melee", true)
	end
	if nameSet.Wrench and not nameSet.Crowbar then
		return rem(model, "WRENCH", "melee", false)
	end
	if nameSet.Pin and nameSet.He and not nameSet.MagPart then
		return rem(model, "GRENADE", "grenade", true)
	end
	if nameSet.Chain1 or (nameSet.Blade and nameSet.Cord) then
		return rem(model, "CHAINSAW", "melee", false)
	end
	if nameSet.BoltPart and nameSet.MagPart then
		return rem(model, "RIFLE", "gun", false)
	end
	if nameSet.MagPart and (nameSet.Barrel or nameSet.SlidePart or nameSet.Slide) then
		return rem(model, "PISTOL", "gun", false)
	end
	if nameSet.MagPart then
		return rem(model, "GUN", "gun", false)
	end
	if nameSet.WeaponHandle or nameSet.WeaponHandle2 then
		return rem(model, "WEAPON", "melee", false)
	end

	local n = string.upper(tostring(model.Name or ""))
	if n:find("HELMET", 1, true) or n:find("VEST", 1, true) or n:find("ARMOR", 1, true)
		or n:find("KEVLAR", 1, true) or n:find("BALACLAVA", 1, true)
	then
		return rem(model, n, "armor", true)
	end
	if nameSet.OriginPart and not nameSet.MagPart and not nameSet.WeaponHandle then
		return rem(model, "ARMOR", "armor", false)
	end
	return rem(model, "ITEM", "other", false)
end

function gunWatch.getPart(model)
	if not model then
		return nil
	end
	for _, name in ipairs({
		"WeaponHandle",
		"WeaponHandle2",
		"KatanaMesh",
		"ClubMesh",
		"HandlePart",
		"Handle",
	}) do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	local meshNamed = gunWatch.nameFromMesh(model)
	if meshNamed then
		local p = model:FindFirstChild(meshNamed .. "Mesh", true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return getModelPart(model)
end

-- Call-sites use gunWatch.identify / getPart / hasDeep / byModel / idCache

function gunWatch.kindColor(kind, S)
	if kind == "gun" then
		return S.CrimGunESPGunColor or COLORS.gun
	end
	if kind == "grenade" then
		return COLORS.nade
	end
	if kind == "melee" then
		return S.CrimGunESPMeleeColor or COLORS.melee
	end
	return COLORS.tool
end

function gunWatch.shouldShow(S, kind)
	if not S.CrimGunESP then
		return false
	end
	if kind == "gun" or kind == "grenade" then
		return S.CrimGunESPGuns ~= false
	end
	if kind == "melee" then
		return S.CrimGunESPMelee ~= false
	end
	return true
end

function gunWatch.isModel(model)
	return model and model:IsA("Model")
end

function gunWatch.filterFolder()
	return workspace:FindFirstChild("Filter")
end

function gunWatch.spawnedFolder()
	local filter = gunWatch.filterFolder()
	if not filter then
		return nil
	end
	return filter:FindFirstChild("SpawnedTools")
end

function gunWatch.inFolder(model)
	local folder = gunWatch.spawnedFolder()
	if not folder or not model then
		return false
	end
	return model:IsDescendantOf(folder)
end

function gunWatch.iterModels(folder)
	local models = {}
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			table.insert(models, ch)
		elseif ch:IsA("Folder") then
			for _, sub in ipairs(ch:GetChildren()) do
				if sub:IsA("Model") then
					table.insert(models, sub)
				end
			end
		end
	end
	return models
end

function gunWatch.destroyEntry(model)
	local e = gunWatch.byModel[model]
	if not e then return end
	gunWatch.byModel[model] = nil
	gunWatch.idCache[model] = nil
	if e.hOwned ~= false and alive(e.h) then
		e.h:Destroy()
	end
	if alive(e.bg) then e.bg:Destroy() end
	for i, entry in ipairs(ESP.guns) do
		if entry == e then
			table.remove(ESP.guns, i)
			break
		end
	end
end

function gunWatch.sweepOrphans()
	local gui = getGui()
	local folder = gunWatch.spawnedFolder()
	if not gui or not folder then
		return
	end
	for _, ch in ipairs(gui:GetChildren()) do
		if ch:IsA("Highlight") and ch.Adornee and ch.Adornee:IsA("Model") then
			if ch.Adornee:IsDescendantOf(folder) and not gunWatch.byModel[ch.Adornee] then
				ch:Destroy()
			end
		elseif ch:IsA("BillboardGui") and ch.Adornee and ch.Adornee:IsA("BasePart") then
			local model = ch.Adornee:FindFirstAncestorOfClass("Model")
			if model and model:IsDescendantOf(folder) and not gunWatch.byModel[model] then
				ch:Destroy()
			end
		end
	end
end

function gunWatch.clear()
	for model in pairs(gunWatch.byModel) do
		gunWatch.destroyEntry(model)
	end
	table.clear(ESP.guns)
	table.clear(gunWatch.byModel)
	gunWatch.sweepOrphans()
end

function gunWatch.playSpawnFx(entry, fill)
	if not entry or not alive(entry.h) then
		return
	end
	entry.visState = true
	entry.h.Enabled = true
	entry.h.FillColor = fill
	entry.h.FillTransparency = 1
	entry.h.OutlineTransparency = 1
	if alive(entry.bg) then
		entry.bg.Enabled = true
		entry.bg.StudsOffset = Vector3.new(0, 1.5, 0)
	end
	local popIn = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TS:Create(entry.h, popIn, { FillTransparency = 0.42, OutlineTransparency = 0 }):Play()
	if alive(entry.bg) then
		TS:Create(entry.bg, popIn, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	end
end

function gunWatch.add(model, S, withSpawnFx)
	if not gunWatch.isModel(model) or gunWatch.byModel[model] then
		return false
	end
	local label, kind = gunWatch.identify(model)
	if not gunWatch.shouldShow(S, kind) then
		return false
	end
	local fill = gunWatch.kindColor(kind, S)
	local ok, entry = pcall(makeEntry, model, fill, Color3.fromRGB(255, 255, 255), label, nil)
	if not ok or not entry then
		return false
	end
	entry.hOwned = true
	local existingHl = model:FindFirstChildWhichIsA("Highlight")
	if existingHl then
		if alive(entry.h) then
			entry.h:Destroy()
		end
		entry.h = existingHl
		entry.hOwned = false
		existingHl.FillColor = fill
		existingHl.OutlineColor = Color3.fromRGB(255, 255, 255)
		existingHl.FillTransparency = 0.55
		existingHl.OutlineTransparency = 0
		existingHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		existingHl.Adornee = model
		existingHl.Enabled = false
	end
	local wh = gunWatch.getPart(model)
	if wh and wh:IsA("BasePart") then
		entry.part = wh
		if alive(entry.bg) then entry.bg.Adornee = wh end
	elseif alive(entry.part) and alive(entry.bg) then
		entry.bg.Adornee = entry.part
	end
	if alive(entry.bg) then
		entry.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 22, 64, 140), 0, 20)
	end
	entry.kind = kind
	entry.label = label
	gunWatch.byModel[model] = entry
	table.insert(ESP.guns, entry)
	if withSpawnFx then
		gunWatch.playSpawnFx(entry, fill)
	end
	return true
end

function gunWatch.sync(S)
	if not S.CrimGunESP then
		if #ESP.guns > 0 then
			gunWatch.clear()
		end
		return
	end

	local folder = gunWatch.spawnedFolder()
	if not folder then
		return
	end

	for i = #ESP.guns, 1, -1 do
		local e = ESP.guns[i]
		local model = e.model
		local keep = alive(model) and gunWatch.isModel(model) and gunWatch.inFolder(model)
		if keep then
			local label, kind = gunWatch.identify(model)
			keep = gunWatch.shouldShow(S, kind)
			if keep and (e.label ~= label or e.kind ~= kind) then
				e.label = label
				e.kind = kind
				local fill = gunWatch.kindColor(kind, S)
				if alive(e.h) then e.h.FillColor = fill end
				if alive(e.lbl) then e.lbl.Text = label end
				if alive(e.bg) then
					e.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 22, 64, 122), 0, 20)
				end
			end
		end
		if not keep then
			gunWatch.destroyEntry(model)
		end
	end

	for _, model in ipairs(gunWatch.iterModels(folder)) do
		gunWatch.add(model, S, false)
	end
end

function gunWatch.bindFolder(folder)
	if gunWatch.folderWatch then
		gunWatch.folderWatch:Disconnect()
		gunWatch.folderWatch = nil
	end
	if gunWatch.folderConn then
		gunWatch.folderConn:Disconnect()
		gunWatch.folderConn = nil
	end
	if gunWatch.removeConn then
		gunWatch.removeConn:Disconnect()
		gunWatch.removeConn = nil
	end
	gunWatch.folderConn = folder.ChildAdded:Connect(function(ch)
			task.defer(function()
				local curS = _G.__VG_S
				if not curS then
					return
				end
				RS.Heartbeat:Wait()
				task.wait(0.2)
				local targets = ch:IsA("Model") and { ch } or gunWatch.iterModels(ch)
				if curS.CrimGunESP then
					for _, model in ipairs(targets) do
						gunWatch.idCache[model] = nil
						local added = gunWatch.add(model, curS, true)
						if added then
							pcall(tickESP, curS)
						end
					end
				end
				if curS.CrimSkinDropped and misc.skinChanger and misc.skinChanger.applyToDroppedModel then
					for _, model in ipairs(targets) do
						pcall(misc.skinChanger.applyToDroppedModel, model)
					end
				end
		end)
	end)
	gunWatch.removeConn = folder.ChildRemoved:Connect(function(ch)
		if ch:IsA("Model") then
			gunWatch.destroyEntry(ch)
		else
			for _, model in ipairs(gunWatch.iterModels(ch)) do
				gunWatch.destroyEntry(model)
			end
		end
	end)
end

function gunWatch.ensure(S)
	local folder = gunWatch.spawnedFolder()
	if folder then
		gunWatch.bindFolder(folder)
		return
	end

	local filter = gunWatch.filterFolder()
	if filter then
		if not gunWatch.folderWatch then
			gunWatch.folderWatch = filter.ChildAdded:Connect(function(ch)
				if ch.Name ~= "SpawnedTools" then
					return
				end
				task.defer(function()
					local curS = _G.__VG_S
					if curS and curS.CrimGunESP then
						gunWatch.bindFolder(ch)
						gunWatch.sync(curS)
					end
				end)
			end)
		end
		return
	end

	if gunWatch.folderWatch then
		return
	end
	gunWatch.folderWatch = workspace.ChildAdded:Connect(function(ch)
		if ch.Name ~= "Filter" then
			return
		end
		task.defer(function()
			local curS = _G.__VG_S
			if curS and curS.CrimGunESP then
				gunWatch.ensure(curS)
				gunWatch.sync(curS)
			end
		end)
	end)
end

-- Hot path: zero allocations, no pcall on happy path.

local function tickESP(S)
	local maxDist = S.CrimESPMaxDist or 300
	local crateDist = S.CrimCrateMaxDist or maxDist
	local gunDist = S.CrimGunESPMaxDist or maxDist
	local camPos  = workspace.CurrentCamera.CFrame.Position

	-- Safes / registers (BredMakurz â†’ Values.Broken)
	local showSafe = S.CrimSafeESP
	local showBroken = S.CrimSafeShowBroken == true
	for _, e in ipairs(ESP.safes) do
		local vis = false
		if showSafe and alive(e.part) then
			local open = e.broken and e.broken.Value == true
			if open and not showBroken then
				vis = false
			else
				vis = (camPos - e.part.Position).Magnitude <= maxDist
			end
		end
		if alive(e.h) then
			if vis then
				local open   = e.broken and e.broken.Value == true
				local newCol = open and COLORS.open or (S.CrimSafeColor or COLORS.safeD)
				if e.h.FillColor ~= newCol then
					e.h.FillColor = newCol
					if e.stroke and e.stroke.Parent then e.stroke.Color = newCol end
				end
				local base = e.baseLabel or "SAFE"
				local newTxt = open and ("OPEN " .. base) or base
				if e.lbl.Text ~= newTxt then e.lbl.Text = newTxt end
				espShow(e)
			else
				espHide(e)
			end
		end
	end

	-- Dealers (RebelDealer = map-wide, ignore CrimESPMaxDist)
	local showDlr = S.CrimDealerESP
	for _, e in ipairs(ESP.dealers) do
		local vis = false
		if showDlr and alive(e.part) then
			if e.rebel then
				vis = true
			else
				vis = (camPos - e.part.Position).Magnitude <= maxDist
			end
		end
		if alive(e.h) then
			if vis then espShow(e) else espHide(e) end
		end
	end

	-- Crates
	local showCrate = S.CrimCrateESP
	for _, e in ipairs(ESP.crates) do
		local vis = false
		if showCrate and alive(e.model) and isInSpawnedPiles(e.model) then
			if not alive(e.part) or not isReasonableCratePart(e.part) then
				e.part = getCrateVisualPart(e.model)
			end
			if alive(e.part) then
				if alive(e.bg) and e.bg.Adornee ~= e.part then
					e.bg.Adornee = e.part
				end
				-- Airdrop (cot_=10): always map-wide, ignore Crate View Distance
				if e.airdrop or e.kind == "airdrop" then
					vis = true
				else
					vis = (camPos - e.part.Position).Magnitude <= crateDist
				end
			end
		end
		if alive(e.h) then
			if vis then espShow(e) else espHide(e) end
		end
	end

	-- Guns / dropped tools (SpawnedTools)
	local showGun = S.CrimGunESP
	for _, e in ipairs(ESP.guns) do
		local vis = false
		if showGun and alive(e.model) and gunWatch.inFolder(e.model) then
			if not gunWatch.shouldShow(S, e.kind or "other") then
				vis = false
			else
			if not alive(e.part) then
				e.part = gunWatch.getPart(e.model)
			end
			if alive(e.part) then
				if alive(e.bg) and e.bg.Adornee ~= e.part then
					e.bg.Adornee = e.part
				end
				if alive(e.h) and e.h.Adornee ~= e.model then
					e.h.Adornee = e.model
				end
				vis = (camPos - e.part.Position).Magnitude <= gunDist
			end
			end
		end
		if alive(e.h) then
			if vis then espShow(e) else espHide(e) end
		end
	end
end

-- â”€â”€ CRATE AUTO PICKUP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- ReplicatedStorage.Events.PIC_PU:FireServer(crateId)

-- Packed into one table to stay under Luau's 200-local limit.
local cratePu = { remote = nil, lastAt = 0, cooldownIds = {}, fxByModel = {}, FX_DURATION = 2.0 }

local function getPicPuRemote()
	if cratePu.remote and cratePu.remote.Parent then
		return cratePu.remote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("PIC_PU")
	if ev and ev:IsA("RemoteEvent") then
		cratePu.remote = ev
		return ev
	end
	return nil
end

local function getCrateId(model)
	if not model then
		return nil
	end
	local id = model:GetAttribute("Id")
	if id == nil then
		return nil
	end
	return tostring(id)
end

local function getCratePart(model)
	return getCrateVisualPart(model, true)
end

local function getCrateDist(model)
	local hrp = getHRP()
	local part = getCratePart(model)
	if not hrp or not part then
		return math.huge
	end
	return (hrp.Position - part.Position).Magnitude
end

local function shouldPickupCrate(S, model)
	if not S.CrimCratePickup then
		return false
	end
	if not isCrateModel(model) then
		return false
	end
	local kind = getCrateKind(model)
	if kind == "airdrop" then
		return S.CrimCratePickupAirdrop ~= false
	end
	if kind == "rare" then
		return S.CrimCratePickupRare ~= false
	end
	return S.CrimCratePickupBasic ~= false
end

local function stopPickupFx(model)
	local fx = cratePu.fxByModel[model]
	if not fx then
		return
	end
	cratePu.fxByModel[model] = nil
	if fx.pulseTween then
		pcall(function() fx.pulseTween:Cancel() end)
	end
	if fx.bobTween then
		pcall(function() fx.bobTween:Cancel() end)
	end
	if alive(fx.h) then
		fx.h:Destroy()
	end
	if alive(fx.bg) then
		fx.bg:Destroy()
	end
end

local function clearAllPickupFx()
	for model in pairs(cratePu.fxByModel) do
		stopPickupFx(model)
	end
end

local function startPickupFx(model, kind)
	if not model or not alive(model) then
		return
	end
	for m in pairs(cratePu.fxByModel) do
		if m ~= model then
			stopPickupFx(m)
		end
	end
	if cratePu.fxByModel[model] then
		return
	end

	local part = getCratePart(model)
	if not part then
		return
	end

	local fill = Color3.fromRGB(60, 255, 130)
	local txt = "PICKING UP"
	if kind == "airdrop" then
		fill = COLORS.crateAirdrop
		txt = "AIRDROP PICKUP"
	elseif kind == "rare" then
		fill = Color3.fromRGB(255, 70, 255)
		txt = "RARE PICKUP"
	end
	local gui = getGui()

	local h = Instance.new("Highlight")
	h.Name = "VG_CratePickupFx"
	h.FillColor = fill
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.3
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = model
	h.Parent = gui

	local bg = Instance.new("BillboardGui")
	bg.Name = "VG_CratePickupFx"
	bg.Size = UDim2.new(0, 96, 0, 24)
	bg.StudsOffset = Vector3.new(0, 5, 0)
	bg.AlwaysOnTop = true
	bg.Adornee = part
	bg.Parent = gui

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = txt
	lbl.TextColor3 = fill
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.2
	lbl.Parent = bg

	local fx = { h = h, bg = bg, lbl = lbl, model = model }
	cratePu.fxByModel[model] = fx

	local pulseInfo = TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	fx.pulseTween = TS:Create(h, pulseInfo, { FillTransparency = 0.72, OutlineTransparency = 0.35 })
	fx.pulseTween:Play()

	local bobInfo = TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	fx.bobTween = TS:Create(bg, bobInfo, { StudsOffset = Vector3.new(0, 6.4, 0) })
	fx.bobTween:Play()

	task.delay(cratePu.FX_DURATION, function()
		if cratePu.fxByModel[model] == fx then
			stopPickupFx(model)
		end
	end)
end

local function getCrateFireDist(S)
	return math.clamp(tonumber(S.CrimCratePickupDist) or 3.5, 2, 8)
end

local function tryPickupCrate(S, model)
	local dist = getCrateDist(model)
	if dist > getCrateFireDist(S) then
		return false
	end
	local id = getCrateId(model)
	if not id then
		return false
	end
	local now = tick()
	if cratePu.cooldownIds[id] and now - cratePu.cooldownIds[id] < 2.5 then
		return false
	end
	local remote = getPicPuRemote()
	if not remote then
		return false
	end
	if S.CrimCratePickupFx ~= false then
		startPickupFx(model, getCrateKind(model))
	end
	local ok = pcall(function()
		remote:FireServer(id)
	end)
	if ok then
		cratePu.cooldownIds[id] = now
		cratePu.lastAt = now
	elseif S.CrimCratePickupFx ~= false then
		stopPickupFx(model)
	end
	return ok
end

local function tickCratePickup(S)
	if not S.CrimCratePickup then
		return
	end
	local now = tick()
	local delay = math.max(0.08, (tonumber(S.CrimCratePickupDelay) or 200) / 1000)
	if now - cratePu.lastAt < delay then
		return
	end

	local piles = getSpawnedPiles()
	if not piles then
		return
	end

	local fireDist = getCrateFireDist(S)
	local best, bestScore = nil, math.huge

	for _, model in ipairs(piles:GetChildren()) do
		if alive(model) and shouldPickupCrate(S, model) then
			local dist = getCrateDist(model)
			if dist <= fireDist then
				local kind = getCrateKind(model)
				-- Priority: airdrop > rare > basic
				local bonus = 2000
				if kind == "airdrop" then
					bonus = 0
				elseif kind == "rare" then
					bonus = 1000
				end
				local score = dist + bonus
				if score < bestScore then
					bestScore = score
					best = model
				end
			end
		end
	end

	if best then
		tryPickupCrate(S, best)
	end

	for id, t in pairs(cratePu.cooldownIds) do
		if now - t > 12 then
			cratePu.cooldownIds[id] = nil
		end
	end
end

-- â”€â”€ AUTO PICKUP MONEY (SpawnedBread + CZDPZUS) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- Packed into one table to stay under Luau's 200-local limit.
local moneyPu = { remote = nil, lastAt = 0 }

local function getMoneyPickupRemote()
	if moneyPu.remote and moneyPu.remote.Parent then
		return moneyPu.remote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("CZDPZUS")
	if ev and ev:IsA("RemoteEvent") then
		moneyPu.remote = ev
		return ev
	end
	return nil
end

local function getSpawnedBread()
	local filter = workspace:FindFirstChild("Filter")
	if not filter then
		return nil
	end
	return filter:FindFirstChild("SpawnedBread")
end

local function getMoneyItemPosition(item)
	if not item then
		return nil
	end
	if item:IsA("BasePart") then
		return item.Position
	end
	if item:IsA("Model") then
		local part = getModelPart(item)
		return part and part.Position
	end
	return nil
end

local function tickMoneyPickup(S)
	if not S.CrimMoneyPickup then
		return
	end

	local hum = getHum()
	if not hum or hum.Health <= 0 then
		return
	end
	local hrp = getHRP()
	if not hrp then
		return
	end

	local now = tick()
	local delay = math.max(0.5, (tonumber(S.CrimMoneyPickupDelay) or 1000) / 1000)
	if now - moneyPu.lastAt < delay then
		return
	end

	local folder = getSpawnedBread()
	local remote = getMoneyPickupRemote()
	if not folder or not remote then
		return
	end

	local maxDist = math.clamp(tonumber(S.CrimMoneyPickupDist) or 5, 2, 25)
	local rootPos = hrp.Position
	local best, bestDist = nil, maxDist

	for _, item in ipairs(folder:GetChildren()) do
		if alive(item) then
			local itemPos = getMoneyItemPosition(item)
			if itemPos then
				local dist = (rootPos - itemPos).Magnitude
				if dist <= maxDist and dist < bestDist then
					bestDist = dist
					best = item
				end
			end
		end
	end

	if best then
		local ok = pcall(function()
			remote:FireServer(best)
		end)
		if ok then
			moneyPu.lastAt = now
		end
	end
end

-- â”€â”€ AUTO CLAIM ALLOWANCE (CLMZALOW + PlayerbaseData2.NextAllowance.Claim) â”€â”€â”€

local allow = { remote=nil, lastAt=0, atm=nil }

local function getAllowanceRemote()
	if allow.remote and allow.remote.Parent then
		return allow.remote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("CLMZALOW")
	if ev and (ev:IsA("RemoteFunction") or ev:IsA("RemoteEvent")) then
		allow.remote = ev
		return ev
	end
	return nil
end

local function getAllowanceClaimFlag()
	local lp = getLP()
	if not lp then
		return false
	end
	local data = RepSt:FindFirstChild("PlayerbaseData2")
	if not data then
		return false
	end
	local folder = data:FindFirstChild(lp.Name)
	if not folder then
		return false
	end
	local nextAllow = folder:FindFirstChild("NextAllowance")
	if not nextAllow then
		return false
	end
	local claim = nextAllow:FindFirstChild("Claim")
	return claim and claim:IsA("BoolValue") and claim.Value == true
end

local function getAtmMainPart(atm)
	if not atm then
		return nil
	end
	local main = atm:FindFirstChild("MainPart", true)
	if main and main:IsA("BasePart") then
		return main
	end
	return getModelPart(atm)
end

local function findNearestAtmPart(rootPos, maxDist)
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("ATMz")
	if not folder then
		return nil
	end
	local best, bestDist = nil, maxDist or math.huge
	for _, atm in ipairs(folder:GetChildren()) do
		if alive(atm) then
			local part = getAtmMainPart(atm)
			if part then
				local dist = (rootPos - part.Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = part
				end
			end
		end
	end
	return best
end

local function syncAllowanceAtmESP(S)
	if not S.CrimAllowanceClaim or not getAllowanceClaimFlag() then
		if allow.atm then
			if alive(allow.atm.h) then allow.atm.h:Destroy() end
			if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
			allow.atm = nil
		end
		return
	end
	local hrp = getHRP()
	if not hrp then
		if allow.atm then
			if alive(allow.atm.h) then allow.atm.h:Destroy() end
			if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
			allow.atm = nil
		end
		return
	end
	local part = findNearestAtmPart(hrp.Position, nil)
	if not part then
		if allow.atm then
			if alive(allow.atm.h) then allow.atm.h:Destroy() end
			if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
			allow.atm = nil
		end
		return
	end
	if allow.atm and allow.atm.part == part then
		if alive(allow.atm.h) and not allow.atm.h.Enabled then
			allow.atm.h.Enabled = true
		end
		if alive(allow.atm.bg) and not allow.atm.bg.Enabled then
			allow.atm.bg.Enabled = true
		end
		return
	end
	if allow.atm then
		if alive(allow.atm.h) then allow.atm.h:Destroy() end
		if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
		allow.atm = nil
	end
	local model = part:FindFirstAncestorOfClass("Model") or part.Parent
	local ok, entry = pcall(makeEntry, model, Color3.fromRGB(90, 210, 255),
		Color3.fromRGB(255, 255, 255), "ATM", nil, part)
	if not ok or not entry then
		return
	end
	entry.h.Name = "VG_AllowanceAtm"
	entry.bg.Name = "VG_AllowanceAtm"
	entry.h.Enabled = true
	entry.bg.Enabled = true
	allow.atm = entry
end

local function tickAllowanceClaim(S)
	if not S.CrimAllowanceClaim then
		if allow.atm then
			if alive(allow.atm.h) then allow.atm.h:Destroy() end
			if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
			allow.atm = nil
		end
		return
	end
	syncAllowanceAtmESP(S)
	if not getAllowanceClaimFlag() then
		return
	end

	local hum = getHum()
	if not hum or hum.Health <= 0 then
		return
	end
	local hrp = getHRP()
	if not hrp then
		return
	end

	local now = tick()
	local delay = math.max(1, (tonumber(S.CrimAllowanceClaimDelay) or 3000) / 1000)
	if now - allow.lastAt < delay then
		return
	end

	local remote = getAllowanceRemote()
	if not remote then
		return
	end

	local maxDist = math.clamp(tonumber(S.CrimAllowanceClaimDist) or 12, 4, 30)
	local atmPart = findNearestAtmPart(hrp.Position, maxDist)
	if not atmPart then
		return
	end

	local ok
	if remote:IsA("RemoteFunction") then
		ok = pcall(function()
			remote:InvokeServer(atmPart, nil)
		end)
	else
		ok = pcall(function()
			remote:FireServer(atmPart, nil)
		end)
	end
	if ok then
		allow.lastAt = now
	end
end

-- â”€â”€ FAST PICKUP (PIC_TLO â€” guns/melee on ground) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Cobalt dump uses getnilinstances + WeaponHandle; we resolve dynamically.

-- Packed to stay under Luau's 200-local limit
local fastPu = { remote = nil, prompt = nil, target = nil, lastAt = 0, inputConn = nil }

local function getPicTloRemote()
	if fastPu.remote and fastPu.remote.Parent then
		return fastPu.remote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("PIC_TLO")
	if ev and ev:IsA("RemoteEvent") then
		fastPu.remote = ev
		return ev
	end
	return nil
end

-- Guns use WeaponHandle; helmet/vest use OriginPart (often in getnilinstances).
local function resolvePickupHandle(model)
	if not model then
		return nil
	end
	local wh = model:FindFirstChild("WeaponHandle", true)
	if wh and wh:IsA("BasePart") then
		return wh
	end
	local origin = model:FindFirstChild("OriginPart", true)
	if origin and origin:IsA("BasePart") then
		return origin
	end
	local handle = model:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		return handle
	end
	if typeof(getnilinstances) == "function" then
		local anchor = getModelPart(model)
		if anchor then
			local pos = anchor.Position
			local best, bestDist = nil, 12
			for _, obj in ipairs(getnilinstances()) do
				if obj:IsA("BasePart") and (obj.Name == "WeaponHandle" or obj.Name == "OriginPart") then
					local d = (obj.Position - pos).Magnitude
					if d < bestDist then
						bestDist = d
						best = obj
					end
				end
			end
			return best
		end
	end
	return nil
end

-- Nearest helmet/vest OriginPart sitting in nil (Cobalt dumps). No hardcoded DebugId.
local function findNearestNilArmorOrigin(maxDist)
	if typeof(getnilinstances) ~= "function" then
		return nil, math.huge
	end
	local hrp = getHRP()
	if not hrp then
		return nil, math.huge
	end
	local best, bestDist = nil, maxDist
	local ok, list = pcall(getnilinstances)
	if not ok or type(list) ~= "table" then
		return nil, math.huge
	end
	for _, obj in ipairs(list) do
		if obj and obj.Name == "OriginPart" and obj:IsA("BasePart") then
			local d = (obj.Position - hrp.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = obj
			end
		end
	end
	return best, bestDist
end

local function getToolPickupDist(model)
	local hrp = getHRP()
	local part = getModelPart(model)
	if not hrp or not part then
		return math.huge
	end
	return (hrp.Position - part.Position).Magnitude
end

local function shouldFastPickupItem(S, model)
	if not S.CrimFastPickup then
		return false
	end
	if not gunWatch.isModel(model) or not alive(model) then
		return false
	end
	local _, kind = gunWatch.identify(model)
	if kind == "gun" or kind == "grenade" then
		return S.CrimFastPickupGuns ~= false
	end
	if kind == "melee" then
		return S.CrimFastPickupMelee ~= false
	end
	if kind == "armor" then
		return S.CrimFastPickupArmor ~= false
	end
	return true
end

local function hideFastPickupPrompt()
	fastPu.target = nil
	if fastPu.prompt and alive(fastPu.prompt) then
		fastPu.prompt.Enabled = false
	end
end

local function ensureFastPickupPrompt()
	if fastPu.prompt and alive(fastPu.prompt) then
		return
	end
	local bg = Instance.new("BillboardGui")
	bg.Name = "VG_FastPickup"
	bg.Size = UDim2.new(0, 40, 0, 40)
	bg.StudsOffset = Vector3.new(0, 2.8, 0)
	bg.AlwaysOnTop = true
	bg.Enabled = false
	bg.Parent = getGui()

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Q"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextSize = 24
	lbl.Font = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.15
	lbl.Parent = bg

	fastPu.prompt = bg
end

-- target = { handle, model?, adornee, kind }
local function showFastPickupPrompt(target)
	ensureFastPickupPrompt()
	local part = target and (target.adornee or target.handle)
	if not part or not fastPu.prompt then
		hideFastPickupPrompt()
		return
	end
	fastPu.target = target
	fastPu.prompt.Adornee = part
	fastPu.prompt.Enabled = true
end

local function findNearestFastPickup(S)
	local maxDist = math.clamp(tonumber(S.CrimFastPickupRange) or 6, 2, 15)
	local best, bestDist = nil, maxDist

	local folder = gunWatch.spawnedFolder()
	if folder then
		for _, model in ipairs(gunWatch.iterModels(folder)) do
			if shouldFastPickupItem(S, model) then
				local dist = getToolPickupDist(model)
				if dist <= maxDist and dist < bestDist then
					local handle = resolvePickupHandle(model)
					if handle then
						bestDist = dist
						best = {
							handle = handle,
							model = model,
							adornee = getModelPart(model) or handle,
							kind = select(2, gunWatch.identify(model)),
						}
					end
				end
			end
		end
	end

	-- Helmet / vest: OriginPart often lives in nil, not under SpawnedTools
	if S.CrimFastPickupArmor ~= false then
		local origin, od = findNearestNilArmorOrigin(maxDist)
		if origin and od < bestDist then
			bestDist = od
			best = { handle = origin, adornee = origin, kind = "armor" }
		end
	end

	return best
end

local function tryFastPickup(target)
	if type(target) ~= "table" or not target.handle then
		return false
	end
	local S = _G.__VG_S
	if not S or not S.CrimFastPickup then
		return false
	end
	local hrp = getHRP()
	if not hrp then
		return false
	end
	local maxDist = math.clamp(tonumber(S.CrimFastPickupRange) or 6, 2, 15)
	if (hrp.Position - target.handle.Position).Magnitude > maxDist + 1 then
		return false
	end
	local now = tick()
	if now - fastPu.lastAt < 0.35 then
		return false
	end
	local remote = getPicTloRemote()
	if not remote then
		return false
	end
	local ok = pcall(function()
		remote:FireServer(target.handle, nil, nil)
	end)
	if ok then
		fastPu.lastAt = now
		if target.model then
			gunWatch.destroyEntry(target.model)
		end
		hideFastPickupPrompt()
	end
	return ok
end

local function tickFastPickup(S)
	if not S.CrimFastPickup then
		hideFastPickupPrompt()
		return
	end
	local hum = getHum()
	if not hum or hum.Health <= 0 then
		hideFastPickupPrompt()
		return
	end
	local nearest = findNearestFastPickup(S)
	if nearest then
		showFastPickupPrompt(nearest)
	else
		hideFastPickupPrompt()
	end
end

local function startFastPickupInput()
	if fastPu.inputConn or not UIS then
		return
	end
	fastPu.inputConn = UIS.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Q then
			return
		end
		local S = _G.__VG_S
		if not S or not S.CrimFastPickup or not fastPu.target then
			return
		end
		tryFastPickup(fastPu.target)
	end)
end

local function stopFastPickupInput()
	if fastPu.inputConn then
		fastPu.inputConn:Disconnect()
		fastPu.inputConn = nil
	end
	hideFastPickupPrompt()
	if fastPu.prompt and alive(fastPu.prompt) then
		fastPu.prompt:Destroy()
		fastPu.prompt = nil
	end
end

-- â”€â”€ GUN MODS (weapon GC tables: recoil / spread / equip) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local featureRunning = {
	noFall = false,
	noSpike = false,
	noRagdoll = false,
	ragdollDrag = false,
	fastAccel = false,
	gunMods = false,
	staffDetect = false,
	noFailLockpick = false,
	fullBright = false,
	noFog = false,
	skipIntro = false,
	skinChanger = false,
	hitSounds = false,
	autoRespawn = false,
	removeSmoke = false,
	hideHelmet = false,
}
local gunMod = {
	conns = {},
	charConns = {},
	scanToken = 0,
	cache = {},
	orig = {},
	lastApplyAt = 0,
	lastDeepAt = 0,
	lastScanAt = 0,
	reapplyInterval = 15,
	rescanInterval = 90, -- rare: getgc is 50–250ms even off-thread
	deepCooldown = 18,
	scanCooldown = 6,
	lastReloadAt = 0,
	reloadBusy = false,
	scanning = false,
	toolChangeAt = 0,
	lastApplyOnlyAt = 0,
}

-- Heavy work MUST leave the Heartbeat frame first. Some executors run
-- task.defer inline — that put getgc inside Criminality.Main (max~110ms hitch).
local heavy = { queue = {}, busy = false }

local function runHeavy(fn)
	if typeof(fn) ~= "function" then
		return
	end
	table.insert(heavy.queue, fn)
	if heavy.busy then
		return
	end
	heavy.busy = true
	task.spawn(function()
		while #heavy.queue > 0 do
			local job = table.remove(heavy.queue, 1)
			task.wait() -- next frame — guaranteed off Heartbeat
			pcall(job)
			task.wait() -- breathe so consecutive getgc/ESP scans don't stack hitch
		end
		heavy.busy = false
	end)
end

-- `orig` is keyed by live getgc() weapon tables. Firing/reloading makes some
-- games re-create their weapon stat table, so getgc scans can pick up a
-- steady trickle of *different* table identities over a play session. Regular
-- (strong) keys would pin every one of those snapshots in memory forever ÔÇö
-- exactly the "freeze + climbing RAM while shooting" bug. Weak keys let Lua
-- collect a weapon snapshot the moment the game itself drops the table,
-- without changing any read/write behavior of gunMod.orig elsewhere.
setmetatable(gunMod.orig, { __mode = "k" })

-- Extra numeric fields that help 3rd-person kick / walk bloom when present.
-- Folded into gunMod table to save a register.
gunMod.EXTRA_KEYS = {
	"WalkSpreadIncrease",
	"HipSpread",
	"AimSpread",
	"MinSpread",
	"MaxSpread",
	"CamShake",
	"CameraShake",
	"Kick",
	"RecoilPunch",
	"VRecoil",
	"HRecoil",
}

local function isWeaponTable(v)
	return type(v) == "table" and rawget(v, "EquipTime") ~= nil
end

local function gunSet(weapon, key, value)
	if rawget(weapon, key) ~= nil then
		weapon[key] = value
	end
end

local function gunRestore(weapon, orig, key)
	if orig[key] ~= nil then
		weapon[key] = orig[key]
	end
end

local function captureWeaponOrig(v)
	local o = {
		Recoil = v.Recoil,
		CameraRecoilingEnabled = v.CameraRecoilingEnabled,
		AngleX_Min = v.AngleX_Min, AngleX_Max = v.AngleX_Max,
		AngleY_Min = v.AngleY_Min, AngleY_Max = v.AngleY_Max,
		AngleZ_Min = v.AngleZ_Min, AngleZ_Max = v.AngleZ_Max,
		Spread = v.Spread,
		EquipTime = v.EquipTime,
	}
	for _, key in ipairs(gunMod.EXTRA_KEYS) do
		local val = rawget(v, key)
		if val ~= nil then
			o[key] = val
		end
	end
	-- Also snapshot recoil/shake/kick/spread/reload/fire/aim/slow numeric keys
	for k, val in pairs(v) do
		if type(k) == "string" and type(val) == "number" and o[k] == nil then
			local low = string.lower(k)
			if low:find("recoil", 1, true) or low:find("shake", 1, true) or low:find("kick", 1, true)
				or low:find("spread", 1, true)
				or low:find("reload", 1, true) or low:find("chamber", 1, true) or low:find("bolt", 1, true)
				or low:find("fire", 1, true) or low:find("shoot", 1, true) or low:find("cycle", 1, true)
				or low:find("aim", 1, true) or low:find("slow", 1, true)
				or (low:find("walk", 1, true) and low:find("speed", 1, true)) then
				o[k] = val
			end
		end
	end
	return o
end

local function pruneWeaponOrig(active)
	for weapon in pairs(gunMod.orig) do
		if not active[weapon] then
			gunMod.orig[weapon] = nil
		end
	end
end

local function cacheWeapons(deep, force)
	if typeof(getgc) ~= "function" then return end
	-- Global scan cooldown: getgc allocates huge arrays; rapid re-scans (e.g.
	-- scope re-equipping the tool) caused freezes + RAM spikes.
	-- `force` bypasses cooldown for backpack/equip events (new guns in EQ).
	local now = tick()
	if not force and (now - (gunMod.lastScanAt or 0) < (gunMod.scanCooldown or 2.5)) then
		return
	end
	gunMod.lastScanAt = now
	local active = {}
	local found = {}
	-- shallow first; when deep requested, also deep-merge (do NOT early-break —
	-- old guns already in shallow GC would otherwise block discovering new ones).
	local scans = deep and { false, true } or { false }
	for _, useDeep in ipairs(scans) do
		local ok, gc = pcall(getgc, useDeep)
		if ok and type(gc) == "table" then
			for _, v in ipairs(gc) do
				if isWeaponTable(v) and not active[v] then
					active[v] = true
					table.insert(found, v)
					if not gunMod.orig[v] then
						gunMod.orig[v] = captureWeaponOrig(v)
					elseif gunMod.orig[v].EquipTime == nil then
						gunMod.orig[v].EquipTime = v.EquipTime
					end
				end
			end
		end
		-- Only skip deep when shallow is empty *and* we did not ask for deep.
		if #found > 0 and not deep then
			break
		end
	end
	if #found > 0 then
		gunMod.cache = found
		pruneWeaponOrig(active)
	end
end

local function clearGunModCharConns()
	for _, conn in ipairs(gunMod.charConns) do
		pcall(conn.Disconnect, conn)
	end
	table.clear(gunMod.charConns)
end

local function gunModsWant(S)
	-- getgc ONLY for No Recoil / No Spread / Quick Equip
	return S and (
		S.CrimNoRecoil == true
		or S.CrimNoSpread == true
		or S.CrimQuickEquip == true
	)
end

-- Criminality ammo HUD: PlayerGui.GunGUI.Frame.Main.Current / Stored
-- NEVER keep long-lived label refs — switching Tool leaves old GunGUI text on screen.
local function parseAmmoText(text)
	if typeof(text) ~= "string" then
		return nil
	end
	local n = tonumber((text:gsub("%s+", "")))
	if n ~= nil then
		return math.floor(n)
	end
	local digits = string.match(text, "%-?%d+")
	if digits then
		return tonumber(digits)
	end
	return nil
end

local function isAmmoTextObj(inst)
	return inst ~= nil
		and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))
end

local function readAmmoLabel(inst)
	if not isAmmoTextObj(inst) then
		return nil, nil
	end
	local raw = nil
	pcall(function()
		raw = inst.Text
	end)
	if raw == nil or raw == "" then
		pcall(function()
			raw = inst.ContentText
		end)
	end
	if typeof(raw) ~= "string" then
		raw = raw ~= nil and tostring(raw) or nil
	end
	return raw, parseAmmoText(raw)
end

local function gunTitleMatchesTool(titleText, toolName)
	if typeof(titleText) ~= "string" or titleText == "" then
		return true
	end
	if typeof(toolName) ~= "string" or toolName == "" then
		return true
	end
	local t = string.lower(titleText)
	local n = string.lower(toolName)
	if t:find(n, 1, true) or n:find(t, 1, true) then
		return true
	end
	local tc = t:gsub("%W", "")
	local nc = n:gsub("%W", "")
	if tc ~= "" and nc ~= "" and (tc:find(nc, 1, true) or nc:find(tc, 1, true)) then
		return true
	end
	return false
end

-- returns: currentNum, storedNum, debugTbl
-- toolName: equipped Tool.Name — used to reject stale HUD from previous gun
local function getGunGuiAmmo(toolName)
	local dbg = {
		ok = false,
		path = "?",
		curClass = nil,
		stoClass = nil,
		curRaw = nil,
		stoRaw = nil,
		gg = false,
		main = false,
		enabled = nil,
		title = nil,
		titleOk = true,
	}

	local function finish(curInst, stoInst, path, titleInst)
		dbg.path = path or dbg.path
		dbg.curClass = curInst and curInst.ClassName or nil
		dbg.stoClass = stoInst and stoInst.ClassName or nil
		if titleInst and isAmmoTextObj(titleInst) then
			local tr = select(1, readAmmoLabel(titleInst))
			dbg.title = tr
			dbg.titleOk = gunTitleMatchesTool(tr, toolName)
		end
		local curRaw, curNum = readAmmoLabel(curInst)
		local stoRaw, stoNum = readAmmoLabel(stoInst)
		dbg.curRaw = curRaw
		dbg.stoRaw = stoRaw
		if not dbg.titleOk then
			dbg.ok = false
			dbg.path = (path or "?") .. "+STALE_TITLE"
			return nil, nil, dbg
		end
		dbg.ok = curNum ~= nil and stoNum ~= nil
		return curNum, stoNum, dbg
	end

	-- Drop any previous cache on tool swap
	if toolName ~= gunMod.lastAmmoToolName then
		gunMod.lastAmmoToolName = toolName
		gunMod.gunGui = nil
	end

	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then
		dbg.path = "no PlayerGui"
		return nil, nil, dbg
	end

	local gg = pg:FindFirstChild("GunGUI")
	dbg.gg = gg ~= nil
	if not gg then
		dbg.path = "no GunGUI"
		return nil, nil, dbg
	end

	local enabled = true
	pcall(function()
		enabled = gg.Enabled ~= false
	end)
	dbg.enabled = enabled
	if not enabled then
		dbg.path = "GunGUI.Disabled"
		return nil, nil, dbg
	end

	-- Canonical: GunGUI.Frame.Main.{Current,Stored,Title}
	local frame = gg:FindFirstChild("Frame")
	local main = frame and frame:FindFirstChild("Main")
	dbg.main = main ~= nil
	if main then
		local current = main:FindFirstChild("Current")
		local stored = main:FindFirstChild("Stored")
		local title = main:FindFirstChild("Title")
		if isAmmoTextObj(current) and isAmmoTextObj(stored) then
			return finish(current, stored, "GunGUI.Frame.Main", title)
		end
	end

	main = gg:FindFirstChild("Main")
	if main then
		local current = main:FindFirstChild("Current")
		local stored = main:FindFirstChild("Stored")
		local title = main:FindFirstChild("Title")
		if isAmmoTextObj(current) and isAmmoTextObj(stored) then
			return finish(current, stored, "GunGUI.Main", title)
		end
	end

	local current = gg:FindFirstChild("Current", true)
	local stored = gg:FindFirstChild("Stored", true)
	local title = gg:FindFirstChild("Title", true)
	if current or stored then
		return finish(current, stored, "GunGUI/**/deep", title)
	end

	dbg.path = "GunGUI found but no Current/Stored"
	return nil, nil, dbg
end

local function pressReloadKey()
	if VIM then
		local ok = pcall(function()
			VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
		end)
		task.defer(function()
			pcall(function()
				VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
			end)
		end)
		if ok then return true end
	end
	if typeof(keypress) == "function" then
		pcall(keypress, Enum.KeyCode.R)
		task.defer(function()
			if typeof(keyrelease) == "function" then
				pcall(keyrelease, Enum.KeyCode.R)
			end
		end)
		return true
	end
	return false
end

-- Auto Reload: ONLY when Current == 0 and Stored >= 1 (never on 0/0)
-- Ignores stale GunGUI left over from previous gun (Title vs Tool.Name).
local function tickAutoReload(S)
	if not S or not S.CrimAutoReload then
		return
	end
	if gunMod.reloadBusy then
		return
	end
	local now = tick()
	if now - gunMod.lastReloadAt < 1.35 then
		return
	end

	local char = getChar()
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	local current, stored, dbg = getGunGuiAmmo(tool.Name)
	dbg = dbg or {}
	if dbg.titleOk == false or dbg.enabled == false then
		return
	end
	if current == nil or stored == nil then
		return
	end
	if current ~= 0 then
		return
	end
	if stored < 1 then
		return
	end

	gunMod.reloadBusy = true
	gunMod.lastReloadAt = now
	task.spawn(function()
		pressReloadKey()
		task.wait(0.4)
		gunMod.reloadBusy = false
	end)
end


local function applyNoRecoil(weapon, orig, on)
	if on then
		gunSet(weapon, "Recoil", 0)
		gunSet(weapon, "CameraRecoilingEnabled", false)
		gunSet(weapon, "AngleX_Min", 0); gunSet(weapon, "AngleX_Max", 0)
		gunSet(weapon, "AngleY_Min", 0); gunSet(weapon, "AngleY_Max", 0)
		gunSet(weapon, "AngleZ_Min", 0); gunSet(weapon, "AngleZ_Max", 0)
		-- Extra kick / shake fields (3rd person bloom)
		for k, val in pairs(orig or {}) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				if low:find("recoil", 1, true) or low:find("shake", 1, true) or low:find("kick", 1, true) then
					weapon[k] = 0
				end
			end
		end
		gunSet(weapon, "WalkSpreadIncrease", 0)
	elseif orig then
		gunRestore(weapon, orig, "Recoil")
		gunRestore(weapon, orig, "CameraRecoilingEnabled")
		gunRestore(weapon, orig, "AngleX_Min"); gunRestore(weapon, orig, "AngleX_Max")
		gunRestore(weapon, orig, "AngleY_Min"); gunRestore(weapon, orig, "AngleY_Max")
		gunRestore(weapon, orig, "AngleZ_Min"); gunRestore(weapon, orig, "AngleZ_Max")
		for k, val in pairs(orig) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				if low:find("recoil", 1, true) or low:find("shake", 1, true) or low:find("kick", 1, true) then
					weapon[k] = val
				end
			end
		end
		-- WalkSpread only restored here if No Spread is also off (handled below)
	end
end

local function applyNoSpread(weapon, orig, on)
	if on then
		gunSet(weapon, "Spread", 0)
		gunSet(weapon, "WalkSpreadIncrease", 0)
		gunSet(weapon, "HipSpread", 0)
		gunSet(weapon, "AimSpread", 0)
		gunSet(weapon, "MinSpread", 0)
		gunSet(weapon, "MaxSpread", 0)
		for k, val in pairs(orig or {}) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				if low:find("spread", 1, true) then
					weapon[k] = 0
				end
			end
		end
	elseif orig then
		gunRestore(weapon, orig, "Spread")
		gunRestore(weapon, orig, "WalkSpreadIncrease")
		gunRestore(weapon, orig, "HipSpread")
		gunRestore(weapon, orig, "AimSpread")
		gunRestore(weapon, orig, "MinSpread")
		gunRestore(weapon, orig, "MaxSpread")
		for k, val in pairs(orig) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				if low:find("spread", 1, true) then
					weapon[k] = val
				end
			end
		end
	end
end

local function applyGunMods(S)
	if not gunModsWant(S) then
		return
	end
	for _, weapon in ipairs(gunMod.cache) do
		local orig = gunMod.orig[weapon]
		applyNoRecoil(weapon, orig, S.CrimNoRecoil == true)
		-- Spread is independent; if No Recoil is on we still leave Spread to CrimNoSpread
		-- unless user wants both (common). WalkSpread zeroed by either toggle.
		if S.CrimNoSpread then
			applyNoSpread(weapon, orig, true)
		elseif not S.CrimNoRecoil then
			applyNoSpread(weapon, orig, false)
		elseif orig then
			-- No Recoil on, No Spread off Ôćĺ restore Spread but keep WalkSpread at 0 from recoil path
			gunRestore(weapon, orig, "Spread")
			gunRestore(weapon, orig, "HipSpread")
			gunRestore(weapon, orig, "AimSpread")
			gunRestore(weapon, orig, "MinSpread")
			gunRestore(weapon, orig, "MaxSpread")
			gunSet(weapon, "WalkSpreadIncrease", 0)
		end
		if S.CrimQuickEquip then
			gunSet(weapon, "EquipTime", 0)
		elseif orig and orig.EquipTime ~= nil then
			weapon.EquipTime = orig.EquipTime
		end
	end
end

local function refreshGunMods(S, preferDeep, force)
	if not gunModsWant(S) then
		return
	end
	if gunMod.scanning and not force then
		return
	end
	gunMod.scanning = true
	local ok, err = pcall(function()
		local now = tick()
		local wantDeep = preferDeep == true and (force == true or (now - gunMod.lastDeepAt >= gunMod.deepCooldown))
		cacheWeapons(wantDeep, force == true)
		if wantDeep then
			gunMod.lastDeepAt = now
		end
		applyGunMods(S)
		gunMod.lastApplyAt = now
	end)
	gunMod.scanning = false
	if not ok then
		warn("[VG] refreshGunMods", err)
	end
end

local function refreshGunModsAsync(S, preferDeep, force)
	if not gunModsWant(S) or gunMod.scanning then
		return
	end
	runHeavy(function()
		local cur = S or _G.__VG_S
		if gunModsWant(cur) then
			refreshGunMods(cur, preferDeep, force)
		end
	end)
end

local function scheduleGunModRefresh(preferDeep, delaySec, force)
	gunMod.scanToken += 1
	local token = gunMod.scanToken
	task.delay(delaySec or 0.4, function()
		if token ~= gunMod.scanToken then
			return
		end
		local S = _G.__VG_S
		if not gunModsWant(S) then
			return
		end
		runHeavy(function()
			if token ~= gunMod.scanToken then
				return
			end
			refreshGunMods(S, preferDeep, force)
		end)
	end)
end

-- New Tool in EQ / equip: debounced rescan (spray/reload used to force deep getgc every shot → freezes).
local function onGunToolChanged()
	local now = tick()
	-- Soft path: re-apply cached tables only (no getgc) while spraying
	if now - (gunMod.toolChangeAt or 0) < 2.8 then
		scheduleGunModRefresh(false, 0.9, false)
		return
	end
	gunMod.toolChangeAt = now
	scheduleGunModRefresh(true, 0.55, true)
	gunMod.followToken = (gunMod.followToken or 0) + 1
	local ft = gunMod.followToken
	task.delay(2.0, function()
		if ft ~= gunMod.followToken then
			return
		end
		local S = _G.__VG_S
		if gunModsWant(S) then
			refreshGunModsAsync(S, false, false)
		end
	end)
end

local function resetGunMods()
	for weapon, values in pairs(gunMod.orig) do
		if type(weapon) == "table" then
			for k, val in pairs(values) do
				pcall(function()
					weapon[k] = val
				end)
			end
		end
	end
	gunMod.cache = {}
	table.clear(gunMod.orig)
	gunMod.lastApplyAt = 0
	gunMod.lastDeepAt = 0
end

local function watchBackpackForGuns(backpack)
	if not backpack then
		return
	end
	table.insert(gunMod.charConns, backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onGunToolChanged()
		end
	end))
	table.insert(gunMod.charConns, backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onGunToolChanged()
		end
	end))
end

local function onGunModCharacter(character)
	clearGunModCharConns()
	scheduleGunModRefresh(true, 1.0, true)
	table.insert(gunMod.charConns, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onGunToolChanged()
		end
	end))
	table.insert(gunMod.charConns, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onGunToolChanged()
		end
	end))
	local humanoid = character:WaitForChild("Humanoid", 2)
	if humanoid then
		table.insert(gunMod.charConns, humanoid.Died:Connect(function()
			gunMod.lastDeepAt = 0
			scheduleGunModRefresh(true, 2.0, true)
		end))
	end
	local lp = getLP()
	watchBackpackForGuns(lp and lp:FindFirstChildOfClass("Backpack"))
end

local function startGunMods(S)
	clearGunModCharConns()
	gunMod.lastDeepAt = 0
	gunMod.lastScanAt = 0
	-- NEVER getgc on the calling thread (often Heartbeat via syncGunMods)
	refreshGunModsAsync(S, true, true)
	local lp = getLP()
	table.insert(gunMod.conns, lp.CharacterAdded:Connect(onGunModCharacter))
	table.insert(gunMod.conns, lp.ChildAdded:Connect(function(ch)
		if ch:IsA("Backpack") then
			watchBackpackForGuns(ch)
			scheduleGunModRefresh(true, 0.5, true)
		end
	end))
	watchBackpackForGuns(lp:FindFirstChildOfClass("Backpack"))
	if lp.Character then
		onGunModCharacter(lp.Character)
	end
end

local function stopGunMods()
	gunMod.scanToken += 1
	clearGunModCharConns()
	resetGunMods()
	for _, conn in ipairs(gunMod.conns) do pcall(conn.Disconnect, conn) end
	gunMod.conns = {}
end

local function gunModCombo(S)
	-- Signature of the toggle combination; re-apply only when it changes.
	return (S.CrimNoRecoil == true and 1 or 0)
		+ (S.CrimNoSpread == true and 2 or 0)
		+ (S.CrimQuickEquip == true and 4 or 0)
end

local function syncGunMods(S)
	local want = gunModsWant(S)
	if featureRunning.gunMods == want then
		if want then
			-- Re-apply ONLY when the toggle combo changed (was: every call =
			-- 10x/s full weapon-table sweep Ôćĺ CPU waste + freeze w/ scope).
			local combo = gunModCombo(S)
			if combo ~= gunMod.lastCombo then
				gunMod.lastCombo = combo
				runHeavy(function()
					applyGunMods(_G.__VG_S or S)
				end)
			end
		end
		return
	end
	featureRunning.gunMods = want
	if want then
		gunMod.lastCombo = gunModCombo(S)
		pcall(function() startGunMods(S) end)
	else
		gunMod.lastCombo = nil
		pcall(stopGunMods)
	end
end

-- legacy names for stopMaster
local function stopNoRecoil()
	stopGunMods()
end

-- ── STAFF DETECTOR ───────────────────────────────────────────────────────────
-- Packed into one table to stay under Luau's 200-local limit.
local staff = { conn = nil }

staff.GROUPS = {
	[4165692] = {
		["Tester"] = true, ["Contributor"] = true, ["Tester+"] = true, ["Developer"] = true,
		["Developer+"] = true, ["Community Manager"] = true, ["Manager"] = true, ["Owner"] = true,
	},
	[32406137] = {
		["Junior"] = true, ["Moderator"] = true, ["Senior"] = true, ["Administrator"] = true,
		["Manager"] = true, ["Holder"] = true,
	},
	[8024440] = {
		["zzzz"] = true, ["reshape enjoyer"] = true, ["i heart reshape"] = true, ["reshape superfan"] = true,
	},
	[14927228] = {
		["\226\153\158"] = true, -- War Room
	},
}

staff.USERS = {
	3294804378, 93676120, 54087314, 81275825, 140837601, 1229486091, 46567801, 418086275, 29706395,
	3717066084, 1424338327, 5046662686, 5046661126, 5046659439, 418199326, 1024216621, 1810535041,
	63238912, 111250044, 63315426, 730176906, 141193516, 194512073, 193945439, 412741116, 195538733,
	102045519, 955294, 957835150, 25689921, 366613818, 281593651, 455275714, 208929505, 96783330,
	156152502, 93281166, 959606619, 142821118, 632886139, 175931803, 122209625, 278097946, 142989311,
	1517131734, 446849296, 87189764, 67180844, 9212846, 47352513, 48058122, 155413858, 10497435,
	513615792, 55893752, 55476024, 151691292, 136584758, 16983447, 3111449, 94693025, 271400893,
	5005262660, 295331237, 64489098, 244844600, 114332275, 25048901, 69262878, 50801509, 92504899,
	42066711, 50585425, 31365111, 166406495, 2457253857, 29761878, 21831137, 948293345, 439942262,
	38578487, 1163048, 7713309208, 3659305297, 15598614, 34616594, 626833004, 198610386, 153835477,
	3923114296, 3937697838, 102146039, 119861460, 371665775, 1206543842, 93428604, 1863173316, 90814576,
	374665997, 423005063, 140172831, 42662179, 9066859, 438805620, 14855669, 727189337, 1871290386,
	608073286,
}

crimNotify = function(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title or "Vanguard",
			Text = text or "",
			Duration = duration or 5,
		})
	end)
end

local function hasStaffTracker(player)
	if not player or not player:IsA("Player") then return false, nil end
	for _, child in ipairs(player:GetChildren()) do
		if typeof(child.Name) == "string" and child.Name:sub(-8) == "Tracker$" then
			local trackedName = child.Name:sub(1, -9)
			if Plrs:FindFirstChild(trackedName) then
				return true, trackedName
			end
		end
	end
	return false, nil
end

local function isStaffPlayer(player)
	if not player or not player:IsA("Player") then return false end
	for groupId, roles in pairs(staff.GROUPS) do
		local okRank, rank = pcall(function() return player:GetRankInGroup(groupId) end)
		if okRank and rank and rank > 0 then
			local okRole, roleName = pcall(function() return player:GetRoleInGroup(groupId) end)
			if okRole and roleName and roles[roleName] then
				return true, roleName, groupId
			end
		end
	end
	for _, userId in ipairs(staff.USERS) do
		if player.UserId == userId then
			return true, "UserID", userId
		end
	end
	return false
end

local function formatStaffKick(staffList)
	local msg = "Staff detected:\n"
	for i, staff in ipairs(staffList) do
		local idType = "Role"
		local idValue = staff.Role or "Unknown"
		if staff.Role == "UserID" then
			idType = "UserID"
			idValue = tostring(staff.GroupId or "Unknown")
		elseif staff.Role == "Tracker User" then
			idType = "Tracker"
			idValue = "Active"
		end
		msg = msg .. string.format(
			"- %s (%s: %s)%s",
			staff.Name or "Unknown",
			idType,
			idValue,
			staff.TrackedPlayer and (" - Tracking: " .. staff.TrackedPlayer) or ""
		)
		if i < #staffList then msg = msg .. "\n" end
	end
	return msg
end

local function kickForStaff(staffList)
	local lp = getLP()
	if not lp then return end
	local body = formatStaffKick(staffList)
	crimNotify("Staff Detected", body, 8)
	task.delay(1.5, function()
		local S = _G.__VG_S
		if not S or not S.CrimStaffDetect then return end
		if S.CrimStaffAutoKick ~= true then return end
		pcall(function() lp:Kick("Staff joined\n\n" .. body) end)
	end)
end

local function collectStaffInfo(player)
	local isStaff, role, groupId = isStaffPlayer(player)
	local hasTrack, tracked = hasStaffTracker(player)
	if not isStaff and not hasTrack then return nil end
	return {
		Name = player.Name,
		Role = hasTrack and "Tracker User" or role,
		GroupId = groupId,
		TrackedPlayer = tracked,
	}
end

local function onStaffPlayerAdded(player)
	local S = _G.__VG_S
	if not S or not S.CrimStaffDetect then return end
	if player == getLP() then return end
	local info = collectStaffInfo(player)
	if info then
		kickForStaff({ info })
	end
end

local function checkExistingStaff()
	local found = {}
	local lp = getLP()
	for _, player in ipairs(Plrs:GetPlayers()) do
		if player ~= lp then
			local info = collectStaffInfo(player)
			if info then table.insert(found, info) end
		end
	end
	if #found > 0 then
		kickForStaff(found)
		return true
	end
	return false
end

local function startStaffDetect()
	if staff.conn then staff.conn:Disconnect() end
	staff.conn = Plrs.PlayerAdded:Connect(onStaffPlayerAdded)
	crimNotify("Staff Detection", "Monitoring active", 5)
	task.spawn(function()
		if checkExistingStaff() and staff.conn then
			staff.conn:Disconnect()
			staff.conn = nil
		end
	end)
end

local function stopStaffDetect()
	if staff.conn then staff.conn:Disconnect(); staff.conn = nil end
end

-- â”€â”€ NO FAIL LOCKPICK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
misc.lockpickConn = nil  -- folded into misc table to save a register

local function scaleLockpickBars(frames, scale)
	if not frames then return end
	for _, key in ipairs({ "B1", "B2", "B3" }) do
		local bar = frames:FindFirstChild(key)
		if bar and bar:FindFirstChild("Bar") then
			local uiScale = bar.Bar:FindFirstChild("UIScale")
			if uiScale then uiScale.Scale = scale end
		end
	end
end

local function applyNoFailLockpick(item)
	if item.Name ~= "LockpickGUI" then return end
	local mf = item:WaitForChild("MF", 10); if not mf then return end
	local lpFrame = mf:WaitForChild("LP_Frame", 10); if not lpFrame then return end
	local frames = lpFrame:WaitForChild("Frames", 10)
	scaleLockpickBars(frames, 10)
end

local function startNoFailLockpick()
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then return end
	if misc.lockpickConn then misc.lockpickConn:Disconnect() end
	misc.lockpickConn = pg.ChildAdded:Connect(applyNoFailLockpick)
end

local function stopNoFailLockpick()
	if misc.lockpickConn then misc.lockpickConn:Disconnect(); misc.lockpickConn = nil end
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	local gui = pg and pg:FindFirstChild("LockpickGUI")
	if gui then
		local mf = gui:FindFirstChild("MF")
		local lpFrame = mf and mf:FindFirstChild("LP_Frame")
		local frames = lpFrame and lpFrame:FindFirstChild("Frames")
		scaleLockpickBars(frames, 1)
	end
end

-- â”€â”€ AUTO OPEN / UNLOCK DOORS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into one table to stay under Luau's 200-local limit.
local door = { RADIUS = 6, INTERVAL = 0.25, lastTick = 0 }

local function tickDoors(S)
	if not S.CrimAutoOpenDoors and not S.CrimAutoUnlockDoors then return end
	local now = tick()
	if now - door.lastTick < door.INTERVAL then return end
	door.lastTick = now

	local hrp = getHRP()
	local hum = getHum()
	if not hrp or not hum or hum.Health <= 0 then return end

	local map = workspace:FindFirstChild("Map")
	if not map then return end
	local doorsFolder = map:FindFirstChild("Doors")
	if not doorsFolder then return end

	local playerPos = hrp.Position
	for _, doorInstance in ipairs(doorsFolder:GetChildren()) do
		local doorBase = doorInstance:FindFirstChild("DoorBase")
		local valuesFolder = doorInstance:FindFirstChild("Values")
		local eventsFolder = doorInstance:FindFirstChild("Events")
		if doorBase and valuesFolder and eventsFolder then
			if (playerPos - doorBase.Position).Magnitude <= door.RADIUS then
				local toggleEvent = eventsFolder:FindFirstChild("Toggle")
				if toggleEvent then
					if S.CrimAutoUnlockDoors then
						local lockedValue = valuesFolder:FindFirstChild("Locked")
						local lockArg = doorInstance:FindFirstChild("Lock")
						if lockedValue and lockArg and typeof(lockedValue.Value) == "boolean" and lockedValue.Value == true then
							pcall(function() toggleEvent:FireServer("Unlock", lockArg) end)
						end
					end
					if S.CrimAutoOpenDoors then
						local openValue = valuesFolder:FindFirstChild("Open")
						local knobArg = doorInstance:FindFirstChild("Knob2") or doorInstance:FindFirstChild("Knob")
						if openValue and knobArg and typeof(openValue.Value) == "boolean" and openValue.Value == false then
							local lockedVal = valuesFolder:FindFirstChild("Locked")
							if not lockedVal or lockedVal.Value == false or not S.CrimAutoUnlockDoors then
								pcall(function() toggleEvent:FireServer("Open", knobArg) end)
							end
						end
					end
				end
			end
		end
	end
end

-- ── REMOTE ELEVATOR ─────────────────────────────────────────────────────────
-- Fire Toggle when near knob (~11 st). Far away: use TP button first (no pos spoof).
-- Cobalt: Elevator_N.Events.Toggle:FireServer("Do", Elevator_N.Knob1)
local elev = { conn = nil, lastAt = 0, busy = false, NEAR = 11 }

local function findBestElevator(S)
	local cam = workspace.CurrentCamera
	local hrp = getHRP()
	if not cam or not hrp then
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local doors = map and map:FindFirstChild("Doors")
	if not doors then
		return nil
	end
	local maxDist = math.clamp(tonumber(S and S.CrimRemoteElevatorMaxDist) or 400, 50, 1000)
	local origin = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local playerPos = hrp.Position
	local bestToggle, bestKnob, bestPart, bestName, bestScore, bestDist = nil, nil, nil, nil, nil, nil

	for _, ch in ipairs(doors:GetChildren()) do
		local n = ch.Name
		if typeof(n) == "string" and string.sub(n, 1, 8) == "Elevator" then
			local knob = ch:FindFirstChild("Knob1") or ch:FindFirstChild("Knob2") or ch:FindFirstChild("Knob")
			local evFolder = ch:FindFirstChild("Events")
			local toggle = evFolder and evFolder:FindFirstChild("Toggle")
			local part = knob or ch:FindFirstChild("DoorBase") or ch:FindFirstChildWhichIsA("BasePart", true)
			if knob and toggle and part then
				local to = part.Position - origin
				local dist = to.Magnitude
				if dist <= maxDist and dist > 0.5 then
					local dot = to.Unit:Dot(look)
					local score = (dot > 0.72) and (dist / math.max(dot, 0.01)) or (dist + 800)
					if not bestScore or score < bestScore then
						bestScore = score
						bestToggle = toggle
						bestKnob = knob
						bestPart = part
						bestName = n
						bestDist = (playerPos - part.Position).Magnitude
					end
				end
			end
		end
	end

	if not bestToggle or not bestKnob then
		return nil
	end
	return {
		toggle = bestToggle,
		knob = bestKnob,
		part = bestPart,
		name = bestName,
		dist = bestDist or 0,
	}
end

local function teleportToElevator(S)
	local hit = findBestElevator(S or _G.__VG_S)
	if not hit then
		crimNotify("Elevator", "Brak windy w zasięgu", 2)
		return
	end
	local root = getHRP()
	if not root or not alive(hit.knob) then
		return
	end
	local near = hit.knob.CFrame * CFrame.new(0, 1.2, -1.8)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = near
	end)
	crimNotify("Elevator", "TP → " .. tostring(hit.name) .. string.format("  %.0fm", hit.dist), 2)
end

local function tryRemoteElevator(S)
	if not S or S.CrimRemoteElevator ~= true or elev.busy then
		return
	end
	local now = tick()
	if now - elev.lastAt < 0.55 then
		return
	end
	local hit = findBestElevator(S)
	if not hit then
		crimNotify("Elevator", "Brak windy w zasięgu", 2)
		return
	end
	if (hit.dist or 999) > elev.NEAR then
		crimNotify("Elevator", "Za daleko — użyj TP to Elevator, potem key", 3)
		return
	end

	elev.busy = true
	elev.lastAt = now
	task.spawn(function()
		if not alive(hit.knob) or not alive(hit.toggle) then
			elev.busy = false
			return
		end
		local ok = pcall(function()
			hit.toggle:FireServer("Do", hit.knob)
		end)
		elev.busy = false
		if ok then
			crimNotify("Elevator", tostring(hit.name) .. string.format("  %.0fm", hit.dist or 0), 2)
		else
			crimNotify("Elevator", "Fire failed", 2)
		end
	end)
end

local function syncRemoteElevator(S)
	local want = S and S.CrimRemoteElevator == true
	if want and not elev.conn and UIS then
		elev.conn = UIS.InputBegan:Connect(function(input, gp)
			if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local cur = _G.__VG_S
			if not cur or cur.CrimRemoteElevator ~= true then
				return
			end
			local keyName = cur.CrimRemoteElevatorKey or "T"
			local ok, key = pcall(function()
				return Enum.KeyCode[keyName]
			end)
			if ok and key and input.KeyCode == key then
				pcall(tryRemoteElevator, cur)
			end
		end)
	elseif not want and elev.conn then
		elev.conn:Disconnect()
		elev.conn = nil
	end
end

-- â”€â”€ INFINITE STAMINA (Criminality) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into one table to stay under Luau's 200-local limit.
local crimStamina = { hooked=false, active=false, oldFn=nil }

local function setupCrimStaminaHook()
	if crimStamina.hooked or typeof(hookfunction) ~= "function" or typeof(getupvalue) ~= "function" then
		return
	end
	pcall(function()
		local env
		if typeof(getrenv) == "function" then
			local ok, renv = pcall(getrenv)
			if ok then env = renv end
		end
		if not env and typeof(getfenv) == "function" then
			local ok, fenv = pcall(getfenv)
			if ok then env = fenv end
		end
		if not env or not env._G or not env._G.S_Take then return end

		local okUp, targetFn = pcall(getupvalue, env._G.S_Take, 2)
		if not okUp or type(targetFn) ~= "function" then return end

		crimStamina.oldFn = hookfunction(targetFn, function(v1, ...)
			if crimStamina.active and crimStamina.oldFn then
				return crimStamina.oldFn(0, ...)
			end
			return crimStamina.oldFn(v1, ...)
		end)
		if crimStamina.oldFn then crimStamina.hooked = true end
	end)
end

local function refillCrimStamina()
	local lp = getLP()
	local char = getChar()
	if not lp or not char then return end
	for _, key in ipairs({ "Stamina", "stamina", "STAMINA", "Sprint", "Energy" }) do
		local ok, val = pcall(function() return lp:GetAttribute(key) end)
		if ok and type(val) == "number" and val < 100 then
			pcall(function() lp:SetAttribute(key, 100) end)
		end
		local ok2, val2 = pcall(function() return char:GetAttribute(key) end)
		if ok2 and type(val2) == "number" and val2 < 100 then
			pcall(function() char:SetAttribute(key, 100) end)
		end
	end
	for _, key in ipairs({ "Stamina", "Sprint", "Energy", "Stam" }) do
		local nv = char:FindFirstChild(key) or lp:FindFirstChild(key)
		if nv and nv:IsA("NumberValue") and nv.Value < nv.MaxValue then
			pcall(function() nv.Value = nv.MaxValue end)
		end
	end
end

-- â”€â”€ FULLBRIGHT (Criminality) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Packed into one table to stay under Luau's 200-local limit.
local fb = {
	conn  = nil,
	saved = nil,
	target = {
		Brightness = 5,
		ClockTime = 14,
		Ambient = Color3.new(1, 1, 1),
		OutdoorAmbient = Color3.new(1, 1, 1),
		ColorShift_Top = Color3.new(0, 0, 0),
		FogStart = 100000,
		FogEnd = 100000,
	},
}

local function captureFbLighting()
	if fb.saved then
		return
	end
	fb.saved = {
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		GlobalShadows = Lighting.GlobalShadows,
	}
end

local function applyFbTarget()
	for k, v in pairs(fb.target) do
		Lighting[k] = v
	end
	Lighting.GlobalShadows = false
end

local function startFullBright()
	if fb.conn then
		return
	end
	captureFbLighting()
	applyFbTarget()
	fb.conn = RS.RenderStepped:Connect(function()
		if not _G.__VG_S or not _G.__VG_S.CrimFullBright then
			return
		end
		for k, v in pairs(fb.target) do
			if Lighting[k] ~= v then
				Lighting[k] = v
			end
		end
		if Lighting.GlobalShadows then
			Lighting.GlobalShadows = false
		end
	end)
end

local function stopFullBright()
	if fb.conn then
		fb.conn:Disconnect()
		fb.conn = nil
	end
	if fb.saved then
		Lighting.Brightness = fb.saved.Brightness
		Lighting.ClockTime = fb.saved.ClockTime
		Lighting.Ambient = fb.saved.Ambient
		Lighting.OutdoorAmbient = fb.saved.OutdoorAmbient
		Lighting.ColorShift_Top = fb.saved.ColorShift_Top
		Lighting.FogStart = fb.saved.FogStart
		Lighting.FogEnd = fb.saved.FogEnd
		Lighting.GlobalShadows = fb.saved.GlobalShadows
	end
end

-- ── NO FOG (ReplicatedStorage.Values.SetFogValue / SetHazeValue → 0) ──
misc.noFog = { conns = {}, saved = {}, litSaved = nil, lastRemoteAt = 0 }

function misc.noFog.clearConns()
	for _, c in ipairs(misc.noFog.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.noFog.conns = {}
end

function misc.noFog.findValuesFolder()
	local values = RepSt:FindFirstChild("Values")
	if values then
		return values
	end
	local fog = RepSt:FindFirstChild("SetFogValue", true)
	return fog and fog.Parent or nil
end

function misc.noFog.writeZero(obj)
	if not obj then
		return
	end
	if obj:IsA("NumberValue") or obj:IsA("IntValue") then
		if misc.noFog.saved[obj] == nil then
			misc.noFog.saved[obj] = obj.Value
		end
		if obj.Value ~= 0 then
			pcall(function()
				obj.Value = 0
			end)
		end
	elseif obj:IsA("BoolValue") then
		if misc.noFog.saved[obj] == nil then
			misc.noFog.saved[obj] = obj.Value
		end
		if obj.Value ~= false then
			pcall(function()
				obj.Value = false
			end)
		end
	elseif obj:IsA("StringValue") then
		if misc.noFog.saved[obj] == nil then
			misc.noFog.saved[obj] = obj.Value
		end
		if obj.Value ~= "0" then
			pcall(function()
				obj.Value = "0"
			end)
		end
	elseif obj:IsA("RemoteEvent") then
		-- some Crim builds expose SetFogValue as a remote
		if tick() - (misc.noFog.lastRemoteAt or 0) >= 1.25 then
			misc.noFog.lastRemoteAt = tick()
			pcall(function()
				obj:FireServer(0)
			end)
		end
	elseif obj:IsA("RemoteFunction") then
		if tick() - (misc.noFog.lastRemoteAt or 0) >= 1.25 then
			misc.noFog.lastRemoteAt = tick()
			pcall(function()
				obj:InvokeServer(0)
			end)
		end
	end
end

function misc.noFog.applyLighting()
	if not misc.noFog.litSaved then
		misc.noFog.litSaved = {
			FogStart = Lighting.FogStart,
			FogEnd = Lighting.FogEnd,
		}
	end
	if Lighting.FogStart < 100000 then
		Lighting.FogStart = 100000
	end
	if Lighting.FogEnd < 100000 then
		Lighting.FogEnd = 100000
	end
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst:IsA("Atmosphere") then
			if misc.noFog.saved[inst] == nil then
				misc.noFog.saved[inst] = { Density = inst.Density, Haze = inst.Haze }
			end
			pcall(function()
				inst.Density = 0
				inst.Haze = 0
			end)
		end
	end
end

function misc.noFog.apply()
	local folder = misc.noFog.findValuesFolder()
	if folder then
		misc.noFog.writeZero(folder:FindFirstChild("SetFogValue"))
		misc.noFog.writeZero(folder:FindFirstChild("SetHazeValue"))
	else
		misc.noFog.writeZero(RepSt:FindFirstChild("SetFogValue", true))
		misc.noFog.writeZero(RepSt:FindFirstChild("SetHazeValue", true))
	end
	misc.noFog.applyLighting()
	return true
end

function misc.noFog.restore()
	for obj, prev in pairs(misc.noFog.saved) do
		if typeof(obj) == "Instance" and obj.Parent then
			if typeof(prev) == "table" and obj:IsA("Atmosphere") then
				pcall(function()
					if prev.Density ~= nil then
						obj.Density = prev.Density
					end
					if prev.Haze ~= nil then
						obj.Haze = prev.Haze
					end
				end)
			elseif obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("BoolValue") or obj:IsA("StringValue") then
				pcall(function()
					obj.Value = prev
				end)
			end
		end
	end
	table.clear(misc.noFog.saved)
	if misc.noFog.litSaved then
		pcall(function()
			Lighting.FogStart = misc.noFog.litSaved.FogStart
			Lighting.FogEnd = misc.noFog.litSaved.FogEnd
		end)
		misc.noFog.litSaved = nil
	end
end

function misc.noFog.start()
	misc.noFog.clearConns()
	misc.noFog.apply()
	local function reapply()
		if _G.__VG_S and _G.__VG_S.CrimNoFog then
			misc.noFog.apply()
		end
	end
	local folder = misc.noFog.findValuesFolder() or RepSt
	for _, name in ipairs({ "SetFogValue", "SetHazeValue" }) do
		local obj = folder:FindFirstChild(name) or RepSt:FindFirstChild(name, true)
		if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue") or obj:IsA("BoolValue")) then
			table.insert(
				misc.noFog.conns,
				obj:GetPropertyChangedSignal("Value"):Connect(reapply)
			)
		end
	end
	table.insert(misc.noFog.conns, Lighting:GetPropertyChangedSignal("FogEnd"):Connect(reapply))
	table.insert(misc.noFog.conns, Lighting:GetPropertyChangedSignal("FogStart"):Connect(reapply))
	if not folder or folder == RepSt then
		table.insert(
			misc.noFog.conns,
			RepSt.ChildAdded:Connect(function(ch)
				if ch.Name == "Values" or ch.Name == "SetFogValue" then
					task.defer(function()
						if _G.__VG_S and _G.__VG_S.CrimNoFog then
							misc.noFog.start()
						end
					end)
				end
			end)
		)
	end
end

function misc.noFog.stop()
	misc.noFog.clearConns()
	misc.noFog.restore()
end

-- ── SKIP MENU INTRO (ReplicatedStorage.Values.SkipMenuIntro = true/false) ──
misc.skipIntro = { conns = {}, saved = nil, active = false }

function misc.skipIntro.clearConns()
	for _, c in ipairs(misc.skipIntro.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.skipIntro.conns = {}
end

function misc.skipIntro.getValue()
	local values = RepSt:FindFirstChild("Values")
	if not values then
		return nil
	end
	local v = values:FindFirstChild("SkipMenuIntro")
	if v and (v:IsA("BoolValue") or v:IsA("NumberValue") or v:IsA("IntValue")) then
		return v
	end
	return nil
end

function misc.skipIntro.apply(want)
	local v = misc.skipIntro.getValue()
	if not v then
		return false
	end
	if misc.skipIntro.saved == nil then
		misc.skipIntro.saved = v.Value
	end
	local target = want and true or false
	if v:IsA("BoolValue") then
		if v.Value ~= target then
			pcall(function()
				v.Value = target
			end)
		end
	else
		-- NumberValue fallback
		local n = target and 1 or 0
		if v.Value ~= n then
			pcall(function()
				v.Value = n
			end)
		end
	end
	return true
end

function misc.skipIntro.start()
	misc.skipIntro.clearConns()
	misc.skipIntro.active = true
	misc.skipIntro.apply(true)
	local v = misc.skipIntro.getValue()
	if v then
		table.insert(
			misc.skipIntro.conns,
			v:GetPropertyChangedSignal("Value"):Connect(function()
				if _G.__VG_S and _G.__VG_S.CrimSkipMenuIntro then
					misc.skipIntro.apply(true)
				end
			end)
		)
	else
		local values = RepSt:FindFirstChild("Values") or RepSt
		table.insert(
			misc.skipIntro.conns,
			values.ChildAdded:Connect(function(ch)
				if ch.Name == "SkipMenuIntro" or ch.Name == "Values" then
					task.defer(function()
						if _G.__VG_S and _G.__VG_S.CrimSkipMenuIntro then
							misc.skipIntro.start()
						end
					end)
				end
			end)
		)
	end
end

function misc.skipIntro.stop()
	misc.skipIntro.active = false
	misc.skipIntro.clearConns()
	-- OFF → false (explicit), then restore original if we had one and it wasn't false
	local v = misc.skipIntro.getValue()
	if v and v:IsA("BoolValue") then
		pcall(function()
			v.Value = false
		end)
	elseif v then
		pcall(function()
			v.Value = 0
		end)
	end
	misc.skipIntro.saved = nil
end

-- ── CLIENT GUN SKINCHANGER (RepPBR SurfaceAppearance → Tool Gun meshes + ViewModel) ──
-- Skins live at ReplicatedStorage.Storage.CosmeticsStuff.RepPBR (e.g. Mare_Heartseeker).
-- Tool jumps Backpack ↔ Character on equip; FP view is CurrentCamera.ViewModel.
misc.skinChanger = {
	conns = {},
	active = false,
	lastToolName = "",
	cycleIdx = {},
	meshToGun = {}, -- MeshId → gunName (dropped Models are all named "Model")
	_dropAt = 0,
}

function misc.skinChanger.clearConns()
	for _, c in ipairs(misc.skinChanger.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.skinChanger.conns = {}
end

function misc.skinChanger.getRepPBR()
	local storage = RepSt:FindFirstChild("Storage")
	local cos = storage and storage:FindFirstChild("CosmeticsStuff")
	return cos and cos:FindFirstChild("RepPBR")
end

-- TextureID catalog (from getgc / UpdateClient cosmetic dumps)
function misc.skinChanger.getTexCatalog()
	if misc.skinChanger._texCat then
		return misc.skinChanger._texCat
	end
	local cat = {}
	if typeof(_G.__VG_CrimSkinIds) == "table" then
		for gun, skins in pairs(_G.__VG_CrimSkinIds) do
			if typeof(skins) == "table" then
				cat[gun] = cat[gun] or {}
				for disp, tex in pairs(skins) do
					cat[gun][disp] = tex
				end
			end
		end
	end
	pcall(function()
		if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
			return
		end
		local HS = game:GetService("HttpService")
		for _, path in ipairs({
			"VG_CrimSkinIds.json",
			"CrimSkinIds.json",
			"Vanguard/CrimSkinIds.json",
		}) do
			if isfile(path) then
				local ok, decoded = pcall(function()
					return HS:JSONDecode(readfile(path))
				end)
				if ok and typeof(decoded) == "table" then
					for gun, skins in pairs(decoded) do
						if typeof(skins) == "table" then
							cat[gun] = cat[gun] or {}
							for disp, tex in pairs(skins) do
								cat[gun][disp] = tex
							end
						end
					end
				end
			end
		end
	end)
	misc.skinChanger._texCat = cat
	return cat
end

function misc.skinChanger.isTexSkinKey(skinKey)
	return typeof(skinKey) == "string" and string.sub(skinKey, 1, 2) == "T:"
end

function misc.skinChanger.texIdFromKey(skinKey)
	if not misc.skinChanger.isTexSkinKey(skinKey) then
		return nil
	end
	return tonumber(string.sub(skinKey, 3))
end

function misc.skinChanger.texKey(texId)
	return "T:" .. tostring(texId)
end

function misc.skinChanger.catalogKeysForGun(gunName)
	local keys = {}
	if typeof(gunName) ~= "string" or gunName == "" then
		return keys
	end
	keys[#keys + 1] = gunName
	if string.sub(gunName, -2) == "-1" then
		keys[#keys + 1] = string.sub(gunName, 1, #gunName - 2)
	else
		keys[#keys + 1] = gunName .. "-1"
	end
	return keys
end

function misc.skinChanger.listTexSkinsForGun(gunName)
	local out, seen = {}, {}
	local cat = misc.skinChanger.getTexCatalog()
	for _, key in ipairs(misc.skinChanger.catalogKeysForGun(gunName)) do
		local bucket = cat[key]
		if typeof(bucket) == "table" then
			for disp, tex in pairs(bucket) do
				local id = tonumber(tex)
				if id and typeof(disp) == "string" and not seen[disp] then
					seen[disp] = true
					out[#out + 1] = {
						full = misc.skinChanger.texKey(id),
						label = disp,
						texId = id,
						preview = "rbxassetid://" .. tostring(id),
					}
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.label < b.label
	end)
	return out
end

function misc.skinChanger.applyTextureToInstance(root, texId, quiet)
	if not root or not texId then
		return 0
	end
	misc.skinChanger.captureDefaults(root)
	local idStr = "rbxassetid://" .. tostring(texId)
	local saName = misc.skinChanger.texKey(texId)
	local n, patched = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		-- Catalog TextureID from cosmetics is a ColorMap-style asset (see Emerald UV preview).
		-- Applying as MeshPart.TextureID only hits some meshes / UVs → half-skinned melee.
		if d:IsA("MeshPart") and misc.skinChanger.shouldSkinMesh(d) then
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			local okMap = false
			if sa and sa.Name == saName then
				local cur = misc.skinChanger.contentId(sa.ColorMap)
				okMap = cur == misc.skinChanger.contentId(idStr)
			end
			if okMap then
				n = n + 1
			else
				pcall(function()
					if sa then
						sa:Destroy()
					end
					local neo = Instance.new("SurfaceAppearance")
					neo.Name = saName
					neo.ColorMap = idStr
					neo.Parent = d
					if d.TextureID and d.TextureID ~= "" then
						d:SetAttribute("VG_PrevTex", d.TextureID)
						d.TextureID = ""
					end
					d:SetAttribute("VG_TexSkin", tostring(texId))
				end)
				patched = patched + 1
				n = n + 1
			end
		elseif d:IsA("BasePart") and not d:IsA("MeshPart") and not d:IsA("Terrain") then
			-- Legacy SpecialMesh melee pieces
			local sm = d:FindFirstChildOfClass("SpecialMesh")
			if sm then
				pcall(function()
					sm.TextureId = idStr
				end)
				patched = patched + 1
				n = n + 1
			end
		end
	end
	if not quiet and patched > 0 then
		misc.skinChanger.log(string.format("applyTexSA root=%s n=%d id=%s", root.Name, n, tostring(texId)))
	end
	return n
end

function misc.skinChanger.isSkinnableTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end
	local n = tool.Name
	if n == "Fists" or n == "Bandage" or n == "VM" or n == "Clippers" then
		return false
	end
	-- guns
	if tool:GetAttribute("__IsGUN") == true then
		return true
	end
	if tool:FindFirstChild("IsGun") then
		return true
	end
	if tool:FindFirstChild("Gun", true) then
		return true
	end
	-- melee / anything that has RepPBR or TextureID catalog entries
	if #misc.skinChanger.listSkinsForGun(n) > 0 then
		return true
	end
	if #misc.skinChanger.listTexSkinsForGun(n) > 0 then
		return true
	end
	-- saved skin for this tool name
	if misc.skinChanger.getSavedSkinKey(n) then
		return true
	end
	return false
end

-- back-compat alias
function misc.skinChanger.isGunTool(tool)
	return misc.skinChanger.isSkinnableTool(tool)
end

function misc.skinChanger.findActiveWeapon()
	local lp = getLP()
	if not lp then
		return nil
	end
	-- 1) Equipped on character (guns + melee) — highest priority
	local char = lp.Character
	if char then
		for _, ch in ipairs(char:GetChildren()) do
			if misc.skinChanger.isSkinnableTool(ch) then
				return ch
			end
		end
	end
	local chars = workspace:FindFirstChild("Characters")
	local model = chars and chars:FindFirstChild(lp.Name)
	if model then
		for _, ch in ipairs(model:GetChildren()) do
			if misc.skinChanger.isSkinnableTool(ch) then
				return ch
			end
		end
	end
	-- 2) Backpack fallback
	local bp = lp:FindFirstChild("Backpack")
	if bp then
		for _, ch in ipairs(bp:GetChildren()) do
			if misc.skinChanger.isSkinnableTool(ch) then
				return ch
			end
		end
	end
	return nil
end

function misc.skinChanger.findActiveGun()
	return misc.skinChanger.findActiveWeapon()
end

function misc.skinChanger.listSkinsForGun(gunName)
	local out = {}
	local folder = misc.skinChanger.getRepPBR()
	if not folder or not gunName or gunName == "" then
		return out
	end
	local prefix = gunName .. "_"
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("SurfaceAppearance") and string.sub(ch.Name, 1, #prefix) == prefix then
			out[#out + 1] = ch
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

function misc.skinChanger.resolveTemplate(gunName, skinKey)
	local folder = misc.skinChanger.getRepPBR()
	if not folder then
		return nil
	end
	if typeof(skinKey) == "string" and skinKey ~= "" then
		local direct = folder:FindFirstChild(skinKey)
		if direct and direct:IsA("SurfaceAppearance") then
			return direct
		end
		-- suffix only: "Heartseeker" → "Mare_Heartseeker"
		if gunName and not string.find(skinKey, "_", 1, true) then
			local full = folder:FindFirstChild(gunName .. "_" .. skinKey)
			if full and full:IsA("SurfaceAppearance") then
				return full
			end
		end
	end
	return nil
end

function misc.skinChanger.shouldSkinMesh(part)
	if not part or not part:IsA("MeshPart") then
		return false
	end
	local n = part.Name
	-- limbs / holders only (ViewModel arms) — never skin those
	if n == "Left Arm" or n == "Right Arm" or n == "Head" or n == "Torso" or n == "HumanoidRootPart"
		or n == "LArmHolder" or n == "RArmHolder" then
		return false
	end
	-- Crim guns use MeshParts like Base/Scope/Glass/LeverPart (NOT named "Gun").
	-- "Gun" on the tool is often a ModuleScript. Default skins = TextureID, no SurfaceAppearance.
	return true
end

function misc.skinChanger.log(msg)
	pcall(function()
		if typeof(_G.__VG_LOG_FILE) == "function" then
			_G.__VG_LOG_FILE("INFO", "[VG:skin] " .. tostring(msg))
		end
	end)
	print("[VG:skin]", msg)
end

function misc.skinChanger.dumpAttrs(inst, prefix)
	local lines = {}
	pcall(function()
		for name, val in pairs(inst:GetAttributes()) do
			lines[#lines + 1] = string.format("%sattr %s = %s (%s)", prefix or "", name, tostring(val), typeof(val))
		end
	end)
	return lines
end

function misc.skinChanger.dumpMeshTree(root, label, maxLines)
	maxLines = maxLines or 80
	local lines = {}
	if not root then
		lines[#lines + 1] = label .. ": <nil>"
		return lines
	end
	lines[#lines + 1] = string.format(
		"%s: %s (%s) parent=%s path-ish=%s",
		label,
		root.Name,
		root.ClassName,
		root.Parent and root.Parent:GetFullName() or "nil",
		root:GetFullName()
	)
	local meshN, saN = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			meshN = meshN + 1
			if #lines < maxLines then
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				local tex = ""
				pcall(function()
					tex = tostring(d.TextureID or "")
				end)
				if sa then
					saN = saN + 1
					lines[#lines + 1] = string.format(
						"  MeshPart '%s' size=%s SA='%s' ColorMap=%s Metal=%s Norm=%s Rough=%s tex=%s",
						d.Name,
						tostring(d.Size),
						sa.Name,
						tostring(sa.ColorMap),
						tostring(sa.MetalnessMap),
						tostring(sa.NormalMap),
						tostring(sa.RoughnessMap),
						tex
					)
				else
					lines[#lines + 1] = string.format(
						"  MeshPart '%s' size=%s SA=<none> tex=%s Material=%s",
						d.Name,
						tostring(d.Size),
						tex,
						tostring(d.Material)
					)
				end
			end
		elseif d:IsA("SurfaceAppearance") and #lines < maxLines then
			saN = saN + 1
			lines[#lines + 1] = string.format(
				"  SurfaceAppearance '%s' parent=%s ColorMap=%s",
				d.Name,
				d.Parent and d.Parent.Name or "?",
				tostring(d.ColorMap)
			)
		end
	end
	lines[#lines + 1] = string.format("  totals: MeshPart=%d SurfaceAppearance=%d (listed up to %d lines)", meshN, saN, maxLines)
	-- top-level children names
	local kids = {}
	for _, ch in ipairs(root:GetChildren()) do
		kids[#kids + 1] = ch.Name .. ":" .. ch.ClassName
	end
	lines[#lines + 1] = "  children: " .. table.concat(kids, ", ")
	return lines
end

function misc.skinChanger.dumpRepPBR(gunName)
	local lines = {}
	local storage = RepSt:FindFirstChild("Storage")
	local cos = storage and storage:FindFirstChild("CosmeticsStuff")
	lines[#lines + 1] = "=== RepPBR / CosmeticsStuff ==="
	lines[#lines + 1] = "Storage=" .. tostring(storage and storage:GetFullName())
	lines[#lines + 1] = "CosmeticsStuff=" .. tostring(cos and cos:GetFullName())
	if cos then
		local kids = {}
		for _, ch in ipairs(cos:GetChildren()) do
			kids[#kids + 1] = ch.Name .. ":" .. ch.ClassName .. "(" .. #ch:GetChildren() .. ")"
		end
		lines[#lines + 1] = "CosmeticsStuff children: " .. table.concat(kids, ", ")
	end
	local folder = misc.skinChanger.getRepPBR()
	if not folder then
		lines[#lines + 1] = "RepPBR: NOT FOUND"
		-- deep search
		local hit = RepSt:FindFirstChild("RepPBR", true)
		lines[#lines + 1] = "deep FindFirstChild RepPBR=" .. tostring(hit and hit:GetFullName())
		return lines
	end
	lines[#lines + 1] = "RepPBR path=" .. folder:GetFullName() .. " count=" .. #folder:GetChildren()
	local sample, match = {}, {}
	local prefix = gunName and (gunName .. "_") or nil
	for i, ch in ipairs(folder:GetChildren()) do
		if i <= 40 then
			sample[#sample + 1] = ch.Name .. ":" .. ch.ClassName
		end
		if prefix and string.sub(ch.Name, 1, #prefix) == prefix then
			match[#match + 1] = ch.Name
		end
	end
	lines[#lines + 1] = "RepPBR sample(40): " .. table.concat(sample, ", ")
	if gunName then
		lines[#lines + 1] = string.format("matches for '%s_*': %d → %s", gunName, #match, table.concat(match, ", "))
	end
	-- CasePBRs too
	local casePbr = cos and cos:FindFirstChild("CasePBRs")
	if casePbr then
		lines[#lines + 1] = "CasePBRs path=" .. casePbr:GetFullName() .. " count=" .. #casePbr:GetChildren()
		local cs = {}
		for i, ch in ipairs(casePbr:GetChildren()) do
			if i <= 25 then
				cs[#cs + 1] = ch.Name .. ":" .. ch.ClassName
			end
		end
		lines[#lines + 1] = "CasePBRs sample: " .. table.concat(cs, ", ")
	end
	return lines
end

function misc.skinChanger.dump()
	local lines = {}
	local stamp = os.date("%Y-%m-%d %H:%M:%S")
	lines[#lines + 1] = "======== VG SKIN DUMP " .. stamp .. " ========"
	local lp = getLP()
	lines[#lines + 1] = "LocalPlayer=" .. tostring(lp and lp.Name)
	lines[#lines + 1] = "Character=" .. tostring(lp and lp.Character and lp.Character:GetFullName())
	lines[#lines + 1] = "_G.VM=" .. tostring(_G.VM ~= nil) .. " Enabled=" .. tostring(_G.VM and _G.VM.Enabled) .. " Tool=" .. tostring(_G.VM and _G.VM.Tool and _G.VM.Tool.Name)
	local tool = misc.skinChanger.findActiveGun()
	if tool then
		lines[#lines + 1] = "ActiveGun=" .. tool.Name .. " parent=" .. (tool.Parent and tool.Parent:GetFullName() or "nil")
		for _, a in ipairs(misc.skinChanger.dumpAttrs(tool, "  ")) do
			lines[#lines + 1] = a
		end
		-- Values folder inside tool
		local vals = tool:FindFirstChild("Values")
		if vals then
			local vn = {}
			for _, v in ipairs(vals:GetChildren()) do
				local vv = ""
				pcall(function()
					if v:IsA("ValueBase") then
						vv = "=" .. tostring(v.Value)
					end
				end)
				vn[#vn + 1] = v.Name .. ":" .. v.ClassName .. vv
			end
			lines[#lines + 1] = "  Tool.Values: " .. table.concat(vn, ", ")
		end
		for _, l in ipairs(misc.skinChanger.dumpMeshTree(tool, "TOOL", 100)) do
			lines[#lines + 1] = l
		end
		for _, l in ipairs(misc.skinChanger.dumpRepPBR(tool.Name)) do
			lines[#lines + 1] = l
		end
	else
		lines[#lines + 1] = "ActiveGun=<none> — hold a gun then dump again"
		for _, l in ipairs(misc.skinChanger.dumpRepPBR(nil)) do
			lines[#lines + 1] = l
		end
	end
	-- backpack tools list
	local bp = lp and lp:FindFirstChild("Backpack")
	if bp then
		local bt = {}
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Tool") then
				bt[#bt + 1] = ch.Name .. (misc.skinChanger.isGunTool(ch) and "[GUN]" or "")
			end
		end
		lines[#lines + 1] = "Backpack tools: " .. table.concat(bt, ", ")
	end
	-- Character tools
	local char = lp and lp.Character
	if char then
		local ct = {}
		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("Tool") then
				ct[#ct + 1] = ch.Name .. (misc.skinChanger.isGunTool(ch) and "[GUN]" or "")
			end
		end
		lines[#lines + 1] = "Character tools: " .. table.concat(ct, ", ")
	end
	-- ViewModel
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("ViewModel")
	for _, l in ipairs(misc.skinChanger.dumpMeshTree(vm, "ViewModel(Camera)", 80)) do
		lines[#lines + 1] = l
	end
	local rf = game:GetService("ReplicatedFirst")
	local vmFolder = rf:FindFirstChild("ViewModels")
	if vmFolder then
		lines[#lines + 1] = "ReplicatedFirst.ViewModels children=" .. #vmFolder:GetChildren()
		for _, ch in ipairs(vmFolder:GetChildren()) do
			for _, l in ipairs(misc.skinChanger.dumpMeshTree(ch, "RF.ViewModels." .. ch.Name, 40)) do
				lines[#lines + 1] = l
			end
		end
	end
	-- workspace search for other viewmodels
	pcall(function()
		for _, inst in ipairs(cam:GetChildren()) do
			if inst.Name ~= "ViewModel" and (inst.Name:lower():find("view") or inst.Name:lower():find("vm")) then
				lines[#lines + 1] = "Camera child: " .. inst:GetFullName() .. " " .. inst.ClassName
			end
		end
	end)
	lines[#lines + 1] = "======== END SKIN DUMP ========"

	local text = table.concat(lines, "\n")
	for _, line in ipairs(lines) do
		misc.skinChanger.log(line)
	end
	-- dedicated paste file
	pcall(function()
		if typeof(makefolder) == "function" then
			makefolder("Vanguard")
			makefolder("Vanguard/logs")
		end
		if typeof(writefile) == "function" then
			writefile("Vanguard/logs/skin_dump.txt", text .. "\n")
		end
	end)
	return text, #lines
end

function misc.skinChanger.indexMeshes(root, gunName)
	if not root or not gunName or gunName == "" then
		return
	end
	local map = misc.skinChanger.meshToGun
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			local mid = ""
			pcall(function()
				mid = tostring(d.MeshId or "")
			end)
			if mid ~= "" and mid ~= "rbxassetid://0" and not string.find(mid, "ContentId", 1, true) then
				map[mid] = gunName
			end
		end
	end
end

function misc.skinChanger.indexInventory()
	local lp = getLP()
	if not lp then
		return
	end
	local function scan(container)
		if not container then
			return
		end
		for _, ch in ipairs(container:GetChildren()) do
			if misc.skinChanger.isSkinnableTool(ch) then
				misc.skinChanger.indexMeshes(ch, ch.Name)
			end
		end
	end
	scan(lp:FindFirstChild("Backpack"))
	scan(lp.Character)
	local chars = workspace:FindFirstChild("Characters")
	local model = chars and chars:FindFirstChild(lp.Name)
	if model then
		scan(model)
	end
end

function misc.skinChanger.contentId(val)
	if val == nil then
		return ""
	end
	local s = tostring(val)
	if s == "" or s == "nil" or string.find(s, "ContentId", 1, true) then
		return ""
	end
	local id = string.match(s, "(%d%d%d+)")
	if id then
		return "rbxassetid://" .. id
	end
	if string.find(s, "rbxasset", 1, true) then
		return s
	end
	return ""
end

function misc.skinChanger.applyTemplateToInstance(root, template, quiet)
	if not root or not template then
		return 0
	end
	misc.skinChanger.captureDefaults(root)
	local n, patched, skipped = 0, 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			if misc.skinChanger.shouldSkinMesh(d) then
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				-- Name match = already applied — never rewrite maps (avoids asset refetch lag)
				if sa and sa.Name == template.Name then
					n = n + 1
				elseif not sa then
					sa = template:Clone()
					sa.Parent = d
					patched = patched + 1
					n = n + 1
					if not quiet then
						misc.skinChanger.log(string.format("CLONE SA '%s' → %s", template.Name, d.Name))
					end
				else
					-- Replace wrong skin: destroy + clone is faster/cleaner than rewriting 4 maps
					pcall(function()
						sa:Destroy()
					end)
					local neo = template:Clone()
					neo.Parent = d
					patched = patched + 1
					n = n + 1
				end
				pcall(function()
					if d.TextureID and d.TextureID ~= "" then
						d:SetAttribute("VG_PrevTex", d.TextureID)
						d.TextureID = ""
					end
				end)
			else
				skipped = skipped + 1
			end
		end
	end
	if not quiet and patched > 0 then
		misc.skinChanger.log(string.format("applyTemplate root=%s ok=%d patched=%d skip=%d tmpl=%s", root.Name, n, patched, skipped, template.Name))
	end
	return n
end

-- Snapshot default TextureID / SA maps once before first skin apply (for No Skin)
function misc.skinChanger.captureDefaults(root)
	if not root then
		return
	end
	local function mapId(sa, prop)
		local ok, val = pcall(function()
			return sa[prop]
		end)
		if not ok or val == nil then
			return ""
		end
		return misc.skinChanger.contentId(val)
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") and misc.skinChanger.shouldSkinMesh(d) then
			if d:GetAttribute("VG_DefCaptured") ~= true then
				pcall(function()
					d:SetAttribute("VG_DefTex", d.TextureID or "")
					local sa = d:FindFirstChildOfClass("SurfaceAppearance")
					if sa then
						d:SetAttribute("VG_DefHadSA", true)
						d:SetAttribute("VG_DefSAName", sa.Name)
						d:SetAttribute("VG_DefColorMap", mapId(sa, "ColorMap"))
						d:SetAttribute("VG_DefMetalnessMap", mapId(sa, "MetalnessMap"))
						d:SetAttribute("VG_DefNormalMap", mapId(sa, "NormalMap"))
						d:SetAttribute("VG_DefRoughnessMap", mapId(sa, "RoughnessMap"))
					else
						d:SetAttribute("VG_DefHadSA", false)
					end
					d:SetAttribute("VG_DefCaptured", true)
				end)
			end
		end
	end
end

function misc.skinChanger.restoreDefaults(root)
	if not root then
		return 0
	end
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") and misc.skinChanger.shouldSkinMesh(d) then
			pcall(function()
				for _, ch in ipairs(d:GetChildren()) do
					if ch:IsA("SurfaceAppearance") then
						ch:Destroy()
					end
				end
				if d:GetAttribute("VG_DefHadSA") == true then
					local neo = Instance.new("SurfaceAppearance")
					neo.Name = d:GetAttribute("VG_DefSAName") or "Default"
					local function setMap(prop, attr)
						local id = d:GetAttribute(attr)
						if typeof(id) == "string" and id ~= "" then
							pcall(function()
								neo[prop] = id
							end)
						end
					end
					setMap("ColorMap", "VG_DefColorMap")
					setMap("MetalnessMap", "VG_DefMetalnessMap")
					setMap("NormalMap", "VG_DefNormalMap")
					setMap("RoughnessMap", "VG_DefRoughnessMap")
					neo.Parent = d
				end
				local tex = d:GetAttribute("VG_DefTex")
				if tex == nil then
					tex = d:GetAttribute("VG_PrevTex")
				end
				if typeof(tex) == "string" then
					d.TextureID = tex
				end
				n = n + 1
			end)
		end
	end
	return n
end

function misc.skinChanger.restoreNamed(gunName)
	if not gunName then
		return false, "no gun"
	end
	misc.skinChanger.setSavedSkinKey(gunName, nil)
	local n = 0
	local seen = {}
	local function tryOnce(tool)
		if not tool or seen[tool] then
			return
		end
		if tool.Name ~= gunName then
			return
		end
		seen[tool] = true
		n = n + misc.skinChanger.restoreDefaults(tool)
	end
	tryOnce(misc.skinChanger.findActiveGun())
	local lp = getLP()
	if lp then
		tryOnce(lp.Character and lp.Character:FindFirstChild(gunName))
		local chars = workspace:FindFirstChild("Characters")
		local model = chars and chars:FindFirstChild(lp.Name)
		tryOnce(model and model:FindFirstChild(gunName))
		local bp = lp:FindFirstChild("Backpack")
		tryOnce(bp and bp:FindFirstChild(gunName))
	end
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("ViewModel")
	if vm then
		n = n + misc.skinChanger.restoreDefaults(vm)
	end
	local rf = game:GetService("ReplicatedFirst")
	local folder = rf:FindFirstChild("ViewModels")
	if folder then
		for _, ch in ipairs(folder:GetChildren()) do
			n = n + misc.skinChanger.restoreDefaults(ch)
		end
	end
	local filter = workspace:FindFirstChild("Filter")
	local spawned = filter and filter:FindFirstChild("SpawnedTools")
	if spawned then
		for _, model in ipairs(spawned:GetChildren()) do
			if model:IsA("Model") and misc.skinChanger.resolveDroppedGunName(model) == gunName then
				n = n + misc.skinChanger.restoreDefaults(model)
			end
		end
	end
	return true, string.format("%s → No Skin (%d)", gunName, n)
end

function misc.skinChanger.toolAlreadyHasSkin(tool, skinKey)
	if not tool or not skinKey then
		return false
	end
	if misc.skinChanger.isTexSkinKey(skinKey) then
		local wantName = skinKey
		local wantId = misc.skinChanger.contentId("rbxassetid://" .. tostring(misc.skinChanger.texIdFromKey(skinKey)))
		local any = false
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("MeshPart") and misc.skinChanger.shouldSkinMesh(d) then
				any = true
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				if not sa or sa.Name ~= wantName then
					return false
				end
				if misc.skinChanger.contentId(sa.ColorMap) ~= wantId then
					return false
				end
			end
		end
		return any
	end
	local any = false
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("MeshPart") and misc.skinChanger.shouldSkinMesh(d) then
			any = true
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			if not sa or sa.Name ~= skinKey then
				return false
			end
		end
	end
	return any
end

function misc.skinChanger.listAllWeapons()
	local out, seen = {}, {}
	local function addGun(gun)
		if typeof(gun) ~= "string" or gun == "" or seen[gun] then
			return
		end
		-- Normalize catalog quirks like M4A1-1 → prefer base name if both exist later
		local base = gun
		if string.sub(gun, -2) == "-1" then
			base = string.sub(gun, 1, #gun - 2)
		end
		if not seen[base] then
			seen[base] = true
			out[#out + 1] = base
		end
	end
	local folder = misc.skinChanger.getRepPBR()
	if folder then
		for _, ch in ipairs(folder:GetChildren()) do
			if ch:IsA("SurfaceAppearance") then
				local name = ch.Name
				local us = string.find(name, "_", 1, true)
				if us and us > 1 then
					addGun(string.sub(name, 1, us - 1))
				end
			end
		end
	end
	local cat = misc.skinChanger.getTexCatalog()
	for gun in pairs(cat) do
		addGun(gun)
	end
	table.sort(out)
	return out
end

-- Cached longest-first weapon names (avoid sort+scan every drop/ESP identify)
function misc.skinChanger.weaponsByLen()
	local now = tick()
	if misc.skinChanger._wepCache and (now - (misc.skinChanger._wepAt or 0)) < 45 then
		return misc.skinChanger._wepCache
	end
	local list = misc.skinChanger.listAllWeapons()
	local weapons = {}
	for i, g in ipairs(list) do
		weapons[i] = g
	end
	table.sort(weapons, function(a, b)
		return #a > #b
	end)
	misc.skinChanger._wepCache = weapons
	misc.skinChanger._wepAt = now
	return weapons
end

function misc.skinChanger.skinLabel(fullName)
	if typeof(fullName) ~= "string" then
		return "?"
	end
	if misc.skinChanger.isTexSkinKey(fullName) then
		local id = misc.skinChanger.texIdFromKey(fullName)
		local cat = misc.skinChanger.getTexCatalog()
		for _, skins in pairs(cat) do
			if typeof(skins) == "table" then
				for disp, tex in pairs(skins) do
					if tonumber(tex) == id then
						return disp
					end
				end
			end
		end
		return tostring(id or "?")
	end
	local us = string.find(fullName, "_", 1, true)
	if us then
		return string.sub(fullName, us + 1)
	end
	return fullName
end

function misc.skinChanger.applyTextureToTool(tool, texId, quiet)
	if not tool or not texId then
		return 0
	end
	misc.skinChanger.indexMeshes(tool, tool.Name)
	local n = misc.skinChanger.applyTextureToInstance(tool, texId, quiet)
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("ViewModel")
	if vm then
		n = n + misc.skinChanger.applyTextureToInstance(vm, texId, true)
	end
	local rf = game:GetService("ReplicatedFirst")
	local folder = rf:FindFirstChild("ViewModels")
	if folder then
		for _, ch in ipairs(folder:GetChildren()) do
			n = n + misc.skinChanger.applyTextureToInstance(ch, texId, quiet)
		end
	end
	return n
end

function misc.skinChanger.applyNamed(gunName, skinKey)
	if not gunName or not skinKey then
		return false, "bad args"
	end
	misc.skinChanger.setSavedSkinKey(gunName, skinKey)

	local texId = misc.skinChanger.isTexSkinKey(skinKey) and misc.skinChanger.texIdFromKey(skinKey) or nil
	local tmpl = nil
	if not texId then
		tmpl = misc.skinChanger.resolveTemplate(gunName, skinKey)
		if not tmpl then
			return false, "template missing: " .. tostring(skinKey)
		end
	end

	local n = 0
	local seen = {}
	local function tryOnce(tool)
		if not tool or seen[tool] then
			return
		end
		if tool.Name ~= gunName or not misc.skinChanger.isGunTool(tool) then
			return
		end
		seen[tool] = true
		if texId then
			n = n + misc.skinChanger.applyTextureToTool(tool, texId, true)
		else
			n = n + misc.skinChanger.applyToTool(tool, tmpl, true)
		end
	end
	tryOnce(misc.skinChanger.findActiveGun())
	local lp = getLP()
	if lp then
		tryOnce(lp.Character and lp.Character:FindFirstChild(gunName))
		local chars = workspace:FindFirstChild("Characters")
		local model = chars and chars:FindFirstChild(lp.Name)
		tryOnce(model and model:FindFirstChild(gunName))
		local bp = lp:FindFirstChild("Backpack")
		tryOnce(bp and bp:FindFirstChild(gunName))
	end
	local S = _G.__VG_S
	if S and S.CrimSkinDropped then
		if texId then
			n = n + (misc.skinChanger.applyDroppedForGunTex(gunName, skinKey, texId) or 0)
		else
			n = n + (misc.skinChanger.applyDroppedForGun(gunName, tmpl) or 0)
		end
	end
	return true, string.format("%s → %s (%d)", gunName, misc.skinChanger.skinLabel(skinKey), n)
end

-- Resolve Crim gun name from Filter.SpawnedTools Model (all named "Model")
function misc.skinChanger.resolveDroppedGunName(model)
	if not model then
		return nil
	end
	local cached = model:GetAttribute("VG_DropGun")
	if typeof(cached) == "string" and cached ~= "" then
		return cached
	end
	for _, key in ipairs({ "Name", "Item", "ToolName", "GunName", "DisplayName", "Weapon", "WeaponName" }) do
		local val = model:GetAttribute(key)
		if val ~= nil and tostring(val) ~= "" then
			local g = tostring(val)
			pcall(function()
				model:SetAttribute("VG_DropGun", g)
			end)
			return g
		end
	end

	local map = misc.skinChanger.meshToGun
	local fromSa, fromMesh, fromVal
	local nameSet = {}
	for _, d in ipairs(model:GetDescendants()) do
		nameSet[d.Name] = true
		if d:IsA("StringValue") or d:IsA("ObjectValue") then
			local n = d.Name
			if not fromVal and (n == "Name" or n == "Item" or n == "ToolName" or n == "GunName" or n == "Weapon") then
				local v = d.Value
				if typeof(v) == "string" and v ~= "" then
					fromVal = v
				elseif typeof(v) == "Instance" and v.Name ~= "" then
					fromVal = v.Name
				end
			end
		elseif d:IsA("SurfaceAppearance") and not fromSa then
			local us = string.find(d.Name, "_", 1, true)
			if us and us > 1 then
				fromSa = string.sub(d.Name, 1, us - 1)
			end
		elseif d:IsA("MeshPart") then
			local mid = ""
			pcall(function()
				mid = tostring(d.MeshId or "")
			end)
			local gun = map[mid]
			if gun then
				pcall(function()
					model:SetAttribute("VG_DropGun", gun)
				end)
				return gun
			end
			local n = d.Name
			if not fromMesh and string.sub(n, -4) == "Mesh" and #n > 4 then
				fromMesh = string.sub(n, 1, #n - 4)
			end
		elseif d:IsA("BasePart") then
			local n = d.Name
			if not fromMesh and string.sub(n, -4) == "Mesh" and #n > 4 then
				fromMesh = string.sub(n, 1, #n - 4)
			end
		end
	end

	local gun = fromVal or fromSa or fromMesh
	if not gun then
		local weapons = misc.skinChanger.weaponsByLen()
		for _, w in ipairs(weapons) do
			if nameSet[w] or nameSet[w .. "Mesh"] then
				gun = w
				break
			end
		end
	end
	if gun then
		pcall(function()
			model:SetAttribute("VG_DropGun", gun)
		end)
	end
	return gun
end

function misc.skinChanger.dropNearLocal(model, S)
	local hrp = getHRP()
	if not hrp or not model then
		return false
	end
	local maxd = math.clamp(tonumber(S and S.CrimSkinDroppedDist) or 70, 15, 200)
	local part = model:FindFirstChild("WeaponHandle", true)
		or model:FindFirstChild("WeaponHandle2", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not part or not part:IsA("BasePart") then
		return false
	end
	return (part.Position - hrp.Position).Magnitude <= maxd
end

function misc.skinChanger.applyToDroppedModel(model)
	local S = _G.__VG_S
	if not S or not S.CrimSkinDropped or not misc.skinChanger.active then
		return 0
	end
	if not model or not model:IsA("Model") then
		return 0
	end
	-- FPS: only skin drops near local character
	if not misc.skinChanger.dropNearLocal(model, S) then
		return 0
	end
	local gunName = misc.skinChanger.resolveDroppedGunName(model)
	if not gunName then
		return 0
	end
	local key = misc.skinChanger.getSavedSkinKey(gunName)
	if not key then
		return 0
	end
	-- Attribute skip — avoid GetDescendants every poll
	if model:GetAttribute("VG_DropSkin") == key then
		return 0
	end
	if misc.skinChanger.toolAlreadyHasSkin(model, key) then
		pcall(function()
			model:SetAttribute("VG_DropSkin", key)
		end)
		return 0
	end
	local n = 0
	if misc.skinChanger.isTexSkinKey(key) then
		local texId = misc.skinChanger.texIdFromKey(key)
		n = misc.skinChanger.applyTextureToInstance(model, texId, true)
	else
		local tmpl = misc.skinChanger.resolveTemplate(gunName, key)
		if not tmpl then
			return 0
		end
		n = misc.skinChanger.applyTemplateToInstance(model, tmpl, true)
	end
	if n > 0 then
		pcall(function()
			model:SetAttribute("VG_DropSkin", key)
			model:SetAttribute("VG_DropGun", gunName)
		end)
	end
	return n
end

function misc.skinChanger.applyDroppedForGunTex(gunName, skinKey, texId)
	local filter = workspace:FindFirstChild("Filter")
	local folder = filter and filter:FindFirstChild("SpawnedTools")
	if not folder or not gunName or not texId then
		return 0
	end
	local S = _G.__VG_S
	local n = 0
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and misc.skinChanger.dropNearLocal(model, S) then
			local resolved = misc.skinChanger.resolveDroppedGunName(model)
			if resolved == gunName then
				pcall(function()
					model:SetAttribute("VG_DropSkin", nil)
				end)
				n = n + misc.skinChanger.applyTextureToInstance(model, texId, true)
				if n > 0 then
					pcall(function()
						model:SetAttribute("VG_DropSkin", skinKey)
					end)
				end
			end
		end
	end
	return n
end

function misc.skinChanger.applyDroppedForGun(gunName, tmpl)
	local filter = workspace:FindFirstChild("Filter")
	local folder = filter and filter:FindFirstChild("SpawnedTools")
	if not folder or not gunName or not tmpl then
		return 0
	end
	local S = _G.__VG_S
	local n = 0
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and misc.skinChanger.dropNearLocal(model, S) then
			local resolved = misc.skinChanger.resolveDroppedGunName(model)
			if resolved == gunName then
				pcall(function()
					model:SetAttribute("VG_DropSkin", nil)
				end)
				n = n + misc.skinChanger.applyTemplateToInstance(model, tmpl, true)
				if n > 0 then
					pcall(function()
						model:SetAttribute("VG_DropSkin", tmpl.Name)
					end)
				end
			end
		end
	end
	return n
end

-- Budgeted scan near player: max 3 nearby models per call
function misc.skinChanger.applyDroppedModels()
	local S = _G.__VG_S
	if not S or not S.CrimSkinDropped or not misc.skinChanger.active then
		return 0
	end
	local filter = workspace:FindFirstChild("Filter")
	local folder = filter and filter:FindFirstChild("SpawnedTools")
	if not folder then
		return 0
	end
	local kids = folder:GetChildren()
	local total = #kids
	if total == 0 then
		return 0
	end
	local budget = 3
	local start = (misc.skinChanger._dropIdx or 0) % total
	local n = 0
	local checked = 0
	-- Walk whole ring but only spend budget on nearby unresolved drops
	while checked < total and budget > 0 do
		local i = (start + checked) % total + 1
		checked = checked + 1
		local model = kids[i]
		if model and model:IsA("Model") and misc.skinChanger.dropNearLocal(model, S) then
			local applied = misc.skinChanger.applyToDroppedModel(model)
			if applied > 0 then
				n = n + applied
				budget = budget - 1
			elseif model:GetAttribute("VG_DropSkin") == nil then
				budget = budget - 1
			end
		end
	end
	misc.skinChanger._dropIdx = start + checked
	return n
end

function misc.skinChanger.getSavedSkinKey(gunName)
	local S = _G.__VG_S or {}
	local map = S.CrimGunSkins
	if typeof(map) ~= "table" or not gunName then
		return nil
	end
	local direct = map[gunName]
	if direct then
		return direct
	end
	local lower = string.lower(gunName)
	for k, v in pairs(map) do
		if typeof(k) == "string" and string.lower(k) == lower then
			return v
		end
	end
	return nil
end

function misc.skinChanger.setSavedSkinKey(gunName, skinKey)
	local S = _G.__VG_S
	if not S or not gunName then
		return
	end
	if typeof(S.CrimGunSkins) ~= "table" then
		S.CrimGunSkins = {}
	end
	if skinKey and skinKey ~= "" then
		S.CrimGunSkins[gunName] = skinKey
	else
		S.CrimGunSkins[gunName] = nil
	end
end

function misc.skinChanger.applyToTool(tool, template, quiet)
	if not tool or not template then
		return 0
	end
	misc.skinChanger.indexMeshes(tool, tool.Name)
	local n = misc.skinChanger.applyTemplateToInstance(tool, template, quiet)
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("ViewModel")
	if vm then
		n = n + misc.skinChanger.applyTemplateToInstance(vm, template, true)
	end
	local rf = game:GetService("ReplicatedFirst")
	local folder = rf:FindFirstChild("ViewModels")
	if folder then
		for _, ch in ipairs(folder:GetChildren()) do
			n = n + misc.skinChanger.applyTemplateToInstance(ch, template, quiet)
		end
	end
	return n
end

function misc.skinChanger.applySavedForTool(tool, quiet)
	if not misc.skinChanger.isGunTool(tool) then
		return false
	end
	local key = misc.skinChanger.getSavedSkinKey(tool.Name)
	if not key then
		return false
	end
	-- skip if already looking correct (main FPS win)
	if misc.skinChanger.toolAlreadyHasSkin(tool, key) then
		local rf = game:GetService("ReplicatedFirst")
		local vmTool = rf:FindFirstChild("ViewModels") and rf.ViewModels:FindFirstChild("Tool")
		if vmTool and not misc.skinChanger.toolAlreadyHasSkin(vmTool, key) then
			if misc.skinChanger.isTexSkinKey(key) then
				misc.skinChanger.applyTextureToInstance(vmTool, misc.skinChanger.texIdFromKey(key), true)
			else
				local tmpl = misc.skinChanger.resolveTemplate(tool.Name, key)
				if tmpl then
					misc.skinChanger.applyTemplateToInstance(vmTool, tmpl, true)
				end
			end
		end
		return true
	end
	if misc.skinChanger.isTexSkinKey(key) then
		local texId = misc.skinChanger.texIdFromKey(key)
		if not texId then
			return false
		end
		misc.skinChanger.applyTextureToTool(tool, texId, quiet ~= false)
		misc.skinChanger.lastToolName = tool.Name
		return true
	end
	local tmpl = misc.skinChanger.resolveTemplate(tool.Name, key)
	if not tmpl then
		return false
	end
	misc.skinChanger.applyToTool(tool, tmpl, quiet ~= false)
	misc.skinChanger.lastToolName = tool.Name
	return true
end

function misc.skinChanger.tick()
	if not misc.skinChanger.active then
		return
	end
	-- Held gun only on Heartbeat path — dropped skins are budgeted via runHeavy
	local tool = misc.skinChanger.findActiveGun()
	if tool then
		if misc.skinChanger.lastToolName ~= tool.Name then
			misc.skinChanger.indexMeshes(tool, tool.Name)
			misc.skinChanger.lastToolName = tool.Name
		end
		misc.skinChanger.applySavedForTool(tool, true)
	end
end

function misc.skinChanger.cycleForCurrent()
	local tool = misc.skinChanger.findActiveGun()
	if not tool then
		misc.skinChanger.log("cycle: no gun (equip first — Character in Workspace, not Players)")
		return false, "no gun"
	end
	local keys = {}
	for _, sa in ipairs(misc.skinChanger.listSkinsForGun(tool.Name)) do
		keys[#keys + 1] = sa.Name
	end
	local saLabels = {}
	for _, k in ipairs(keys) do
		saLabels[string.lower(misc.skinChanger.skinLabel(k))] = true
	end
	for _, row in ipairs(misc.skinChanger.listTexSkinsForGun(tool.Name)) do
		if not saLabels[string.lower(row.label)] then
			keys[#keys + 1] = row.full
		end
	end
	misc.skinChanger.log(string.format("cycle: tool=%s skins=%d", tool.Name, #keys))
	if #keys == 0 then
		return false, "no skins for " .. tool.Name
	end
	local idx = (misc.skinChanger.cycleIdx[tool.Name] or 0) % #keys + 1
	misc.skinChanger.cycleIdx[tool.Name] = idx
	local key = keys[idx]
	return misc.skinChanger.applyNamed(tool.Name, key)
end

function misc.skinChanger.clearCurrent()
	local tool = misc.skinChanger.findActiveGun()
	if not tool then
		return false, "no gun"
	end
	return misc.skinChanger.restoreNamed(tool.Name)
end

function misc.skinChanger.statusText()
	local tool = misc.skinChanger.findActiveGun()
	local folder = misc.skinChanger.getRepPBR()
	if not folder then
		return "RepPBR not found"
	end
	if not tool then
		return "No gun (equip one)"
	end
	local saved = misc.skinChanger.getSavedSkinKey(tool.Name) or "(default)"
	local n = #misc.skinChanger.listSkinsForGun(tool.Name)
	return string.format("%s | skin: %s | %d available", tool.Name, tostring(saved), n)
end

function misc.skinChanger.hookContainer(container)
	if not container then
		return
	end
	table.insert(
		misc.skinChanger.conns,
		container.ChildAdded:Connect(function(ch)
			if misc.skinChanger.active and misc.skinChanger.isGunTool(ch) then
				task.defer(function()
					task.wait(0.15)
					misc.skinChanger.applySavedForTool(ch)
				end)
			end
		end)
	)
end

function misc.skinChanger.start()
	misc.skinChanger.clearConns()
	misc.skinChanger.active = true
	local lp = getLP()
	if not lp then
		return
	end
	misc.skinChanger.hookContainer(lp:FindFirstChild("Backpack"))
	misc.skinChanger.hookContainer(lp.Character)
	table.insert(
		misc.skinChanger.conns,
		lp.CharacterAdded:Connect(function(char)
			task.defer(function()
				misc.skinChanger.hookContainer(char)
				task.wait(0.3)
				misc.skinChanger.tick()
			end)
		end)
	)
	table.insert(
		misc.skinChanger.conns,
		lp.ChildAdded:Connect(function(ch)
			if ch.Name == "Backpack" then
				misc.skinChanger.hookContainer(ch)
			end
		end)
	)
	-- Dropped tools: Workspace.Filter.SpawnedTools
	local function hookSpawnedTools(folder)
		if not folder then
			return
		end
		table.insert(
			misc.skinChanger.conns,
			folder.ChildAdded:Connect(function(ch)
				if not ch:IsA("Model") then
					return
				end
				task.defer(function()
					local S = _G.__VG_S
					if not S or not S.CrimSkinDropped then
						return
					end
					-- meshes stream in late — retry
					for _, delaySec in ipairs({ 0.15, 0.5, 1.2 }) do
						task.wait(delaySec)
						if not ch.Parent then
							return
						end
						misc.skinChanger.indexInventory()
						misc.skinChanger.applyToDroppedModel(ch)
					end
				end)
			end)
		)
	end
	local filter = workspace:FindFirstChild("Filter")
	local spawned = filter and filter:FindFirstChild("SpawnedTools")
	if spawned then
		hookSpawnedTools(spawned)
	elseif filter then
		table.insert(
			misc.skinChanger.conns,
			filter.ChildAdded:Connect(function(ch)
				if ch.Name == "SpawnedTools" then
					hookSpawnedTools(ch)
					task.defer(misc.skinChanger.applyDroppedModels)
				end
			end)
		)
	else
		table.insert(
			misc.skinChanger.conns,
			workspace.ChildAdded:Connect(function(ch)
				if ch.Name == "Filter" then
					local st = ch:WaitForChild("SpawnedTools", 10)
					hookSpawnedTools(st)
					task.defer(misc.skinChanger.applyDroppedModels)
				end
			end)
		)
	end
	-- VM enable/disable (from game VM.lua)
	if _G.VM and _G.VM.ChangeEvent then
		table.insert(
			misc.skinChanger.conns,
			_G.VM.ChangeEvent.Event:Connect(function()
				task.defer(function()
					task.wait(0.05)
					misc.skinChanger.tick()
				end)
			end)
		)
	end
	misc.skinChanger.tick()
	misc.skinChanger.indexInventory()
	misc.skinChanger.bindUi(_G.__VG_S)
end

function misc.skinChanger.stop()
	misc.skinChanger.active = false
	misc.skinChanger.clearConns()
end

function misc.skinChanger.bindUi(S)
	if typeof(S) ~= "table" then
		return
	end
	local function ensureOn()
		if not S.CrimSkinChanger then
			S.CrimSkinChanger = true
		end
		if not misc.skinChanger.active then
			misc.skinChanger.start()
		end
	end
	S._crimSkinCycle = function()
		ensureOn()
		return misc.skinChanger.cycleForCurrent()
	end
	S._crimSkinClear = function(gunName)
		gunName = gunName or (misc.skinChanger.findActiveGun() and misc.skinChanger.findActiveGun().Name)
		if not gunName then
			return false, "no gun"
		end
		ensureOn()
		return misc.skinChanger.restoreNamed(gunName)
	end
	S._crimSkinStatus = function()
		return misc.skinChanger.statusText()
	end
	S._crimSkinApply = function()
		ensureOn()
		misc.skinChanger.tick()
		return true, misc.skinChanger.statusText()
	end
	S._crimSkinDump = function()
		local text, n = misc.skinChanger.dump()
		return true, string.format("dumped %d lines → Vanguard/logs/skin_dump.txt", n or 0), text
	end
	S._crimSkinListWeapons = function()
		return misc.skinChanger.listAllWeapons()
	end
	S._crimSkinListSkins = function(gunName)
		local rows = {}
		local saLabels = {}
		local skins = misc.skinChanger.listSkinsForGun(gunName)
		for _, sa in ipairs(skins) do
			local label = misc.skinChanger.skinLabel(sa.Name)
			saLabels[string.lower(label)] = true
			rows[#rows + 1] = {
				full = sa.Name,
				label = label,
				selected = misc.skinChanger.getSavedSkinKey(gunName) == sa.Name,
				preview = misc.skinChanger.contentId(sa.ColorMap),
			}
		end
		for _, tex in ipairs(misc.skinChanger.listTexSkinsForGun(gunName)) do
			if not saLabels[string.lower(tex.label)] then
				rows[#rows + 1] = {
					full = tex.full,
					label = tex.label,
					selected = misc.skinChanger.getSavedSkinKey(gunName) == tex.full,
					preview = tex.preview,
				}
			end
		end
		return rows
	end
	S._crimSkinPick = function(gunName, skinFull)
		ensureOn()
		S.CrimSkinUiWeapon = gunName
		return misc.skinChanger.applyNamed(gunName, skinFull)
	end
	S._crimSkinSaved = function(gunName)
		return misc.skinChanger.getSavedSkinKey(gunName)
	end
	S._crimSkinApplyDropped = function()
		ensureOn()
		S.CrimSkinDropped = true
		return true, "dropped skins: " .. tostring(misc.skinChanger.applyDroppedModels())
	end
	S._crimSkinPersist = function()
		-- UI / Main should call Config.SaveGlobals; this is a fallback write of skin keys
		pcall(function()
			if typeof(writefile) ~= "function" or typeof(isfile) ~= "function" then
				return
			end
			local HS = game:GetService("HttpService")
			local path = "Vanguard/globals.json"
			local data = {}
			if isfile(path) and typeof(readfile) == "function" then
				pcall(function()
					data = HS:JSONDecode(readfile(path))
				end)
			end
			if typeof(data) ~= "table" then
				data = {}
			end
			data.CrimGunSkins = S.CrimGunSkins
			data.CrimSkinUiWeapon = S.CrimSkinUiWeapon
			data.CrimSkinChanger = S.CrimSkinChanger == true
			data.CrimSkinDropped = S.CrimSkinDropped == true
			if typeof(makefolder) == "function" then
				makefolder("Vanguard")
			end
			writefile(path, HS:JSONEncode(data))
		end)
	end
end

-- ── HIDE HelmetOverlayGUI (PlayerGui.HelmetOverlayGUI.Enabled = false) ───────
-- Methods on misc.helmet — no extra chunk locals (Luau 200-register limit).
misc.helmet = { conns = {}, active = false }

function misc.helmet.clearConns()
	for _, c in ipairs(misc.helmet.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	misc.helmet.conns = {}
end

function misc.helmet.addConn(c)
	if c then
		table.insert(misc.helmet.conns, c)
	end
end

function misc.helmet.disable(gui)
	if not gui then
		return
	end
	pcall(function()
		if gui:IsA("LayerCollector") or gui:IsA("ScreenGui") then
			gui.Enabled = false
		end
	end)
end

function misc.helmet.enable(gui)
	if not gui then
		return
	end
	pcall(function()
		if gui:IsA("LayerCollector") or gui:IsA("ScreenGui") then
			gui.Enabled = true
		end
	end)
end

function misc.helmet.hookPlayerGui(pg)
	if not pg then
		return
	end
	local existing = pg:FindFirstChild("HelmetOverlayGUI")
	if existing then
		misc.helmet.disable(existing)
		misc.helmet.addConn(existing:GetPropertyChangedSignal("Enabled"):Connect(function()
			if misc.helmet.active and existing.Enabled then
				misc.helmet.disable(existing)
			end
		end))
	end
	misc.helmet.addConn(pg.ChildAdded:Connect(function(ch)
		if ch.Name == "HelmetOverlayGUI" then
			misc.helmet.disable(ch)
			misc.helmet.addConn(ch:GetPropertyChangedSignal("Enabled"):Connect(function()
				if misc.helmet.active and ch.Enabled then
					misc.helmet.disable(ch)
				end
			end))
		end
	end))
end

function misc.helmet.start()
	if misc.helmet.active then
		return
	end
	misc.helmet.active = true
	misc.helmet.clearConns()
	local lp = getLP()
	if not lp then
		return
	end
	local pg = lp:FindFirstChild("PlayerGui")
	if pg then
		misc.helmet.hookPlayerGui(pg)
	else
		misc.helmet.addConn(lp.ChildAdded:Connect(function(ch)
			if ch.Name == "PlayerGui" or ch:IsA("PlayerGui") then
				misc.helmet.hookPlayerGui(ch)
			end
		end))
	end
end

function misc.helmet.stop()
	misc.helmet.clearConns()
	misc.helmet.active = false
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	local gui = pg and pg:FindFirstChild("HelmetOverlayGUI")
	if gui then
		misc.helmet.enable(gui)
	end
end

-- ── MENU INTRO MUSIC SWAP (PlayerGui.Intro.music) ────────────────────────────
-- Only swaps SoundId — game itself still decides when to Play(). Portable via globals.json.
local menuMus = {
	started = false,
	conns = {},
	patched = {},
	DEFAULT = "PolskiePola",
	VOLUME = 1.8,
	PRESETS = {
		-- Public-domain only (verified). Copyrighted Cypis/Multi/etc. are all 403.
		PolskiePola = "rbxassetid://89202760707274", -- NASZE POLSKIE POLA I ŁĄKI
		DiscoPolo = "rbxassetid://111241611178446", -- Moja Żono — Disco Polo
		Miguel = "rbxassetid://92299938059573", -- Miguel Phonk
		Polka = "rbxassetid://1845005853", -- Polish Accordion Polka
		Accordion = "rbxassetid://9043829590", -- Accordion Polka
		Mountain = "rbxassetid://1845005692", -- Mountain Polka
		Oberek = "rbxassetid://1845019921", -- Flute Oberek
		Krakowiak = "rbxassetid://105595896535305", -- Solo Joy Krakowiak
		Mazurka = "rbxassetid://1836282546", -- Coppelia: Mazurka
		HardKiller = "rbxassetid://70863080128515", -- Polish Hard Killer
		Polski11 = "rbxassetid://85263852134870", -- polski eleven
		Panpipe = "rbxassetid://129323914286343", -- Panpipe Polka
	},
}

function menuMus.resolveId(S)
	S = S or _G.__VG_S
	local key = (S and S.CrimMenuMusicTrack) or menuMus.DEFAULT
	return menuMus.PRESETS[key] or menuMus.PRESETS[menuMus.DEFAULT]
end

function menuMus.patch(s, id)
	if not s or not s:IsA("Sound") then
		return false
	end
	-- ID swap only — never Play(); Crim menu starts the sound itself.
	return (pcall(function()
		if s.SoundId ~= id then
			s.SoundId = id
		end
		if s.Volume ~= menuMus.VOLUME then
			s.Volume = menuMus.VOLUME
		end
		if not menuMus.patched[s] then
			menuMus.patched[s] = true
			table.insert(
				menuMus.conns,
				s:GetPropertyChangedSignal("SoundId"):Connect(function()
					local cur = _G.__VG_S
					if not cur or cur.CrimMenuMusic ~= true then
						return
					end
					local want = menuMus.resolveId(cur)
					if s.SoundId ~= want then
						s.SoundId = want
					end
				end)
			)
			table.insert(
				menuMus.conns,
				s:GetPropertyChangedSignal("Volume"):Connect(function()
					local cur = _G.__VG_S
					if cur and cur.CrimMenuMusic == true and s.Volume ~= menuMus.VOLUME then
						s.Volume = menuMus.VOLUME
					end
				end)
			)
		end
	end))
end

function menuMus.scan(S)
	if not S or S.CrimMenuMusic ~= true then
		return
	end
	local id = menuMus.resolveId(S)
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local intro = pg:FindFirstChild("Intro")
	if not intro then
		return
	end
	-- Shallow only — Intro:GetDescendants() during lobby stream freezes/crashes clients
	local music = intro:FindFirstChild("music") or intro:FindFirstChild("Music")
	if music and music:IsA("Sound") then
		menuMus.patch(music, id)
		return
	end
	for _, ch in ipairs(intro:GetChildren()) do
		if ch:IsA("Sound") and (ch.Name == "music" or ch.Name == "Music") then
			menuMus.patch(ch, id)
			return
		end
		local nested = ch:FindFirstChild("music") or ch:FindFirstChild("Music")
		if nested and nested:IsA("Sound") then
			menuMus.patch(nested, id)
			return
		end
	end
end

function menuMus.start(S)
	S = S or _G.__VG_S
	if not S then
		return
	end
	_G.__VG_S = S
	pcall(menuMus.scan, S)
	if menuMus.started then
		return
	end
	menuMus.started = true
	local lp = getLP()
	if not lp then
		return
	end

	-- IMPORTANT: do NOT use PlayerGui.DescendantAdded — Criminality lobby streams
	-- thousands of Intro UI instances and that callback storm freezes/crashes the client.
	local function hookIntro(intro)
		if not intro or menuMus.patched[intro] then
			return
		end
		menuMus.patched[intro] = true
		pcall(menuMus.scan, _G.__VG_S)
		table.insert(
			menuMus.conns,
			intro.ChildAdded:Connect(function(ch)
				local cur = _G.__VG_S
				if not cur or cur.CrimMenuMusic ~= true then
					return
				end
				if ch:IsA("Sound") and (ch.Name == "music" or ch.Name == "Music") then
					menuMus.patch(ch, menuMus.resolveId(cur))
				elseif ch.Name == "music" or ch.Name == "Music" then
					task.defer(function()
						menuMus.scan(cur)
					end)
				end
			end)
		)
	end

	local function hookPlayerGui(pg)
		if not pg then
			return
		end
		local intro = pg:FindFirstChild("Intro")
		if intro then
			hookIntro(intro)
		end
		table.insert(
			menuMus.conns,
			pg.ChildAdded:Connect(function(ch)
				if ch.Name == "Intro" then
					hookIntro(ch)
				end
			end)
		)
		task.spawn(function()
			for _ = 1, 30 do
				local cur = _G.__VG_S
				if cur and cur.CrimMenuMusic == true then
					menuMus.scan(cur)
				end
				task.wait(0.15)
			end
		end)
	end

	local pg = lp:FindFirstChild("PlayerGui")
	if pg then
		hookPlayerGui(pg)
	else
		table.insert(
			menuMus.conns,
			lp.ChildAdded:Connect(function(ch)
				if ch:IsA("PlayerGui") or ch.Name == "PlayerGui" then
					hookPlayerGui(ch)
				end
			end)
		)
	end
end

function Criminality.StartMenuMusicEarly(_S)
	-- Intentionally no-op. Starting music during Main module-load raced Criminality
	-- lobby Intro streaming and contributed to client freezes at boot (~78% loader).
	-- Music starts later from Criminality.Init (deferred).
end

-- ── CUSTOM HIT SOUNDS (CoreGUI + ReplicatedStorage HitSounds_Head) ───────────
-- Packed into snd.* methods — no extra chunk locals (200-register limit).
-- ── CUSTOM HIT SOUNDS (CoreGUI + ReplicatedStorage HitSounds_Head) ───────────
-- Packed into snd.* methods — no extra chunk locals (200-register limit).
local snd = {
	orig = {},
	gateConns = {}, -- [Sound] = RBXScriptConnection
	lastHeadAt = 0,
	HITMARKER = "rbxassetid://4868633804",
	PRESETS = {
		CS = "rbxassetid://5764885315",
		UT = "rbxassetid://92457871987705",
	},
	HEAD_NAMES = { "Headshot1", "Headshot2", "Headshot3", "Headshot4" },
}

function snd.resolveHeadshotId(S)
	local preset = (S and S.CrimHitSoundPreset) or "UT"
	return snd.PRESETS[preset] or snd.PRESETS.UT
end

function snd.cooldownSec(S)
	S = S or _G.__VG_S
	local ms = S and S.CrimHitSoundCooldown
	if typeof(ms) ~= "number" then
		ms = 180
	end
	return math.clamp(ms, 0, 800) / 1000
end

function snd.clearGates()
	for _, c in pairs(snd.gateConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(snd.gateConns)
	snd.lastHeadAt = 0
end

function snd.gateHeadshot(s)
	if not s or not s:IsA("Sound") or snd.gateConns[s] then
		return
	end
	-- Shared cooldown across all headshot sources (P90 spray spam)
	snd.gateConns[s] = s:GetPropertyChangedSignal("Playing"):Connect(function()
		if not s.Playing then
			return
		end
		local cur = _G.__VG_S
		if not cur or not cur.CrimHitSoundSwap then
			return
		end
		local cd = snd.cooldownSec(cur)
		if cd <= 0 then
			return
		end
		local now = tick()
		if now - snd.lastHeadAt < cd then
			pcall(function()
				s:Stop()
			end)
			return
		end
		snd.lastHeadAt = now
	end)
end

function snd.patchOne(s, key, id, on, gate)
	if not s or not s:IsA("Sound") then
		return
	end
	if on then
		if snd.orig[key] == nil then
			snd.orig[key] = s.SoundId
		end
		if s.SoundId ~= id then
			s.SoundId = id
		end
		if gate then
			snd.gateHeadshot(s)
		end
	elseif snd.orig[key] then
		s.SoundId = snd.orig[key]
	end
end

function snd.apply(on, S)
	S = S or _G.__VG_S
	local hsId = snd.resolveHeadshotId(S)

	if not on then
		snd.clearGates()
	end

	-- PlayerGui CoreGUI (HUD hitmarkers)
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	local core = pg and (pg:FindFirstChild("CoreGUI") or pg:FindFirstChild("CoreGui"))
	if core then
		snd.patchOne(core:FindFirstChild("HeadshotSound"), "core_HeadshotSound", hsId, on, true)
		snd.patchOne(core:FindFirstChild("HitmarkerSound"), "core_HitmarkerSound", snd.HITMARKER, on, false)
	end

	-- Actual Crim headshot SFX: ReplicatedStorage.Storage.HitStuff.Main.HitSounds_Head
	pcall(function()
		local storage = RepSt:FindFirstChild("Storage")
		local hitStuff = storage and storage:FindFirstChild("HitStuff")
		local main = hitStuff and hitStuff:FindFirstChild("Main")
		local folder = main and main:FindFirstChild("HitSounds_Head")
		if not folder then
			return
		end
		for _, name in ipairs(snd.HEAD_NAMES) do
			snd.patchOne(folder:FindFirstChild(name), "rs_" .. name, hsId, on, true)
		end
	end)

	-- MouseGUI headshot tick: ReplicatedStorage.Storage.GUIs.MouseGUI.HeadshotSound
	pcall(function()
		local storage = RepSt:FindFirstChild("Storage")
		local guis = storage and storage:FindFirstChild("GUIs")
		local mouseGui = guis and guis:FindFirstChild("MouseGUI")
		local hs = mouseGui and mouseGui:FindFirstChild("HeadshotSound")
		snd.patchOne(hs, "rs_MouseGUI_HeadshotSound", hsId, on, true)
	end)

	if not on then
		table.clear(snd.orig)
	end
end

function snd.start()
	snd.apply(true, _G.__VG_S)
end

function snd.stop()
	snd.apply(false, _G.__VG_S)
end

_G.__VG_ReapplyHitSounds = function()
	if _G.__VG_S and _G.__VG_S.CrimHitSoundSwap then
		snd.apply(true, _G.__VG_S)
	end
end

function snd.listGameSounds()
	task.spawn(function()
		local header = _G.__VG_SoundHeader
		if header then
			header.Text = "Scanning…"
		end

		local roots = {}
		local function addRoot(inst, label)
			if inst then
				table.insert(roots, { inst = inst, label = label })
			end
		end
		addRoot(game:GetService("SoundService"), "SoundService")
		addRoot(workspace, "Workspace")
		addRoot(game:GetService("ReplicatedStorage"), "ReplicatedStorage")
		addRoot(game:GetService("Lighting"), "Lighting")
		local lp = getLP()
		if lp then
			addRoot(lp:FindFirstChild("PlayerGui"), "PlayerGui")
			addRoot(lp:FindFirstChild("PlayerScripts"), "PlayerScripts")
			addRoot(lp.Character, "Character")
		end
		pcall(function()
			addRoot(game:GetService("CoreGui"), "CoreGui")
		end)
		if typeof(gethui) == "function" then
			pcall(function()
				addRoot(gethui(), "gethui")
			end)
		end

		local byId = {}
		local n = 0

		local function fullPath(inst, rootLabel)
			local parts = { inst.Name }
			local cur = inst.Parent
			local guard = 0
			while cur and cur ~= game and guard < 24 do
				table.insert(parts, 1, cur.Name)
				cur = cur.Parent
				guard += 1
			end
			return rootLabel .. " → " .. table.concat(parts, ".")
		end

		for _, root in ipairs(roots) do
			local ok, descs = pcall(function()
				return root.inst:GetDescendants()
			end)
			if ok and type(descs) == "table" then
				for i, d in ipairs(descs) do
					if d:IsA("Sound") then
						n += 1
						local id = tostring(d.SoundId or "")
						local path = fullPath(d, root.label)
						local g = byId[id]
						if not g then
							g = { count = 0, names = {}, sample = path, playing = 0 }
							byId[id] = g
						end
						g.count += 1
						g.names[d.Name] = (g.names[d.Name] or 0) + 1
						if d.IsPlaying then
							g.playing += 1
						end
						if i % 400 == 0 then
							task.wait()
						end
					end
				end
			end
			task.wait()
		end

		local unique = {}
		for id in pairs(byId) do
			table.insert(unique, id)
		end
		local primaryName = {}
		for id, g in pairs(byId) do
			local best, bestCnt = nil, -1
			for name, cnt in pairs(g.names) do
				if cnt > bestCnt or (cnt == bestCnt and (not best or name < best)) then
					bestCnt = cnt
					best = name
				end
			end
			primaryName[id] = string.lower(best or "")
		end
		table.sort(unique, function(a, b)
			local na, nb = primaryName[a], primaryName[b]
			if na ~= nb then
				return na < nb
			end
			return a < b
		end)

		local rows = {}
		for _, id in ipairs(unique) do
			local g = byId[id]
			local nameList = {}
			for name, cnt in pairs(g.names) do
				table.insert(nameList, cnt > 1 and (name .. "×" .. cnt) or name)
			end
			table.sort(nameList)
			local namesStr = table.concat(nameList, ", ")
			if #namesStr > 72 then
				namesStr = string.sub(namesStr, 1, 69) .. "…"
			end
			table.insert(rows, {
				id = id,
				count = g.count,
				playing = g.playing,
				names = namesStr,
				sample = g.sample,
			})
		end

		if typeof(_G.__VG_FillSoundList) == "function" then
			pcall(_G.__VG_FillSoundList, rows, n)
		end
		crimNotify("Sounds", string.format("%d Sound · %d unique — lista w Visual", n, #rows), 4)
	end)
end

-- ── AUTO RESPAWN (packed into autoRespawn.* — saves chunk locals) ───────────
local autoRespawn = {
	conns = {},
	charConns = {},
	lastAt = 0,
	loopToken = 0,
	KEY = "KMG4R904",
	INTERVAL = 0.6,
}

function autoRespawn.isAlive()
	local lp = getLP()
	local char = lp and lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and hum:IsDescendantOf(workspace)
end

function autoRespawn.invokeOnce()
	pcall(function()
		local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
		local rem = events and events:FindFirstChild("DeathRespawn")
		if rem then
			rem:InvokeServer(autoRespawn.KEY, nil)
		end
	end)
end

function autoRespawn.stopLoop()
	autoRespawn.loopToken += 1
end

function autoRespawn.startLoop()
	local S = _G.__VG_S
	if not S or not S.CrimAutoRespawn then
		return
	end
	autoRespawn.loopToken += 1
	local token = autoRespawn.loopToken
	task.spawn(function()
		autoRespawn.invokeOnce()
		autoRespawn.lastAt = tick()
		while token == autoRespawn.loopToken do
			task.wait(autoRespawn.INTERVAL)
			if token ~= autoRespawn.loopToken then
				break
			end
			local cur = _G.__VG_S
			if not cur or not cur.CrimAutoRespawn then
				break
			end
			if autoRespawn.isAlive() then
				break
			end
			autoRespawn.lastAt = tick()
			autoRespawn.invokeOnce()
		end
	end)
end

function autoRespawn.clearCharConns()
	for _, c in ipairs(autoRespawn.charConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	autoRespawn.charConns = {}
end

function autoRespawn.hookChar(char)
	autoRespawn.clearCharConns()
	if not char then
		return
	end
	if autoRespawn.isAlive() then
		autoRespawn.stopLoop()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		local w
		w = char.ChildAdded:Connect(function(ch)
			if ch:IsA("Humanoid") then
				pcall(function()
					w:Disconnect()
				end)
				autoRespawn.hookChar(char)
			end
		end)
		table.insert(autoRespawn.charConns, w)
		return
	end
	local function onDead()
		autoRespawn.startLoop()
	end
	table.insert(autoRespawn.charConns, hum.Died:Connect(onDead))
	table.insert(
		autoRespawn.charConns,
		hum.HealthChanged:Connect(function(hp)
			if hp <= 0 then
				onDead()
			elseif hp > 0 then
				autoRespawn.stopLoop()
			end
		end)
	)
	if hum.Health <= 0 then
		onDead()
	end
end

function autoRespawn.start()
	for _, c in ipairs(autoRespawn.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	autoRespawn.conns = {}
	autoRespawn.clearCharConns()
	autoRespawn.stopLoop()
	local lp = getLP()
	if not lp then
		return
	end
	if lp.Character then
		autoRespawn.hookChar(lp.Character)
	end
	table.insert(
		autoRespawn.conns,
		lp.CharacterAdded:Connect(function(char)
			task.defer(function()
				if _G.__VG_S and _G.__VG_S.CrimAutoRespawn then
					autoRespawn.hookChar(char)
				end
			end)
		end)
	)
end

function autoRespawn.stop()
	autoRespawn.stopLoop()
	for _, c in ipairs(autoRespawn.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	autoRespawn.conns = {}
	autoRespawn.clearCharConns()
end



-- â”€â”€ MASTER HEARTBEAT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Single connection instead of 5 separate ones = less scheduler overhead.

local master = { conn = nil, frame = 0 }  -- packed to stay under Luau 200-local limit

local function crimFlag(v)
	return v == true
end

local function syncFeatureToggle(key, settingKey, startFn, stopFn, S)
	local want = crimFlag(S[settingKey])
	if featureRunning[key] == want then
		return
	end
	featureRunning[key] = want
	if want then
		pcall(startFn)
	else
		pcall(stopFn)
	end
end

local function syncFromConfig(S)
	if not Criminality.IsCriminality() then
		return
	end
	setupCrimStaminaHook()
	crimStamina.active = crimFlag(S.CrimInfStamina)
	syncFeatureToggle("noFall", "CrimNoFall", startNoFall, stopNoFall, S)
	syncFeatureToggle("noSpike", "CrimNoSpike", startNoSpike, stopNoSpike, S)
	syncFeatureToggle("noRagdoll", "CrimNoRagdoll", startNoRagdoll, stopNoRagdoll, S)
	syncFeatureToggle("ragdollDrag", "CrimRagdollDrag", misc.ragdollDrag.start, misc.ragdollDrag.stop, S)
	syncFeatureToggle("fastAccel", "CrimFastAccel", misc.fastAccel.start, misc.fastAccel.stop, S)
	syncGunMods(S)
	syncFeatureToggle("staffDetect", "CrimStaffDetect", startStaffDetect, stopStaffDetect, S)
	syncFeatureToggle("noFailLockpick", "CrimNoFailLockpick", startNoFailLockpick, stopNoFailLockpick, S)
	syncFeatureToggle("fullBright", "CrimFullBright", startFullBright, stopFullBright, S)
	syncFeatureToggle("noFog", "CrimNoFog", misc.noFog.start, misc.noFog.stop, S)
	syncFeatureToggle("skipIntro", "CrimSkipMenuIntro", misc.skipIntro.start, misc.skipIntro.stop, S)
	syncFeatureToggle("skinChanger", "CrimSkinChanger", misc.skinChanger.start, misc.skinChanger.stop, S)
	pcall(misc.skinChanger.bindUi, S)
	syncFeatureToggle("hideHelmet", "CrimHideHelmetOverlay", misc.helmet.start, misc.helmet.stop, S)
	syncFeatureToggle("removeSmoke", "CrimRemoveSmokeExplosion", startRemoveSmokeExplosion, stopRemoveSmokeExplosion, S)
	syncFeatureToggle("hitSounds", "CrimHitSoundSwap", snd.start, snd.stop, S)
	syncFeatureToggle("autoRespawn", "CrimAutoRespawn", autoRespawn.start, autoRespawn.stop, S)
	if crimFlag(S.CrimInfStamina) then
		refillCrimStamina()
	end
	if crimFlag(S.CrimCrateESP) then
		pcall(ensureCrateWatch, S)
		pcall(syncCrateESP, S)
	elseif #ESP.crates > 0 then
		pcall(clearCrateESP)
	end
	if crimFlag(S.CrimSafeESP) then
		pcall(syncSafeESP, S)
	elseif #ESP.safes > 0 then
		pcall(clearSafeESP)
	end
	if crimFlag(S.CrimDealerESP) then
		pcall(syncDealerESP, S)
	elseif #ESP.dealers > 0 then
		pcall(clearDealerESP)
	end
	if crimFlag(S.CrimGunESP) then
		pcall(gunWatch.ensure, S)
		pcall(gunWatch.sync, S)
	elseif #ESP.guns > 0 then
		pcall(gunWatch.clear)
	end
end

local function startMaster(S)
	if master.conn then return end

	local espInitTick = false

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	master.conn = RS.Heartbeat:Connect(perfWrap("Criminality.Main", function()
		master.frame = master.frame + 1

		-- Toggle-sync is cheap but not latency-sensitive: run every 12 frames (~0.2s)
		if master.frame % 12 == 0 then
			syncFeatureToggle("noFall", "CrimNoFall", startNoFall, stopNoFall, S)
			syncFeatureToggle("noSpike", "CrimNoSpike", startNoSpike, stopNoSpike, S)
			syncFeatureToggle("noRagdoll", "CrimNoRagdoll", startNoRagdoll, stopNoRagdoll, S)
			syncFeatureToggle("ragdollDrag", "CrimRagdollDrag", misc.ragdollDrag.start, misc.ragdollDrag.stop, S)
			syncFeatureToggle("fastAccel", "CrimFastAccel", misc.fastAccel.start, misc.fastAccel.stop, S)
			syncGunMods(S)
			syncFeatureToggle("staffDetect", "CrimStaffDetect", startStaffDetect, stopStaffDetect, S)
			syncFeatureToggle("noFailLockpick", "CrimNoFailLockpick", startNoFailLockpick, stopNoFailLockpick, S)
			syncFeatureToggle("fullBright", "CrimFullBright", startFullBright, stopFullBright, S)
			syncFeatureToggle("noFog", "CrimNoFog", misc.noFog.start, misc.noFog.stop, S)
			syncFeatureToggle("skipIntro", "CrimSkipMenuIntro", misc.skipIntro.start, misc.skipIntro.stop, S)
			syncFeatureToggle("skinChanger", "CrimSkinChanger", misc.skinChanger.start, misc.skinChanger.stop, S)
			syncFeatureToggle("hideHelmet", "CrimHideHelmetOverlay", misc.helmet.start, misc.helmet.stop, S)
			syncFeatureToggle("removeSmoke", "CrimRemoveSmokeExplosion", startRemoveSmokeExplosion, stopRemoveSmokeExplosion, S)
			syncFeatureToggle("hitSounds", "CrimHitSoundSwap", snd.start, snd.stop, S)
			syncFeatureToggle("autoRespawn", "CrimAutoRespawn", autoRespawn.start, autoRespawn.stop, S)
			pcall(syncRemoteElevator, S)
		end

		if crimFlag(S.CrimInfStamina) and not crimStamina.hooked then
			setupCrimStaminaHook()
		end
		crimStamina.active = crimFlag(S.CrimInfStamina)
		if crimStamina.active and master.frame % 15 == 0 then
			refillCrimStamina()
		end
		if featureRunning.noRagdoll and master.frame % 6 == 0 then
			pcall(misc.noRagdoll.applyCharStats)
			local char = getChar()
			if char and not (misc.ragdollDrag and misc.ragdollDrag.active) then
				misc.unragdollChar(char)
			end
		end
		if featureRunning.ragdollDrag then
			pcall(misc.ragdollDrag.tick, S)
		elseif misc.ragdollDrag and misc.ragdollDrag.active then
			pcall(misc.ragdollDrag.exit)
		end
		if featureRunning.fastAccel and master.frame % 10 == 0 then
			pcall(misc.fastAccel.apply)
		end
		if featureRunning.noFog and master.frame % 12 == 0 then
			pcall(misc.noFog.apply)
		end
		if featureRunning.skipIntro and master.frame % 60 == 0 then
			pcall(misc.skipIntro.apply, true)
		end
		if featureRunning.skinChanger then
			-- held: ~2 Hz — cheap. drops: off Heartbeat via runHeavy, budgeted
			if master.frame % 30 == 0 then
				pcall(misc.skinChanger.tick)
			end
			if S.CrimSkinDropped and master.frame % 90 == 15 then
				runHeavy(function()
					pcall(misc.skinChanger.applyDroppedModels)
				end)
			end
			if master.frame % 300 == 0 then
				runHeavy(function()
					pcall(misc.skinChanger.indexInventory)
				end)
			end
		end

		-- Gun mods: never getgc / apply on Heartbeat thread (was max~250ms hitch)
		if featureRunning.gunMods and gunModsWant(S) then
			local now = tick()
			if now - (gunMod.lastScanAt or 0) >= gunMod.rescanInterval then
				refreshGunModsAsync(S, false, false)
			elseif now - (gunMod.lastApplyOnlyAt or 0) >= gunMod.reapplyInterval then
				gunMod.lastApplyOnlyAt = now
				runHeavy(function()
					local cur = _G.__VG_S
					if gunModsWant(cur) then
						applyGunMods(cur)
					end
				end)
			end
		end
		if featureRunning.hitSounds and master.frame % 180 == 0 then
			runHeavy(function()
				pcall(snd.apply, true, _G.__VG_S)
			end)
		end
		if S.CrimAutoReload and master.frame % 6 == 0 then
			pcall(tickAutoReload, S)
		end

		if (S.CrimAutoOpenDoors or S.CrimAutoUnlockDoors) and master.frame % 4 == 0 then
			pcall(tickDoors, S)
		end
		if S.CrimSafeESP then
			if master.frame % 75 == 5 then
				runHeavy(function()
					pcall(syncSafeESP, _G.__VG_S)
				end)
			end
		elseif #ESP.safes > 0 then
			pcall(clearSafeESP)
		end
		if S.CrimDealerESP then
			if master.frame % 90 == 0 then
				runHeavy(function()
					pcall(syncDealerESP, _G.__VG_S)
				end)
			end
		elseif #ESP.dealers > 0 then
			pcall(clearDealerESP)
		end

		if S.CrimCrateESP then
			if master.frame % 90 == 10 then
				runHeavy(function()
					pcall(ensureCrateWatch, _G.__VG_S)
				end)
			end
			if master.frame % 45 == 20 then
				ESP.crateScanAt = tick()
				runHeavy(function()
					pcall(syncCrateESP, _G.__VG_S)
				end)
			end
		elseif #ESP.crates > 0 then
			pcall(clearCrateESP)
		end

		if S.CrimGunESP then
			if master.frame % 90 == 30 then
				runHeavy(function()
					pcall(gunWatch.ensure, _G.__VG_S)
				end)
			end
			if master.frame % 90 == 45 then
				ESP.gunScanAt = tick()
				runHeavy(function()
					pcall(gunWatch.sync, _G.__VG_S)
				end)
			end
		elseif #ESP.guns > 0 then
			pcall(gunWatch.clear)
		end

		if (S.CrimSafeESP or S.CrimDealerESP) and not espInitTick then
			espInitTick = true
			task.spawn(function()
				local deadline = os.clock() + 10
				while os.clock() < deadline do
					if workspace:FindFirstChild("Map") then break end
					task.wait(0.5)
				end
				runHeavy(function()
					local cur = _G.__VG_S
					if cur and cur.CrimSafeESP then pcall(syncSafeESP, cur) end
					if cur and cur.CrimDealerESP then pcall(syncDealerESP, cur) end
				end)
			end)
		end

		if S.CrimMeleeAura then
			tickMelee(S)
		end

		if S.CrimCratePickup and master.frame % 5 == 0 then
			pcall(tickCratePickup, S)
		end
		if S.CrimMoneyPickup and master.frame % 5 == 1 then
			pcall(tickMoneyPickup, S)
		end

		if S.CrimAllowanceClaim and master.frame % 8 == 2 then
			pcall(syncAllowanceAtmESP, S)
		end

		if S.CrimAllowanceClaim and master.frame % 20 == 0 then
			pcall(tickAllowanceClaim, S)
		end

		if S.CrimFastPickup and master.frame % 6 == 3 then
			pcall(tickFastPickup, S)
		end

		-- ESP distance fade: every 4 frames (was 2) — big win with Safe+Gun+Crate on
		if master.frame % 4 == 0 then
			local anyOn = S.CrimSafeESP or S.CrimDealerESP or S.CrimCrateESP or S.CrimGunESP
			local hasCached = #ESP.safes > 0 or #ESP.dealers > 0 or #ESP.crates > 0 or #ESP.guns > 0
			if anyOn or hasCached then
				tickESP(S)
			end
			if not S.CrimCrateESP and #ESP.crates > 0 then
				pcall(clearCrateESP)
			end
			if not S.CrimGunESP and #ESP.guns > 0 then
				pcall(gunWatch.clear)
			end
		end
		-- rare orphan cleanup
		if master.frame % 180 == 0 then
			local anyOn = S.CrimSafeESP or S.CrimDealerESP or S.CrimCrateESP or S.CrimGunESP
			if not anyOn then
				runHeavy(function()
					local gui = getGui()
					if not gui then return end
					for _, ch in ipairs(gui:GetChildren()) do
						if ch.Name == "VG_CrimESP" or ch.Name == "VG_CratePickupFx" then
							ch:Destroy()
						elseif ch:IsA("Highlight") and ch.Parent == gui and not ch.Name:find("^VG_") then
							ch:Destroy()
						end
					end
				end)
			end
		end
	end))
end

local function stopMaster()
	if master.conn then master.conn:Disconnect(); master.conn=nil end
	if crateWatch.folderConn then crateWatch.folderConn:Disconnect(); crateWatch.folderConn=nil end
	if crateWatch.removeConn then crateWatch.removeConn:Disconnect(); crateWatch.removeConn=nil end
	if crateWatch.folderWatch then crateWatch.folderWatch:Disconnect(); crateWatch.folderWatch=nil end
	if gunWatch.folderConn then gunWatch.folderConn:Disconnect(); gunWatch.folderConn=nil end
	if gunWatch.removeConn then gunWatch.removeConn:Disconnect(); gunWatch.removeConn=nil end
	if gunWatch.folderWatch then gunWatch.folderWatch:Disconnect(); gunWatch.folderWatch=nil end
	pcall(stopNoRecoil)
	pcall(stopNoRagdoll)
	pcall(misc.ragdollDrag.stop)
	pcall(misc.fastAccel.stop)
	pcall(stopStaffDetect)
	pcall(stopNoFailLockpick)
	pcall(stopFullBright)
	pcall(misc.noFog.stop)
	pcall(misc.skipIntro.stop)
	pcall(misc.skinChanger.stop)
	pcall(misc.helmet.stop)
	pcall(stopRemoveSmokeExplosion)
	pcall(snd.stop)
	pcall(autoRespawn.stop)
	clearAllPickupFx()
	stopFastPickupInput()
	if elev.conn then
		elev.conn:Disconnect()
		elev.conn = nil
	end
	crimStamina.active = false
	door.lastTick = 0
	clearCrateESP()
	gunWatch.clear()
	clearSafeESP()
	clearDealerESP()
	if allow.atm then
		if alive(allow.atm.h) then allow.atm.h:Destroy() end
		if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
		allow.atm = nil
	end
	table.clear(gunWatch.idCache)
end

-- ── INVSEE (manual scan: Backpack + Character / Workspace.Characters) ─────────
function Criminality.ScanInventories()
	local out = {}
	local lp = getLP()
	local charsFolder = workspace:FindFirstChild("Characters")
	local SKIP = {
		VM = true,
	}

	local function collectFrom(container, where, equipped, tools, seen)
		if not container then
			return
		end
		for _, ch in ipairs(container:GetChildren()) do
			if ch:IsA("Tool") and not SKIP[ch.Name] and not seen[ch] then
				seen[ch] = true
				tools[#tools + 1] = {
					name = ch.Name,
					equipped = equipped == true,
					where = where,
				}
			end
		end
	end

	for _, plr in ipairs(Plrs:GetPlayers()) do
		local tools, seen = {}, {}
		collectFrom(plr:FindFirstChild("Backpack"), "Backpack", false, tools, seen)
		local charModel = nil
		if charsFolder then
			charModel = charsFolder:FindFirstChild(plr.Name)
		end
		if not charModel then
			charModel = plr.Character
		end
		collectFrom(charModel, "Hand", true, tools, seen)
		-- If Players.Character differs from Workspace.Characters, merge both
		if plr.Character and plr.Character ~= charModel then
			collectFrom(plr.Character, "Hand", true, tools, seen)
		end
		table.sort(tools, function(a, b)
			if a.equipped ~= b.equipped then
				return a.equipped
			end
			return string.lower(a.name) < string.lower(b.name)
		end)
		local handName = nil
		for _, t in ipairs(tools) do
			if t.equipped then
				handName = t.name
				break
			end
		end
		out[#out + 1] = {
			name = plr.Name,
			display = plr.DisplayName,
			userId = plr.UserId,
			isLocal = plr == lp,
			tools = tools,
			count = #tools,
			hand = handName,
		}
	end
	table.sort(out, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return out
end

-- â”€â”€ INIT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S
	S._crimInvseeScan = Criminality.ScanInventories
	if S.CrimMenuMusicTrack == nil then
		S.CrimMenuMusicTrack = menuMus.DEFAULT
	end
	if S.CrimMenuMusic == nil then
		S.CrimMenuMusic = false
	end

	local function crimLog(level, msg)
		pcall(function()
			if typeof(_G.__VG_LOG_FILE) == "function" then
				_G.__VG_LOG_FILE(level or "INFO", string.format("[VG:crim][%.2f] %s", os.clock(), tostring(msg)))
			end
		end)
	end

	local function crimStep(name, fn)
		local t0 = os.clock()
		crimLog("INFO", "step >>> " .. name)
		local ok, err = pcall(fn)
		local ms = math.floor((os.clock() - t0) * 1000)
		if ok then
			crimLog("INFO", string.format("step <<< %s OK (%dms)", name, ms))
		else
			crimLog("ERROR", string.format("step <<< %s ERR (%dms): %s", name, ms, tostring(err)))
		end
		return ok
	end

	crimLog(
		"INFO",
		string.format(
			"Init enter music=%s smoke=%s safeESP=%s crateESP=%s gunESP=%s stamina=%s",
			tostring(S.CrimMenuMusic),
			tostring(S.CrimRemoveSmokeExplosion),
			tostring(S.CrimSafeESP),
			tostring(S.CrimCrateESP),
			tostring(S.CrimGunESP),
			tostring(S.CrimInfStamina)
		)
	)

	S._crimStartMenuMusic = function()
		pcall(menuMus.start, S)
	end
	S._crimSyncGunESP = function()
		if crimFlag(S.CrimGunESP) then
			pcall(gunWatch.sync, S)
			pcall(tickESP, S)
		end
	end
	S._crimRefreshGunMods = function()
		if gunModsWant(S) then
			pcall(function()
				syncGunMods(S)
				refreshGunModsAsync(S, true, true)
			end)
		else
			pcall(syncGunMods, S)
		end
	end
	S._crimElevatorTeleport = function()
		pcall(teleportToElevator, S)
	end
	S._crimListGameSounds = snd.listGameSounds
	S._configApplyHooks = S._configApplyHooks or {}
	table.insert(S._configApplyHooks, function()
		syncFromConfig(S)
	end)

	startFastPickupInput()

	local bootStarted = false
	local function runDeferredBoot()
		if bootStarted or S.Unloaded or _G.__VG_S ~= S then
			return
		end
		bootStarted = true
		crimLog("INFO", "deferred boot begin uiReady=" .. tostring(S._vgUiReady == true))
		if crimFlag(S.CrimInfStamina) then
			crimStep("setupCrimStaminaHook", setupCrimStaminaHook)
		else
			crimLog("INFO", "skip stamina hook (feature off)")
		end
		crimStep("startMaster", function()
			startMaster(S)
		end)
		crimStep("syncFromConfig", function()
			syncFromConfig(S)
		end)
		if S.CrimMenuMusic == true then
			crimStep("menuMus.start", function()
				menuMus.start(S)
			end)
		else
			crimLog("INFO", "skip menu music (off)")
		end
		crimLog("INFO", "deferred boot end")
	end

	S._onVgUiReady = function()
		crimLog("INFO", "UI ready signal received")
		task.defer(function()
			task.wait(0.5)
			runDeferredBoot()
		end)
	end

	task.defer(function()
		local deadline = os.clock() + 12
		while os.clock() < deadline do
			if S._vgUiReady or S.Unloaded or bootStarted then
				break
			end
			task.wait(0.25)
		end
		if S.Unloaded or bootStarted then
			return
		end
		crimLog("WARN", "UI ready timeout — starting deferred boot anyway")
		runDeferredBoot()
	end)
end

return Criminality
