-- Plik: workspace/Vanguard/Aim.lua

local Aim = {}

function Aim.Init(S, ParentGUI, TF, Util)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local VIM = game:GetService("VirtualInputManager")
	local CAS = game:GetService("ContextActionService")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local jitterSeed = math.random() * 100
	local lastTrigger = 0
	local lastTogglePress = 0
	local triggerToggled = false
	local botList = {}
	local botScanAt = 0
	local triggerLock = nil
	local triggerLockUntil = 0
	local silentBusy = false

	local AIM_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local FOVC = C("Frame", {
		Name = "FOVCircle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, S.FOV * 2, 0, S.FOV * 2),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = FOVC })
	C("UIStroke", { Color = S.V, Thickness = 1, Transparency = 0.3, Parent = FOVC })

	local TriggerHud = C("Frame", {
		Name = "TriggerHud",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(1, -22, 0.58, 0),
		BackgroundColor3 = S.V,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = TriggerHud })
	C("UIStroke", { Name = "DotStroke", Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.35, Parent = TriggerHud })

	local TriggerHudFull = C("TextLabel", {
		Name = "TriggerHudFull",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 130, 0, 22),
		Position = UDim2.new(1, -20, 0.58, 0),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.35,
		Text = "TRIGGER",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 140),
		Visible = false,
		ZIndex = 50,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = TriggerHudFull })
	C("UIStroke", { Color = Color3.fromRGB(40, 40, 48), Thickness = 1, Transparency = 0.5, Parent = TriggerHudFull })

	local function getTriggerKey()
		if not S.TriggerKey or S.TriggerKey == "" or S.TriggerKey == "None" then
			return nil
		end
		local ok, key = pcall(function()
			return Enum.KeyCode[S.TriggerKey]
		end)
		if ok then
			return key
		end
		return nil
	end

	local function triggerArmed()
		if not S.Trigger then
			return false
		end
		if S.TriggerMode == "Toggle" then
			return triggerToggled
		end
		local key = getTriggerKey()
		if not key then
			return true
		end
		return UIS:IsKeyDown(key)
	end

	local function updFOV()
		local d = math.max(S.FOV * 2, 4)
		FOVC.Size = UDim2.new(0, d, 0, d)
		FOVC.Visible = S.ShowFOV and not S.MasterRage and (S.Aimbot or S.Silent or S.Trigger)
	end

	local function isMinimalHud()
		return S.TriggerHudMinimal ~= false
	end

	local function updTriggerHud()
		if not S.ShowTriggerHud or not S.Trigger then
			TriggerHud.Visible = false
			TriggerHudFull.Visible = false
			return
		end

		local active = triggerArmed()
		local label = "IDLE"
		if S.TriggerMode == "Toggle" then
			label = triggerToggled and "ON" or "OFF"
		else
			label = active and "HOLD" or "IDLE"
		end

		if isMinimalHud() then
			TriggerHudFull.Visible = false
			TriggerHud.Visible = true
			local dotStroke = TriggerHud:FindFirstChild("DotStroke")
			if active then
				TriggerHud.Size = UDim2.new(0, 14, 0, 14)
				TriggerHud.BackgroundColor3 = S.V
				TriggerHud.BackgroundTransparency = 0
				if dotStroke then
					dotStroke.Transparency = 0.15
				end
			else
				TriggerHud.Size = UDim2.new(0, 9, 0, 9)
				TriggerHud.BackgroundColor3 = Color3.fromRGB(160, 160, 170)
				TriggerHud.BackgroundTransparency = 0.35
				if dotStroke then
					dotStroke.Transparency = 0.55
				end
			end
		else
			TriggerHud.Visible = false
			TriggerHudFull.Visible = true
			TriggerHudFull.Text = "TRIGGER · " .. label
			if active then
				TriggerHudFull.TextColor3 = S.V
				TriggerHudFull.BackgroundTransparency = 0.2
			else
				TriggerHudFull.TextColor3 = Color3.fromRGB(170, 170, 180)
				TriggerHudFull.BackgroundTransparency = 0.35
			end
		end
	end

	local function isAliveHumanoid(hum)
		if not hum or hum.Health <= 0 then
			return false
		end
		local ok, state = pcall(function()
			return hum:GetState()
		end)
		if ok and state == Enum.HumanoidStateType.Dead then
			return false
		end
		return true
	end

	local function isAliveChar(char)
		if not char or not char.Parent then
			return false
		end
		return isAliveHumanoid(char:FindFirstChildOfClass("Humanoid"))
	end

	local function refreshBots()
		if not S.AimBots then
			table.clear(botList)
			return
		end
		if tick() - botScanAt > 1.5 then
			botScanAt = tick()
			Util.refreshBotList(botList, true, LP)
		end
	end

	local function screenDist(part)
		local pos3 = Util.getPartPosition(part)
		if not pos3 then
			return math.huge
		end
		local pos, onScreen = Cam:WorldToViewportPoint(pos3)
		if not onScreen then
			return math.huge
		end
		local center = Cam.ViewportSize / 2
		return (Vector2.new(pos.X, pos.Y) - Vector2.new(center.X, center.Y)).Magnitude
	end

	local function resolveHitPart(char)
		if S.HitPart == "Head" then
			return Util.resolveAimPart(char, "Head") or Util.resolveAimPart(char, "HumanoidRootPart")
		elseif S.HitPart == "Torso" then
			return Util.resolveAimPart(char, "UpperTorso")
				or Util.resolveAimPart(char, "Torso")
				or Util.resolveAimPart(char, "HumanoidRootPart")
		elseif S.HitPart == "Random" then
			local pool = {}
			for _, n in ipairs(AIM_PARTS) do
				local p = Util.resolveAimPart(char, n)
				if p then
					table.insert(pool, p)
				end
			end
			if #pool == 0 then
				return Util.resolveAimPart(char, "HumanoidRootPart")
			end
			return pool[math.random(1, #pool)]
		else
			local best, bestD = nil, math.huge
			for _, n in ipairs(AIM_PARTS) do
				local p = Util.resolveAimPart(char, n)
				if p then
					local d = screenDist(p)
					if d < bestD then
						bestD = d
						best = p
					end
				end
			end
			return best or Util.resolveAimPart(char, "Head")
		end
	end

	local function isEnemyPlayer(plr)
		if plr == LP then
			return false
		end
		local char = plr.Character
		if not isAliveChar(char) then
			return false
		end
		if TF and TF.shouldExclude(S, LP, plr) then
			return false
		end
		if not TF and S.ExcludeTeam and plr.Team and LP.Team and plr.Team == LP.Team then
			return false
		end
		return true
	end

	local function findCrosshairEntry()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * (S.MaxDist or 500), params)
		if not hit or not hit.Instance then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not model or not isAliveChar(model) then
			return nil
		end
		if LP.Character and model == LP.Character then
			return nil
		end
		local plr = Players:GetPlayerFromCharacter(model)
		if plr then
			if not isEnemyPlayer(plr) then
				return nil
			end
			return { char = model, plr = plr }
		end
		if S.AimBots then
			return { char = model, plr = nil }
		end
		return nil
	end

	local function isVisible(part, char)
		if not S.VisibleCheck then
			return true
		end
		local partPos = Util.getPartPosition(part)
		if not partPos then
			return false
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local hit = workspace:Raycast(Cam.CFrame.Position, partPos - Cam.CFrame.Position, params)
		if not hit then
			return true
		end
		return hit.Instance:IsDescendantOf(char)
	end

	local function collectTargets()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemyPlayer(plr) and plr.Character then
				table.insert(list, { char = plr.Character, plr = plr })
			end
		end
		if S.AimBots then
			refreshBots()
			for _, model in ipairs(botList) do
				if model.Parent and isAliveChar(model) then
					table.insert(list, { char = model, plr = nil })
				end
			end
		end
		return list
	end

	local function scoreTarget(entry)
		local char = entry.char
		if not isAliveChar(char) then
			return nil
		end
		local part = resolveHitPart(char)
		if not part then
			return nil
		end

		local dist2d = screenDist(part)
		if dist2d > math.max(S.FOV, 1) then
			return nil
		end
		if not isVisible(part, char) then
			return nil
		end

		local partPos = Util.getPartPosition(part)
		if not partPos then
			return nil
		end
		local dist3d = (Cam.CFrame.Position - partPos).Magnitude
		if dist3d > S.MaxDist then
			return nil
		end

		local hum = char:FindFirstChild("Humanoid")
		local score
		if S.TargetMode == "Distance" then
			score = dist3d
		elseif S.TargetMode == "Health" then
			score = hum and hum.Health or math.huge
		else
			score = dist2d
		end

		return { part = part, char = char, plr = entry.plr, score = score }
	end

	local function getBestTarget()
		local crossEntry = findCrosshairEntry()
		if crossEntry then
			local crossCand = scoreTarget(crossEntry)
			if crossCand then
				return crossCand
			end
		end

		local best, bestScore = nil, math.huge
		for _, entry in ipairs(collectTargets()) do
			local cand = scoreTarget(entry)
			if cand and cand.score < bestScore then
				bestScore = cand.score
				best = cand
			end
		end
		return best
	end

	local function getStableTriggerTarget()
		if triggerLock and tick() < triggerLockUntil then
			local part = triggerLock.part
			local char = triggerLock.char
			if part and part.Parent and char and isAliveChar(char) and isVisible(part, char) then
				if screenDist(part) <= math.max(S.FOV, 1) * 1.25 then
					return triggerLock
				end
			end
		end
		triggerLock = getBestTarget()
		triggerLockUntil = tick() + 0.55
		return triggerLock
	end

	local function aimCamera(targetPos)
		local goal = CFrame.new(Cam.CFrame.Position, targetPos)
		local alpha = math.clamp((1 - S.Smooth) * 0.22, 0.012, 0.45)
		if S.AimCurve then
			local j = (math.noise(tick() * 2.5, jitterSeed) - 0.5) * 0.35
			alpha = math.clamp(alpha * (1 + j * S.Smooth), 0.008, 0.5)
		end
		Cam.CFrame = Cam.CFrame:Lerp(goal, alpha)
	end

	local function runSilentShot(tgt)
		if silentBusy or not tgt or not tgt.part then
			return
		end
		silentBusy = true
		task.spawn(function()
			local part = tgt.part
			local char = tgt.char
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local lead = Util.getNetworkLead(0.05)
			local function getTarget()
				return Util.predictAimPoint(part, char, lead)
			end
			local pos = getTarget()
			if pos then
				Util.performSilentShot(RS, Cam, VIM, pos, 2, { getTarget = getTarget })
				S.LastShotAt = tick()
				if hum then
					S.LastShotHum = hum
				end
			end
			silentBusy = false
		end)
	end

	local function tryTriggerShot()
		if S.MenuOpen or S.MasterRage or silentBusy then
			return
		end
		if not triggerArmed() then
			return
		end
		local baseDelay = math.max(S.TriggerDelay or 1, 1) / 1000
		local jitter = baseDelay * (math.random() * 0.2 - 0.1)
		if tick() - lastTrigger < baseDelay + jitter then
			return
		end

		local tgt = getStableTriggerTarget()
		if not tgt or not tgt.part then
			return
		end

		local lead = Util.getNetworkLead(baseDelay + 0.03)
		local targetPos = Util.predictAimPoint(tgt.part, tgt.char, lead)
		if not targetPos then
			return
		end

		lastTrigger = tick()
		S.LastShotAt = tick()
		if tgt.char then
			S.LastShotHum = tgt.char:FindFirstChildOfClass("Humanoid")
		end
		Util.fireAtWorld(VIM, Cam, targetPos)
	end

	pcall(function()
		CAS:UnbindAction("VanguardSilent")
	end)
	CAS:BindActionAtPriority("VanguardSilent", function(_, state, input)
		if S.MenuOpen or S.MasterRage or not S.Silent then
			return Enum.ContextActionResult.Pass
		end
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return Enum.ContextActionResult.Pass
		end
		local tgt = getBestTarget()
		if tgt then
			runSilentShot(tgt)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1)

	UIS.InputBegan:Connect(function(input, processed)
		if S.MenuOpen or S.MasterRage then
			return
		end

		local key = getTriggerKey()
		if S.Trigger and S.TriggerMode == "Toggle" and key and input.KeyCode == key then
			if tick() - lastTogglePress < 0.2 then
				return
			end
			lastTogglePress = tick()
			triggerToggled = not triggerToggled
		end
	end)

	RS.RenderStepped:Connect(function()
		updFOV()
		updTriggerHud()

		if not S.Trigger then
			triggerToggled = false
			triggerLock = nil
		end

		if S.MenuOpen or S.MasterRage then
			return
		end

		pcall(tryTriggerShot)

		if S.Aimbot and not S.Silent and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			pcall(function()
				local tgt = getBestTarget()
				if tgt and tgt.part then
					local lead = Util.getNetworkLead(0.02)
					local pos = Util.predictAimPoint(tgt.part, tgt.char, lead)
					if pos then
						aimCamera(pos)
					end
				end
			end)
		end
	end)
end

return Aim
