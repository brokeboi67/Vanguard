-- ClientBuild.lua  v2.52.29
-- NOTE: bump with Settings.Version when changing.
-- Client-only bridge + delete + wallbang.
-- Wallbang = ONLY punch what crosshair hits (never under feet / never full-map scan).
-- Fix Floor = nuclear CanCollide=true near you + on Map floors.

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
local wallbangMapConn = nil -- unused for scan; kept nil
local wallbangFeetConn = nil
local wallbangAimConn = nil
local wallbangSyncConn = nil
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

-- ── Wallbang: crosshair only ──────────────────────────────────────────────────

local function isHiddenPart(part)
	for _, e in ipairs(hidden) do
		if e.part == part then
			return true
		end
	end
	return false
end

local function isCharacterPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) ~= nil
end

-- Is this part under / around the player's feet? Never punch those.
local function isUnderOrAtFeet(part, hitPos)
	local player = lp()
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not part then
		return false
	end
	local pos = hitPos or part.Position
	-- Below character waist
	if pos.Y < hrp.Position.Y - 0.5 then
		return true
	end
	local rel = hrp.CFrame:PointToObjectSpace(pos)
	if rel.Y < 1.25 and math.abs(rel.X) < 8 and math.abs(rel.Z) < 8 then
		return true
	end
	return false
end

local function forceSolid(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	pcall(function()
		part.CanCollide = true
	end)
end

--[[
	NUCLEAR floor fix — Fix Floor Collide / boot / wallbang OFF.
	Does NOT depend on wallbang{} tracking (that was why disable left soft floors).
]]
local function healFloorsHard(showNotify)
	local n = 0
	-- 1) restore everything we tracked
	for part, orig in pairs(wallbang) do
		if part and part.Parent then
			pcall(function()
				part.CanCollide = true
				if type(orig) == "table" and orig.canQuery ~= nil then
					part.CanQuery = orig.canQuery
				else
					part.CanQuery = true
				end
			end)
			n += 1
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)

	local player = lp()
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local folder = ensureFolder()

	-- 2) huge box around player: ANY soft anchored part → solid
	if hrp then
		pcall(function()
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { char, folder }
			local parts = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(250, 250, 250), op)
			for _, p in ipairs(parts) do
				if p:IsA("BasePart") and not p.CanCollide and not isCharacterPart(p) then
					-- skip our bridges folder
					if not p:IsDescendantOf(folder) and not isHiddenPart(p) then
						p.CanCollide = true
						n += 1
					end
				end
			end
		end)
		-- 3) raycasts from high above down — catch floors even if you're already under
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, folder }
		for dx = -40, 40, 8 do
			for dz = -40, 40, 8 do
				local origin = hrp.Position + Vector3.new(dx, 120, dz)
				local hit = workspace:Raycast(origin, Vector3.new(0, -300, 0), params)
				if hit and hit.Instance and hit.Instance:IsA("BasePart") then
					forceSolid(hit.Instance)
					n += 1
				end
			end
		end
	end

	-- 4) Map-wide: punch signature (both flags false, still visible) → solid
	local map = workspace:FindFirstChild("Map")
	if map then
		for i, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") and d.Anchored and not d.CanCollide and not d.CanQuery and d.Transparency < 0.99 then
				if not isHiddenPart(d) then
					pcall(function()
						d.CanCollide = true
						d.CanQuery = true
					end)
					n += 1
				end
			end
			if i % 300 == 0 then
				task.wait()
			end
		end
	end

	if showNotify then
		notify("Fix Floor", "Przywrócono collidy (~" .. tostring(n) .. "). Jak dalej spadasz → Rejoin.")
	end
end

local function protectStanding()
	local player = lp()
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local folder = ensureFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }
	local origin = hrp.Position + Vector3.new(0, 3, 0)
	for _, off in ipairs({
		Vector3.zero,
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2),
		Vector3.new(3, 0, 3),
		Vector3.new(-3, 0, -3),
	}) do
		local hit = workspace:Raycast(origin + off, Vector3.new(0, -40, 0), params)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") then
			-- if we had punched it, restore fully
			local orig = wallbang[hit.Instance]
			if orig then
				wallbang[hit.Instance] = nil
				pcall(function()
					hit.Instance.CanCollide = true
					hit.Instance.CanQuery = type(orig) == "table" and orig.canQuery or true
				end)
			else
				forceSolid(hit.Instance)
			end
		end
	end
	pcall(function()
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { char, folder }
		for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame * CFrame.new(0, -2, 0), Vector3.new(16, 14, 16), op)) do
			if p:IsA("BasePart") and not isCharacterPart(p) then
				local orig = wallbang[p]
				if orig then
					wallbang[p] = nil
					p.CanCollide = true
					p.CanQuery = type(orig) == "table" and orig.canQuery or true
				elseif not p.CanCollide then
					p.CanCollide = true
				end
			end
		end
	end)
end

local function punchPart(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	if wallbang[part] ~= nil then
		return
	end
	if part:IsDescendantOf(ensureFolder()) or isHiddenPart(part) or isCharacterPart(part) then
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

-- Crosshair aim: punch ONLY what you're looking at, never under feet.
local function punchCrosshair()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local player = lp()
	local char = player and player.Character
	local folder = ensureFolder()
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excl = { folder }
	if char then
		table.insert(excl, char)
	end
	params.FilterDescendantsInstances = excl

	-- Walk a few hits so one thin trim doesn't block the real wall
	local origin = ray.Origin
	local unit = ray.Direction.Unit
	local left = 350
	local ignore = { folder }
	if char then
		table.insert(ignore, char)
	end
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, unit * left, params)
		if not hit then
			return
		end
		local part = hit.Instance
		if not part:IsA("BasePart") then
			part = part:FindFirstAncestorWhichIsA("BasePart")
		end
		if not part then
			return
		end
		-- NEVER punch under yourself
		if isUnderOrAtFeet(part, hit.Position) then
			forceSolid(part)
			table.insert(ignore, part)
		else
			punchPart(part)
			table.insert(ignore, part)
		end
		local step = (hit.Position - origin).Magnitude + 0.15
		left -= step
		origin = hit.Position + unit * 0.15
		if left < 1 then
			return
		end
	end
end

local function clearWallbangRuntime()
	if wallbangFeetConn then
		wallbangFeetConn:Disconnect()
		wallbangFeetConn = nil
	end
	if wallbangAimConn then
		wallbangAimConn:Disconnect()
		wallbangAimConn = nil
	end
	if wallbangMapConn then
		wallbangMapConn:Disconnect()
		wallbangMapConn = nil
	end
end

local function restoreTracked()
	for part, orig in pairs(wallbang) do
		if part and part.Parent and type(orig) == "table" then
			pcall(function()
				part.CanCollide = true
				part.CanQuery = orig.canQuery
			end)
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)
end

function ClientBuild.HealWallbangCollide()
	task.spawn(function()
		healFloorsHard(true)
		protectStanding()
	end)
end

function ClientBuild.SetWallbang(on)
	on = on == true
	if on == wallbangOn then
		return
	end
	wallbangOn = on
	clearWallbangRuntime()
	if on then
		-- clean soft floors from older broken scans before enabling
		healFloorsHard(false)
		protectStanding()
		wallbangFeetConn = RS.Stepped:Connect(function()
			if wallbangOn then
				protectStanding()
			end
		end)
		-- Aim loop: only what crosshair sees
		wallbangAimConn = RS.RenderStepped:Connect(function()
			if wallbangOn then
				punchCrosshair()
			end
		end)
		notify("Wallbang", "ON — tylko celownik (NIGDY pod nogami)")
	else
		restoreTracked()
		healFloorsHard(true)
		protectStanding()
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
	wallbangOn = false
	clearWallbangRuntime()
	restoreTracked()
	task.spawn(function()
		healFloorsHard(false)
	end)
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

	-- Force off + heal leftovers from old full-map punch versions
	S.CrimWallbang = false
	task.spawn(function()
		healFloorsHard(true)
		protectStanding()
	end)

	wallbangSyncConn = RS.Heartbeat:Connect(function()
		local want = settingsRef and settingsRef.CrimWallbang == true
		if want ~= wallbangOn then
			ClientBuild.SetWallbang(want)
		end
		-- Always keep feet solid even with wallbang off (leftover soft floors)
		if not wallbangOn then
			local player = lp()
			local char = player and player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and (hum:GetState() == Enum.HumanoidStateType.Freefall or hum.FloorMaterial == Enum.Material.Air) then
				protectStanding()
			end
		end
	end)
end

return ClientBuild
