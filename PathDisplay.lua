-- PathDisplay.lua  v2.46.0
-- Visual-only path to nearest Criminality target (safes / dealers / crates).
-- Inspired by MagicScripts ShowPath: PathfindingService + adaptive agent + waypoint beams.

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
	local lastTargetKey = ""
	local lastStatus = ""

	local AGENT_LADDER = {
		{
			AgentRadius = 1,
			AgentHeight = 4,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 2,
		},
		{
			AgentRadius = 1.2,
			AgentHeight = 4.5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 2.5,
		},
		{
			AgentRadius = 1.5,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 3,
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
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	local function getModelPart(model)
		if not model then
			return nil
		end
		if model:IsA("BasePart") then
			return model
		end
		return model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("PrimaryPart")
			or model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function isBrokenSafe(model)
		local values = model:FindFirstChild("Values")
		local broken = (values and values:FindFirstChild("Broken")) or model:FindFirstChild("Broken", true)
		return broken and broken:IsA("BoolValue") and broken.Value == true
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
								table.insert(list, { part = part, dist = d, name = safe.Name })
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
							table.insert(list, { part = part, dist = d, name = shop.Name })
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
								table.insert(list, { part = part, dist = d, name = c.Name })
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

		-- end marker
		if prevPart then
			prevPart.Size = Vector3.new(1.1, 1.1, 1.1)
			prevPart.Color = S.CrimPathEndColor or Color3.fromRGB(90, 255, 140)
		end
	end

	local function computePath(fromPos, toPos)
		for _, agent in ipairs(AGENT_LADDER) do
			local path = PFS:CreatePath(agent)
			local ok = pcall(function()
				path:ComputeAsync(fromPos, toPos)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				local wps = path:GetWaypoints()
				if wps and #wps > 1 then
					return wps, path.Status
				end
			end
		end
		-- direct fallback line (2 points) if navmesh fails
		return {
			{ Position = fromPos, Action = Enum.PathWaypointAction.Walk },
			{ Position = toPos, Action = Enum.PathWaypointAction.Walk },
		}, "Direct"
	end

	local function tickPath()
		if S.Unloaded or not S.CrimPathDisplay then
			clearVisual()
			lastTargetKey = ""
			return
		end

		local hrp = getHRP()
		if not hrp then
			clearVisual()
			return
		end

		local refresh = math.clamp(tonumber(S.CrimPathRefresh) or 0.55, 0.25, 2)
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
			lastTargetKey = ""
			S.CrimPathStatus = "No target"
			return
		end

		local targetPos = best.part.Position
		local key = tostring(best.part) .. ":" .. math.floor(targetPos.X) .. "," .. math.floor(targetPos.Z)
		-- still recompute periodically even if same target (player moved)
		lastCompute = tick()
		computing = true

		task.spawn(function()
			local ok, wps, status = pcall(function()
				local w, st = computePath(origin, targetPos)
				return w, st
			end)
			computing = false
			if S.Unloaded or not S.CrimPathDisplay then
				clearVisual()
				return
			end
			if not ok or not wps then
				S.CrimPathStatus = "Path failed"
				return
			end
			lastTargetKey = key
			lastStatus = tostring(status)
			local jumps = 0
			for _, wp in ipairs(wps) do
				if wp.Action == Enum.PathWaypointAction.Jump then
					jumps += 1
				end
			end
			S.CrimPathStatus = string.format("%s · %dm · %d pts · %d jump", best.name or kind, math.floor(best.dist), #wps, jumps)
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
