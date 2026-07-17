-- ClientBuild.lua  v2.52.26
-- NOTE: bump with Settings.Version when changing.
-- Client-only bridge + delete + wallbang.
-- Wallbang = gun raycast penetration ONLY (no CanCollide edits).
-- Editing map collide caused Anti Exploit "movement cheats" rectify/reset.

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
local wallbangSyncConn = nil
local wallbangHooks = false
local settingsRef = nil

-- originals
local oldRaycast = nil
local oldFindPartOnRay = nil
local oldFindPartOnRayIgnore = nil
local oldFindPartOnRayWhite = nil

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
	-- Use raw raycast (bypass wallbang hook via oldRaycast when available)
	if oldRaycast then
		return oldRaycast(workspace, ray.Origin, ray.Direction * (maxDist or 500), params)
	end
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

-- ── Wallbang (ray penetration — NO map collide edits) ─────────────────────────

local function wrap(fn)
	if typeof(newcclosure) == "function" then
		local ok, w = pcall(newcclosure, fn)
		if ok and w then
			return w
		end
	end
	return fn
end

local function isCharacterPart(inst)
	if not inst then
		return false
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	if not model then
		return false
	end
	return Players:GetPlayerFromCharacter(model) ~= nil
		or model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function hasGunOut()
	local player = lp()
	local char = player and player.Character
	if not char then
		return false
	end
	return char:FindFirstChildOfClass("Tool") ~= nil
end

local function shouldPenetrate()
	return wallbangOn and hasGunOut()
end

-- Continue ray through world geo until a character (or budget exhausted).
local function penetrateRaycast(self, origin, direction, params)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return oldRaycast(self, origin, direction, params)
	end
	local mag = direction.Magnitude
	if mag < 0.05 then
		return oldRaycast(self, origin, direction, params)
	end
	local unit = direction.Unit
	local left = mag
	local pos = origin
	for _ = 1, 10 do
		if left <= 0.05 then
			return nil
		end
		local result = oldRaycast(self, pos, unit * left, params)
		if not result then
			return nil
		end
		if isCharacterPart(result.Instance) then
			return result
		end
		-- skip wall / prop / floor — keep going (physics collide untouched)
		local step = (result.Position - pos).Magnitude + 0.1
		if step < 0.1 then
			step = 0.1
		end
		left -= step
		pos = result.Position + unit * 0.1
	end
	return nil
end

local function penetrateFindOnRay(ray, ignoreList)
	-- Legacy API: returns hitPart, position
	if not oldFindPartOnRayIgnore and not oldFindPartOnRay then
		return nil
	end
	local origin = ray.Origin
	local dir = ray.Direction
	local unit = dir.Unit
	local left = dir.Magnitude
	if left < 0.05 then
		left = 999
	end
	local pos = origin
	local ignore = ignoreList
	if type(ignore) ~= "table" then
		ignore = {}
	end
	local list = {}
	for i = 1, #ignore do
		list[i] = ignore[i]
	end
	for _ = 1, 10 do
		local hit, hitPos
		if oldFindPartOnRayIgnore then
			hit, hitPos = oldFindPartOnRayIgnore(workspace, Ray.new(pos, unit * left), list)
		else
			hit, hitPos = oldFindPartOnRay(workspace, Ray.new(pos, unit * left), true)
		end
		if not hit then
			return nil
		end
		if isCharacterPart(hit) then
			return hit, hitPos
		end
		table.insert(list, hit)
		local step = (hitPos - pos).Magnitude + 0.1
		left -= step
		if left <= 0.05 then
			return nil
		end
		pos = hitPos + unit * 0.1
	end
	return nil
end

-- Undo previous wallbang versions that zeroed CanCollide (stops fall + AC rectify).
local function healOldCollidePunches()
	local roots = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(roots, map)
	end
	for _, root in ipairs(roots) do
		local descs = root:GetDescendants()
		for i, d in ipairs(descs) do
			if d:IsA("BasePart") and d.Anchored and not d.CanCollide and not d.CanQuery and d.Transparency < 0.99 then
				pcall(function()
					d.CanCollide = true
					d.CanQuery = true
				end)
			end
			if i % 200 == 0 then
				task.wait()
			end
		end
	end
	-- Always solidify whatever is under feet right now
	local player = lp()
	local char = player and player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, ensureFolder() }
		local raw = oldRaycast or workspace.Raycast
		for _, off in ipairs({
			Vector3.zero,
			Vector3.new(2, 0, 0),
			Vector3.new(-2, 0, 0),
			Vector3.new(0, 0, 2),
			Vector3.new(0, 0, -2),
		}) do
			local hit = raw(workspace, hrp.Position + Vector3.new(0, 1, 0) + off, Vector3.new(0, -20, 0), params)
			if hit and hit.Instance and hit.Instance:IsA("BasePart") then
				pcall(function()
					hit.Instance.CanCollide = true
				end)
			end
		end
	end
end

local function installWallbangHooks()
	if wallbangHooks then
		return true
	end
	if typeof(hookfunction) ~= "function" then
		notify("Wallbang", "Executor bez hookfunction — wallbang niedostępny")
		return false
	end

	local ok1, err1 = pcall(function()
		oldRaycast = hookfunction(
			workspace.Raycast,
			wrap(function(self, origin, direction, params)
				if shouldPenetrate() and self == workspace then
					return penetrateRaycast(self, origin, direction, params)
				end
				return oldRaycast(self, origin, direction, params)
			end)
		)
	end)
	if not ok1 then
		notify("Wallbang", "Hook Raycast fail: " .. tostring(err1))
		return false
	end

	pcall(function()
		if typeof(workspace.FindPartOnRayWithIgnoreList) == "function" then
			oldFindPartOnRayIgnore = hookfunction(
				workspace.FindPartOnRayWithIgnoreList,
				wrap(function(self, ray, ignoreList, ...)
					if shouldPenetrate() and self == workspace then
						local hit, pos = penetrateFindOnRay(ray, ignoreList)
						return hit, pos
					end
					return oldFindPartOnRayIgnore(self, ray, ignoreList, ...)
				end)
			)
		end
	end)

	pcall(function()
		if typeof(workspace.FindPartOnRay) == "function" then
			oldFindPartOnRay = hookfunction(
				workspace.FindPartOnRay,
				wrap(function(self, ray, terrainCellsAreCubes, ignoreWater, ...)
					if shouldPenetrate() and self == workspace and oldFindPartOnRayIgnore then
						-- reuse ignore-list path with empty ignore
						local hit, pos = penetrateFindOnRay(ray, {})
						return hit, pos
					end
					return oldFindPartOnRay(self, ray, terrainCellsAreCubes, ignoreWater, ...)
				end)
			)
		end
	end)

	pcall(function()
		if typeof(workspace.FindPartOnRayWithWhitelist) == "function" then
			oldFindPartOnRayWhite = hookfunction(
				workspace.FindPartOnRayWithWhitelist,
				wrap(function(self, ray, whitelist, ...)
					-- whitelist mode: don't penetrate (would break includes)
					return oldFindPartOnRayWhite(self, ray, whitelist, ...)
				end)
			)
		end
	end)

	wallbangHooks = true
	return true
end

function ClientBuild.SetWallbang(on)
	on = on == true
	if on == wallbangOn then
		return
	end
	wallbangOn = on
	if on then
		task.spawn(healOldCollidePunches)
		if not installWallbangHooks() then
			wallbangOn = false
			if settingsRef then
				settingsRef.CrimWallbang = false
			end
			return
		end
		notify("Wallbang", "ON — tylko raycast kuli (bez ruszania collidów mapy)")
	else
		notify("Wallbang", "OFF")
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

	-- Heal leftover collide-punches from older wallbang versions on load
	task.spawn(healOldCollidePunches)

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
