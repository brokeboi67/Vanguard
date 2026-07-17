-- ClientBuild.lua  v2.52.31
-- Wallbang = crosshair punch ONLY on real walls (never floors, never doors, never look-down).
-- Heal restores CanCollide+CanQuery on Map (incl. Doors) — also non-anchored parts.

local ClientBuild = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local FOLDER = "VG_ClientBuild"
local mode, bridgeA, inputConn = nil, nil, nil
local markerA, markerB = nil, nil
local bridges = {}
local hidden = {}

local wallbangOn = false
local wallbang = {} -- [part] = { canCollide, canQuery }
local wallbangAimConn = nil
local wallbangFeetConn = nil
local wallbangSyncConn = nil
local settingsRef = nil

local function notify(msg, sub)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = msg or "VG",
			Text = sub or "",
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

local function isHidden(part)
	for _, e in ipairs(hidden) do
		if e.part == part then
			return true
		end
	end
	return false
end

local function isCharPart(part)
	local m = part:FindFirstAncestorOfClass("Model")
	return m and Players:GetPlayerFromCharacter(m) ~= nil
end

local function getDoorsFolder()
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Doors")
end

local function isDoorPart(part)
	if not part then
		return false
	end
	local doors = getDoorsFolder()
	if doors and part:IsDescendantOf(doors) then
		return true
	end
	-- also catch door models outside that folder
	local cur = part
	for _ = 1, 8 do
		if not cur then
			break
		end
		local n = string.lower(cur.Name)
		if n:find("door", 1, true) or n:find("frame", 1, true) or n:find("knob", 1, true)
			or n:find("hinge", 1, true) or n:find("jam", 1, true)
		then
			return true
		end
		cur = cur.Parent
		if cur == workspace or cur == nil then
			break
		end
	end
	return false
end

-- Flat walk surfaces — never punch (looking down used to kill these).
local function isLikelyFloor(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local size = part.Size
	local upY = math.abs(part.CFrame.UpVector.Y)
	local footprint = size.X * size.Z
	local maxXZ = math.max(size.X, size.Z)
	if upY >= 0.55 then
		if size.Y <= 10 then
			return true
		end
		if footprint >= 25 and size.Y <= 35 then
			return true
		end
		if footprint >= size.Y * maxXZ * 0.35 then
			return true
		end
	end
	if footprint >= 60 and size.Y <= 14 then
		return true
	end
	return false
end

local function restorePartSolid(part, orig)
	if not part or not part.Parent then
		return
	end
	pcall(function()
		part.CanCollide = true
		-- Always restore query too — doorframes / floors need raycast+touch
		if type(orig) == "table" and orig.canQuery ~= nil then
			part.CanQuery = orig.canQuery
		else
			part.CanQuery = true
		end
	end)
end

--[[
	Full heal: tracked punches + Map (incl Doors) + near player.
	Heals NON-anchored too (door parts / welded floors).
]]
local function healEverything(showNotify)
	local n = 0
	for part, orig in pairs(wallbang) do
		restorePartSolid(part, orig)
		wallbang[part] = nil
		n += 1
	end
	table.clear(wallbang)

	local folder = ensureFolder()
	local function healPart(d)
		if not d:IsA("BasePart") then
			return
		end
		if d:IsDescendantOf(folder) or isHidden(d) or isCharPart(d) then
			return
		end
		-- Our punch signature OR soft collide
		local soft = not d.CanCollide
		local punchedSig = soft and (not d.CanQuery) and d.Transparency < 0.99
		local door = isDoorPart(d)
		local floor = isLikelyFloor(d)
		if soft or punchedSig or door then
			pcall(function()
				-- Doors / floors / punched always solid + queryable
				if door or floor or punchedSig or soft then
					d.CanCollide = true
					if punchedSig or door or floor then
						d.CanQuery = true
					end
				end
			end)
			n += 1
		end
	end

	-- Prefer Map.Doors first (broken doorframes)
	local doors = getDoorsFolder()
	if doors then
		for _, d in ipairs(doors:GetDescendants()) do
			healPart(d)
		end
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		for i, d in ipairs(map:GetDescendants()) do
			healPart(d)
			if i % 400 == 0 then
				task.wait()
			end
		end
	end

	local char = lp() and lp().Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		pcall(function()
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { char, folder }
			for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(350, 350, 350), op)) do
				healPart(p)
			end
		end)
	end

	if showNotify then
		notify("Fix Floor", "Heal ~" .. tostring(n) .. " (floory+drzwi). Jak dalej → Rejoin.")
	end
	return n
end

local function bootHealSync()
	-- sync pass: Map + Doors only (no wait), for Init
	local n = 0
	local folder = ensureFolder()
	local function healOne(d)
		if not d:IsA("BasePart") then
			return
		end
		if d:IsDescendantOf(folder) or isHidden(d) or isCharPart(d) then
			return
		end
		if (not d.CanCollide) or isDoorPart(d) then
			pcall(function()
				d.CanCollide = true
				if (not d.CanQuery) or isDoorPart(d) or isLikelyFloor(d) then
					d.CanQuery = true
				end
			end)
			n += 1
		end
	end
	local doors = getDoorsFolder()
	if doors then
		for _, d in ipairs(doors:GetDescendants()) do
			healOne(d)
		end
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, d in ipairs(map:GetDescendants()) do
			healOne(d)
		end
	end
	return n
end

local function protectFeet()
	local char = lp() and lp().Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local folder = ensureFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }
	for _, off in ipairs({
		Vector3.zero,
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2),
		Vector3.new(4, 0, 4),
		Vector3.new(-4, 0, -4),
	}) do
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 3, 0) + off, Vector3.new(0, -40, 0), params)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") then
			local orig = wallbang[hit.Instance]
			wallbang[hit.Instance] = nil
			restorePartSolid(hit.Instance, orig)
		end
	end
	pcall(function()
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { char, folder }
		for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame * CFrame.new(0, -2, 0), Vector3.new(20, 16, 20), op)) do
			if p:IsA("BasePart") and (not p.CanCollide or isLikelyFloor(p) or isDoorPart(p)) then
				local orig = wallbang[p]
				wallbang[p] = nil
				restorePartSolid(p, orig or { canQuery = true })
			end
		end
	end)
end

function ClientBuild.HealWallbangCollide()
	task.spawn(function()
		healEverything(true)
		protectFeet()
	end)
end

local function lookingDown()
	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end
	-- LookVector.Y < -0.12 ≈ looking down a bit — NEVER punch (protects floors)
	return cam.CFrame.LookVector.Y < -0.12
end

local function shouldSkipPunch(part, hitPos)
	if not part or not part:IsA("BasePart") then
		return true
	end
	if isHidden(part) or isCharPart(part) or part:IsDescendantOf(ensureFolder()) then
		return true
	end
	if isDoorPart(part) then
		return true
	end
	if isLikelyFloor(part) then
		return true
	end
	local hrp = lp() and lp().Character and lp().Character:FindFirstChild("HumanoidRootPart")
	if hrp and hitPos then
		-- anything below chest height near you
		if hitPos.Y < hrp.Position.Y - 0.25 then
			return true
		end
		local rel = hrp.CFrame:PointToObjectSpace(hitPos)
		if rel.Y < 3 and math.abs(rel.X) < 12 and math.abs(rel.Z) < 12 then
			return true
		end
	end
	return false
end

local function punchCrosshair()
	if lookingDown() then
		-- Looking at floor: only heal under aim, never punch
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local char = lp() and lp().Character
		local folder = ensureFolder()
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder, char }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 80, params)
		if hit and hit.Instance then
			local p = hit.Instance
			if not p:IsA("BasePart") then
				p = p:FindFirstAncestorWhichIsA("BasePart")
			end
			if p then
				local orig = wallbang[p]
				wallbang[p] = nil
				restorePartSolid(p, orig or { canQuery = true })
			end
		end
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local char = lp() and lp().Character
	local folder = ensureFolder()
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	if char then
		table.insert(ignore, char)
	end

	local origin, unit, left = ray.Origin, ray.Direction.Unit, 300
	for _ = 1, 5 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, unit * left, params)
		if not hit then
			return
		end
		local p = hit.Instance
		if not p:IsA("BasePart") then
			p = p:FindFirstAncestorWhichIsA("BasePart")
			if not p then
				return
			end
		end

		if shouldSkipPunch(p, hit.Position) then
			-- restore if previously punched by mistake
			local orig = wallbang[p]
			if orig or isDoorPart(p) or isLikelyFloor(p) then
				wallbang[p] = nil
				restorePartSolid(p, orig or { canQuery = true })
			end
			table.insert(ignore, p)
		else
			if wallbang[p] == nil then
				wallbang[p] = { canCollide = p.CanCollide, canQuery = p.CanQuery }
				pcall(function()
					p.CanCollide = false
					p.CanQuery = false
				end)
			end
			table.insert(ignore, p)
		end

		left = left - ((hit.Position - origin).Magnitude + 0.15)
		origin = hit.Position + unit * 0.15
		if left < 1 then
			return
		end
	end
end

local function stopWallbangConns()
	if wallbangAimConn then
		wallbangAimConn:Disconnect()
		wallbangAimConn = nil
	end
	if wallbangFeetConn then
		wallbangFeetConn:Disconnect()
		wallbangFeetConn = nil
	end
end

local function restoreTracked()
	for part, orig in pairs(wallbang) do
		restorePartSolid(part, orig)
		wallbang[part] = nil
	end
	table.clear(wallbang)
end

function ClientBuild.SetWallbang(on)
	on = on == true
	if on == wallbangOn then
		return
	end
	wallbangOn = on
	stopWallbangConns()
	if on then
		bootHealSync()
		protectFeet()
		wallbangFeetConn = RS.Stepped:Connect(function()
			if wallbangOn then
				protectFeet()
			end
		end)
		wallbangAimConn = RS.RenderStepped:Connect(function()
			if wallbangOn then
				punchCrosshair()
			end
		end)
		notify("Wallbang", "ON — ściany z celownika (nie podłoga/drzwi)")
	else
		restoreTracked()
		task.spawn(function()
			healEverything(true)
			protectFeet()
		end)
		notify("Wallbang", "OFF + heal drzwi/podłóg")
	end
end

-- ── bridge / delete ───────────────────────────────────────────────────────────
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

local function stopMode()
	mode = nil
	bridgeA = nil
	clearMarkers()
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
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
	local ex = { ensureFolder() }
	if player.Character then
		table.insert(ex, player.Character)
	end
	params.FilterDescendantsInstances = ex
	return workspace:Raycast(ray.Origin, ray.Direction * (maxDist or 500), params)
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
	notify("Delete", "Schowano: " .. part.Name)
	return true
end

local function onClick()
	if not mode then
		return
	end
	local hit = mouseRay(600)
	if mode == "bridge" then
		if not hit then
			notify("Bridge", "Nic nie trafiono")
			return
		end
		local pos = hit.Position + hit.Normal * 0.15
		if not bridgeA then
			bridgeA = pos
			clearMarkers()
			markerA = makeMarker(pos, Color3.fromRGB(80, 220, 120))
			notify("Bridge", "Punkt A — kliknij B")
		else
			markerB = makeMarker(pos, Color3.fromRGB(80, 160, 255))
			local dist = (pos - bridgeA).Magnitude
			if dist < 1 or dist > 400 then
				notify("Bridge", "Za blisko / za daleko")
				stopMode()
				return
			end
			local mid = (bridgeA + pos) * 0.5
			local p = Instance.new("Part")
			p.Name = "VG_Bridge"
			p.Anchored = true
			p.CanCollide = true
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.WoodPlanks
			p.Color = Color3.fromRGB(110, 85, 55)
			p.Size = Vector3.new(5, 0.85, dist)
			p.CFrame = CFrame.lookAt(mid, pos)
			p.Parent = ensureFolder()
			table.insert(bridges, p)
			notify("Bridge", "Most gotowy")
			stopMode()
		end
	elseif mode == "delete" then
		if not hit or not hit.Instance then
			notify("Delete", "Nic")
			return
		end
		local p = hit.Instance
		if not p:IsA("BasePart") then
			p = p:FindFirstAncestorWhichIsA("BasePart")
		end
		if p then
			hideAsset(p)
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
			notify("Build", "Anulowano")
			stopMode()
		end
	end)
end

function ClientBuild.StartBridge()
	stopMode()
	mode = "bridge"
	bridgeA = nil
	bindInput()
	notify("Bridge", "Kliknij A, potem B  (Esc = anuluj)")
end

function ClientBuild.StartDelete()
	stopMode()
	mode = "delete"
	bindInput()
	notify("Delete", "Kliknij asset  (Esc = anuluj)")
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
	notify("Bridge", "Wyczyszczono mosty")
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
	notify("Delete", "Przywrócono assety")
end

function ClientBuild.Stop()
	stopMode()
	wallbangOn = false
	stopWallbangConns()
	restoreTracked()
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

	-- Sync heal doors+floors immediately (fixes leftover doorframes / soft floors)
	bootHealSync()

	S._clientBridgeStart = ClientBuild.StartBridge
	S._clientDeleteStart = ClientBuild.StartDelete
	S._clientBridgeClear = ClientBuild.ClearBridges
	S._clientDeleteRestore = ClientBuild.RestoreHidden
	S._clientWallbangSet = ClientBuild.SetWallbang
	S._clientWallbangHeal = ClientBuild.HealWallbangCollide

	S.CrimWallbang = false

	-- Deeper async heal (doors folder + soft map parts)
	task.spawn(function()
		healEverything(false)
	end)

	wallbangSyncConn = RS.Heartbeat:Connect(function()
		local want = settingsRef and settingsRef.CrimWallbang == true
		if want ~= wallbangOn then
			ClientBuild.SetWallbang(want)
		end
	end)
end

return ClientBuild
