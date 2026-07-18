-- Criminality.lua  v2.52.19
-- Game-specific features for Criminality (Universe 1494262959).
-- Architecture: ONE Heartbeat loop for all features + built-in profiler.
-- Profiler writes timing stats to the log file every 30 s.
-- NOTE: many small state vars are packed into shared tables (COLORS, misc,
-- crateWatch, gunWatch, staff, door, melee, moneyPu, cratePu, ...) purely to
-- stay under Luau's 200-local-register limit for the main chunk.
-- v2.52.19: CS:GO headshot sound (5764885315) as default HeadshotSound swap.
-- v2.52.18: bounty via CoreGUI.NotificationFrame; optional hit sound swap.
-- v2.52.17: removed No Gun Slow. Auto Reload uses GunGUI Current/Stored.

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
local misc = { noFallConns = {}, noSpikeConn = nil }

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

local ESP = { safes={}, dealers={}, crates={}, guns={}, safeByModel={}, crateScanAt=0, gunScanAt=0 }
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

local function isRareCrate(model)
	local cot = getCrateRarityValue(model)
	return cot == 7 or cot == "7"
end

-- Packed into one table to stay under Luau's 200-local limit.
local COLORS = {
	crateNorm = Color3.fromRGB(255, 190, 60),
	crateRare = Color3.fromRGB(255, 55, 55),
	gun       = Color3.fromRGB(80, 255, 140),
	melee     = Color3.fromRGB(255, 170, 60),
	nade      = Color3.fromRGB(255, 90, 90),
	tool      = Color3.fromRGB(170, 195, 255),
	open      = Color3.fromRGB(100, 255, 100),
	safeD     = Color3.fromRGB(255, 220, 50),
}

local function shouldShowCrate(S, rare)
	if not S.CrimCrateESP then
		return false
	end
	if rare then
		return S.CrimCrateRare ~= false
	end
	return S.CrimCrateBasic ~= false
end

local function playCrateSpawnFx(entry, rare)
	if not entry or not alive(entry.h) then
		return
	end
	local fill = rare and (COLORS.crateRare) or (COLORS.crateNorm)
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
		entry.lbl.Text = rare and "\u{2726} RARE SPAWN \u{2726}" or "\u{25B2} CRATE SPAWN \u{25B2}"
		if alive(entry.bg) then
			entry.bg.Size = UDim2.new(0, 118, 0, 20)
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
	local rare = isRareCrate(model)
	if not shouldShowCrate(S, rare) then
		return false
	end
	local fill = rare and (S.CrimCrateRareColor or COLORS.crateRare) or (S.CrimCrateColor or COLORS.crateNorm)
	local label = rare and "RARE CRATE" or "CRATE"
	local part = getCrateVisualPart(model, true)
	if not part then
		return false
	end
	local ok, entry = pcall(makeEntry, model, fill, Color3.fromRGB(255, 255, 255), label, nil, part)
	if not ok or not entry then
		return false
	end
	entry.rare = rare
	crateByModel[model] = entry
	table.insert(ESP.crates, entry)
	if withSpawnFx then
		playCrateSpawnFx(entry, rare)
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
			local rare = isRareCrate(model)
			keep = shouldShowCrate(S, rare)
		end
		if not keep then
			destroyCrateEntry(model)
		else
			-- Refresh rarity label/color if attribute changed
			local rare = isRareCrate(model)
			if e.rare ~= rare then
				e.rare = rare
				local fill = rare and (S.CrimCrateRareColor or COLORS.crateRare) or (S.CrimCrateColor or COLORS.crateNorm)
				local label = rare and "RARE CRATE" or "CRATE"
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
local gunByModel = {}
-- Packed into one table to stay under Luau's 200-local limit.
local gunWatch = { folderConn = nil, removeConn = nil, folderWatch = nil }


local function hasDeepChild(model, name)
	return model and model:FindFirstChild(name, true) ~= nil
end

local toolIdCache = setmetatable({}, { __mode = "k" })

local function rememberToolId(model, label, kind)
	local entry = { label, kind }
	toolIdCache[model] = entry
	return label, kind
end

local function identifySpawnedTool(model)
	local cached = toolIdCache[model]
	if cached then
		return cached[1], cached[2]
	end
	for _, key in ipairs({ "Name", "Item", "ToolName", "GunName", "DisplayName" }) do
		local val = model:GetAttribute(key)
		if val ~= nil and tostring(val) ~= "" then
			local label = string.upper(tostring(val))
			local kind = "other"
			if label:find("GRENADE", 1, true) then
				kind = "grenade"
			elseif hasDeepChild(model, "MagPart") or hasDeepChild(model, "BoltPart") or hasDeepChild(model, "Barrel") then
				kind = "gun"
			elseif hasDeepChild(model, "WeaponHandle") or hasDeepChild(model, "ClubMesh") or hasDeepChild(model, "Crowbar") then
				kind = "melee"
			end
			return rememberToolId(model, label, kind)
		end
	end

	if hasDeepChild(model, "Crowbar") then return rememberToolId(model, "CROWBAR", "melee") end
	if hasDeepChild(model, "ClubMesh") then return rememberToolId(model, "CLUB", "melee") end
	if hasDeepChild(model, "Wrench") and not hasDeepChild(model, "Crowbar") then return rememberToolId(model, "WRENCH", "melee") end
	if hasDeepChild(model, "Pin") and hasDeepChild(model, "He") then return rememberToolId(model, "GRENADE", "grenade") end
	if hasDeepChild(model, "Chain1") or (hasDeepChild(model, "Blade") and hasDeepChild(model, "Cord")) then
		return rememberToolId(model, "CHAINSAW", "melee")
	end
	if hasDeepChild(model, "BoltPart") and hasDeepChild(model, "MagPart") then return rememberToolId(model, "RIFLE", "gun") end
	if hasDeepChild(model, "MagPart") and (hasDeepChild(model, "Barrel") or hasDeepChild(model, "SlidePart") or hasDeepChild(model, "Slide")) then
		return rememberToolId(model, "PISTOL", "gun")
	end
	if hasDeepChild(model, "MagPart") and hasDeepChild(model, "Bullets") then return rememberToolId(model, "GUN", "gun") end
	if hasDeepChild(model, "MagPart") then return rememberToolId(model, "GUN", "gun") end
	if hasDeepChild(model, "WeaponHandle") then return rememberToolId(model, "WEAPON", "melee") end
	if hasDeepChild(model, "Handle") and hasDeepChild(model, "Pin") then return rememberToolId(model, "GRENADE", "grenade") end

	-- Helmet / vest / armor often expose OriginPart (PIC_TLO) instead of WeaponHandle
	local n = string.upper(tostring(model.Name or ""))
	if n:find("HELMET", 1, true) or n:find("VEST", 1, true) or n:find("ARMOR", 1, true)
		or n:find("KEVLAR", 1, true) or n:find("BALACLAVA", 1, true) then
		return rememberToolId(model, n, "armor")
	end
	if hasDeepChild(model, "OriginPart") and not hasDeepChild(model, "MagPart") and not hasDeepChild(model, "WeaponHandle") then
		return rememberToolId(model, "ARMOR", "armor")
	end

	return rememberToolId(model, "ITEM", "other")
end

local function kindColor(kind, S)
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

local function shouldShowGun(S, kind)
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

local function isSpawnedToolModel(model)
	return model and model:IsA("Model")
end

local function getFilterFolder()
	return workspace:FindFirstChild("Filter")
end

local function getSpawnedTools()
	local filter = getFilterFolder()
	if not filter then
		return nil
	end
	return filter:FindFirstChild("SpawnedTools")
end

local function isInSpawnedTools(model)
	local folder = getSpawnedTools()
	if not folder or not model then
		return false
	end
	return model:IsDescendantOf(folder)
end

local function iterSpawnedToolModels(folder)
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

local function destroyGunEntry(model)
	local e = gunByModel[model]
	if not e then return end
	gunByModel[model] = nil
	toolIdCache[model] = nil
	if alive(e.h)  then e.h:Destroy()  end
	if alive(e.bg) then e.bg:Destroy() end
	for i, entry in ipairs(ESP.guns) do
		if entry == e then
			table.remove(ESP.guns, i)
			break
		end
	end
end

local function sweepOrphanGunGui()
	local gui = getGui()
	local folder = getSpawnedTools()
	if not gui or not folder then
		return
	end
	for _, ch in ipairs(gui:GetChildren()) do
		if ch:IsA("Highlight") and ch.Adornee and ch.Adornee:IsA("Model") then
			if ch.Adornee:IsDescendantOf(folder) and not gunByModel[ch.Adornee] then
				ch:Destroy()
			end
		elseif ch:IsA("BillboardGui") and ch.Adornee and ch.Adornee:IsA("BasePart") then
			local model = ch.Adornee:FindFirstAncestorOfClass("Model")
			if model and model:IsDescendantOf(folder) and not gunByModel[model] then
				ch:Destroy()
			end
		end
	end
end

local function clearGunESP()
	for model in pairs(gunByModel) do
		destroyGunEntry(model)
	end
	table.clear(ESP.guns)
	table.clear(gunByModel)
	sweepOrphanGunGui()
end

local function playGunSpawnFx(entry, fill)
	if not entry or not alive(entry.h) then
		return
	end
	entry.visState = true  -- mark visible so tickESP doesn't re-run fade-in over the fx
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

local function addGunESP(model, S, withSpawnFx)
	if not isSpawnedToolModel(model) or gunByModel[model] then
		return false
	end
	local label, kind = identifySpawnedTool(model)
	if not shouldShowGun(S, kind) then
		return false
	end
	local fill = kindColor(kind, S)
	local ok, entry = pcall(makeEntry, model, fill, Color3.fromRGB(255, 255, 255), label, nil)
	if not ok or not entry then
		return false
	end
	local wh = model:FindFirstChild("WeaponHandle", true)
	if wh and wh:IsA("BasePart") then
		entry.part = wh
		if alive(entry.bg) then entry.bg.Adornee = wh end
	elseif alive(entry.part) and alive(entry.bg) then
		entry.bg.Adornee = entry.part
	end
	if alive(entry.bg) then
		entry.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 22, 64, 122), 0, 20)
	end
	entry.kind = kind
	entry.label = label
	gunByModel[model] = entry
	table.insert(ESP.guns, entry)
	if withSpawnFx then
		playGunSpawnFx(entry, fill)
	end
	return true
end

local function syncGunESP(S)
	if not S.CrimGunESP then
		if #ESP.guns > 0 then
			clearGunESP()
		end
		return
	end

	local folder = getSpawnedTools()
	if not folder then
		return
	end

	for i = #ESP.guns, 1, -1 do
		local e = ESP.guns[i]
		local model = e.model
		local keep = alive(model) and isSpawnedToolModel(model) and isInSpawnedTools(model)
		if keep then
			local label, kind = identifySpawnedTool(model)
			keep = shouldShowGun(S, kind)
			if keep and (e.label ~= label or e.kind ~= kind) then
				e.label = label
				e.kind = kind
				local fill = kindColor(kind, S)
				if alive(e.h) then e.h.FillColor = fill end
				if alive(e.lbl) then e.lbl.Text = label end
				if alive(e.bg) then
					e.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 22, 64, 122), 0, 20)
				end
			end
		end
		if not keep then
			destroyGunEntry(model)
		end
	end

	for _, model in ipairs(iterSpawnedToolModels(folder)) do
		addGunESP(model, S, false)
	end
end

local function bindGunFolder(folder)
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
				if not curS or not curS.CrimGunESP then
					return
				end
				RS.Heartbeat:Wait()
				local targets = ch:IsA("Model") and { ch } or iterSpawnedToolModels(ch)
				for _, model in ipairs(targets) do
					local added = addGunESP(model, curS, true)
					if added then
						pcall(tickESP, curS)
					end
				end
		end)
	end)
	gunWatch.removeConn = folder.ChildRemoved:Connect(function(ch)
		if ch:IsA("Model") then
			destroyGunEntry(ch)
		else
			for _, model in ipairs(iterSpawnedToolModels(ch)) do
				destroyGunEntry(model)
			end
		end
	end)
end

local function ensureGunWatch(S)
	local folder = getSpawnedTools()
	if folder then
		bindGunFolder(folder)
		return
	end

	local filter = getFilterFolder()
	if filter then
		if not gunWatch.folderWatch then
			gunWatch.folderWatch = filter.ChildAdded:Connect(function(ch)
				if ch.Name ~= "SpawnedTools" then
					return
				end
				task.defer(function()
					local curS = _G.__VG_S
					if curS and curS.CrimGunESP then
						bindGunFolder(ch)
						syncGunESP(curS)
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
				ensureGunWatch(curS)
				syncGunESP(curS)
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

	-- Dealers
	local showDlr = S.CrimDealerESP
	for _, e in ipairs(ESP.dealers) do
		local vis = false
		if showDlr and alive(e.part) then
			vis = (camPos - e.part.Position).Magnitude <= maxDist
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
				vis = (camPos - e.part.Position).Magnitude <= crateDist
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
		if showGun and alive(e.model) and isInSpawnedTools(e.model) then
			if not shouldShowGun(S, e.kind or "other") then
				vis = false
			else
			if not alive(e.part) then
				local wh = e.model:FindFirstChild("WeaponHandle", true)
				e.part = (wh and wh:IsA("BasePart")) and wh or getModelPart(e.model)
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
	local rare = isRareCrate(model)
	if rare then
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

local function startPickupFx(model, rare)
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

	local fill = rare and Color3.fromRGB(255, 70, 255) or Color3.fromRGB(60, 255, 130)
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
	lbl.Text = rare and "RARE PICKUP" or "PICKING UP"
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
		startPickupFx(model, isRareCrate(model))
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
				local rare = isRareCrate(model)
				local score = dist + (rare and 0 or 1000)
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
	if not isSpawnedToolModel(model) or not alive(model) then
		return false
	end
	local _, kind = identifySpawnedTool(model)
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

	local folder = getSpawnedTools()
	if folder then
		for _, model in ipairs(iterSpawnedToolModels(folder)) do
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
							kind = select(2, identifySpawnedTool(model)),
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
			destroyGunEntry(target.model)
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
	gunMods = false,
	staffDetect = false,
	noFailLockpick = false,
	fullBright = false,
	hitSounds = false,
	autoRespawn = false,
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
	-- Prefer the real menu track object; fall back to any Sound named music
	local music = intro:FindFirstChild("music") or intro:FindFirstChild("Music")
	if music and music:IsA("Sound") then
		menuMus.patch(music, id)
		return
	end
	for _, d in ipairs(intro:GetDescendants()) do
		if d:IsA("Sound") and (d.Name == "music" or d.Name == "Music") then
			menuMus.patch(d, id)
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

	local function hookPlayerGui(pg)
		if not pg then
			return
		end
		table.insert(
			menuMus.conns,
			pg.DescendantAdded:Connect(function(inst)
				local cur = _G.__VG_S
				if not cur or cur.CrimMenuMusic ~= true then
					return
				end
				if inst:IsA("Sound") then
					local intro = pg:FindFirstChild("Intro")
					if intro and inst:IsDescendantOf(intro) then
						menuMus.patch(inst, menuMus.resolveId(cur))
					elseif inst.Name == "music" or inst.Name == "Music" then
						menuMus.patch(inst, menuMus.resolveId(cur))
					end
				elseif inst.Name == "Intro" then
					task.defer(function()
						menuMus.scan(cur)
					end)
				end
			end)
		)
		task.spawn(function()
			for _ = 1, 40 do
				local cur = _G.__VG_S
				if cur and cur.CrimMenuMusic == true then
					menuMus.scan(cur)
				end
				task.wait(0.05)
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

function Criminality.StartMenuMusicEarly(S)
	if not Criminality.IsCriminality() then
		return
	end
	if S then
		if S.CrimMenuMusic == nil then
			S.CrimMenuMusic = true
		end
		if S.CrimMenuMusicTrack == nil then
			S.CrimMenuMusicTrack = menuMus.DEFAULT
		end
	end
	if not S or S.CrimMenuMusic == true then
		menuMus.start(S)
	end
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
	syncGunMods(S)
	syncFeatureToggle("staffDetect", "CrimStaffDetect", startStaffDetect, stopStaffDetect, S)
	syncFeatureToggle("noFailLockpick", "CrimNoFailLockpick", startNoFailLockpick, stopNoFailLockpick, S)
	syncFeatureToggle("fullBright", "CrimFullBright", startFullBright, stopFullBright, S)
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
	if crimFlag(S.CrimGunESP) then
		pcall(ensureGunWatch, S)
		pcall(syncGunESP, S)
	elseif #ESP.guns > 0 then
		pcall(clearGunESP)
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
			syncGunMods(S)
			syncFeatureToggle("staffDetect", "CrimStaffDetect", startStaffDetect, stopStaffDetect, S)
			syncFeatureToggle("noFailLockpick", "CrimNoFailLockpick", startNoFailLockpick, stopNoFailLockpick, S)
			syncFeatureToggle("fullBright", "CrimFullBright", startFullBright, stopFullBright, S)
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
		if S.CrimDealerESP and not espBuilt.dealers and workspace:FindFirstChild("Map") then
			if master.frame % 90 == 0 then
				runHeavy(function()
					pcall(buildDealerESP, _G.__VG_S)
				end)
			end
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
					pcall(ensureGunWatch, _G.__VG_S)
				end)
			end
			if master.frame % 50 == 35 then
				ESP.gunScanAt = tick()
				runHeavy(function()
					pcall(syncGunESP, _G.__VG_S)
				end)
			end
		elseif #ESP.guns > 0 then
			pcall(clearGunESP)
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
					if cur and cur.CrimDealerESP then pcall(buildDealerESP, cur) end
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
				pcall(clearGunESP)
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
	pcall(stopStaffDetect)
	pcall(stopNoFailLockpick)
	pcall(stopFullBright)
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
	clearGunESP()
	clearSafeESP()
	if allow.atm then
		if alive(allow.atm.h) then allow.atm.h:Destroy() end
		if alive(allow.atm.bg) then allow.atm.bg:Destroy() end
		allow.atm = nil
	end
	table.clear(toolIdCache)
end

-- â”€â”€ INIT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S

	-- Menu music as early as Init allows (also started from Main via StartMenuMusicEarly)
	if S.CrimMenuMusic == true then
		pcall(menuMus.start, S)
	end
	S._crimStartMenuMusic = function()
		pcall(menuMus.start, S)
	end

	S._crimSyncGunESP = function()
		if crimFlag(S.CrimGunESP) then
			pcall(syncGunESP, S)
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

	setupCrimStaminaHook()
	startFastPickupInput()
	startMaster(S)
	syncFromConfig(S)
end

return Criminality
