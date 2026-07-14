-- CriminalityPath.lua  v2.43.87
-- Lightweight PathfindingService overlay to safes/registers (Home by default).

local CriminalityPath = {}

local PathS = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local Plrs = game:GetService("Players")
local Debris = game:GetService("Debris")

local folderName = "VG_SafePath"
local conn = nil
local computing = false
local lastComputeAt = 0
local COOLDOWN = 0.6

local function getLP()
	return Plrs.LocalPlayer
end

local function getChar()
	local lp = getLP()
	return lp and lp.Character
end

local function getHRP()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function alive(inst)
	return inst and typeof(inst) == "Instance" and inst.Parent ~= nil
end

local function clearPathFolder()
	local f = workspace:FindFirstChild(folderName)
	if f then
		f:Destroy()
	end
end

local function ensureFolder()
	clearPathFolder()
	local f = Instance.new("Folder")
	f.Name = folderName
	f.Parent = workspace
	return f
end

local function flashStatus(text, col)
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local old = pg:FindFirstChild("VG_SafePathStatus")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VG_SafePathStatus"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = pg
	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	lbl.Position = UDim2.new(0.5, 0, 0.12, 0)
	lbl.Size = UDim2.new(0, 320, 0, 26)
	lbl.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	lbl.BackgroundTransparency = 0.25
	lbl.Text = text
	lbl.TextColor3 = col or Color3.fromRGB(120, 255, 160)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = lbl
	Debris:AddItem(gui, 2.2)
end

local function isSafeOrRegister(model)
	if not model then
		return false
	end
	local n = model.Name
	if typeof(n) ~= "string" then
		return false
	end
	return string.sub(n, 1, 8) == "Register"
		or string.sub(n, 1, 9) == "SmallSafe"
		or string.sub(n, 1, 10) == "MediumSafe"
end

local function getBredFolder()
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("BredMakurz")
end

local function getSafePart(model)
	if not model then
		return nil
	end
	local main = model:FindFirstChild("MainPart", true)
	if main and main:IsA("BasePart") then
		return main
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function resolveLookTarget(maxDist)
	local cam = workspace.CurrentCamera
	local hrp = getHRP()
	if not cam or not hrp then
		return nil
	end
	local folder = getBredFolder()
	if not folder then
		return nil
	end

	local origin = cam.CFrame.Position
	local dir = cam.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = getChar()
	params.FilterDescendantsInstances = char and { char } or {}

	local hit = workspace:Raycast(origin, dir * maxDist, params)
	if hit and hit.Instance then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		while model and model ~= folder do
			if isSafeOrRegister(model) and model:IsDescendantOf(folder) then
				return model, getSafePart(model)
			end
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		-- ancestor walk
		local anc = hit.Instance
		while anc and anc ~= folder do
			if isSafeOrRegister(anc) then
				return anc, getSafePart(anc)
			end
			anc = anc.Parent
		end
	end

	-- cone fallback: nearest safe roughly in front of camera
	local best, bestScore = nil, nil
	for _, ch in ipairs(folder:GetChildren()) do
		if isSafeOrRegister(ch) then
			local part = getSafePart(ch)
			if part then
				local to = part.Position - origin
				local dist = to.Magnitude
				if dist <= maxDist and dist > 1 then
					local nd = to.Unit
					local dot = nd:Dot(dir)
					if dot > 0.88 then
						local score = dist / math.max(dot, 0.01)
						if not bestScore or score < bestScore then
							bestScore = score
							best = ch
						end
					end
				end
			end
		end
	end
	if best then
		return best, getSafePart(best)
	end
	return nil
end

local function drawWaypoints(waypoints)
	local f = ensureFolder()
	local count = #waypoints
	-- subsample if long path — keep it light
	local step = 1
	if count > 48 then
		step = math.ceil(count / 40)
	end
	for i = 1, count, step do
		local wp = waypoints[i]
		local pos = wp.Position + Vector3.new(0, 0.2, 0)
		local p = Instance.new("Part")
		p.Name = "WP"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Shape = Enum.PartType.Ball
		local isJump = wp.Action == Enum.PathWaypointAction.Jump
		p.Size = isJump and Vector3.new(0.55, 0.55, 0.55) or Vector3.new(0.35, 0.35, 0.35)
		p.Color = isJump and Color3.fromRGB(255, 210, 70) or Color3.fromRGB(80, 255, 140)
		p.Transparency = 0.15
		p.CFrame = CFrame.new(pos)
		p.Parent = f

		if i > 1 then
			local prev = waypoints[math.max(1, i - step)].Position + Vector3.new(0, 0.15, 0)
			local mid = (prev + pos) * 0.5
			local dist = (pos - prev).Magnitude
			if dist > 0.05 and dist < 40 then
				local beam = Instance.new("Part")
				beam.Name = "Seg"
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.CastShadow = false
				beam.Material = Enum.Material.Neon
				beam.Color = Color3.fromRGB(60, 220, 120)
				beam.Transparency = 0.45
				beam.Size = Vector3.new(0.12, 0.12, dist)
				beam.CFrame = CFrame.lookAt(mid, pos)
				beam.Parent = f
			end
		end
	end
	-- mark destination
	local last = waypoints[count]
	if last then
		local mark = Instance.new("Part")
		mark.Name = "Goal"
		mark.Anchored = true
		mark.CanCollide = false
		mark.CanQuery = false
		mark.CanTouch = false
		mark.CastShadow = false
		mark.Material = Enum.Material.Neon
		mark.Shape = Enum.PartType.Cylinder
		mark.Size = Vector3.new(0.2, 1.6, 1.6)
		mark.Color = Color3.fromRGB(255, 230, 90)
		mark.Transparency = 0.35
		mark.CFrame = CFrame.new(last.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		mark.Parent = f
	end
end

local function computePath(S)
	if computing then
		return
	end
	local now = tick()
	if now - lastComputeAt < COOLDOWN then
		return
	end
	lastComputeAt = now

	local hrp = getHRP()
	if not hrp then
		flashStatus("Path: no character", Color3.fromRGB(255, 120, 120))
		return
	end

	local maxDist = math.clamp(tonumber(S.CrimESPMaxDist) or 300, 50, 800)
	local model, part = resolveLookTarget(maxDist)
	if not model or not part then
		flashStatus("Path: look at a safe/register", Color3.fromRGB(255, 180, 90))
		clearPathFolder()
		return
	end

	computing = true
	flashStatus("Path: computing…", Color3.fromRGB(180, 200, 255))

	task.spawn(function()
		local ok, err = pcall(function()
			local path = PathS:CreatePath({
				AgentRadius = 1.6,
				AgentHeight = 5,
				AgentCanJump = true,
				AgentCanClimb = true,
				WaypointSpacing = 3.5,
				Costs = {
					Climb = 1,
					Jump = 2,
				},
			})
			local goal = part.Position
			-- stand next to object if center is inside solid
			local offset = (hrp.Position - goal)
			if offset.Magnitude > 0.1 then
				goal = goal + offset.Unit * 2.5
			end
			goal = Vector3.new(goal.X, part.Position.Y, goal.Z)

			path:ComputeAsync(hrp.Position, goal)
			if path.Status ~= Enum.PathStatus.Success then
				-- retry slightly above in case of roof/gap navmesh issues
				path:ComputeAsync(hrp.Position, goal + Vector3.new(0, 2, 0))
			end

			if path.Status ~= Enum.PathStatus.Success then
				clearPathFolder()
				flashStatus("Path: no route (blocked)", Color3.fromRGB(255, 120, 120))
				return
			end

			local wps = path:GetWaypoints()
			if not wps or #wps < 2 then
				clearPathFolder()
				flashStatus("Path: empty", Color3.fromRGB(255, 120, 120))
				return
			end

			drawWaypoints(wps)
			local label = model.Name
			if string.sub(label, 1, 8) == "Register" then
				label = "REGISTER"
			elseif string.sub(label, 1, 9) == "SmallSafe" then
				label = "SMALL SAFE"
			elseif string.sub(label, 1, 10) == "MediumSafe" then
				label = "MED SAFE"
			end
			flashStatus("Path → " .. label .. "  (" .. tostring(#wps) .. " pts)", Color3.fromRGB(90, 255, 150))
		end)
		computing = false
		if not ok then
			clearPathFolder()
			flashStatus("Path error", Color3.fromRGB(255, 100, 100))
		end
	end)
end

local function bindNameToKeyCode(name)
	if typeof(name) ~= "string" or name == "" then
		return Enum.KeyCode.Home
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[name]
	end)
	if ok and key then
		return key
	end
	return Enum.KeyCode.Home
end

function CriminalityPath.Stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	computing = false
	clearPathFolder()
	local lp = getLP()
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if pg then
		local st = pg:FindFirstChild("VG_SafePathStatus")
		if st then
			st:Destroy()
		end
	end
end

function CriminalityPath.Init(S)
	CriminalityPath.Stop()
	if not S then
		return
	end
	_G.__VG_S = S

	conn = UIS.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		local cur = _G.__VG_S or S
		if not cur or cur.CrimSafePath ~= true then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local want = bindNameToKeyCode(cur.CrimSafePathKey or "Home")
		if input.KeyCode == want then
			local existing = workspace:FindFirstChild(folderName)
			if existing then
				clearPathFolder()
				flashStatus("Path cleared", Color3.fromRGB(180, 180, 190))
				return
			end
			computePath(cur)
		end
	end)

	-- clear path on death/respawn
	local lp = getLP()
	if lp then
		lp.CharacterAdded:Connect(function()
			clearPathFolder()
		end)
	end
end

return CriminalityPath
