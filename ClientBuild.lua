-- ClientBuild.lua  v2.52.27
-- NOTE: bump with Settings.Version when changing.
-- Client-only bridge + delete + wallbang.
-- Wallbang = CanCollide+CanQuery off on WALLS only (Criminality needs this for bullets).
-- Floors stay solid: geometry filter + Stepped protect-under-feet (obfuscated names ignored).

local ClientBuild = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local FOLDER = "VG_ClientBuild"
local mode = nil -- "bridge", "delete", nil
local bridgeA = nil
local inputConn = nil
local markerA = nil
local markerB = nil
local bridges = {}
local hidden = {} -- { part = BasePart, canCollide, transparency, canQuery }

local wallbangOn = false
local wallbang = {} -- [part] = { canCollide, canQuery }
local wallbangSafe = {} -- [part] = true — floor / stood-on — NEVER punch
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

-- ── Wallbang (collide-off walls ONLY — floors stay solid) ─────────────────────

local function isHiddenPart(part)
	for _, e in ipairs(hidden) do
		if e.part == part then
			return true
		end
	end
	return false
end

-- Obfuscated map: NO name checks. Flat / walkable slabs must never lose collide.
local function isLikelyFloor(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local size = part.Size
	local upY = math.abs(part.CFrame.UpVector.Y)
	-- Top face roughly world-up → floor/ceiling/platform
	if upY < 0.65 then
		return false
	end
	local footprint = size.X * size.Z
	local tallFace = size.Y * math.max(size.X, size.Z)
	-- Thin slab
	if size.Y <= 6 then
		return true
	end
	-- Large pad / foundation
	if footprint >= 40 and size.Y <= 25 then
		return true
	end
	-- More horizontal than vertical
	if footprint >= tallFace * 0.45 then
		return true
	end
	return false
end

-- Only punch vertical cover / walls (what bullets hit).
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

	-- Upright part: thin in X or Z, has height
	if upY >= 0.65 then
		if size.Y >= 3.5 and minXZ <= 7 then
			return true
		end
		if size.Y >= 5 and minXZ <= 12 and maxXZ >= 3 then
			return true
		end
		if size.Y >= 8 and minXZ <= 14 then
			return true
		end
		return false
	end
	-- Tilted / sideways mesh — treat as cover
	return size.Y >= 2 or maxXZ >= 4 or math.max(size.X, size.Y, size.Z) >= 4
end

local function markSafeAndSolid(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	wallbangSafe[part] = true
	local orig = wallbang[part]
	if type(orig) == "table" then
		pcall(function()
			part.CanCollide = true
			part.CanQuery = orig.canQuery == true
		end)
		wallbang[part] = nil
	else
		pcall(function()
			if not part.CanCollide then
				part.CanCollide = true
			end
		end)
	end
end

-- Every Stepped: whatever is under the character MUST be solid (no name needed).
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

	local origin = hrp.Position + Vector3.new(0, 1.0, 0)
	local offs = {
		Vector3.zero,
		Vector3.new(1.8, 0, 0),
		Vector3.new(-1.8, 0, 0),
		Vector3.new(0, 0, 1.8),
		Vector3.new(0, 0, -1.8),
		Vector3.new(1.2, 0, 1.2),
		Vector3.new(-1.2, 0, -1.2),
		Vector3.new(1.2, 0, -1.2),
		Vector3.new(-1.2, 0, 1.2),
	}
	for _, off in ipairs(offs) do
		local hit = workspace:Raycast(origin + off, Vector3.new(0, -18, 0), params)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") then
			markSafeAndSolid(hit.Instance)
		end
	end

	local ok, parts = pcall(function()
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { char, folder }
		return workspace:GetPartBoundsInBox(
			hrp.CFrame * CFrame.new(0, -3.5, 0),
			Vector3.new(10, 10, 10),
			op
		)
	end)
	if ok and type(parts) == "table" then
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				local rel = hrp.CFrame:PointToObjectSpace(p.Position)
				-- below / around feet only
				if rel.Y < 2.5 then
					markSafeAndSolid(p)
				end
			end
		end
	end
end

local function shouldWallbangPart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:IsDescendantOf(ensureFolder()) then
		return false
	end
	if isHiddenPart(part) then
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
	if not part.CanCollide and not part.CanQuery then
		return false
	end
	-- ONLY walls/cover — never random floors
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
		-- Roblox: CanQuery=false only works after CanCollide=false
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

local function restoreWallbang()
	clearWallbangConns()
	wallbangScanToken += 1
	for part, orig in pairs(wallbang) do
		if part and part.Parent and not isHiddenPart(part) and type(orig) == "table" then
			pcall(function()
				part.CanCollide = orig.canCollide
				part.CanQuery = orig.canQuery
			end)
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)
	table.clear(wallbangSafe)
end

local function wallbangRoots()
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
	return roots
end

local function scanWallsOnly()
	wallbangScanToken += 1
	local token = wallbangScanToken
	task.spawn(function()
		protectStanding()
		local roots = wallbangRoots()
		if #roots == 0 then
			for _, ch in ipairs(workspace:GetChildren()) do
				if ch:IsA("Folder") or ch:IsA("Model") then
					if not Players:GetPlayerFromCharacter(ch) and ch.Name ~= FOLDER then
						table.insert(roots, ch)
					end
				end
			end
		end
		for _, root in ipairs(roots) do
			if token ~= wallbangScanToken or not wallbangOn then
				return
			end
			local descs = root:GetDescendants()
			for i, d in ipairs(descs) do
				if token ~= wallbangScanToken or not wallbangOn then
					return
				end
				punchPart(d)
				if i % 120 == 0 then
					protectStanding()
					task.wait()
				end
			end
		end
		if token == wallbangScanToken and wallbangOn then
			protectStanding()
			-- Final pass: unpunch anything that looks like a floor if it slipped in
			local removeList = {}
			for part, orig in pairs(wallbang) do
				if part and part.Parent and (isLikelyFloor(part) or wallbangSafe[part]) then
					markSafeAndSolid(part)
					table.insert(removeList, part)
				end
			end
			for _, p in ipairs(removeList) do
				wallbang[p] = nil
			end
		end
	end)
end

local function startFeetWatch()
	if wallbangFeetConn then
		return
	end
	-- Before physics step — collide back under feet before you sink
	wallbangFeetConn = RS.Stepped:Connect(function()
		if wallbangOn then
			protectStanding()
		end
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
		clearWallbangConns()
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
		notify("Wallbang", "ON — tylko ściany bez collidu; podłoga solidna")
	else
		restoreWallbang()
		notify("Wallbang", "OFF — przywrócono collidy ścian")
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
				if wallbangOn and shouldWallbangPart(p) then
					wallbang[p] = {
						canCollide = e.canCollide,
						canQuery = e.canQuery,
					}
					p.CanCollide = false
					p.CanQuery = false
				else
					p.CanQuery = e.canQuery
				end
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
		ClientBuild.SetWallbang(false)
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

	wallbangSyncConn = RS.Heartbeat:Connect(function()
		local want = settingsRef and settingsRef.CrimWallbang == true
		if want ~= wallbangOn then
			ClientBuild.SetWallbang(want)
		end
	end)
	if S.CrimWallbang then
		ClientBuild.SetWallbang(true)
	end
end

return ClientBuild
