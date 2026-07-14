-- CriminalityPath.lua  v2.43.88

local CriminalityPath = {}

local PathS = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local Plrs = game:GetService("Players")
local Debris = game:GetService("Debris")

local folderName = "VG_SafePath"
local conn = nil
local computing = false
local lastComputeAt = 0
local COOLDOWN = 0.55

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
	lbl.Size = UDim2.new(0, 360, 0, 26)
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
	Debris:AddItem(gui, 2.4)
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

local function makeExcludeParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = {}
	local char = getChar()
	if char then
		table.insert(list, char)
	end
	local pathF = workspace:FindFirstChild(folderName)
	if pathF then
		table.insert(list, pathF)
	end
	if extra then
		table.insert(list, extra)
	end
	params.FilterDescendantsInstances = list
	return params
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
	local params = makeExcludeParams(nil)

	local hit = workspace:Raycast(origin, dir * maxDist, params)
	if hit and hit.Instance then
		local anc = hit.Instance
		while anc and anc ~= folder do
			if isSafeOrRegister(anc) then
				return anc, getSafePart(anc)
			end
			anc = anc.Parent
		end
	end

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
					if dot > 0.82 then
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

local function snapFloor(pos, exclude, fromH)
	local params = makeExcludeParams(exclude)
	local origin = pos + Vector3.new(0, fromH or 8, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), params)
	if hit then
		return hit.Position + Vector3.new(0, 0.15, 0)
	end
	return Vector3.new(pos.X, pos.Y, pos.Z)
end

local function rotY(v, deg)
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

-- true if any "player slot" height can traverse (low shutters + mid wall holes)
local function canTraverse(a, b, exclude)
	local params = makeExcludeParams(exclude)
	local delta = b - a
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 0.05 then
		return true, 0
	end
	local heights = { 1.0, 1.4, 1.8, 2.2, 2.8, 3.4, 4.0 }
	for _, h in ipairs(heights) do
		local from = Vector3.new(a.X, a.Y + h, a.Z)
		local to = Vector3.new(b.X, b.Y + h, b.Z)
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then
			return true, h
		end
		-- allow if we nearly reached the end (edge of collider)
		local remain = (to - hit.Position).Magnitude
		if remain < 1.1 then
			return true, h
		end
	end
	return false, 0
end

local function headroomOk(pos, exclude)
	local params = makeExcludeParams(exclude)
	-- need ~2 studs free above feet so player can stand/crouch through
	local hit = workspace:Raycast(pos + Vector3.new(0, 0.3, 0), Vector3.new(0, 2.2, 0), params)
	return hit == nil
end

local function probePath(startPos, goalPos, exclude)
	local cur = snapFloor(startPos, exclude, 6)
	local goal = snapFloor(goalPos, exclude, 8)
	local points = { { Position = cur, Action = Enum.PathWaypointAction.Walk } }
	local angles = { 0, 18, -18, 36, -36, 55, -55, 75, -75, 95, -95, 120, -120, 150, -150 }
	local maxSteps = 70
	local stuck = 0

	for _ = 1, maxSteps do
		local flat = Vector3.new(goal.X - cur.X, 0, goal.Z - cur.Z)
		local rem = flat.Magnitude
		if rem < 3.2 then
			table.insert(points, { Position = goal, Action = Enum.PathWaypointAction.Walk })
			return points, "probe"
		end

		local dir = flat.Unit
		local stepLen = math.clamp(rem, 2.2, 4.0)
		local found = nil
		local foundH = 0

		for _, ang in ipairs(angles) do
			local d = rotY(dir, ang)
			local guess = cur + d * stepLen
			local floored = snapFloor(guess, exclude, 10)
			-- reject insane vertical jumps
			if math.abs(floored.Y - cur.Y) <= 7 then
				local okTrav, h = canTraverse(cur, floored, exclude)
				if okTrav and headroomOk(floored, exclude) then
					found = floored
					foundH = h
					break
				end
			end
		end

		if not found then
			-- shorter step retry
			for _, ang in ipairs({ 0, 30, -30, 60, -60, 90, -90 }) do
				local d = rotY(dir, ang)
				local guess = cur + d * 1.6
				local floored = snapFloor(guess, exclude, 10)
				if math.abs(floored.Y - cur.Y) <= 7 then
					local okTrav = canTraverse(cur, floored, exclude)
					if okTrav and headroomOk(floored, exclude) then
						found = floored
						break
					end
				end
			end
		end

		if not found then
			stuck += 1
			if stuck >= 3 then
				break
			end
		else
			stuck = 0
			local action = Enum.PathWaypointAction.Walk
			if foundH > 0 and foundH < 1.6 then
				action = Enum.PathWaypointAction.Jump -- mark low crawl / shutter
			elseif math.abs(found.Y - cur.Y) > 2.2 then
				action = Enum.PathWaypointAction.Jump
			end
			table.insert(points, { Position = found, Action = action })
			cur = found
			if #points > 64 then
				break
			end
		end
	end

	-- accept partial path if we got meaningfully closer
	local last = points[#points]
	if last and (last.Position - goal).Magnitude < (startPos - goal).Magnitude * 0.55 then
		table.insert(points, { Position = goal, Action = Enum.PathWaypointAction.Walk })
		return points, "probe-partial"
	end
	if #points >= 3 then
		return points, "probe-partial"
	end
	return nil, "probe-fail"
end

local function drawWaypoints(waypoints)
	local f = ensureFolder()
	local count = #waypoints
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

local AGENT_PROFILES = {
	{ AgentRadius = 1.5, AgentHeight = 5.0, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3.5 },
	{ AgentRadius = 1.2, AgentHeight = 3.0, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3.0 },
	{ AgentRadius = 1.0, AgentHeight = 2.2, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2.5 },
}

local function tryPathfinding(from, goal)
	for _, profile in ipairs(AGENT_PROFILES) do
		local path = PathS:CreatePath(profile)
		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local wps = path:GetWaypoints()
			if wps and #wps >= 2 then
				return wps, "nav"
			end
		end
	end
	return nil
end

local function gatherGoals(hrpPos, part)
	local base = part.Position
	local goals = {}
	local flat = Vector3.new(hrpPos.X - base.X, 0, hrpPos.Z - base.Z)
	local toward = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
	-- stand in front of safe (toward player), then ring around
	table.insert(goals, base + toward * 3.0)
	table.insert(goals, base + toward * 2.0)
	table.insert(goals, base - toward * 2.5)
	for ang = 0, 315, 45 do
		local r = rotY(toward, ang)
		table.insert(goals, base + r * 3.5)
	end
	table.insert(goals, base + Vector3.new(0, 1.5, 0))
	return goals
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
		local okOuter = pcall(function()
			local start = snapFloor(hrp.Position, model, 6)
			local goals = gatherGoals(hrp.Position, part)
			local wps, mode = nil, nil

			for _, g in ipairs(goals) do
				local goal = snapFloor(g, model, 8)
				wps, mode = tryPathfinding(start, goal)
				if wps then
					break
				end
			end

			-- PathfindingService can't see smashed wall holes / many client doors
			if not wps then
				local goal = snapFloor(part.Position + (hrp.Position - part.Position).Unit * 2.5, model, 8)
				wps, mode = probePath(start, goal, model)
			end

			if not wps or #wps < 2 then
				clearPathFolder()
				flashStatus("Path: still blocked — move / peek opening", Color3.fromRGB(255, 120, 120))
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
			local tag = mode == "nav" and "navmesh" or tostring(mode or "probe")
			flashStatus("Path → " .. label .. "  [" .. tag .. "]", Color3.fromRGB(90, 255, 150))
		end)
		computing = false
		if not okOuter then
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

	local lp = getLP()
	if lp then
		lp.CharacterAdded:Connect(function()
			clearPathFolder()
		end)
	end
end

return CriminalityPath
