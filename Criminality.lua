-- Criminality.lua  v2.52.7
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
local Lighting = game:GetService("Lighting")
local TS    = game:GetService("TweenService")

local function getLP()   return Plrs.LocalPlayer end
local function getChar() local lp=getLP(); return lp and lp.Character end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid"),c end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart"),c end

local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local UIS; pcall(function() UIS = game:GetService("UserInputService") end)

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

-- ── SAFE / DEALER / CRATE ESP ────────────────────────────────────────────────
-- Safes/dealers: one build pass. Crates: dynamic (SpawnedPiles).
-- Per-frame: only reads cached .part.Position and sets .Enabled.

local ESP = { safes={}, dealers={}, crates={}, guns={}, safeByModel={}, crateScanAt=0, gunScanAt=0 }
local espBuilt = { safes=false, dealers=false }
local crateByModel = {}
local crateFolderConn = nil
local crateRemoveConn = nil
local crateFolderWatch = nil

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

local CRATE_MAX_AXIS = 10

local function isReasonableCratePart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local sz = part.Size
	return sz.X <= CRATE_MAX_AXIS and sz.Y <= CRATE_MAX_AXIS and sz.Z <= CRATE_MAX_AXIS
end

local function getCrateVisualPart(model)
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
	-- deep fallback — crates often stream nested MeshParts a frame late
	if not best then
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
	-- Workspace.Filter.SpawnedPiles → each child named C1 is a crate.
	return model.Name == "C1" and isInSpawnedPiles(model)
end

local function getCrateRarityValue(model)
	return model:GetAttribute("cot_") or model:GetAttribute("col_")
end

local function getCrateMeshPart(model)
	return getCrateVisualPart(model)
end

local function isRareCrate(model)
	local cot = getCrateRarityValue(model)
	return cot == 7 or cot == "7"
end

local colCrateNorm = Color3.fromRGB(255, 190, 60)
local colCrateRare = Color3.fromRGB(255, 55, 55)

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
	local fill = rare and (colCrateRare) or (colCrateNorm)
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
		entry.lbl.Text = rare and "✦ RARE SPAWN ✦" or "▲ CRATE SPAWN ▲"
		task.delay(1.1, function()
			if alive(entry.lbl) and entry.lbl.Text:find("SPAWN") then
				entry.lbl.Text = finalText
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
	local fill = rare and (S.CrimCrateRareColor or colCrateRare) or (S.CrimCrateColor or colCrateNorm)
	local label = rare and "RARE CRATE" or "CRATE"
	local part = getCrateVisualPart(model)
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
				local fill = rare and (S.CrimCrateRareColor or colCrateRare) or (S.CrimCrateColor or colCrateNorm)
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
				e.part = getCrateVisualPart(model)
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
		if crateFolderWatch then
			crateFolderWatch:Disconnect()
			crateFolderWatch = nil
		end
		if not crateFolderConn then
			crateFolderConn = piles.ChildAdded:Connect(function(ch)
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
			crateRemoveConn = piles.ChildRemoved:Connect(function(ch)
				destroyCrateEntry(ch)
			end)
		end
		return
	end

	if crateFolderWatch then
		return
	end
	local filter = workspace:FindFirstChild("Filter")
	if filter then
		crateFolderWatch = filter.ChildAdded:Connect(function(ch)
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
	crateFolderWatch = workspace.ChildAdded:Connect(function(ch)
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

-- ── SPAWNED TOOL / GUN ESP (SpawnedTools) ────────────────────────────────────
local gunByModel = {}
local gunFolderConn = nil
local gunRemoveConn = nil
local gunFolderWatch = nil

local colGun    = Color3.fromRGB(80, 255, 140)
local colMelee  = Color3.fromRGB(255, 170, 60)
local colNade   = Color3.fromRGB(255, 90, 90)
local colTool   = Color3.fromRGB(170, 195, 255)

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
		return S.CrimGunESPGunColor or colGun
	end
	if kind == "grenade" then
		return colNade
	end
	if kind == "melee" then
		return S.CrimGunESPMeleeColor or colMelee
	end
	return colTool
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
		entry.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 18, 64, 110), 0, 16)
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
					e.bg.Size = UDim2.new(0, math.clamp(#label * 7 + 18, 64, 110), 0, 16)
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
	if gunFolderWatch then
		gunFolderWatch:Disconnect()
		gunFolderWatch = nil
	end
	if gunFolderConn then
		gunFolderConn:Disconnect()
		gunFolderConn = nil
	end
	if gunRemoveConn then
		gunRemoveConn:Disconnect()
		gunRemoveConn = nil
	end
	gunFolderConn = folder.ChildAdded:Connect(function(ch)
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
	gunRemoveConn = folder.ChildRemoved:Connect(function(ch)
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
		if not gunFolderWatch then
			gunFolderWatch = filter.ChildAdded:Connect(function(ch)
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

	if gunFolderWatch then
		return
	end
	gunFolderWatch = workspace.ChildAdded:Connect(function(ch)
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
local colOpen   = Color3.fromRGB(100,255,100)
local colSafeD  = Color3.fromRGB(255,220,50)

local function tickESP(S)
	local maxDist = S.CrimESPMaxDist or 300
	local crateDist = S.CrimCrateMaxDist or maxDist
	local gunDist = S.CrimGunESPMaxDist or maxDist
	local camPos  = workspace.CurrentCamera.CFrame.Position

	-- Safes / registers (BredMakurz → Values.Broken)
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
				local newCol = open and colOpen or (S.CrimSafeColor or colSafeD)
				if e.h.FillColor ~= newCol then e.h.FillColor = newCol end
				local base = e.baseLabel or "SAFE"
				local newTxt = open and ("OPEN " .. base) or base
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
			if vis then
				if not e.h.Enabled  then e.h.Enabled  = true end
				if not e.bg.Enabled then e.bg.Enabled = true end
			else
				if e.h.Enabled  then e.h.Enabled  = false end
				if e.bg.Enabled then e.bg.Enabled = false end
			end
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

-- ── CRATE AUTO PICKUP ────────────────────────────────────────────────────────
-- ReplicatedStorage.Events.PIC_PU:FireServer(crateId)

local picPuRemote = nil
local lastPickupAt = 0
local pickupCooldownIds = {}

local function getPicPuRemote()
	if picPuRemote and picPuRemote.Parent then
		return picPuRemote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("PIC_PU")
	if ev and ev:IsA("RemoteEvent") then
		picPuRemote = ev
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
	return getCrateVisualPart(model)
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

local pickupFxByModel = {}
local PICKUP_FX_DURATION = 2.0

local function stopPickupFx(model)
	local fx = pickupFxByModel[model]
	if not fx then
		return
	end
	pickupFxByModel[model] = nil
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
	for model in pairs(pickupFxByModel) do
		stopPickupFx(model)
	end
end

local function startPickupFx(model, rare)
	if not model or not alive(model) then
		return
	end
	for m in pairs(pickupFxByModel) do
		if m ~= model then
			stopPickupFx(m)
		end
	end
	if pickupFxByModel[model] then
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
	pickupFxByModel[model] = fx

	local pulseInfo = TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	fx.pulseTween = TS:Create(h, pulseInfo, { FillTransparency = 0.72, OutlineTransparency = 0.35 })
	fx.pulseTween:Play()

	local bobInfo = TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	fx.bobTween = TS:Create(bg, bobInfo, { StudsOffset = Vector3.new(0, 6.4, 0) })
	fx.bobTween:Play()

	task.delay(PICKUP_FX_DURATION, function()
		if pickupFxByModel[model] == fx then
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
	if pickupCooldownIds[id] and now - pickupCooldownIds[id] < 2.5 then
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
		pickupCooldownIds[id] = now
		lastPickupAt = now
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
	if now - lastPickupAt < delay then
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

	for id, t in pairs(pickupCooldownIds) do
		if now - t > 12 then
			pickupCooldownIds[id] = nil
		end
	end
end

-- ── AUTO PICKUP MONEY (SpawnedBread + CZDPZUS) ───────────────────────────────

local moneyRemote = nil
local lastMoneyPickupAt = 0

local function getMoneyPickupRemote()
	if moneyRemote and moneyRemote.Parent then
		return moneyRemote
	end
	local events = RepSt:FindFirstChild("Events")
	if not events then
		return nil
	end
	local ev = events:FindFirstChild("CZDPZUS")
	if ev and ev:IsA("RemoteEvent") then
		moneyRemote = ev
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
	if now - lastMoneyPickupAt < delay then
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
			lastMoneyPickupAt = now
		end
	end
end

-- ── AUTO CLAIM ALLOWANCE (CLMZALOW + PlayerbaseData2.NextAllowance.Claim) ───

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

-- ── FAST PICKUP (PIC_TLO — guns/melee on ground) ─────────────────────────────
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

-- ── GUN MODS (weapon GC tables: recoil / spread / equip) ─────────────────────
local featureRunning = {
	noFall = false,
	noSpike = false,
	gunMods = false,
	staffDetect = false,
	noFailLockpick = false,
	fullBright = false,
}
local gunMod = {
	conns = {},
	charConns = {},
	scanToken = 0,
	cache = {},
	orig = {},
	lastApplyAt = 0,
	lastDeepAt = 0,
	reapplyInterval = 8,
	deepCooldown = 4,
	baseWalk = nil,
	lastReloadAt = 0,
	reloadBusy = false,
}

-- Extra numeric fields that help 3rd-person kick / walk bloom when present.
local GUN_EXTRA_KEYS = {
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
	for _, key in ipairs(GUN_EXTRA_KEYS) do
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

local function cacheWeapons(deep)
	if typeof(getgc) ~= "function" then return end
	local active = {}
	local found = {}
	-- shallow first; deep only when requested or shallow empty
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
		if #found > 0 then
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
	return S and (
		S.CrimNoRecoil == true
		or S.CrimNoSpread == true
		or S.CrimQuickEquip == true
		or S.CrimNoGunSlow == true
	)
end

local function applyNoGunSlow(weapon, orig, on)
	-- Zero client-side aim/reload walk penalties on the weapon table.
	if on then
		for k, val in pairs(orig or {}) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				local isSlow = low:find("slow", 1, true)
					or (low:find("walk", 1, true) and (low:find("aim", 1, true) or low:find("reload", 1, true) or low:find("ads", 1, true)))
					or low:find("aimwalk", 1, true) or low:find("reloadwalk", 1, true)
				if isSlow then
					-- If it looks like a multiplier (< 1.5), set to 1; if a flat speed, leave to WalkSpeed tick
					if val > 0 and val <= 1.5 then
						weapon[k] = 1
					elseif val < 16 then
						weapon[k] = 16
					end
				end
			end
		end
		gunSet(weapon, "AimWalkSpeed", 16)
		gunSet(weapon, "ReloadWalkSpeed", 16)
		gunSet(weapon, "AdsWalkSpeed", 16)
		gunSet(weapon, "ADSWalkSpeed", 16)
	elseif orig then
		for k, val in pairs(orig) do
			if type(k) == "string" and type(val) == "number" then
				local low = string.lower(k)
				if low:find("slow", 1, true) or low:find("walk", 1, true) then
					if low:find("aim", 1, true) or low:find("reload", 1, true) or low:find("ads", 1, true) or low:find("slow", 1, true) then
						weapon[k] = val
					end
				end
			end
		end
	end
end

-- Restore WalkSpeed if the game slows you during reload/ADS (client-side).
local function tickNoGunSlow(S)
	if not S or not S.CrimNoGunSlow then
		gunMod.baseWalk = nil
		return
	end
	local char = getChar()
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local hasTool = char:FindFirstChildOfClass("Tool") ~= nil
	local ws = hum.WalkSpeed
	if not hasTool then
		gunMod.baseWalk = ws
		return
	end
	if gunMod.baseWalk == nil or ws > gunMod.baseWalk then
		gunMod.baseWalk = ws
	elseif ws + 0.4 < gunMod.baseWalk then
		pcall(function()
			hum.WalkSpeed = gunMod.baseWalk
		end)
	end
end

-- Auto Reload: when mag is empty, press R (client input — server accepts normal reload).
local function ammoNameMatch(n)
	if type(n) ~= "string" then return false end
	n = string.lower(n)
	return n == "ammo" or n == "mag" or n == "magazine" or n == "clip"
		or n == "bullets" or n == "rounds" or n == "chamber"
		or n:find("ammo", 1, true) ~= nil or n:find("mag", 1, true) ~= nil
end

local function readNumberish(v)
	if typeof(v) == "Instance" then
		if v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue") then
			return tonumber(v.Value)
		end
		return nil
	end
	if type(v) == "number" then return v end
	if type(v) == "string" then return tonumber(v) end
	return nil
end

local function getToolAmmo(tool)
	if not tool then return nil end
	-- Attributes first (cheap)
	for _, key in ipairs({ "Ammo", "ammo", "Mag", "Magazine", "Clip" }) do
		local ok, a = pcall(function() return tool:GetAttribute(key) end)
		if ok then
			local n = readNumberish(a)
			if n ~= nil then return n end
		end
	end
	-- Shallow children + one nested folder (Values / Stats)
	local function scanContainer(cont)
		if not cont then return nil end
		for _, ch in ipairs(cont:GetChildren()) do
			if ammoNameMatch(ch.Name) then
				local n = readNumberish(ch)
				if n ~= nil then return n end
			end
			if ch:IsA("Folder") or ch:IsA("Configuration") or ch.Name == "Values" or ch.Name == "Stats" then
				for _, g in ipairs(ch:GetChildren()) do
					if ammoNameMatch(g.Name) then
						local n = readNumberish(g)
						if n ~= nil then return n end
					end
				end
			end
		end
		return nil
	end
	return scanContainer(tool)
end

local function isGunTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	-- Has ammo state → gun
	if getToolAmmo(tool) ~= nil then return true end
	-- Common gun parts / names
	if tool:FindFirstChild("MagPart") or tool:FindFirstChild("Gun") or tool:FindFirstChild("Shoot") then
		return true
	end
	local n = string.lower(tool.Name)
	if n:find("knife") or n:find("crowbar") or n:find("bat") or n:find("sword")
		or n:find("axe") or n:find("pipe") or n:find("wrench") or n:find("taser") then
		return false
	end
	return false
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

local function tickAutoReload(S)
	if not S or not S.CrimAutoReload then return end
	if gunMod.reloadBusy then return end
	local now = tick()
	if now - gunMod.lastReloadAt < 1.1 then return end

	local char = getChar()
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool or not isGunTool(tool) then return end

	local ammo = getToolAmmo(tool)
	if ammo == nil then return end
	if ammo > 0 then return end

	gunMod.reloadBusy = true
	gunMod.lastReloadAt = now
	task.spawn(function()
		pressReloadKey()
		task.wait(0.35)
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
			-- No Recoil on, No Spread off → restore Spread but keep WalkSpread at 0 from recoil path
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
		applyNoGunSlow(weapon, orig, S.CrimNoGunSlow == true)
	end
end

local function refreshGunMods(S, preferDeep)
	if not gunModsWant(S) then
		return
	end
	local now = tick()
	local wantDeep = preferDeep == true and (now - gunMod.lastDeepAt >= gunMod.deepCooldown)
	cacheWeapons(wantDeep)
	if wantDeep then
		gunMod.lastDeepAt = now
	end
	applyGunMods(S)
	gunMod.lastApplyAt = now
end

local function scheduleGunModRefresh(preferDeep, delaySec)
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
		refreshGunMods(S, preferDeep)
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
			scheduleGunModRefresh(true, 0.35)
		end
	end))
	table.insert(gunMod.charConns, backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleGunModRefresh(true, 0.35)
		end
	end))
end

local function onGunModCharacter(character)
	clearGunModCharConns()
	scheduleGunModRefresh(true, 1.0)
	table.insert(gunMod.charConns, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			scheduleGunModRefresh(true, 0.25)
		end
	end))
	table.insert(gunMod.charConns, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleGunModRefresh(true, 0.35)
		end
	end))
	local humanoid = character:WaitForChild("Humanoid", 2)
	if humanoid then
		table.insert(gunMod.charConns, humanoid.Died:Connect(function()
			gunMod.lastDeepAt = 0
			scheduleGunModRefresh(true, 2.0)
		end))
	end
	local lp = getLP()
	watchBackpackForGuns(lp and lp:FindFirstChildOfClass("Backpack"))
end

local function startGunMods(S)
	clearGunModCharConns()
	gunMod.lastDeepAt = 0
	refreshGunMods(S, true)
	local lp = getLP()
	table.insert(gunMod.conns, lp.CharacterAdded:Connect(onGunModCharacter))
	-- Backpack can respawn; keep a live watch on player children
	table.insert(gunMod.conns, lp.ChildAdded:Connect(function(ch)
		if ch:IsA("Backpack") then
			watchBackpackForGuns(ch)
			scheduleGunModRefresh(true, 0.4)
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

local function syncGunMods(S)
	local want = gunModsWant(S)
	if featureRunning.gunMods == want then
		-- already running — still re-apply when toggles change combination
		if want then
			pcall(function() applyGunMods(S) end)
		end
		return
	end
	featureRunning.gunMods = want
	if want then
		pcall(function() startGunMods(S) end)
	else
		pcall(stopGunMods)
	end
end

-- legacy names for stopMaster
local function stopNoRecoil()
	stopGunMods()
end

-- ── STAFF DETECTOR ───────────────────────────────────────────────────────────
local staffConn = nil

local STAFF_GROUPS = {
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

local STAFF_USERS = {
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
	for groupId, roles in pairs(STAFF_GROUPS) do
		local okRank, rank = pcall(function() return player:GetRankInGroup(groupId) end)
		if okRank and rank and rank > 0 then
			local okRole, roleName = pcall(function() return player:GetRoleInGroup(groupId) end)
			if okRole and roleName and roles[roleName] then
				return true, roleName, groupId
			end
		end
	end
	for _, userId in ipairs(STAFF_USERS) do
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
	if staffConn then staffConn:Disconnect() end
	staffConn = Plrs.PlayerAdded:Connect(onStaffPlayerAdded)
	crimNotify("Staff Detection", "Monitoring active", 5)
	task.spawn(function()
		if checkExistingStaff() and staffConn then
			staffConn:Disconnect()
			staffConn = nil
		end
	end)
end

local function stopStaffDetect()
	if staffConn then staffConn:Disconnect(); staffConn = nil end
end

-- ── NO FAIL LOCKPICK ─────────────────────────────────────────────────────────
local lockpickConn = nil

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
	if lockpickConn then lockpickConn:Disconnect() end
	lockpickConn = pg.ChildAdded:Connect(applyNoFailLockpick)
end

local function stopNoFailLockpick()
	if lockpickConn then lockpickConn:Disconnect(); lockpickConn = nil end
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

-- ── AUTO OPEN / UNLOCK DOORS ─────────────────────────────────────────────────
local DOOR_RADIUS  = 6
local DOOR_INTERVAL = 0.25
local lastDoorTick = 0

local function tickDoors(S)
	if not S.CrimAutoOpenDoors and not S.CrimAutoUnlockDoors then return end
	local now = tick()
	if now - lastDoorTick < DOOR_INTERVAL then return end
	lastDoorTick = now

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
			if (playerPos - doorBase.Position).Magnitude <= DOOR_RADIUS then
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
-- Server distance-checks Knob. Far FireServer fails unless we spoof HRP nearby.
-- Spoof = mini-teleport → may trip internal AC (same class as noclip). Prefer
-- no-spoof when already close; Position Spoof toggle OFF by default.
-- Cobalt: Elevator_N.Events.Toggle:FireServer("Do", Elevator_N.Knob1)
local elev = { conn = nil, lastAt = 0, busy = false, NEAR = 11 }
-- ELEV_NEAR packed into elev.NEAR to stay under Luau's 200-local limit

local function tryRemoteElevator(S)
	if not S or S.CrimRemoteElevator ~= true or elev.busy then
		return
	end
	local now = tick()
	if now - elev.lastAt < 0.55 then
		return
	end
	local cam = workspace.CurrentCamera
	local hrp = getHRP()
	if not cam or not hrp then
		return
	end
	local map = workspace:FindFirstChild("Map")
	local doors = map and map:FindFirstChild("Doors")
	if not doors then
		return
	end
	local maxDist = math.clamp(tonumber(S.CrimRemoteElevatorMaxDist) or 400, 50, 1000)
	local origin = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local playerPos = hrp.Position
	local bestToggle, bestKnob, bestName, bestScore, bestDist = nil, nil, nil, nil, nil

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
						bestName = n
						bestDist = (playerPos - part.Position).Magnitude
					end
				end
			end
		end
	end

	if not bestToggle or not bestKnob then
		crimNotify("Elevator", "Brak windy w zasięgu", 2)
		return
	end

	local needSpoof = (bestDist or 999) > elev.NEAR
	if needSpoof and S.CrimRemoteElevatorSpoof ~= true then
		crimNotify("Elevator", "Za daleko — włącz Position Spoof (ryzyko AC) albo podejdź", 3)
		return
	end

	elev.busy = true
	elev.lastAt = now
	task.spawn(function()
		local root = getHRP()
		if not root or not alive(bestKnob) or not alive(bestToggle) then
			elev.busy = false
			return
		end
		local saved = root.CFrame
		local spoofed = false
		if needSpoof then
			local near = bestKnob.CFrame * CFrame.new(0, 1.2, -1.8)
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = near
			end)
			spoofed = true
			-- 1 frame only — shorter blink than 2 waits
			RS.Heartbeat:Wait()
		end
		local ok = pcall(function()
			bestToggle:FireServer("Do", bestKnob)
		end)
		if spoofed then
			pcall(function()
				local r2 = getHRP()
				if r2 then
					r2.CFrame = saved
					r2.AssemblyLinearVelocity = Vector3.zero
				end
			end)
		end
		elev.busy = false
		if ok then
			local tag = spoofed and " [spoof]" or " [near]"
			crimNotify("Elevator", tostring(bestName) .. string.format("  %.0fm", bestDist or 0) .. tag, 2)
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

-- ── INFINITE STAMINA (Criminality) ───────────────────────────────────────────
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

-- ── FULLBRIGHT (Criminality) ─────────────────────────────────────────────────
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

-- ── MASTER HEARTBEAT ─────────────────────────────────────────────────────────
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

		-- Toggle-sync is cheap but not latency-sensitive: run every 6 frames (~0.1s)
		-- to cut per-frame function-call overhead and reduce Criminality tab CPU cost.
		if master.frame % 6 == 0 then
			syncFeatureToggle("noFall", "CrimNoFall", startNoFall, stopNoFall, S)
			syncFeatureToggle("noSpike", "CrimNoSpike", startNoSpike, stopNoSpike, S)
			syncGunMods(S)
			syncFeatureToggle("staffDetect", "CrimStaffDetect", startStaffDetect, stopStaffDetect, S)
			syncFeatureToggle("noFailLockpick", "CrimNoFailLockpick", startNoFailLockpick, stopNoFailLockpick, S)
			syncFeatureToggle("fullBright", "CrimFullBright", startFullBright, stopFullBright, S)
			pcall(syncRemoteElevator, S)
		end

		if crimFlag(S.CrimInfStamina) and not crimStamina.hooked then
			setupCrimStaminaHook()
		end
		crimStamina.active = crimFlag(S.CrimInfStamina)
		if crimStamina.active and master.frame % 8 == 0 then
			refillCrimStamina()
		end

		if featureRunning.gunMods and gunModsWant(S) then
			local now = tick()
			if now - gunMod.lastApplyAt >= gunMod.reapplyInterval then
				gunMod.lastApplyAt = now
				-- cheap: only re-zero cached tables (no getgc every few seconds)
				applyGunMods(S)
			end
		end
		if S.CrimNoGunSlow and master.frame % 2 == 0 then
			pcall(tickNoGunSlow, S)
		end
		if S.CrimAutoReload and master.frame % 4 == 0 then
			pcall(tickAutoReload, S)
		end

		if S.CrimAutoOpenDoors or S.CrimAutoUnlockDoors then
			pcall(tickDoors, S)
		end
		if S.CrimSafeESP then
			if master.frame % 20 == 0 then
				pcall(syncSafeESP, S)
			end
		elseif #ESP.safes > 0 then
			pcall(clearSafeESP)
		end
		if S.CrimDealerESP and not espBuilt.dealers and workspace:FindFirstChild("Map") then
			pcall(buildDealerESP, S)
		end

		if S.CrimCrateESP then
			pcall(ensureCrateWatch, S)
			if master.frame % 8 == 0 or tick() - ESP.crateScanAt > 0.35 then
				ESP.crateScanAt = tick()
				pcall(syncCrateESP, S)
			end
		elseif #ESP.crates > 0 then
			pcall(clearCrateESP)
		end

		if S.CrimGunESP then
			pcall(ensureGunWatch, S)
			if master.frame % 15 == 0 or tick() - ESP.gunScanAt > 0.6 then
				ESP.gunScanAt = tick()
				pcall(syncGunESP, S)
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
				if S.CrimSafeESP   then pcall(syncSafeESP,   S) end
				if S.CrimDealerESP then pcall(buildDealerESP,  S) end
			end)
		end

		if S.CrimMeleeAura then
			tickMelee(S)
		end

		if S.CrimCratePickup and master.frame % 3 == 0 then
			pcall(tickCratePickup, S)
		end
		if S.CrimMoneyPickup and master.frame % 3 == 0 then
			pcall(tickMoneyPickup, S)
		end

		if S.CrimAllowanceClaim and master.frame % 3 == 0 then
			pcall(syncAllowanceAtmESP, S)
		end

		if S.CrimAllowanceClaim and master.frame % 15 == 0 then
			pcall(tickAllowanceClaim, S)
		end

		if S.CrimFastPickup and master.frame % 4 == 0 then
			pcall(tickFastPickup, S)
		end

		if master.frame % 2 == 0 then
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
			if not anyOn then
				local gui = getGui()
				if gui then
					for _, ch in ipairs(gui:GetChildren()) do
						if ch.Name == "VG_CrimESP" or ch.Name == "VG_CratePickupFx" then
							ch:Destroy()
						elseif ch:IsA("Highlight") and ch.Parent == gui and not ch.Name:find("^VG_") then
							ch:Destroy()
						end
					end
				end
			end
		end
	end))
end

local function stopMaster()
	if master.conn then master.conn:Disconnect(); master.conn=nil end
	if crateFolderConn then crateFolderConn:Disconnect(); crateFolderConn=nil end
	if crateRemoveConn then crateRemoveConn:Disconnect(); crateRemoveConn=nil end
	if crateFolderWatch then crateFolderWatch:Disconnect(); crateFolderWatch=nil end
	if gunFolderConn then gunFolderConn:Disconnect(); gunFolderConn=nil end
	if gunRemoveConn then gunRemoveConn:Disconnect(); gunRemoveConn=nil end
	if gunFolderWatch then gunFolderWatch:Disconnect(); gunFolderWatch=nil end
	pcall(stopNoRecoil)
	pcall(stopStaffDetect)
	pcall(stopNoFailLockpick)
	pcall(stopFullBright)
	clearAllPickupFx()
	stopFastPickupInput()
	if elev.conn then
		elev.conn:Disconnect()
		elev.conn = nil
	end
	crimStamina.active = false
	lastDoorTick = 0
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

-- ── INIT ─────────────────────────────────────────────────────────────────────
function Criminality.Init(S)
	if not Criminality.IsCriminality() then return end
	_G.__VG_S = S

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
				refreshGunMods(S, true)
			end)
		else
			pcall(syncGunMods, S)
		end
	end

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
