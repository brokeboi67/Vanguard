-- ClientBuild.lua  v2.52.28
-- NOTE: bump with Settings.Version when changing.
-- Client-only bridge + delete + wallbang.
-- Wallbang punches WALLS only (CanCollide+CanQuery off). Floors never punched.
-- CRITICAL: on disable/init, nuclear-heal leftover collide=false (old bug left floors soft).

local ClientBuild = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local FOLDER = "VG_ClientBuild"
local mode = nil
local bridgeA = nil
local inputConn = nil
local markerA = nil
local markerB = nil
local bridges = {}
local hidden = {}

local wallbangOn = false
local wallbang = {} -- [part] = { canCollide, canQuery }
local wallbangSafe = {}
local wallbangMapConn = nil
local wallbangFeetConn = nil
local wallbangSyncConn = nil
local wallbangScanToken = 0
local settingsRef = nil

local function notify(title, text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title or "Client Build",
			Text = text or "",
			Duration = 3,
		})
	end)
end

local function lp()
	return Players.LocalPlayer
end

local function ensureFolder()
	local f = workspace:FindFirstChild(FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER
		f.Parent = workspace
	end
	return f
end

local function clearMarkers()
	if markerA then
		pcall(function()
			markerA:Destroy()
		end)
		markerA = nil
	end
	if markerB then
		pcall(function()
			markerB:Destroy()
		end)
		markerB = nil
	end
end

local function makeMarker(pos, color)
	local p = Instance.new("Part")
	p.Name = "VG_Mark"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.7, 0.7, 0.7)
	p.Color = color
	p.Transparency = 0.15
	p.CFrame = CFrame.new(pos)
	p.Parent = ensureFolder()
	return p
end

local function mouseRay(maxDist)
	local cam = workspace.CurrentCamera
	local player = lp()
	if not cam or not player then
		return nil
	end
	local mouse = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { ensureFolder() }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * (maxDist or 500), params)
end

local function buildBridge(a, b)
	local dist = (b - a).Magnitude
	if dist < 1 then
		notify("Bridge", "Za blisko — wybierz dalej")
		return nil
	end
	if dist > 400 then
		notify("Bridge", "Za daleko (max 400)")
		return nil
	end
	local mid = (a + b) * 0.5
	local part = Instance.new("Part")
	part.Name = "VG_Bridge"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.WoodPlanks
	part.Color = Color3.fromRGB(110, 85, 55)
	part.Size = Vector3.new(5, 0.85, dist)
	part.CFrame = CFrame.lookAt(mid, b)
	part.Parent = ensureFolder()
	table.insert(bridges, part)
	return part
end

local function hideAsset(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:IsDescendantOf(ensureFolder()) then
		pcall(function()
			part:Destroy()
		end)
		for i = #bridges, 1, -1 do
			if bridges[i] == part then
				table.remove(bridges, i)
			end
		end
		notify("Delete", "Usunięto local bridge")
		return true
	end
	table.insert(hidden, {
		part = part,
		canCollide = part.CanCollide,
		transparency = part.Transparency,
		canQuery = part.CanQuery,
	})
	wallbang[part] = nil
	pcall(function()
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		if part.LocalTransparencyModifier ~= nil then
			part.LocalTransparencyModifier = 1
		end
	end)
	notify("Delete", "Schowano lokalnie: " .. tostring(part.Name))
	return true
end

local function stopMode()
	mode = nil
	bridgeA = nil
	clearMarkers()
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
end

local function onClick()
	if not mode then
		return
	end
	local hit = mouseRay(600)
	if mode == "bridge" then
		if not hit then
			notify("Bridge", "Nie trafilo w nic — kliknij w podłogę/ścianę")
			return
		end
		local pos = hit.Position + hit.Normal * 0.15
		if not bridgeA then
			bridgeA = pos
			clearMarkers()
			markerA = makeMarker(pos, Color3.fromRGB(80, 220, 120))
			notify("Bridge", "Punkt A — kliknij punkt B")
		else
			markerB = makeMarker(pos, Color3.fromRGB(80, 160, 255))
			local ok = buildBridge(bridgeA, pos)
			if ok then
				notify("Bridge", "Most client gotowy")
			end
			stopMode()
		end
	elseif mode == "delete" then
		if not hit or not hit.Instance then
			notify("Delete", "Nic nie trafiono")
			return
		end
		local part = hit.Instance
		if not part:IsA("BasePart") then
			part = part:FindFirstAncestorWhichIsA("BasePart")
		end
		if part then
			hideAsset(part)
		end
		stopMode()
	end
end

local function bindInput()
	if inputConn then
		return
	end
	inputConn = UIS.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onClick()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			notify("Client Build", "Anulowano")
			stopMode()
		end
	end)
end

-- ── Wallbang ─────────────────────────────────────────────────────────────────

local function isHiddenPart(part)
	for _, e in ipairs(hidden) do
		if e.part == part then
			return true
		end
	end
	return false
end

local function iterMapParts(fn)
	local roots = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(roots, map)
	end
	for _, name in ipairs({ "Buildings", "Props", "Structures", "World", "Geometry" }) do
		local f = workspace:FindFirstChild(name)
		if f and f ~= map then
			table.insert(roots, f)
		end
	end
	if #roots == 0 then
		for _, ch in ipairs(workspace:GetChildren()) do
			if (ch:IsA("Folder") or ch:IsA("Model")) and ch.Name ~= FOLDER then
				if not Players:GetPlayerFromCharacter(ch) then
					table.insert(roots, ch)
				end
			end
		end
	end
	for _, root in ipairs(roots) do
		local descs = root:GetDescendants()
		for i, d in ipairs(descs) do
			if d:IsA("BasePart") then
				fn(d)
			end
			if i % 250 == 0 then
				task.wait()
			end
		end
	end
end

-- Flat walk surfaces (no names — map is obfuscated).
local function isLikelyFloor(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local size = part.Size
	local upY = math.abs(part.CFrame.UpVector.Y)
	local footprint = size.X * size.Z
	local maxXZ = math.max(size.X, size.Z)
	local minXZ = math.min(size.X, size.Z)

	-- Classic horizontal slab
	if upY >= 0.55 then
		if size.Y <= 8 then
			return true
		end
		if footprint >= 30 and size.Y <= 30 then
			return true
		end
		if footprint >= size.Y * maxXZ * 0.4 then
			return true
		end
	end
	-- Wide flat-ish even if slightly tilted
	if footprint >= 80 and size.Y <= 12 and minXZ >= 4 then
		return true
	end
	return false
end

-- STRICT walls only. No "tilted catch-all" (that punched floors).
local function isLikelyWall(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if isLikelyFloor(part) then
		return false
	end
	local size = part.Size
	local upY = math.abs(part.CFrame.UpVector.Y)
	local minXZ = math.min(size.X, size.Z)
	local maxXZ = math.max(size.X, size.Z)
	-- Must be upright-ish and thin + tall
	if upY < 0.7 then
		return false
	end
	if size.Y < 4 then
		return false
	end
	if minXZ > 6 then
		return false
	end
	if maxXZ < 2 then
		return false
	end
	return true
end

--[[
	NUCLEAR HEAL — fixes "disabled wallbang but still falling".
	Our punch always sets BOTH CanCollide=false AND CanQuery=false and keeps Transparency.
	Restore every such anchored visible part. Also force-solid every likely floor.
]]
local function healMapCollide(reason)
	local fixed = 0
	-- 1) tracked punches
	for part, orig in pairs(wallbang) do
		if part and part.Parent and type(orig) == "table" then
			pcall(function()
				part.CanCollide = orig.canCollide ~= false and orig.canCollide or true
				part.CanQuery = orig.canQuery
				if not part.CanCollide and isLikelyFloor(part) then
					part.CanCollide = true
				end
			end)
			fixed += 1
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)

	-- 2) orphan punches + all floors
	iterMapParts(function(part)
		if isHiddenPart(part) then
			return
		end
		local punched = part.Anchored and (not part.CanCollide) and (not part.CanQuery) and part.Transparency < 0.99
		local floorSoft = isLikelyFloor(part) and not part.CanCollide
		if punched or floorSoft then
			pcall(function()
				part.CanCollide = true
				if punched then
					part.CanQuery = true
				end
			end)
			fixed += 1
			wallbangSafe[part] = true
		end
	end)

	-- 3) under feet right now
	local player = lp()
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, ensureFolder() }
		for _, off in ipairs({
			Vector3.zero,
			Vector3.new(2, 0, 0),
			Vector3.new(-2, 0, 0),
			Vector3.new(0, 0, 2),
			Vector3.new(0, 0, -2),
			Vector3.new(3, 0, 3),
			Vector3.new(-3, 0, -3),
		}) do
			-- Cast from high above in case already under map
			local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 50, 0) + off, Vector3.new(0, -200, 0), params)
			if hit and hit.Instance and hit.Instance:IsA("BasePart") then
				pcall(function()
					hit.Instance.CanCollide = true
				end)
				wallbangSafe[hit.Instance] = true
			end
		end
		-- Also solidify anything near HRP in a big box (if stuck under)
		pcall(function()
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { char, ensureFolder() }
			local parts = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(40, 40, 40), op)
			for _, p in ipairs(parts) do
				if p:IsA("BasePart") and isLikelyFloor(p) then
					p.CanCollide = true
					wallbangSafe[p] = true
				end
			end
		end)
	end

	if reason then
		notify("Wallbang", "Heal collidów (" .. tostring(reason) .. ") · ~" .. tostring(fixed))
	end
end

local function markSafeAndSolid(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	wallbangSafe[part] = true
	wallbang[part] = nil
	pcall(function()
		part.CanCollide = true
	end)
end

local function protectStanding()
	local player = lp()
	local char = player and player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local folder = ensureFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	for _, off in ipairs({
		Vector3.zero,
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2),
		Vector3.new(1.5, 0, 1.5),
		Vector3.new(-1.5, 0, -1.5),
	}) do
		local hit = workspace:Raycast(origin + off, Vector3.new(0, -25, 0), params)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") then
			markSafeAndSolid(hit.Instance)
		end
	end
	pcall(function()
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { char, folder }
		local parts = workspace:GetPartBoundsInBox(
			hrp.CFrame * CFrame.new(0, -3, 0),
			Vector3.new(12, 12, 12),
			op
		)
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				local rel = hrp.CFrame:PointToObjectSpace(p.Position)
				if rel.Y < 3 then
					markSafeAndSolid(p)
				end
			end
		end
	end)
end

local function shouldWallbangPart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:IsDescendantOf(ensureFolder()) or isHiddenPart(part) then
		return false
	end
	if wallbangSafe[part] then
		return false
	end
	if isLikelyFloor(part) then
		wallbangSafe[part] = true
		return false
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then
		return false
	end
	if not isLikelyWall(part) then
		return false
	end
	return true
end

local function punchPart(part)
	if wallbang[part] ~= nil or wallbangSafe[part] then
		return
	end
	if not shouldWallbangPart(part) then
		return
	end
	wallbang[part] = {
		canCollide = part.CanCollide,
		canQuery = part.CanQuery,
	}
	pcall(function()
		part.CanCollide = false
		part.CanQuery = false
	end)
end

local function clearWallbangConns()
	if wallbangMapConn then
		wallbangMapConn:Disconnect()
		wallbangMapConn = nil
	end
	if wallbangFeetConn then
		wallbangFeetConn:Disconnect()
		wallbangFeetConn = nil
	end
end

local function scanWallsOnly()
	wallbangScanToken += 1
	local token = wallbangScanToken
	task.spawn(function()
		protectStanding()
		local map = workspace:FindFirstChild("Map")
		local roots = {}
		if map then
			table.insert(roots, map)
		end
		for _, root in ipairs(roots) do
			if token ~= wallbangScanToken or not wallbangOn then
				return
			end
			for i, d in ipairs(root:GetDescendants()) do
				if token ~= wallbangScanToken or not wallbangOn then
					return
				end
				punchPart(d)
				if i % 100 == 0 then
					protectStanding()
					task.wait()
				end
			end
		end
		protectStanding()
		-- strip any floor that slipped into wallbang
		for part, _ in pairs(wallbang) do
			if part and isLikelyFloor(part) then
				markSafeAndSolid(part)
			end
		end
	end)
end

local function startFeetWatch()
	if wallbangFeetConn then
		return
	end
	wallbangFeetConn = RS.Stepped:Connect(function()
		if wallbangOn then
			protectStanding()
		end
	end)
end

function ClientBuild.HealWallbangCollide()
	task.spawn(function()
		healMapCollide("manual")
	end)
end

function ClientBuild.SetWallbang(on)
	on = on == true
	if on == wallbangOn then
		if on then
			protectStanding()
			startFeetWatch()
		end
		return
	end
	wallbangOn = on
	if on then
		-- clean slate first so old soft floors are fixed before new punches
		clearWallbangConns()
		healMapCollide(nil)
		table.clear(wallbangSafe)
		protectStanding()
		startFeetWatch()
		local map = workspace:FindFirstChild("Map")
		if map then
			wallbangMapConn = map.DescendantAdded:Connect(function(d)
				if wallbangOn then
					punchPart(d)
				end
			end)
		end
		scanWallsOnly()
		notify("Wallbang", "ON — tylko cienkie ściany; podłoga solidna")
	else
		clearWallbangConns()
		wallbangScanToken += 1
		-- MUST heal orphans — tracked table alone left floors soft after disable
		healMapCollide("OFF")
		table.clear(wallbangSafe)
		notify("Wallbang", "OFF + heal collidów mapy")
	end
end

function ClientBuild.StartBridge()
	stopMode()
	mode = "bridge"
	bridgeA = nil
	bindInput()
	notify("Bridge", "Kliknij punkt A, potem B  (Esc = anuluj)")
end

function ClientBuild.StartDelete()
	stopMode()
	mode = "delete"
	bindInput()
	notify("Delete", "Kliknij 1 asset do schowania lokalnie  (Esc = anuluj)")
end

function ClientBuild.ClearBridges()
	for _, p in ipairs(bridges) do
		pcall(function()
			p:Destroy()
		end)
	end
	table.clear(bridges)
	local f = workspace:FindFirstChild(FOLDER)
	if f then
		for _, ch in ipairs(f:GetChildren()) do
			if ch.Name == "VG_Bridge" or ch.Name == "VG_Mark" then
				pcall(function()
					ch:Destroy()
				end)
			end
		end
	end
	notify("Bridge", "Wyczyszczono mosty client")
end

function ClientBuild.RestoreHidden()
	for _, e in ipairs(hidden) do
		local p = e.part
		if p and p.Parent then
			pcall(function()
				p.CanCollide = e.canCollide
				p.Transparency = e.transparency
				p.CanQuery = e.canQuery
				if p.LocalTransparencyModifier ~= nil then
					p.LocalTransparencyModifier = 0
				end
			end)
		end
	end
	table.clear(hidden)
	notify("Delete", "Przywrócono schowane assety")
end

function ClientBuild.Stop()
	stopMode()
	if wallbangOn then
		wallbangOn = false
		clearWallbangConns()
		healMapCollide(nil)
	end
	if wallbangSyncConn then
		wallbangSyncConn:Disconnect()
		wallbangSyncConn = nil
	end
	settingsRef = nil
end

function ClientBuild.Init(S)
	ClientBuild.Stop()
	if not S then
		return
	end
	settingsRef = S
	S._clientBridgeStart = ClientBuild.StartBridge
	S._clientDeleteStart = ClientBuild.StartDelete
	S._clientBridgeClear = ClientBuild.ClearBridges
	S._clientDeleteRestore = ClientBuild.RestoreHidden
	S._clientWallbangSet = ClientBuild.SetWallbang
	S._clientWallbangHeal = ClientBuild.HealWallbangCollide

	-- Always fix leftover soft floors from older versions / bad disable
	task.spawn(function()
		healMapCollide("boot")
	end)

	-- If freefalling under map with wallbang off, keep healing floors
	wallbangSyncConn = RS.Heartbeat:Connect(function()
		local want = settingsRef and settingsRef.CrimWallbang == true
		if want ~= wallbangOn then
			ClientBuild.SetWallbang(want)
		end
		if wallbangOn then
			return
		end
		local player = lp()
		local char = player and player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < 20 then
				protectStanding()
				pcall(function()
					local op = OverlapParams.new()
					op.FilterType = Enum.RaycastFilterType.Exclude
					op.FilterDescendantsInstances = { char, ensureFolder() }
					for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(60, 80, 60), op)) do
						if p:IsA("BasePart") and not p.CanCollide and isLikelyFloor(p) then
							p.CanCollide = true
						end
					end
				end)
			end
		end
	end)

	-- Force wallbang off on boot if it was left on — user can re-enable
	-- (prevents instant fall from old config). Still honor saved true after heal.
	if S.CrimWallbang then
		task.delay(0.6, function()
			if settingsRef and settingsRef.CrimWallbang then
				ClientBuild.SetWallbang(true)
			end
		end)
	end
end

return ClientBuild
