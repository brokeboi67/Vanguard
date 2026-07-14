-- ClientBuild.lua  v2.44.4
-- NOTE: bump with Settings.Version when changing.
-- Client-only bridge + delete. Local parts / local collision-off — server/AC never sees it.

local ClientBuild = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local FOLDER = "VG_ClientBuild"
local mode = nil -- "bridge", "delete", nil
local bridgeA = nil
local inputConn = nil
local markerA = nil
local markerB = nil
local bridges = {}
local hidden = {} -- { part = BasePart, canCollide, transparency, canQuery }

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
	-- Skip our own client builds (delete those for real)
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
	-- Server asset: local-only. Don't Destroy (replicates back) — collision/vis off.
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
end

function ClientBuild.Init(S)
	ClientBuild.Stop()
	if not S then
		return
	end
	S._clientBridgeStart = ClientBuild.StartBridge
	S._clientDeleteStart = ClientBuild.StartDelete
	S._clientBridgeClear = ClientBuild.ClearBridges
	S._clientDeleteRestore = ClientBuild.RestoreHidden
end

return ClientBuild
