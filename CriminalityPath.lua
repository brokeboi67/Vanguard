-- CriminalityPath.lua  v2.43.90
-- Safe/register path. Navmesh first (stairs); probe only same-floor with hard Y clamps.
-- Map mesh names are obfuscated — we never rely on names, only collidable geometry + Map.Doors.

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
local MAX_STEP_UP = 1.9
local MAX_STEP_DOWN = 2.4

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
	lbl.Size = UDim2.new(0, 420, 0, 26)
	lbl.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	lbl.BackgroundTransparency = 0.25
	lbl.Text = text
	lbl.TextColor3 = col or Color3.fromRGB(120, 255, 160)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = lbl
	Debris:AddItem(gui, 2.6)
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

local function getDoorsFolder()
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Doors")
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

local function isOpenableDoorModel(inst)
	if not inst or not inst:IsA("Model") then
		return false
	end
	if inst:FindFirstChild("DoorMain") or inst:FindFirstChild("DoorBase") or inst:FindFirstChild("DoorBase2") then
		return true
	end
	local n = inst.Name
	return typeof(n) == "string" and string.find(n, "Door", 1, true) ~= nil
end

local function makeExcludeParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local list = {}
	local char = getChar()
	if char then
		table.insert(list, char)
	end
	local pathF = workspace:FindFirstChild(folderName)
	if pathF then
		table.insert(list, pathF)
	end
	local doors = getDoorsFolder()
	if doors then
		table.insert(list, doors)
	end
	if extra then
		table.insert(list, extra)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function nearestDoorInfo(pos)
	local doors = getDoorsFolder()
	if not doors then
		return nil
	end
	local best, bestDist = nil, 6.5
	for _, door in ipairs(doors:GetChildren()) do
		if isOpenableDoorModel(door) then
			local base = door:FindFirstChild("DoorBase") or door:FindFirstChild("DoorBase2")
			local p = base and base:IsA("BasePart") and base or door:FindFirstChildWhichIsA("BasePart", true)
			if p then
				local d = (Vector3.new(pos.X, p.Position.Y, pos.Z) - p.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = door
				end
			end
		end
	end
	return best
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

local function rotY(v, deg)
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

-- Prefer current story floor. Never start ray above next story.
local function snapFloor(pos, exclude, preferY)
	local params = makeExcludeParams(exclude)
	local py = preferY or pos.Y
	local origin = Vector3.new(pos.X, py + 2.5, pos.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -9, 0), params)
	if hit and hit.Normal.Y >= 0.55 then
		local dy = hit.Position.Y - py
		if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
			return hit.Position + Vector3.new(0, 0.12, 0)
		end
	end
	origin = Vector3.new(pos.X, py + 3.8, pos.Z)
	hit = workspace:Raycast(origin, Vector3.new(0, -7, 0), params)
	if hit and hit.Normal.Y >= 0.55 then
		local dy = hit.Position.Y - py
		if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
			return hit.Position + Vector3.new(0, 0.12, 0)
		end
	end
	return Vector3.new(pos.X, py, pos.Z)
end

local function canTraverse(a, b, exclude)
	local params = makeExcludeParams(exclude)
	if math.abs(b.Y - a.Y) > MAX_STEP_UP + 0.4 then
		return false, 0
	end
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if flat.Magnitude < 0.05 then
		return true, 1.8
	end
	for _, h in ipairs({ 1.15, 1.65, 2.15, 2.7, 3.2 }) do
		local from = Vector3.new(a.X, a.Y + h, a.Z)
		local to = Vector3.new(b.X, b.Y + h, b.Z)
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then
			local hitLow = workspace:Raycast(
				Vector3.new(a.X, a.Y + 0.95, a.Z),
				Vector3.new(b.X - a.X, 0, b.Z - a.Z),
				params
			)
			if not hitLow then
				return true, h
			end
			if (Vector3.new(b.X, a.Y + 0.95, b.Z) - hitLow.Position).Magnitude < 1.0 then
				return true, h
			end
		elseif (to - hit.Position).Magnitude < 1.0 then
			return true, h
		end
	end
	return false, 0
end

local function headroomOk(pos, exclude)
	local params = makeExcludeParams(exclude)
	return workspace:Raycast(pos + Vector3.new(0, 0.25, 0), Vector3.new(0, 2.4, 0), params) == nil
end

-- Same-floor / stair-step probe only. Cross-story = PathfindingService (stairs).
local function probePath(startPos, goalPos, exclude)
	local cur = snapFloor(startPos, exclude, startPos.Y)
	local crossStory = math.abs(goalPos.Y - cur.Y) > 4.0
	local goal = crossStory and snapFloor(goalPos, exclude, cur.Y) or snapFloor(goalPos, exclude, goalPos.Y)
	if math.abs(goal.Y - cur.Y) > 10 then
		goal = snapFloor(goalPos, exclude, cur.Y)
		crossStory = true
	end

	local points = { { Position = cur, Action = Enum.PathWaypointAction.Walk } }
	local angles = { 0, 22, -22, 45, -45, 70, -70, 95, -95, 125, -125 }
	local stuck = 0

	for _ = 1, 80 do
		local flat = Vector3.new(goal.X - cur.X, 0, goal.Z - cur.Z)
		local rem = flat.Magnitude
		if rem < 2.6 then
			if not crossStory then
				table.insert(points, { Position = goal, Action = Enum.PathWaypointAction.Walk })
			end
			return points, crossStory and "probe-samefloor" or "probe"
		end

		local dir = flat.Unit
		local stepLen = math.clamp(rem, 1.6, 2.8)
		local found, foundH = nil, 0

		for _, ang in ipairs(angles) do
			local guess = cur + rotY(dir, ang) * stepLen
			local floored = snapFloor(guess, exclude, cur.Y)
			local dy = floored.Y - cur.Y
			if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
				local okTrav, h = canTraverse(cur, floored, exclude)
				if okTrav and headroomOk(floored, exclude) then
					found, foundH = floored, h
					break
				end
			end
		end

		if not found then
			for _, ang in ipairs({ 0, 40, -40, 80, -80 }) do
				local guess = cur + rotY(dir, ang) * 1.25
				local floored = snapFloor(guess, exclude, cur.Y)
				local dy = floored.Y - cur.Y
				if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
					local okTrav, h = canTraverse(cur, floored, exclude)
					if okTrav and headroomOk(floored, exclude) then
						found, foundH = floored, h
						break
					end
				end
			end
		end

		if not found then
			stuck += 1
			if stuck >= 4 then
				break
			end
		else
			stuck = 0
			local doorHit = nearestDoorInfo(found)
			local action = Enum.PathWaypointAction.Walk
			if not doorHit and (math.abs(found.Y - cur.Y) > 0.85 or (foundH > 0 and foundH < 1.5)) then
				action = Enum.PathWaypointAction.Jump
			end
			table.insert(points, { Position = found, Action = action, IsDoor = doorHit ~= nil })
			cur = found
			if #points > 70 then
				break
			end
		end
	end

	if #points >= 3 then
		return points, crossStory and "probe-samefloor" or "probe-partial"
	end
	return nil, "probe-fail"
end

local function drawWaypoints(waypoints)
	local f = ensureFolder()
	local count = #waypoints
	local step = count > 48 and math.ceil(count / 40) or 1
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
		local isDoor = wp.IsDoor == true or nearestDoorInfo(wp.Position) ~= nil
		local isJump = (not isDoor) and wp.Action == Enum.PathWaypointAction.Jump
		p.Size = (isDoor or isJump) and Vector3.new(0.55, 0.55, 0.55) or Vector3.new(0.35, 0.35, 0.35)
		p.Color = isDoor and Color3.fromRGB(90, 190, 255)
			or (isJump and Color3.fromRGB(255, 210, 70) or Color3.fromRGB(80, 255, 140))
		p.Transparency = 0.15
		p.CFrame = CFrame.new(pos)
		p.Parent = f

		if i > 1 then
			local prev = waypoints[math.max(1, i - step)].Position + Vector3.new(0, 0.15, 0)
			-- Skip drawing segments that clip stories (safety)
			if math.abs(prev.Y - pos.Y) <= 6 then
				local mid = (prev + pos) * 0.5
				local dist = (pos - prev).Magnitude
				if dist > 0.05 and dist < 28 then
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
	{ AgentRadius = 1.5, AgentHeight = 5.0, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3.0 },
	{ AgentRadius = 1.2, AgentHeight = 3.2, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2.8 },
	{ AgentRadius = 1.0, AgentHeight = 2.3, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2.4 },
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
				-- Reject insane navmesh results that teleport vertically through floors
				local bad = false
				for i = 2, #wps do
					if math.abs(wps[i].Position.Y - wps[i - 1].Position.Y) > 10 then
						bad = true
						break
					end
				end
				if not bad then
					return wps, "nav"
				end
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
	table.insert(goals, base + toward * 3.0)
	table.insert(goals, base + toward * 2.0)
	table.insert(goals, base - toward * 2.5)
	for ang = 0, 315, 45 do
		table.insert(goals, base + rotY(toward, ang) * 3.5)
	end
	return goals
end

local function labelOf(model)
	local label = model.Name
	if string.sub(label, 1, 8) == "Register" then
		return "REGISTER"
	elseif string.sub(label, 1, 9) == "SmallSafe" then
		return "SMALL SAFE"
	elseif string.sub(label, 1, 10) == "MediumSafe" then
		return "MED SAFE"
	end
	return label
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
			local start = snapFloor(hrp.Position, model, hrp.Position.Y)
			local goals = gatherGoals(hrp.Position, part)
			local wps, mode = nil, nil
			local needStairs = math.abs(part.Position.Y - hrp.Position.Y) > 4.0

			-- Stairs / floors: PathfindingService first (uses navmesh, not part names)
			for _, g in ipairs(goals) do
				local goal = snapFloor(g, model, part.Position.Y)
				wps, mode = tryPathfinding(start, goal)
				if wps then
					break
				end
			end
			if not wps then
				wps, mode = tryPathfinding(start, part.Position)
			end

			-- Probe only for same-ish floor (won't punch through slabs)
			if not wps and not needStairs then
				local side = (hrp.Position - part.Position)
				if side.Magnitude < 0.1 then
					side = Vector3.new(0, 0, 1)
				end
				local goal = snapFloor(part.Position + side.Unit * 2.5, model, hrp.Position.Y)
				wps, mode = probePath(start, goal, model)
			elseif not wps and needStairs then
				-- Still try probe only for horizontal approach on this floor (shows way toward stairwell), no vertical clip
				wps, mode = probePath(start, part.Position, model)
				if wps then
					mode = "need-stairs"
				end
			end

			if not wps or #wps < 2 then
				clearPathFolder()
				if needStairs then
					flashStatus("Path: use stairs — navmesh blocked", Color3.fromRGB(255, 140, 90))
				else
					flashStatus("Path: blocked — peek door/hole", Color3.fromRGB(255, 120, 120))
				end
				return
			end

			drawWaypoints(wps)
			local tag = mode == "nav" and "navmesh (stairs ok)"
				or mode == "need-stairs" and "same floor only — take stairs"
				or tostring(mode or "probe")
			flashStatus("Path → " .. labelOf(model) .. "  [" .. tag .. "]", Color3.fromRGB(90, 255, 150))
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
			if workspace:FindFirstChild(folderName) then
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
