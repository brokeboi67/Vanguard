-- ClientBuild.lua  v2.52.30
-- Wallbang = crosshair-only (CanCollide off tylko na celowanym parcie).
-- BOOT = synchroniczny heal: wszystko w Map z CanCollide=false → true, zanim cokolwiek innego.

local ClientBuild = {}

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("RunService")

local FOLDER = "VG_ClientBuild"
local mode, bridgeA, inputConn = nil, nil, nil
local markerA, markerB = nil, nil
local bridges = {}
local hidden  = {}   -- Delete list: {part, canCollide, transparency, canQuery}

local wallbangOn   = false
local wallbang     = {}   -- [part] = {canCollide, canQuery}
local wallbangAimConn  = nil
local wallbangFeetConn = nil
local wallbangSyncConn = nil
local settingsRef  = nil

-- ── helpers ──────────────────────────────────────────────────────────────────

local function notify(msg, sub)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = msg or "VG", Text = sub or "", Duration = 3,
		})
	end)
end

local function lp() return Players.LocalPlayer end

local function ensureFolder()
	local f = workspace:FindFirstChild(FOLDER)
	if not f then
		f = Instance.new("Folder"); f.Name = FOLDER; f.Parent = workspace
	end
	return f
end

local function isHidden(part)
	for _, e in ipairs(hidden) do
		if e.part == part then return true end
	end
	return false
end

local function isCharPart(part)
	local m = part:FindFirstAncestorOfClass("Model")
	return m and Players:GetPlayerFromCharacter(m) ~= nil
end

-- ── BOOT HEAL (synchronous — runs before wallbang can do anything) ────────────
-- Fixes leftover CanCollide=false from older wallbang versions.
-- Rule: anchored Map part, not in our Delete list, not a character → restore solid.
local function bootHealSync()
	local map = workspace:FindFirstChild("Map")
	if not map then return end
	local folder = ensureFolder()
	local n = 0
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored and not d.CanCollide
		   and not d:IsDescendantOf(folder) and not isHidden(d) and not isCharPart(d) then
			pcall(function() d.CanCollide = true end)
			n = n + 1
		end
	end
	-- also solidify anything with our punch signature (CanQuery false too)
	return n
end

-- ── Fix Floor button: async nuclear, with notify ──────────────────────────────
function ClientBuild.HealWallbangCollide()
	-- restore tracked punches first
	for part, orig in pairs(wallbang) do
		if part and part.Parent then
			pcall(function()
				part.CanCollide = true
				if type(orig) == "table" then part.CanQuery = orig.canQuery end
			end)
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)
	-- then full map pass
	task.spawn(function()
		local n = bootHealSync()
		-- also big box around character
		local char = lp() and lp().Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			pcall(function()
				local op = OverlapParams.new()
				op.FilterType = Enum.RaycastFilterType.Exclude
				op.FilterDescendantsInstances = { char, ensureFolder() }
				for _, p in ipairs(workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(300,300,300), op)) do
					if p:IsA("BasePart") and not p.CanCollide and not isCharPart(p) and not isHidden(p) then
						p.CanCollide = true
						n = n + 1
					end
				end
			end)
		end
		notify("Fix Floor", "Przywrócono ~" .. n .. " collidów. Jak dalej — Rejoin.")
	end)
end

-- ── protect standing (every Stepped when wallbang on) ────────────────────────
local function protectFeet()
	local char = lp() and lp().Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local folder = ensureFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder }
	for _, off in ipairs({ Vector3.zero,
		Vector3.new(2,0,0), Vector3.new(-2,0,0),
		Vector3.new(0,0,2), Vector3.new(0,0,-2) }) do
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0,2,0) + off, Vector3.new(0,-25,0), params)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") then
			local orig = wallbang[hit.Instance]
			if orig then
				wallbang[hit.Instance] = nil
				pcall(function()
					hit.Instance.CanCollide = true
					if type(orig) == "table" then hit.Instance.CanQuery = orig.canQuery end
				end)
			else
				pcall(function() hit.Instance.CanCollide = true end)
			end
		end
	end
end

-- ── crosshair punch ───────────────────────────────────────────────────────────
local function punchCrosshair()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local char = lp() and lp().Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local folder = ensureFolder()
	local vp  = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X*0.5, vp.Y*0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	if char then table.insert(ignore, char) end

	local origin, unit, left = ray.Origin, ray.Direction.Unit, 350
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, unit * left, params)
		if not hit then return end
		local p = hit.Instance
		if not p:IsA("BasePart") then
			p = p:FindFirstAncestorWhichIsA("BasePart")
			if not p then return end
		end

		-- NEVER punch anything at or below feet
		local underFeet = false
		if hrp then
			local rel = hrp.CFrame:PointToObjectSpace(hit.Position)
			underFeet = (rel.Y < 2.5 and math.abs(rel.X) < 10 and math.abs(rel.Z) < 10)
		end

		if underFeet then
			-- if we had punched it, restore immediately
			local orig = wallbang[p]
			if orig then
				wallbang[p] = nil
				pcall(function()
					p.CanCollide = true
					if type(orig) == "table" then p.CanQuery = orig.canQuery end
				end)
			else
				pcall(function() p.CanCollide = true end)
			end
		elseif not isHidden(p) and not isCharPart(p) and not p:IsDescendantOf(folder) then
			if wallbang[p] == nil then
				wallbang[p] = { canCollide = p.CanCollide, canQuery = p.CanQuery }
				pcall(function() p.CanCollide = false; p.CanQuery = false end)
			end
		end

		table.insert(ignore, p)
		left = left - ((hit.Position - origin).Magnitude + 0.15)
		origin = hit.Position + unit * 0.15
		if left < 1 then return end
	end
end

-- ── wallbang on/off ──────────────────────────────────────────────────────────
local function stopWallbangConns()
	if wallbangAimConn  then wallbangAimConn:Disconnect();  wallbangAimConn  = nil end
	if wallbangFeetConn then wallbangFeetConn:Disconnect(); wallbangFeetConn = nil end
end

local function restoreTracked()
	for part, orig in pairs(wallbang) do
		if part and part.Parent and type(orig) == "table" then
			pcall(function()
				part.CanCollide = true
				part.CanQuery   = orig.canQuery
			end)
		end
		wallbang[part] = nil
	end
	table.clear(wallbang)
end

function ClientBuild.SetWallbang(on)
	on = on == true
	if on == wallbangOn then return end
	wallbangOn = on
	stopWallbangConns()
	if on then
		-- heal before enabling (in case of stale state)
		bootHealSync()
		protectFeet()
		wallbangFeetConn = RS.Stepped:Connect(function()
			if wallbangOn then protectFeet() end
		end)
		wallbangAimConn = RS.RenderStepped:Connect(function()
			if wallbangOn then punchCrosshair() end
		end)
		notify("Wallbang", "ON — tylko celownik")
	else
		restoreTracked()
		-- async full heal so orphan punches also get fixed
		task.spawn(function()
			bootHealSync()
			protectFeet()
		end)
		notify("Wallbang", "OFF")
	end
end

-- ── bridge / delete UI helpers ───────────────────────────────────────────────
local function clearMarkers()
	if markerA then pcall(function() markerA:Destroy() end); markerA = nil end
	if markerB then pcall(function() markerB:Destroy() end); markerB = nil end
end

local function makeMarker(pos, color)
	local p = Instance.new("Part")
	p.Name = "VG_Mark"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.CanTouch = false; p.CastShadow = false; p.Material = Enum.Material.Neon
	p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(0.7,0.7,0.7)
	p.Color = color; p.Transparency = 0.15; p.CFrame = CFrame.new(pos)
	p.Parent = ensureFolder(); return p
end

local function stopMode()
	mode = nil; bridgeA = nil; clearMarkers()
	if inputConn then inputConn:Disconnect(); inputConn = nil end
end

local function mouseRay(maxDist)
	local cam = workspace.CurrentCamera; local player = lp()
	if not cam or not player then return nil end
	local mouse = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { ensureFolder() }
	if player.Character then table.insert(ex, player.Character) end
	params.FilterDescendantsInstances = ex
	return workspace:Raycast(ray.Origin, ray.Direction * (maxDist or 500), params)
end

local function hideAsset(part)
	if not part or not part:IsA("BasePart") then return false end
	if part:IsDescendantOf(ensureFolder()) then
		pcall(function() part:Destroy() end)
		for i = #bridges, 1, -1 do
			if bridges[i] == part then table.remove(bridges, i) end
		end
		notify("Delete", "Usunięto local bridge"); return true
	end
	table.insert(hidden, { part=part, canCollide=part.CanCollide,
		transparency=part.Transparency, canQuery=part.CanQuery })
	wallbang[part] = nil
	pcall(function()
		part.CanCollide = false; part.CanQuery = false; part.Transparency = 1
		if part.LocalTransparencyModifier ~= nil then part.LocalTransparencyModifier = 1 end
	end)
	notify("Delete", "Schowano: " .. part.Name); return true
end

local function onClick()
	if not mode then return end
	local hit = mouseRay(600)
	if mode == "bridge" then
		if not hit then notify("Bridge","Nic nie trafiono"); return end
		local pos = hit.Position + hit.Normal * 0.15
		if not bridgeA then
			bridgeA = pos; clearMarkers()
			markerA = makeMarker(pos, Color3.fromRGB(80,220,120))
			notify("Bridge","Punkt A — kliknij B")
		else
			markerB = makeMarker(pos, Color3.fromRGB(80,160,255))
			local dist = (pos - bridgeA).Magnitude
			if dist < 1 or dist > 400 then
				notify("Bridge","Za blisko / za daleko"); stopMode(); return
			end
			local mid = (bridgeA + pos) * 0.5
			local p = Instance.new("Part"); p.Name = "VG_Bridge"; p.Anchored = true
			p.CanCollide = true; p.CanTouch = false; p.CastShadow = false
			p.Material = Enum.Material.WoodPlanks; p.Color = Color3.fromRGB(110,85,55)
			p.Size = Vector3.new(5, 0.85, dist); p.CFrame = CFrame.lookAt(mid, pos)
			p.Parent = ensureFolder(); table.insert(bridges, p)
			notify("Bridge","Most gotowy"); stopMode()
		end
	elseif mode == "delete" then
		if not hit or not hit.Instance then notify("Delete","Nic"); return end
		local p = hit.Instance
		if not p:IsA("BasePart") then p = p:FindFirstAncestorWhichIsA("BasePart") end
		if p then hideAsset(p) end
		stopMode()
	end
end

local function bindInput()
	if inputConn then return end
	inputConn = UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then onClick()
		elseif input.KeyCode == Enum.KeyCode.Escape then notify("Build","Anulowano"); stopMode() end
	end)
end

function ClientBuild.StartBridge()
	stopMode(); mode = "bridge"; bridgeA = nil; bindInput()
	notify("Bridge","Kliknij A, potem B  (Esc = anuluj)")
end
function ClientBuild.StartDelete()
	stopMode(); mode = "delete"; bindInput()
	notify("Delete","Kliknij asset  (Esc = anuluj)")
end
function ClientBuild.ClearBridges()
	for _, p in ipairs(bridges) do pcall(function() p:Destroy() end) end
	table.clear(bridges)
	local f = workspace:FindFirstChild(FOLDER)
	if f then
		for _, ch in ipairs(f:GetChildren()) do
			if ch.Name == "VG_Bridge" or ch.Name == "VG_Mark" then
				pcall(function() ch:Destroy() end)
			end
		end
	end
	notify("Bridge","Wyczyszczono mosty")
end
function ClientBuild.RestoreHidden()
	for _, e in ipairs(hidden) do
		local p = e.part
		if p and p.Parent then
			pcall(function()
				p.CanCollide = e.canCollide; p.Transparency = e.transparency
				p.CanQuery = e.canQuery
				if p.LocalTransparencyModifier ~= nil then p.LocalTransparencyModifier = 0 end
			end)
		end
	end
	table.clear(hidden); notify("Delete","Przywrócono assety")
end

-- ── Stop / Init ───────────────────────────────────────────────────────────────
function ClientBuild.Stop()
	stopMode()
	wallbangOn = false
	stopWallbangConns()
	restoreTracked()
	if wallbangSyncConn then wallbangSyncConn:Disconnect(); wallbangSyncConn = nil end
	settingsRef = nil
end

function ClientBuild.Init(S)
	ClientBuild.Stop()
	if not S then return end
	settingsRef = S

	-- !! SYNCHRONOUS heal: fix ALL anchored Map parts left with CanCollide=false
	-- (old wallbang versions did a full-map punch and left floors soft)
	bootHealSync()

	S._clientBridgeStart    = ClientBuild.StartBridge
	S._clientDeleteStart    = ClientBuild.StartDelete
	S._clientBridgeClear    = ClientBuild.ClearBridges
	S._clientDeleteRestore  = ClientBuild.RestoreHidden
	S._clientWallbangSet    = ClientBuild.SetWallbang
	S._clientWallbangHeal   = ClientBuild.HealWallbangCollide

	-- force wallbang off on fresh load so saved=true doesn't instantly re-punch
	S.CrimWallbang = false

	wallbangSyncConn = RS.Heartbeat:Connect(function()
		local want = settingsRef and settingsRef.CrimWallbang == true
		if want ~= wallbangOn then
			ClientBuild.SetWallbang(want)
		end
	end)
end

return ClientBuild
