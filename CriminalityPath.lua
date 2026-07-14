-- CriminalityPath.lua  v2.43.94
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
local connLook = nil  -- RenderStepped for look indicator
local lookHighlight = nil
local lastLookModel = nil
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
	local OFFSETS = { -0.45, 0, 0.45 }
	local HEIGHTS = { 0.55, 1.1, 1.6, 2.1, 2.6 }

	for _, h in ipairs(HEIGHTS) do
		local allClear = true
		for _, off in ipairs(OFFSETS) do
			local nudge = perp * off
			local from = Vector3.new(a.X, a.Y + h, a.Z) + nudge
			local to   = Vector3.new(b.X, b.Y + h, b.Z) + nudge
			local hit = workspace:Raycast(from, to - from, params)
			if hit and isSolidHit(hit) then
				allClear = false
				break
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
		local stepLen = math.clamp(rem, 1.2, 1.8) -- small steps: can't skip through thin walls
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
	local model, part = resolveLookTarget(maxDist)
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

			-- Probe only for same-ish floor (won't punch through slabs)
			if not wps and not needStairs then
				local side = (hrp.Position - part.Position)
				if side.Magnitude < 0.1 then
					side = Vector3.new(0, 0, 1)
				end
				local goal = snapFloor(part.Position + side.Unit * 2.5, model, hrp.Position.Y)
				goalPos = goal
				wps, mode = probePath(startPos, goal, model)
			elseif not wps and needStairs then
				-- Still try probe only for horizontal approach on this floor (shows way toward stairwell), no vertical clip
				wps, mode = probePath(startPos, part.Position, model)
				if wps then
					mode = "need-stairs"
				end
			end

			if not wps or #wps < 2 then
				local why = needStairs and "use stairs / navmesh blocked" or "blocked — door or wall"
				-- Ray toward goal to show what solid part blocks
				local params = makeExcludeParams(model)
				local from = startPos + Vector3.new(0, 1.5, 0)
				local to = (goalPos or part.Position) + Vector3.new(0, 1.5, 0)
				local blockHit = workspace:Raycast(from, to - from, params)
				local hitName = ""
				if blockHit and blockHit.Instance then
					hitName = " | hit: " .. tostring(blockHit.Instance.Name)
					if not blockHit.Instance.CanCollide then
						hitName = hitName .. " (nocollide)"
					end
				end
				drawDebugFail(startPos, goalPos or part.Position, why, blockHit)
				flashStatus("Path FAIL: " .. why .. hitName, Color3.fromRGB(255, 120, 120), 5)
				return
			end

			drawWaypoints(wps)
			local tag = mode == "nav" and "navmesh"
				or mode == "need-stairs" and "same floor — find stairs"
				or tostring(mode or "probe")
			flashStatus("Path → " .. labelOf(model) .. "  [" .. tag .. "]", Color3.fromRGB(90, 255, 150), 3.5)
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

local function updateLookIndicator(maxDist)
	local model = resolveLookTarget(maxDist)
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

	-- Highlight safe/register you're currently looking at (blue outline)
	connLook = RunS.Heartbeat:Connect(function()
		local cur = _G.__VG_S or S
		if not cur or cur.CrimSafePath ~= true then
			clearLookIndicator()
			return
		end
		local maxDist = math.clamp(tonumber(cur.CrimESPMaxDist) or 300, 50, 800)
		pcall(updateLookIndicator, maxDist)
	end)
end

return CriminalityPath
