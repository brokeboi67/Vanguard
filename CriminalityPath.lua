-- CriminalityPath.lua  v2.43.97
-- Safe/register path. Navmesh first (stairs); probe only same-floor with hard Y clamps.
-- Map mesh names are obfuscated — we never rely on names, only geometry + Map.Doors.

local CriminalityPath = {}

local PathS = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local RunS = game:GetService("RunService")
local Plrs = game:GetService("Players")
local Debris = game:GetService("Debris")

local folderName = "VG_SafePath"
local conn = nil
local connLook = nil
local lookHighlight = nil
local lastLookModel = nil
local computing = false
local lastComputeAt = 0
local lastGoalPos = nil   -- for auto-clear on arrival
local ARRIVE_DIST = 6     -- studs from goal → clear path
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
	lastGoalPos = nil
end

local function ensureFolder()
	clearPathFolder()
	local f = Instance.new("Folder")
	f.Name = folderName
	f.Parent = workspace
	return f
end

local function flashStatus(text, col, secs)
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
	lbl.Size = UDim2.new(0, 520, 0, 28)
	lbl.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	lbl.BackgroundTransparency = 0.25
	lbl.Text = text
	lbl.TextColor3 = col or Color3.fromRGB(120, 255, 160)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextWrapped = true
	lbl.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = lbl
	Debris:AddItem(gui, secs or 3.5)
end

local function makeMarker(parent, name, pos, color, size, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size or Vector3.new(0.7, 0.7, 0.7)
	p.Color = color
	p.Transparency = 0.1
	p.CFrame = CFrame.new(pos)
	p.Parent = parent
	return p
end

local function makeBeam(parent, a, b, color)
	local mid = (a + b) * 0.5
	local dist = (b - a).Magnitude
	if dist < 0.05 or dist > 80 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "DbgSeg"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Size = Vector3.new(0.14, 0.14, dist)
	beam.CFrame = CFrame.lookAt(mid, b)
	beam.Parent = parent
end

-- Draw start (green), goal (yellow), blocked ray (red) so user sees what failed.
local function drawDebugFail(startPos, goalPos, reason, blockHit)
	local f = ensureFolder()
	makeMarker(f, "DbgStart", startPos + Vector3.new(0, 0.4, 0), Color3.fromRGB(80, 255, 140), Vector3.new(0.9, 0.9, 0.9))
	if goalPos then
		makeMarker(f, "DbgGoal", goalPos + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 220, 60), Vector3.new(1.1, 1.1, 1.1))
		makeBeam(f, startPos + Vector3.new(0, 0.3, 0), goalPos + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 90, 90))
	end
	if blockHit and blockHit.Position then
		makeMarker(f, "DbgBlock", blockHit.Position, Color3.fromRGB(255, 60, 60), Vector3.new(0.55, 0.55, 0.55))
	end
	local bill = Instance.new("BillboardGui")
	bill.Name = "DbgLabel"
	bill.Size = UDim2.new(0, 220, 0, 36)
	bill.StudsOffset = Vector3.new(0, 2.2, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = f:FindFirstChild("DbgStart")
	bill.Parent = f
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = tostring(reason or "blocked")
	t.TextColor3 = Color3.fromRGB(255, 140, 140)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextStrokeTransparency = 0.4
	t.Parent = bill
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

-- Returns params that only exclude player + path folder (+ one optional model).
-- IMPORTANT: we do NOT exclude Map.Doors — in the obfuscated map, walls/fences
-- can be parented there. Excluding the whole folder makes every wall invisible
-- to raycasts, so the probe goes straight through them.
-- Open doors have CanCollide=false → isSolidHit returns false → path passes through.
-- Closed doors have CanCollide=true → isSolidHit returns true → blocked correctly.
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
	-- extra = the target safe/register model so we can stand next to it
	if extra and typeof(extra) == "Instance" then
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

-- Returns true if the safe/register model is broken/open.
local function isBrokenSafe(model)
	local vals = model:FindFirstChild("Values")
	local brk = vals and vals:FindFirstChild("Broken")
		or model:FindFirstChild("Broken")
	return brk and brk.Value == true
end

-- showBroken=true → include broken safes (matches "Show Broken" ESP toggle)
-- showBroken=false → only unbroken (default safe ESP)
local function resolveLookTarget(maxDist, showBroken)
	local cam = workspace.CurrentCamera
	local hrp = getHRP()
	if not cam or not hrp then
		return nil
	end
	local folder = getBredFolder()
	if not folder then
		return nil
	end

	local function allowed(model)
		if not isSafeOrRegister(model) then
			return false
		end
		if not showBroken and isBrokenSafe(model) then
			return false
		end
		return true
	end

	local origin = cam.CFrame.Position
	local dir = cam.CFrame.LookVector
	local params = makeExcludeParams(nil)
	local hit = workspace:Raycast(origin, dir * maxDist, params)
	if hit and hit.Instance then
		local anc = hit.Instance
		while anc and anc ~= folder do
			if allowed(anc) then
				return anc, getSafePart(anc)
			end
			anc = anc.Parent
		end
	end

	local best, bestScore = nil, nil
	for _, ch in ipairs(folder:GetChildren()) do
		if allowed(ch) then
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

-- MUST be above snapFloor/canTraverse (Lua local scoping — otherwise nil call → "Path error")
local function isSolidHit(hit)
	if not hit then
		return false
	end
	local inst = hit.Instance
	if not inst or not inst:IsA("BasePart") then
		return false
	end
	if not inst.CanCollide then
		return false -- decorative / passable mesh
	end
	if inst.Transparency >= 0.85 then
		return false -- nearly invisible = glass/transparent panel
	end
	return true
end

-- Prefer current story floor. Never start ray above next story.
local function snapFloor(pos, exclude, preferY)
	local params = makeExcludeParams(exclude)
	local py = preferY or pos.Y
	local origin = Vector3.new(pos.X, py + 2.5, pos.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -9, 0), params)
	if hit and isSolidHit(hit) and hit.Normal.Y >= 0.55 then
		local dy = hit.Position.Y - py
		if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
			return hit.Position + Vector3.new(0, 0.12, 0)
		end
	end
	origin = Vector3.new(pos.X, py + 3.8, pos.Z)
	hit = workspace:Raycast(origin, Vector3.new(0, -7, 0), params)
	if hit and isSolidHit(hit) and hit.Normal.Y >= 0.55 then
		local dy = hit.Position.Y - py
		if dy <= MAX_STEP_UP and dy >= -MAX_STEP_DOWN then
			return hit.Position + Vector3.new(0, 0.12, 0)
		end
	end
	return Vector3.new(pos.X, py, pos.Z)
end

-- Shoots 3 parallel rays (left/center/right of travel direction) at several heights.
-- A segment is traversable only if ALL 3 lateral offsets are clear at SOME height.
-- This prevents thin walls from slipping between single-ray checks.
local function canTraverse(a, b, exclude)
	local params = makeExcludeParams(exclude)
	if math.abs(b.Y - a.Y) > MAX_STEP_UP + 0.5 then
		return false, 0
	end
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if flat.Magnitude < 0.05 then
		return true, 1.8
	end
	local flatDir = flat.Unit
	-- perpendicular (left/right of travel)
	local perp = Vector3.new(-flatDir.Z, 0, flatDir.X)
	local OFFSETS = { 0, -0.45, 0.45 } -- center first: cheap early-reject when centrally blocked
	local HEIGHTS = { 0.55, 1.1, 1.6, 2.1 }

	for _, h in ipairs(HEIGHTS) do
		local allClear = true
		for _, off in ipairs(OFFSETS) do
			local nudge = perp * off
			local from = Vector3.new(a.X, a.Y + h, a.Z) + nudge
			local to   = Vector3.new(b.X, b.Y + h, b.Z) + nudge
			local hit = workspace:Raycast(from, to - from, params)
			if hit and isSolidHit(hit) then
				allClear = false
				break -- center (or a side) blocked — skip remaining offsets at this height
			end
		end
		if allClear then
			return true, h
		end
	end
	return false, 0
end

local function headroomOk(pos, exclude)
	local params = makeExcludeParams(exclude)
	local hit = workspace:Raycast(pos + Vector3.new(0, 0.25, 0), Vector3.new(0, 2.4, 0), params)
	return not hit or not isSolidHit(hit)
end

local STEP_DOWN_PROBE = 1.6 -- tighter than MAX_STEP_DOWN: avoid dipping into gaps/holes unnecessarily

local function quantizeKey(pos, cell)
	local qx = math.floor(pos.X / cell + 0.5)
	local qz = math.floor(pos.Z / cell + 0.5)
	return qx .. ":" .. qz
end

-- True A* over a lazily-built grid graph (not a greedy walk).
-- Explores multiple directions from EVERY visited node so it can route AROUND
-- buildings/walls to find doors/gaps, instead of getting stuck at the first wall.
-- Node budget keeps it lightweight (one-shot on keypress, not per-frame).
local function probePath(startPos, goalPos, exclude)
	local STEP = 1.6
	local CELL = STEP * 0.8
	local ITER_LIMIT = 220
	local ARRIVE = 2.4
	local DIR_ANGLES = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }

	local start = snapFloor(startPos, exclude, startPos.Y)
	local crossStory = math.abs(goalPos.Y - start.Y) > 4.0
	local goal = snapFloor(goalPos, exclude, start.Y)

	local function heuristic(pos)
		return Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude
	end

	local nodes = { { pos = start, g = 0, f = heuristic(start), parent = nil } }
	local keyToIndex = { [quantizeKey(start, CELL)] = 1 }
	local open = { 1 }
	local closed = {}

	local goalIndex = nil
	local bestPartialIdx, bestPartialH = 1, heuristic(start)
	local iterations = 0

	while #open > 0 and iterations < ITER_LIMIT do
		iterations += 1
		if iterations % 40 == 0 then
			task.wait()
		end

		-- pop lowest f
		local bestPos, curIdx = 1, open[1]
		for i = 2, #open do
			if nodes[open[i]].f < nodes[curIdx].f then
				bestPos, curIdx = i, open[i]
			end
		end
		table.remove(open, bestPos)
		if not closed[curIdx] then
			closed[curIdx] = true
			local curNode = nodes[curIdx]

			local h = heuristic(curNode.pos)
			if h < bestPartialH then
				bestPartialH = h
				bestPartialIdx = curIdx
			end
			if h <= ARRIVE then
				goalIndex = curIdx
				break
			end

			local toGoalFlat = Vector3.new(goal.X - curNode.pos.X, 0, goal.Z - curNode.pos.Z)
			local baseDir = toGoalFlat.Magnitude > 0.05 and toGoalFlat.Unit or Vector3.new(0, 0, 1)

			for _, ang in ipairs(DIR_ANGLES) do
				local dir = rotY(baseDir, ang)
				local guess = curNode.pos + dir * STEP
				local floored = snapFloor(guess, exclude, curNode.pos.Y)
				local dy = floored.Y - curNode.pos.Y
				if dy <= MAX_STEP_UP and dy >= -STEP_DOWN_PROBE then
					local okTrav, hgt = canTraverse(curNode.pos, floored, exclude)
					if okTrav and headroomOk(floored, exclude) then
						local key = quantizeKey(floored, CELL)
						local moveCost = (floored - curNode.pos).Magnitude + math.abs(dy) * 1.5
						local g2 = curNode.g + moveCost
						local existingIdx = keyToIndex[key]
						if not existingIdx then
							table.insert(nodes, {
								pos = floored,
								g = g2,
								f = g2 + heuristic(floored),
								parent = curIdx,
								h = hgt,
							})
							local newIdx = #nodes
							keyToIndex[key] = newIdx
							table.insert(open, newIdx)
						elseif not closed[existingIdx] and g2 < nodes[existingIdx].g - 0.01 then
							nodes[existingIdx].g = g2
							nodes[existingIdx].f = g2 + heuristic(floored)
							nodes[existingIdx].parent = curIdx
						end
					end
				end
			end
		end
	end

	local finalIdx = goalIndex or bestPartialIdx
	if finalIdx == 1 and not goalIndex then
		return nil, "probe-fail" -- couldn't even take one step — truly boxed in
	end

	-- reconstruct path by walking parents
	local chain = {}
	local walk = finalIdx
	while walk do
		table.insert(chain, 1, walk)
		walk = nodes[walk].parent
	end

	local points = {}
	for i, idx in ipairs(chain) do
		local node = nodes[idx]
		local doorHit = nearestDoorInfo(node.pos)
		local action = Enum.PathWaypointAction.Walk
		if i > 1 then
			local prevNode = nodes[chain[i - 1]]
			if not doorHit and (math.abs(node.pos.Y - prevNode.pos.Y) > 0.85 or (node.h and node.h > 0 and node.h < 1.5)) then
				action = Enum.PathWaypointAction.Jump
			end
		end
		table.insert(points, { Position = node.pos, Action = action, IsDoor = doorHit ~= nil })
	end

	if #points < 2 then
		return nil, "probe-fail"
	end
	if goalIndex then
		return points, crossStory and "probe-samefloor" or "probe"
	end
	return points, "probe-partial"
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
		-- PathWaypoint (navmesh) is Roblox userdata, not a Lua table — accessing .IsDoor crashes.
		-- Use type check: probe returns plain tables, navmesh returns PathWaypoint userdata.
		local isDoor = (type(wp) == "table" and wp.IsDoor == true) or nearestDoorInfo(wp.Position) ~= nil
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
	local showBroken = S.CrimSafeShowBroken == true
	local model, part = resolveLookTarget(maxDist, showBroken)
	if not model or not part then
		flashStatus("Path: look at a safe/register", Color3.fromRGB(255, 180, 90))
		clearPathFolder()
		return
	end

	computing = true
	flashStatus("Path: computing…", Color3.fromRGB(180, 200, 255), 2)

	task.spawn(function()
		local startPos, goalPos
		local okOuter, errOuter = pcall(function()
			startPos = snapFloor(hrp.Position, model, hrp.Position.Y)
			goalPos = part.Position
			local goals = gatherGoals(hrp.Position, part)
			local wps, mode = nil, nil
			local needStairs = math.abs(part.Position.Y - hrp.Position.Y) > 4.0

			-- Stairs / floors: PathfindingService first (uses navmesh, not part names)
			for _, g in ipairs(goals) do
				local goal = snapFloor(g, model, part.Position.Y)
				wps, mode = tryPathfinding(startPos, goal)
				if wps then
					goalPos = goal
					break
				end
			end
			if not wps then
				wps, mode = tryPathfinding(startPos, part.Position)
			end

			-- Probe fallback for ALL cases — with fixed canTraverse (multi-ray, no Map.Doors exclusion)
			-- it now properly stops at walls instead of clipping through them.
			if not wps then
				local side = (hrp.Position - part.Position)
				if side.Magnitude < 0.1 then
					side = Vector3.new(0, 0, 1)
				end
				local probeGoal
				if needStairs then
					-- Cross-floor: probe toward target at our floor level (guides to stairs/ladder)
					probeGoal = snapFloor(part.Position, model, hrp.Position.Y)
				else
					probeGoal = snapFloor(part.Position + side.Unit * 2.5, model, hrp.Position.Y)
				end
				goalPos = probeGoal
				wps, mode = probePath(startPos, probeGoal, model)
				-- probe-fail (< 3 points) = truly stuck, don't show
				if mode == "probe-fail" then
					wps = nil
				end
				-- probe-partial = valid up to wall — show as partial guide
			end

			if not wps or #wps < 2 then
				local why = needStairs
					and "navmesh + probe blocked — find stairs/ladder manually"
					or "blocked — try different angle"
				local params = makeExcludeParams(model)
				local from = startPos + Vector3.new(0, 1.5, 0)
				local to = (goalPos or part.Position) + Vector3.new(0, 1.5, 0)
				local blockHit = workspace:Raycast(from, to - from, params)
				local hitName = ""
				if blockHit and blockHit.Instance then
					hitName = " | " .. tostring(blockHit.Instance.Name)
					if not blockHit.Instance.CanCollide then
						hitName = hitName .. "(nocol)"
					end
				end
				clearPathFolder()
				drawDebugFail(startPos, goalPos or part.Position, why, blockHit)
				flashStatus("Path: " .. why .. hitName, Color3.fromRGB(255, 140, 90), 5)
				lastGoalPos = nil
				return
			end

			-- For partial probe, goal = last waypoint (not the safe itself)
			local arrivePos = (mode == "probe-partial")
				and wps[#wps].Position
				or (goalPos or part.Position)
			lastGoalPos = arrivePos
			drawWaypoints(wps)
			local tag = mode == "nav" and "navmesh"
				or (needStairs and (mode == "probe" or mode == "probe-partial")) and "partial — find stairs"
				or mode == "probe-partial" and "partial — reposition"
				or tostring(mode or "probe")
			local col = (mode == "probe-partial")
				and Color3.fromRGB(255, 200, 80)
				or Color3.fromRGB(90, 255, 150)
			flashStatus("Path → " .. labelOf(model) .. "  [" .. tag .. "]", col, 3.5)
		end)
		computing = false
		if not okOuter then
			local msg = tostring(errOuter or "unknown")
			if #msg > 90 then
				msg = string.sub(msg, 1, 87) .. "…"
			end
			if startPos then
				drawDebugFail(startPos, goalPos or (part and part.Position), "crash", nil)
			end
			flashStatus("Path error: " .. msg, Color3.fromRGB(255, 100, 100), 6)
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

local function clearLookIndicator()
	if lookHighlight then
		pcall(function()
			lookHighlight:Destroy()
		end)
		lookHighlight = nil
	end
	lastLookModel = nil
end

local function updateLookIndicator(maxDist, showBroken)
	local model = resolveLookTarget(maxDist, showBroken)
	if model == lastLookModel then
		return
	end
	clearLookIndicator()
	lastLookModel = model
	if not model then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "VG_LookHL"
	h.FillTransparency = 1
	h.OutlineColor = Color3.fromRGB(80, 180, 255)
	h.OutlineTransparency = 0
	h.Adornee = model
	h.Parent = model
	lookHighlight = h
end

function CriminalityPath.Stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if connLook then
		connLook:Disconnect()
		connLook = nil
	end
	clearLookIndicator()
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
			clearLookIndicator()
		end)
	end

	-- Heartbeat: look indicator + auto-clear on arrival
	connLook = RunS.Heartbeat:Connect(function()
		local cur = _G.__VG_S or S
		if not cur or cur.CrimSafePath ~= true then
			clearLookIndicator()
			return
		end

		-- Auto-clear when player reaches goal
		if lastGoalPos and workspace:FindFirstChild(folderName) then
			local hrp2 = getHRP()
			if hrp2 and (hrp2.Position - lastGoalPos).Magnitude <= ARRIVE_DIST then
				clearPathFolder()
				flashStatus("Arrived!", Color3.fromRGB(90, 255, 150), 2)
			end
		end

		local maxDist = math.clamp(tonumber(cur.CrimESPMaxDist) or 300, 50, 800)
		local showBroken = cur.CrimSafeShowBroken == true
		pcall(updateLookIndicator, maxDist, showBroken)
	end)
end

return CriminalityPath
