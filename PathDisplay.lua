-- PathDisplay.lua  v2.46.1
-- Visual-only PathfindingService path (NPC-style navmesh). No walk / no farm.
-- Never draws a straight-line "Direct" through walls.

local PathDisplay = {}

function PathDisplay.Init(S)
	if game.GameId ~= 1494262959 then
		return
	end

	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local PFS = game:GetService("PathfindingService")

	local LP = Players.LocalPlayer
	local folder = nil
	local computing = false
	local lastCompute = 0

	-- Same ladder Magic uses, plus one looser agent for vertical / tight interiors
	local AGENT_LADDER = {
		{
			AgentRadius = 1,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 2,
		},
		{
			AgentRadius = 1.2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 2.5,
		},
		{
			AgentRadius = 1.5,
			AgentHeight = 5.5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 3,
		},
		{
			AgentRadius = 2,
			AgentHeight = 6,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 4,
		},
	}

	local function ensureFolder()
		if folder and folder.Parent then
			return folder
		end
		local old = workspace:FindFirstChild("VG_PathDisplay")
		if old then
			old:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "VG_PathDisplay"
		folder.Parent = workspace
		return folder
	end

	local function clearVisual()
		if folder and folder.Parent then
			folder:ClearAllChildren()
		end
	end

	local function getHRP()
		local char = LP.Character
		return char and char:FindFirstChild("HumanoidRootPart"), char
	end

	local function getModelPart(model)
		if not model then
			return nil
		end
		if model:IsA("BasePart") then
			return model
		end
		return model.PrimaryPart
			or model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function isBrokenSafe(model)
		local values = model:FindFirstChild("Values")
		local broken = (values and values:FindFirstChild("Broken")) or model:FindFirstChild("Broken", true)
		return broken and broken:IsA("BoolValue") and broken.Value == true
	end

	-- Snap to walkable floor (navmesh-friendly), HRP-ish height
	local function snapToGround(pos, extraIgnore)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { LP.Character, folder }
		if extraIgnore then
			table.insert(ignore, extraIgnore)
		end
		params.FilterDescendantsInstances = ignore

		-- try from above, then higher for multi-floor
		for _, up in ipairs({ 6, 14, 28, 48 }) do
			local origin = Vector3.new(pos.X, pos.Y + up, pos.Z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -(up + 60), 0), params)
			if hit then
				return hit.Position + Vector3.new(0, 3, 0)
			end
		end
		return pos + Vector3.new(0, 3, 0)
	end

	-- Destinations around a prop so path doesn't end inside the mesh (FailFinishNotEmpty)
	local function approachGoals(part, kind)
		local base = part.Position
		local model = part:FindFirstAncestorOfClass("Model") or part
		local goals = {}
		local seen = {}

		local function add(p)
			local g = snapToGround(p, model)
			local key = string.format("%d_%d_%d", math.floor(g.X), math.floor(g.Y), math.floor(g.Z))
			if not seen[key] then
				seen[key] = true
				table.insert(goals, g)
			end
		end

		add(base)
		-- denser ring for safes/registers (often flush against walls)
		local radii = (kind == "Safe") and { 3, 5, 7, 9, 12, 16 } or { 3, 5, 8, 12 }
		for _, r in ipairs(radii) do
			for deg = 0, 315, 45 do
				local rad = math.rad(deg)
				add(base + Vector3.new(math.cos(rad) * r, 0, math.sin(rad) * r))
			end
		end
		-- vertical neighbors (floors above/below)
		for _, dy in ipairs({ -12, -6, 6, 12, 20 }) do
			add(base + Vector3.new(0, dy, 0))
			add(base + Vector3.new(4, dy, 0))
			add(base + Vector3.new(-4, dy, 0))
		end
		return goals
	end

	local function collectCandidates(kind, origin, maxDist, showBroken)
		local list = {}
		local map = workspace:FindFirstChild("Map")
		if not map then
			return list
		end

		if kind == "Safe" then
			local f = map:FindFirstChild("BredMakurz")
			if not f then
				return list
			end
			for _, safe in ipairs(f:GetChildren()) do
				if safe:IsA("Model") or safe:IsA("Folder") or safe:IsA("BasePart") then
					if showBroken or not isBrokenSafe(safe) then
						local part = getModelPart(safe)
						if part then
							local d = (origin - part.Position).Magnitude
							if d <= maxDist then
								table.insert(list, { part = part, model = safe, dist = d, name = safe.Name })
							end
						end
					end
				end
			end
		elseif kind == "Dealer" then
			local shops = map:FindFirstChild("Shopz")
			if shops then
				for _, shop in ipairs(shops:GetChildren()) do
					local part = getModelPart(shop)
					if part then
						local d = (origin - part.Position).Magnitude
						if d <= maxDist then
							table.insert(list, { part = part, model = shop, dist = d, name = shop.Name })
						end
					end
				end
			end
		elseif kind == "Crate" then
			local filter = workspace:FindFirstChild("Filter")
			local piles = filter and filter:FindFirstChild("SpawnedPiles")
			if piles then
				for _, c in ipairs(piles:GetChildren()) do
					if c.Name == "C1" or c:IsA("Model") then
						local part = getModelPart(c)
						if part then
							local d = (origin - part.Position).Magnitude
							if d <= maxDist and d > 2 then
								table.insert(list, { part = part, model = c, dist = d, name = c.Name })
							end
						end
					end
				end
			end
		end

		table.sort(list, function(a, b)
			return a.dist < b.dist
		end)
		return list
	end

	local function drawWaypoints(waypoints)
		local root = ensureFolder()
		root:ClearAllChildren()

		local walkCol = S.CrimPathColor or Color3.fromRGB(80, 200, 255)
		local jumpCol = S.CrimPathJumpColor or Color3.fromRGB(255, 170, 40)
		local prevPart = nil

		for i, wp in ipairs(waypoints) do
			local isJump = wp.Action == Enum.PathWaypointAction.Jump
			local part = Instance.new("Part")
			part.Name = "WP_" .. i
			part.Shape = Enum.PartType.Ball
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = isJump and jumpCol or walkCol
			local size = isJump and 0.85 or 0.55
			part.Size = Vector3.new(size, size, size)
			part.Transparency = 0.15
			part.Position = wp.Position + Vector3.new(0, 0.35, 0)
			part.Parent = root

			if prevPart then
				local a0 = Instance.new("Attachment")
				a0.Parent = prevPart
				local a1 = Instance.new("Attachment")
				a1.Parent = part
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.FaceCamera = true
				beam.Width0 = 0.18
				beam.Width1 = 0.18
				beam.LightEmission = 0.7
				beam.Transparency = NumberSequence.new(0.25)
				beam.Color = ColorSequence.new(isJump and jumpCol or walkCol)
				beam.Parent = part
			end
			prevPart = part
		end

		if prevPart then
			prevPart.Size = Vector3.new(1.1, 1.1, 1.1)
			prevPart.Color = S.CrimPathEndColor or Color3.fromRGB(90, 255, 140)
		end
	end

	local function statusOk(st)
		return st == Enum.PathStatus.Success
			or st == Enum.PathStatus.ClosestNoPath
			or tostring(st) == "Enum.PathStatus.Success"
			or tostring(st) == "Enum.PathStatus.ClosestNoPath"
	end

	local function tryCompute(fromPos, toPos, agent)
		local path = PFS:CreatePath(agent)
		local ok = pcall(function()
			path:ComputeAsync(fromPos, toPos)
		end)
		if not ok then
			return nil
		end
		if not statusOk(path.Status) then
			return nil
		end
		local wps = path:GetWaypoints()
		if not wps or #wps < 2 then
			return nil
		end
		-- reject degenerate "almost straight through wall" (1 segment, huge distance)
		-- real navmesh paths usually have several points when obstructed
		return wps, path.Status
	end

	-- Full search: agent ladder × approach goals. NO straight-line fallback.
	local function computeSmartPath(fromPos, part, kind)
		local start = snapToGround(fromPos, LP.Character)
		local goals = approachGoals(part, kind)
		-- try nearer approach points first
		table.sort(goals, function(a, b)
			return (a - start).Magnitude < (b - start).Magnitude
		end)
		-- hard cap so we don't stall the client
		local maxGoals = (kind == "Safe") and 18 or 12
		if #goals > maxGoals then
			local trimmed = {}
			for i = 1, maxGoals do
				trimmed[i] = goals[i]
			end
			goals = trimmed
		end

		local bestWps, bestStatus, bestScore = nil, nil, math.huge

		for _, agent in ipairs(AGENT_LADDER) do
			for _, goal in ipairs(goals) do
				local wps, st = tryCompute(start, goal, agent)
				if wps then
					local score = #wps
					local isSuccess = st == Enum.PathStatus.Success or tostring(st):find("Success")
					if isSuccess then
						score = score - 1000
					end
					local jumps = 0
					for _, wp in ipairs(wps) do
						if wp.Action == Enum.PathWaypointAction.Jump then
							jumps += 1
						end
					end
					score = score + jumps * 2
					local endDist = (wps[#wps].Position - part.Position).Magnitude
					score = score + endDist * 0.15

					if score < bestScore then
						bestScore = score
						bestWps = wps
						bestStatus = st
						if isSuccess and endDist < 12 and #wps >= 2 then
							return bestWps, bestStatus
						end
					end
				end
			end
			-- if we already have a decent Success from a tighter agent, stop
			if bestWps and (bestStatus == Enum.PathStatus.Success or tostring(bestStatus):find("Success")) then
				break
			end
		end

		return bestWps, bestStatus
	end

	local function tickPath()
		if S.Unloaded or not S.CrimPathDisplay then
			clearVisual()
			return
		end

		local hrp = getHRP()
		if not hrp then
			clearVisual()
			return
		end

		local refresh = math.clamp(tonumber(S.CrimPathRefresh) or 0.7, 0.35, 2.5)
		if computing or (tick() - lastCompute) < refresh then
			return
		end

		local kind = S.CrimPathTarget or "Safe"
		local maxDist = tonumber(S.CrimPathMaxDist) or (S.CrimESPMaxDist or 300)
		local origin = hrp.Position
		local cands = collectCandidates(kind, origin, maxDist, S.CrimSafeShowBroken == true)
		local best = cands[1]
		if not best or not best.part then
			clearVisual()
			S.CrimPathStatus = "No target"
			return
		end

		lastCompute = tick()
		computing = true

		task.spawn(function()
			local ok, wps, status = pcall(function()
				return computeSmartPath(origin, best.part, kind)
			end)
			computing = false

			if S.Unloaded or not S.CrimPathDisplay then
				clearVisual()
				return
			end

			if not ok or not wps then
				clearVisual()
				S.CrimPathStatus = "No path (navmesh)"
				return
			end

			local jumps = 0
			for _, wp in ipairs(wps) do
				if wp.Action == Enum.PathWaypointAction.Jump then
					jumps += 1
				end
			end
			S.CrimPathStatus = string.format(
				"%s · %dm · %d pts · %d jump · %s",
				best.name or kind,
				math.floor(best.dist),
				#wps,
				jumps,
				tostring(status):gsub("Enum.PathStatus.", "")
			)
			pcall(drawWaypoints, wps)
		end)
	end

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn)
		return fn
	end

	RS.Heartbeat:Connect(perfWrap("PathDisplay.Main", function()
		pcall(tickPath)
	end))

	if typeof(S._configApplyHooks) == "table" then
		table.insert(S._configApplyHooks, function()
			if not S.CrimPathDisplay then
				clearVisual()
			end
		end)
	end

	LP.CharacterRemoving:Connect(function()
		clearVisual()
	end)
end

return PathDisplay
