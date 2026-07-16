-- PathDisplay.lua  v2.48.0
-- Visual-only "maze solver" path (NPC navmesh + portal graph through DOORS & STAIRS).
-- No walk / no farm. Never draws a straight line through a solid wall.
--
-- How it works (intelligent routing):
--   * Builds a graph of PORTALS = doors (Map.Doors.DoorBase) + stairs/ladders (TrussPart /
--     stair-named parts). Each portal is two nodes (both sides) joined by a free edge — that
--     is how we legally cross a wall: through the doorway, not through the brick.
--   * PathfindingService links nodes that live in the same walkable region.
--   * Dijkstra over {start, target-approach-goals, portal-sides} finds the real route, even
--     when the target is sealed behind walls with only a door to get in (labyrinth from the
--     inside out).
--   * Path is cached & LOCKED to the target while you walk it. It only re-solves when it must
--     (you strayed off it, target changed/moved, or a safety timeout).
--   * Shows live status: a pulsing "solving" node + a billboard telling you what it's doing.

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

	-- cached solved route (locked while following)
	local cur = nil -- { model, targetPos, pts = {{Position,Action,IsDoor,IsStair}}, builtAt, kind, name, dist, doors, stairs, status }

	-- portal cache
	local portals = {} -- { {a=Vector3, b=Vector3, kind="door"/"stair"} }
	local portalsBuiltAt = 0
	local PORTAL_TTL = 12

	local WalkAct = Enum.PathWaypointAction.Walk
	local JumpAct = Enum.PathWaypointAction.Jump

	-- Two agents: tight for interiors, loose for tolerance. Both climb+jump.
	local AGENTS = {
		{ AgentRadius = 1.4, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2.5 },
		{ AgentRadius = 2.2, AgentHeight = 6, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3.5 },
	}

	local MAX_COMPUTES = 95 -- ComputeAsync budget per solve (spread over frames)

	--------------------------------------------------------------------------
	-- basics
	--------------------------------------------------------------------------
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

	local function isRareCrate(model)
		local cot = model:GetAttribute("cot_") or model:GetAttribute("col_")
		return cot == 7 or cot == "7"
	end

	local function shouldPathCrate(rare)
		if rare then
			return S.CrimPathCrateRare ~= false
		end
		return S.CrimPathCrateBasic ~= false
	end

	local function snapToGround(pos, extraIgnore)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { LP.Character, folder }
		if extraIgnore then
			table.insert(ignore, extraIgnore)
		end
		params.FilterDescendantsInstances = ignore
		for _, up in ipairs({ 6, 14, 28, 48 }) do
			local origin = Vector3.new(pos.X, pos.Y + up, pos.Z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -(up + 60), 0), params)
			if hit then
				return hit.Position + Vector3.new(0, 3, 0)
			end
		end
		return pos + Vector3.new(0, 3, 0)
	end

	local function distToSegment(p, a, b)
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 < 1e-4 then
			return (p - a).Magnitude
		end
		local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
		return (p - (a + ab * t)).Magnitude
	end

	--------------------------------------------------------------------------
	-- portals (doors + stairs) = the only legal ways through walls / floors
	--------------------------------------------------------------------------
	local function thinAxisSides(cf, size, offset)
		-- smallest dimension = passage normal (through the doorway / step depth)
		local nx, ny, nz = size.X, size.Y, size.Z
		local normal
		if nx <= ny and nx <= nz then
			normal = cf.RightVector
		elseif nz <= ny then
			normal = cf.LookVector
		else
			normal = cf.UpVector
		end
		return cf.Position + normal * offset, cf.Position - normal * offset
	end

	local function longAxisEnds(cf, size)
		-- largest dimension = travel direction (up a truss / along a ramp)
		local nx, ny, nz = size.X, size.Y, size.Z
		local axis, half
		if ny >= nx and ny >= nz then
			axis, half = cf.UpVector, ny * 0.5
		elseif nz >= nx then
			axis, half = cf.LookVector, nz * 0.5
		else
			axis, half = cf.RightVector, nx * 0.5
		end
		return cf.Position + axis * half, cf.Position - axis * half
	end

	local function buildPortals()
		portals = {}
		local map = workspace:FindFirstChild("Map")

		-- DOORS: Map.Doors.<door>.DoorBase (real doorways). Two sides = crossing.
		if map then
			local doorsFolder = map:FindFirstChild("Doors")
			if doorsFolder then
				local dc = 0
				for _, d in ipairs(doorsFolder:GetChildren()) do
					local base = d:FindFirstChild("DoorBase")
						or d:FindFirstChildWhichIsA("BasePart", true)
					if base and base:IsA("BasePart") then
						local a, b = thinAxisSides(base.CFrame, base.Size, math.max(base.Size.X, base.Size.Z) * 0.5 + 3)
						portals[#portals + 1] = {
							a = snapToGround(a),
							b = snapToGround(b),
							kind = "door",
							center = base.Position,
						}
					end
					dc += 1
					if dc % 40 == 0 then
						task.wait()
					end
				end
			end
		end

		-- STAIRS / LADDERS: TrussPart anywhere + parts named stair/ladder/ramp/steps.
		local scanned = 0
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("TrussPart") then
				local a, b = longAxisEnds(inst.CFrame, inst.Size)
				portals[#portals + 1] = {
					a = snapToGround(a),
					b = snapToGround(b),
					kind = "stair",
					center = inst.Position,
				}
			elseif inst:IsA("BasePart") then
				local n = inst.Name:lower()
				if n:find("stair") or n:find("ladder") or n:find("ramp") or n:find("steps") then
					if inst.Size.Y > 3 or inst.Size.Magnitude > 12 then
						local a, b = longAxisEnds(inst.CFrame, inst.Size)
						portals[#portals + 1] = {
							a = snapToGround(a),
							b = snapToGround(b),
							kind = "stair",
							center = inst.Position,
						}
					end
				end
			end
			scanned += 1
			if scanned % 3000 == 0 then
				task.wait()
			end
			if #portals >= 900 then
				break
			end
		end

		portalsBuiltAt = tick()
	end

	local function relevantPortals(startP, targetP)
		if tick() - portalsBuiltAt > PORTAL_TTL then
			buildPortals()
		end
		local out = {}
		for _, p in ipairs(portals) do
			local c = p.center
			local near = distToSegment(c, startP, targetP) < 55
				or (c - targetP).Magnitude < 90
				or (c - startP).Magnitude < 90
			if near then
				out[#out + 1] = { portal = p, d = (c - targetP).Magnitude }
			end
		end
		table.sort(out, function(x, y)
			return x.d < y.d
		end)
		-- keep the closest handful so the graph stays fast
		local cap = 18
		if #out > cap then
			local t = {}
			for i = 1, cap do
				t[i] = out[i]
			end
			out = t
		end
		return out
	end

	--------------------------------------------------------------------------
	-- target approach goals
	--------------------------------------------------------------------------
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
				goals[#goals + 1] = g
			end
		end
		add(base)
		local radii = (kind == "Safe") and { 4, 7, 11, 16 } or { 3, 6, 10 }
		for _, r in ipairs(radii) do
			for deg = 0, 315, 45 do
				local rad = math.rad(deg)
				add(base + Vector3.new(math.cos(rad) * r, 0, math.sin(rad) * r))
			end
		end
		for _, dy in ipairs({ -12, -6, 6, 12 }) do
			add(base + Vector3.new(0, dy, 0))
		end
		-- cap goal count
		local cap = 6
		if #goals > cap then
			local t = {}
			for i = 1, cap do
				t[i] = goals[i]
			end
			goals = t
		end
		return goals
	end

	--------------------------------------------------------------------------
	-- navmesh link (cached) between two world points
	--------------------------------------------------------------------------
	local function statusOk(st)
		return st == Enum.PathStatus.Success
			or tostring(st):find("Success")
	end

	local function rawCompute(fromPos, toPos, agent)
		local path = PFS:CreatePath(agent)
		local ok = pcall(function()
			path:ComputeAsync(fromPos, toPos)
		end)
		if not ok or not statusOk(path.Status) then
			return nil
		end
		local wps = path:GetWaypoints()
		if not wps or #wps < 2 then
			return nil
		end
		return wps
	end

	--------------------------------------------------------------------------
	-- Dijkstra maze solve (runs inside a coroutine, yields to avoid freezing)
	--------------------------------------------------------------------------
	local function solve(startPos, part, kind, setStatus)
		local start = snapToGround(startPos, LP.Character)
		local goals = approachGoals(part, kind)
		local pool = relevantPortals(start, part.Position)

		-- build nodes
		local nodes = {}
		nodes[1] = { pos = start, kind = "start" }
		local targetNodes = {}
		for _, g in ipairs(goals) do
			nodes[#nodes + 1] = { pos = g, kind = "goal" }
			targetNodes[#nodes] = true
		end
		-- portal side nodes with sibling links
		for _, pe in ipairs(pool) do
			local p = pe.portal
			local ia = #nodes + 1
			nodes[ia] = { pos = p.a, kind = p.kind, portal = true }
			local ib = #nodes + 1
			nodes[ib] = { pos = p.b, kind = p.kind, portal = true }
			nodes[ia].sibling = ib
			nodes[ib].sibling = ia
		end

		local N = #nodes
		local computes = 0
		local linkCache = {} -- key "i:j" -> segment(list of {Position,Action}) or false

		local function segFromWps(wps)
			local seg = {}
			for _, wp in ipairs(wps) do
				seg[#seg + 1] = { Position = wp.Position, Action = wp.Action }
			end
			return seg
		end

		local function reverseSeg(seg)
			local out = {}
			for i = #seg, 1, -1 do
				out[#out + 1] = { Position = seg[i].Position, Action = WalkAct }
			end
			return out
		end

		-- attempt navmesh link between node i and j (undirected cache, oriented i->j on return)
		local function link(i, j)
			local key = (i < j) and (i .. ":" .. j) or (j .. ":" .. i)
			local cached = linkCache[key]
			if cached ~= nil then
				if cached == false then
					return nil
				end
				-- oriented from min->max; flip if needed
				if i < j then
					return cached
				else
					return reverseSeg(cached)
				end
			end
			if computes >= MAX_COMPUTES then
				return nil
			end
			local a, b = nodes[i].pos, nodes[j].pos
			local d = (a - b).Magnitude
			-- allow long links only when start/goal involved; interior links stay short
			local isEndpoint = nodes[i].kind == "start" or nodes[j].kind == "start"
				or targetNodes[i] or targetNodes[j]
			local maxD = isEndpoint and 220 or 130
			if d > maxD then
				linkCache[key] = false
				return nil
			end
			local wps
			for _, agent in ipairs(AGENTS) do
				computes += 1
				wps = rawCompute(a, b, agent)
				if wps then
					local endDist = (wps[#wps].Position - b).Magnitude
					if endDist <= 8 then
						break
					end
					wps = nil
				end
				if computes % 6 == 0 then
					task.wait()
				end
			end
			if not wps then
				linkCache[key] = false
				return nil
			end
			local seg = segFromWps(wps)
			-- store oriented min->max
			if i < j then
				linkCache[key] = seg
				return seg
			else
				linkCache[key] = reverseSeg(seg)
				return reverseSeg(linkCache[key])
			end
		end

		-- Dijkstra
		local INF = math.huge
		local dist = {}
		local prev = {}
		local prevSeg = {}
		local done = {}
		for i = 1, N do
			dist[i] = INF
		end
		dist[1] = 0

		local reachedGoal = nil
		local safety = 0
		while true do
			-- pick min unvisited
			local u, best = nil, INF
			for i = 1, N do
				if not done[i] and dist[i] < best then
					best = dist[i]
					u = i
				end
			end
			if not u then
				break
			end
			done[u] = true
			if targetNodes[u] then
				reachedGoal = u
				break
			end

			-- portal sibling (free crossing through door/step)
			local sib = nodes[u].sibling
			if sib and not done[sib] then
				local a, b = nodes[u].pos, nodes[sib].pos
				local cost = (a - b).Magnitude
				if dist[u] + cost < dist[sib] then
					dist[sib] = dist[u] + cost
					prev[sib] = u
					prevSeg[sib] = {
						{ Position = a, Action = WalkAct, IsPortal = nodes[u].kind },
						{ Position = b, Action = WalkAct, IsPortal = nodes[u].kind },
					}
				end
			end

			-- navmesh edges to other nodes
			for v = 1, N do
				if v ~= u and not done[v] and v ~= sib then
					local approxCost = dist[u] + (nodes[u].pos - nodes[v].pos).Magnitude
					if approxCost < dist[v] then
						local seg = link(u, v)
						if seg then
							local realCost = dist[u] + (#seg * 2)
							if realCost < dist[v] then
								dist[v] = realCost
								prev[v] = u
								prevSeg[v] = seg
							end
						end
					end
				end
			end

			safety += 1
			if safety % 4 == 0 then
				setStatus(string.format("Solving route… %d", computes))
				task.wait()
			end
			if computes >= MAX_COMPUTES then
				-- budget spent: if no goal finalized yet, fall through and use closest reached
				break
			end
		end

		-- choose end node: reached goal, else closest reachable node to target
		local endNode = reachedGoal
		local success = reachedGoal ~= nil
		if not endNode then
			local bestD = INF
			for i = 1, N do
				if dist[i] < INF then
					local d = (nodes[i].pos - part.Position).Magnitude
					if d < bestD then
						bestD = d
						endNode = i
					end
				end
			end
		end
		if not endNode or endNode == 1 then
			return nil
		end

		-- reconstruct
		local segs = {}
		local node = endNode
		local doors, stairs = 0, 0
		while prev[node] do
			table.insert(segs, 1, prevSeg[node])
			if prevSeg[node][1] and prevSeg[node][1].IsPortal == "door" then
				doors += 1
			elseif prevSeg[node][1] and prevSeg[node][1].IsPortal == "stair" then
				stairs += 1
			end
			node = prev[node]
		end

		local pts = {}
		for _, seg in ipairs(segs) do
			for _, wp in ipairs(seg) do
				local last = pts[#pts]
				if not last or (last.Position - wp.Position).Magnitude > 1.2 then
					pts[#pts + 1] = {
						Position = wp.Position,
						Action = wp.Action or WalkAct,
						IsDoor = wp.IsPortal == "door",
						IsStair = wp.IsPortal == "stair",
					}
				end
			end
		end
		if #pts < 2 then
			return nil
		end

		return {
			pts = pts,
			doors = doors,
			stairs = stairs,
			success = success,
			computes = computes,
		}
	end

	--------------------------------------------------------------------------
	-- drawing
	--------------------------------------------------------------------------
	local function makeBillboard(parent, text)
		local bb = Instance.new("BillboardGui")
		bb.Name = "VG_PathStatus"
		bb.Size = UDim2.new(0, 200, 0, 34)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 600
		bb.Parent = parent
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Lbl"
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 0.35
		lbl.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
		lbl.TextColor3 = Color3.fromRGB(120, 230, 255)
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 13
		lbl.Text = text or ""
		lbl.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = lbl
		return bb, lbl
	end

	local searchPart = nil
	local searchBB = nil
	local searchLbl = nil

	local function updateSearchIndicator(hrp, text)
		local root = ensureFolder()
		if not searchPart or not searchPart.Parent then
			searchPart = Instance.new("Part")
			searchPart.Name = "VG_Searching"
			searchPart.Shape = Enum.PartType.Ball
			searchPart.Anchored = true
			searchPart.CanCollide = false
			searchPart.CanQuery = false
			searchPart.CanTouch = false
			searchPart.CastShadow = false
			searchPart.Material = Enum.Material.Neon
			searchPart.Color = Color3.fromRGB(120, 230, 255)
			searchPart.Size = Vector3.new(1.2, 1.2, 1.2)
			searchPart.Parent = root
			searchBB, searchLbl = makeBillboard(searchPart, text)
		end
		local pulse = 0.9 + math.sin(tick() * 6) * 0.35
		searchPart.Size = Vector3.new(pulse, pulse, pulse)
		searchPart.Transparency = 0.1 + (math.sin(tick() * 6) * 0.15)
		searchPart.Position = hrp.Position + Vector3.new(0, 2, 0)
		if searchLbl then
			searchLbl.Text = text
		end
	end

	local function removeSearchIndicator()
		if searchPart then
			searchPart:Destroy()
			searchPart = nil
			searchBB = nil
			searchLbl = nil
		end
	end

	local function drawRoute(route)
		local root = ensureFolder()
		root:ClearAllChildren()
		searchPart = nil
		searchBB = nil
		searchLbl = nil

		local walkCol = S.CrimPathColor or Color3.fromRGB(80, 200, 255)
		local jumpCol = S.CrimPathJumpColor or Color3.fromRGB(255, 170, 40)
		local doorCol = Color3.fromRGB(190, 120, 255)
		local stairCol = Color3.fromRGB(120, 255, 180)
		local pts = route.pts
		local prevPart = nil

		for i, wp in ipairs(pts) do
			local isJump = wp.Action == JumpAct
			local col = walkCol
			if wp.IsDoor then
				col = doorCol
			elseif wp.IsStair then
				col = stairCol
			elseif isJump then
				col = jumpCol
			end
			local part = Instance.new("Part")
			part.Name = "WP_" .. i
			part.Shape = Enum.PartType.Ball
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = col
			local size = (isJump or wp.IsDoor or wp.IsStair) and 0.85 or 0.55
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
				beam.Color = ColorSequence.new(col)
				beam.Parent = part
			end
			prevPart = part
		end

		if prevPart then
			prevPart.Size = Vector3.new(1.15, 1.15, 1.15)
			prevPart.Color = S.CrimPathEndColor or Color3.fromRGB(90, 255, 140)
			local extra = {}
			if route.doors > 0 then
				extra[#extra + 1] = route.doors .. " door"
			end
			if route.stairs > 0 then
				extra[#extra + 1] = route.stairs .. " stair"
			end
			local suffix = (#extra > 0) and (" · " .. table.concat(extra, " · ")) or ""
			if not route.success then
				suffix = suffix .. " · partial"
			end
			makeBillboard(prevPart, string.format("%s · %dm%s", route.name or "Target", math.floor(route.dist or 0), suffix))
		end
	end

	--------------------------------------------------------------------------
	-- candidates
	--------------------------------------------------------------------------
	local function collectCandidates(kind, origin, maxDist, showBroken)
		local list = {}
		local map = workspace:FindFirstChild("Map")
		if not map then
			return list
		end
		if kind == "Safe" then
			local f = map:FindFirstChild("BredMakurz")
			if f then
				for _, safe in ipairs(f:GetChildren()) do
					if (safe:IsA("Model") or safe:IsA("Folder") or safe:IsA("BasePart")) then
						if showBroken or not isBrokenSafe(safe) then
							local part = getModelPart(safe)
							if part then
								local d = (origin - part.Position).Magnitude
								if d <= maxDist then
									list[#list + 1] = { part = part, model = safe, dist = d, name = safe.Name }
								end
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
							list[#list + 1] = { part = part, model = shop, dist = d, name = shop.Name }
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
						local rare = isRareCrate(c)
						if shouldPathCrate(rare) then
							local part = getModelPart(c)
							if part then
								local d = (origin - part.Position).Magnitude
								if d <= maxDist and d > 2 then
									list[#list + 1] = {
										part = part,
										model = c,
										dist = d,
										name = rare and "Rare Crate" or "Crate",
									}
								end
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

	local function pickTarget(kind, origin, maxDist, showBroken)
		local cands = collectCandidates(kind, origin, maxDist, showBroken)
		if #cands == 0 then
			return nil
		end
		-- lock onto current model while it is still valid & not far worse than the closest
		if cur and cur.model and cur.model.Parent and cur.kind == kind then
			for _, c in ipairs(cands) do
				if c.model == cur.model then
					local closest = cands[1]
					if closest.model == cur.model or c.dist <= closest.dist * 1.6 then
						return c
					end
					break
				end
			end
		end
		return cands[1]
	end

	--------------------------------------------------------------------------
	-- stability: only re-solve when necessary
	--------------------------------------------------------------------------
	local function minDistToPath(pos, pts)
		local best = math.huge
		for i = 2, #pts do
			local d = distToSegment(pos, pts[i - 1].Position, pts[i].Position)
			if d < best then
				best = d
			end
		end
		return best
	end

	local function needResolve(target, hrpPos)
		if not cur or not cur.pts then
			return true
		end
		if cur.model ~= target.model then
			return true
		end
		if (cur.targetPos - target.part.Position).Magnitude > 8 then
			return true
		end
		-- strayed off the route → re-solve
		if minDistToPath(hrpPos, cur.pts) > 24 then
			return true
		end
		-- safety refresh
		if tick() - cur.builtAt > 14 then
			return true
		end
		return false
	end

	--------------------------------------------------------------------------
	-- main tick
	--------------------------------------------------------------------------
	local function tickPath()
		if S.Unloaded or not S.CrimPathDisplay then
			if folder and folder.Parent then
				clearVisual()
			end
			cur = nil
			return
		end

		local hrp = getHRP()
		if not hrp then
			clearVisual()
			cur = nil
			return
		end

		-- keep search indicator animating while a solve runs
		if computing then
			updateSearchIndicator(hrp, S.CrimPathStatus or "Solving route…")
			return
		end

		local refresh = math.clamp(tonumber(S.CrimPathRefresh) or 0.7, 0.35, 2.5)
		if (tick() - lastCompute) < refresh then
			return
		end

		local kind = S.CrimPathTarget or "Safe"
		local maxDist = tonumber(S.CrimPathMaxDist) or (S.CrimESPMaxDist or 300)
		local origin = hrp.Position
		local target = pickTarget(kind, origin, maxDist, S.CrimSafeShowBroken == true)
		if not target then
			clearVisual()
			cur = nil
			S.CrimPathStatus = "No target"
			return
		end

		if not needResolve(target, origin) then
			-- following existing locked route → leave it be
			return
		end

		lastCompute = tick()
		computing = true
		S.CrimPathStatus = "Solving route…"

		task.spawn(function()
			local ok, route = pcall(function()
				return solve(origin, target.part, kind, function(txt)
					S.CrimPathStatus = txt
				end)
			end)
			computing = false

			if S.Unloaded or not S.CrimPathDisplay then
				clearVisual()
				cur = nil
				return
			end
			removeSearchIndicator()

			if not ok or not route then
				clearVisual()
				cur = nil
				S.CrimPathStatus = "No path (walled off)"
				return
			end

			route.name = target.name
			route.dist = target.dist
			cur = {
				model = target.model,
				targetPos = target.part.Position,
				pts = route.pts,
				builtAt = tick(),
				kind = kind,
				name = target.name,
				dist = target.dist,
				doors = route.doors,
				stairs = route.stairs,
				status = route.success and "OK" or "Partial",
			}
			S.CrimPathStatus = string.format(
				"%s · %dm · %dpts · %dd/%ds · %s",
				target.name or kind,
				math.floor(target.dist),
				#route.pts,
				route.doors,
				route.stairs,
				route.success and "OK" or "partial"
			)
			pcall(drawRoute, route)
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
				cur = nil
			end
		end)
	end

	LP.CharacterRemoving:Connect(function()
		clearVisual()
		cur = nil
		removeSearchIndicator()
	end)
end

return PathDisplay
