-- ClientBuild.lua  v2.52.65
-- Local client bridge / delete / wallbang corridor (camera → target).

local ClientBuild = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local FOLDER = "VG_ClientBuild"
local mode, bridgeA, inputConn = nil, nil, nil
local markerA, markerB = nil, nil
local bridges = {}
local hidden = {}

-- Wallbang corridor (local CanCollide / CanQuery only)
local wb = {
	targetUserId = 0,
	parts = {}, -- [part] = { canCollide, canQuery, transparency }
	order = {},
	liveConn = nil,
	keyConn = nil,
	beam = nil,
	settings = nil,
}

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

-- ── Wallbang corridor ───────────────────────────────────────────────────────

local function wbClearBeam()
	if wb.beam then
		pcall(function()
			wb.beam:Destroy()
		end)
		wb.beam = nil
	end
end

local function wbDrawBeam(a, b)
	wbClearBeam()
	local dist = (b - a).Magnitude
	if dist < 1 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "VG_WbBeam"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 70, 90)
	p.Transparency = 0.55
	p.Size = Vector3.new(0.12, 0.12, dist)
	p.CFrame = CFrame.lookAt((a + b) * 0.5, b)
	p.Parent = ensureFolder()
	wb.beam = p
end

local function wbShouldPunch(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part:IsA("Terrain") then
		return false
	end
	if part:IsDescendantOf(ensureFolder()) then
		return false
	end
	if part:FindFirstAncestorOfClass("Accessory") then
		return false
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return false
	end
	return true
end

local function wbPunchPart(part)
	if not wbShouldPunch(part) then
		return false
	end
	if wb.parts[part] then
		return false
	end
	wb.parts[part] = {
		canCollide = part.CanCollide,
		canQuery = part.CanQuery,
		transparency = part.Transparency,
	}
	table.insert(wb.order, part)
	pcall(function()
		part.CanCollide = false
		part.CanQuery = false
		-- slight fade so the corridor is visible locally
		if part.Transparency < 0.35 then
			part.Transparency = 0.35
		end
	end)
	return true
end

local function wbGetTarget()
	local uid = tonumber(wb.targetUserId) or 0
	if uid <= 0 then
		return nil
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.UserId == uid then
			return plr
		end
	end
	return nil
end

local function wbTargetPart(plr)
	local char = plr and plr.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Head")
		or char:FindFirstChildWhichIsA("BasePart")
end

local function wbApplyLine()
	local cam = workspace.CurrentCamera
	local me = lp()
	local target = wbGetTarget()
	if not cam or not me then
		return 0, "camera"
	end
	if not target then
		return 0, "notarget"
	end
	local goalPart = wbTargetPart(target)
	if not goalPart then
		return 0, "nochar"
	end

	local origin = cam.CFrame.Position
	local goal = goalPart.Position
	local delta = goal - origin
	local dist = delta.Magnitude
	if dist < 2 then
		return 0, "close"
	end
	if dist > 1200 then
		dist = 1200
		goal = origin + delta.Unit * dist
		delta = goal - origin
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { ensureFolder() }
	if me.Character then
		table.insert(exclude, me.Character)
	end
	if target.Character then
		table.insert(exclude, target.Character)
	end
	params.FilterDescendantsInstances = exclude

	local unit = delta.Unit
	local cursor = origin
	local remaining = dist
	local punched = 0
	local safety = 0

	while remaining > 0.4 and safety < 80 do
		safety = safety + 1
		local hit = workspace:Raycast(cursor, unit * remaining, params)
		if not hit then
			break
		end
		local inst = hit.Instance
		if wbPunchPart(inst) then
			punched = punched + 1
		end
		-- advance past this hit so the next ray continues toward the target
		table.insert(exclude, inst)
		params.FilterDescendantsInstances = exclude
		cursor = hit.Position + unit * 0.08
		remaining = (goal - cursor):Dot(unit)
		if remaining < 0 then
			break
		end
	end

	wbDrawBeam(origin, goal)
	return punched, nil
end

function ClientBuild.WallbangRestore()
	for _, part in ipairs(wb.order) do
		local e = wb.parts[part]
		if e and part and part.Parent then
			pcall(function()
				part.CanCollide = e.canCollide
				part.CanQuery = e.canQuery
				part.Transparency = e.transparency
			end)
		end
	end
	table.clear(wb.parts)
	table.clear(wb.order)
	wbClearBeam()
	notify("Wallbang", "Przywrócono ściany")
end

function ClientBuild.WallbangApply()
	local n, err = wbApplyLine()
	if err == "notarget" then
		notify("Wallbang", "Najpierw wybierz cel")
	elseif err == "nochar" then
		notify("Wallbang", "Cel bez postaci")
	elseif err == "close" then
		notify("Wallbang", "Za blisko")
	elseif err == "camera" then
		notify("Wallbang", "Brak kamery")
	else
		notify("Wallbang", string.format("Linia otwarta (%d parts)", n or 0))
	end
end

function ClientBuild.WallbangSetTarget(plrOrId, displayName)
	local uid, name = 0, ""
	if typeof(plrOrId) == "Instance" and plrOrId:IsA("Player") then
		uid = plrOrId.UserId
		name = displayName
			or ((plrOrId.DisplayName ~= "" and plrOrId.DisplayName) or plrOrId.Name)
	else
		uid = tonumber(plrOrId) or 0
		name = tostring(displayName or "")
		if name == "" and uid > 0 then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.UserId == uid then
					name = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
					break
				end
			end
		end
	end
	wb.targetUserId = uid
	local S = wb.settings
	if S then
		S.CrimWallbangTargetUserId = uid
		S.CrimWallbangTargetName = name
		if S._wallbangTargetChanged then
			pcall(S._wallbangTargetChanged, name)
		end
	end
	if uid > 0 then
		notify("Wallbang", "Cel: " .. name)
	else
		notify("Wallbang", "Cel wyczyszczony")
	end
end

function ClientBuild.WallbangPickClosest()
	local cam = workspace.CurrentCamera
	local me = lp()
	if not cam or not me then
		notify("Wallbang", "Brak kamery")
		return
	end
	local look = cam.CFrame.LookVector
	local origin = cam.CFrame.Position
	local best, bestScore = nil, -1
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= me then
			local part = wbTargetPart(plr)
			if part then
				local to = part.Position - origin
				local dist = to.Magnitude
				if dist > 3 and dist < 900 then
					local score = to.Unit:Dot(look)
					if score > 0.35 and score > bestScore then
						bestScore = score
						best = plr
					end
				end
			end
		end
	end
	if not best then
		notify("Wallbang", "Brak gracza w celowniku")
		return
	end
	ClientBuild.WallbangSetTarget(best)
end

-- Alt+Click: ray only hits player characters (goes through walls/map)
function ClientBuild.WallbangAltClick()
	local cam = workspace.CurrentCamera
	local me = lp()
	if not cam or not me then
		return
	end
	local mouse = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	local chars = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= me and plr.Character then
			table.insert(chars, plr.Character)
		end
	end
	if #chars == 0 then
		notify("Wallbang", "Brak graczy")
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = chars
	params.IgnoreWater = true

	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
	local chosen = nil
	if hit and hit.Instance then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model then
			chosen = Players:GetPlayerFromCharacter(model)
		end
	end

	-- Fallback: closest player to the mouse ray (still through walls)
	if not chosen then
		local best, bestDist = nil, 3.5 -- studs from ray line
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= me then
				local part = wbTargetPart(plr)
				if part then
					local to = part.Position - ray.Origin
					local along = to:Dot(ray.Direction)
					if along > 2 and along < 2500 then
						local closest = ray.Origin + ray.Direction * along
						local lateral = (part.Position - closest).Magnitude
						if lateral < bestDist then
							bestDist = lateral
							best = plr
						end
					end
				end
			end
		end
		chosen = best
	end

	if not chosen then
		notify("Wallbang", "Alt+Click: nic nie trafiono")
		return
	end
	ClientBuild.WallbangSetTarget(chosen)
	local S = wb.settings
	if S and S._wallbangAfterPick then
		pcall(S._wallbangAfterPick)
	end
end

local function wbPickModeAllows(mode, kind)
	mode = tostring(mode or "Both")
	if mode == "Both" then
		return true
	end
	if kind == "menu" then
		return mode == "Menu"
	end
	if kind == "alt" then
		return mode == "AltClick"
	end
	return false
end

function ClientBuild.WallbangClearTarget()
	ClientBuild.WallbangSetTarget(0, "")
end

local function wbStopLive()
	if wb.liveConn then
		wb.liveConn:Disconnect()
		wb.liveConn = nil
	end
end

local function wbStopKey()
	if wb.keyConn then
		wb.keyConn:Disconnect()
		wb.keyConn = nil
	end
end

local function wbMatchKey(input, keyName)
	keyName = tostring(keyName or "")
	if keyName == "" or keyName == "None" then
		return false
	end
	if keyName == "MouseButton1" then
		return input.UserInputType == Enum.UserInputType.MouseButton1
	elseif keyName == "MouseButton2" then
		return input.UserInputType == Enum.UserInputType.MouseButton2
	elseif keyName == "MouseButton3" then
		return input.UserInputType == Enum.UserInputType.MouseButton3
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	return ok and key ~= nil and input.KeyCode == key
end

function ClientBuild.WallbangBindKeys()
	wbStopKey()
	wb.keyConn = UIS.InputBegan:Connect(function(input, gp)
		local S = wb.settings
		if not S then
			return
		end

		-- Alt + LMB: pick player through walls (world click only)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local alt = UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt)
			if alt and not gp and wbPickModeAllows(S.CrimWallbangPickMode, "alt") then
				ClientBuild.WallbangAltClick()
				return
			end
		end

		if gp then
			return
		end

		-- Refresh / open line along current camera → target
		if wbMatchKey(input, S.CrimWallbangRefreshKey or "V") then
			local n, err = wbApplyLine()
			if err == "notarget" then
				notify("Wallbang", "Najpierw wybierz cel")
			elseif err then
				-- quiet for transient errors while holding
			else
				notify("Wallbang", string.format("Linia @%s (%d)", S.CrimWallbangRefreshKey or "V", n or 0))
			end
		end
		-- Optional: pick closest to crosshair (menu modes)
		if wbMatchKey(input, S.CrimWallbangPickKey or "None") then
			if wbPickModeAllows(S.CrimWallbangPickMode, "menu") or tostring(S.CrimWallbangPickMode or "Both") == "Both" then
				ClientBuild.WallbangPickClosest()
				if S._wallbangAfterPick then
					pcall(S._wallbangAfterPick)
				end
			end
		end
	end)
end

function ClientBuild.WallbangSetLive(on)
	wbStopLive()
	if not on then
		return
	end
	local acc = 0
	wb.liveConn = RS.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.35 then
			return
		end
		acc = 0
		local S = wb.settings
		if not S or S.CrimWallbangLive ~= true then
			wbStopLive()
			return
		end
		if (tonumber(wb.targetUserId) or 0) <= 0 then
			return
		end
		wbApplyLine()
	end)
end

function ClientBuild.Stop()
	stopMode()
	wbStopLive()
	wbStopKey()
end

function ClientBuild.Init(S)
	ClientBuild.Stop()
	if not S then
		return
	end
	wb.settings = S
	wb.targetUserId = tonumber(S.CrimWallbangTargetUserId) or 0
	S._clientBridgeStart = ClientBuild.StartBridge
	S._clientDeleteStart = ClientBuild.StartDelete
	S._clientBridgeClear = ClientBuild.ClearBridges
	S._clientDeleteRestore = ClientBuild.RestoreHidden
	S._clientWallbangPick = ClientBuild.WallbangPickClosest
	S._clientWallbangAltClick = ClientBuild.WallbangAltClick
	S._clientWallbangClearTarget = ClientBuild.WallbangClearTarget
	S._clientWallbangSetTarget = ClientBuild.WallbangSetTarget
	S._clientWallbangApply = ClientBuild.WallbangApply
	S._clientWallbangRestore = ClientBuild.WallbangRestore
	S._clientWallbangSetLive = ClientBuild.WallbangSetLive
	S._clientWallbangRebind = ClientBuild.WallbangBindKeys
	-- Delay keybinds until after UI loader (same lobby crash window as Crim Heartbeat)
	task.defer(function()
		task.wait(2.5)
		if not wb.settings then
			return
		end
		ClientBuild.WallbangBindKeys()
		if S.CrimWallbangLive == true then
			ClientBuild.WallbangSetLive(true)
		end
	end)
end

return ClientBuild
