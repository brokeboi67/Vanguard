-- Plik: workspace/Vanguard/Aim.lua

local Aim = {}

function Aim.Init(S, ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local VIM = game:GetService("VirtualInputManager")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local jitterSeed = math.random() * 100
	local lastTrigger = 0
	local triggerToggled = false
	local botList = {}
	local botScanAt = 0

	local silentRestore = nil
	local silentPhase = 0

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

	local StatusPanel = C("TextButton", {
		Name = "AimStatusPopup",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 340, 0, 28),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		Visible = false,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = StatusPanel })
	local StatusText = C("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = StatusPanel,
	})

	local function boolText(value)
		return value and "ON" or "OFF"
	end

	local function updStatus()
		StatusPanel.Visible = S.ShowStatus and (S.Aimbot or S.Silent or S.Trigger)
		StatusText.Text = string.format("Aimbot: %s   Silent: %s   Trigger: %s   (click to hide)", boolText(S.Aimbot), boolText(S.Silent), boolText(S.Trigger))
	end

	StatusPanel.MouseButton1Click:Connect(function()
		S.ShowStatus = false
		StatusPanel.Visible = false
	end)

	local function updFOV()
		local d = math.max(S.FOV * 2, 4)
		FOVC.Size = UDim2.new(0, d, 0, d)
		FOVC.Visible = S.ShowFOV and (S.Aimbot or S.Silent or S.Trigger)
	end

	local function isBotModel(model)
		if not model:IsA("Model") then
			return false
		end
		if LP.Character and model == LP.Character then
			return false
		end
		if Players:GetPlayerFromCharacter(model) then
			return false
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local hrp = model:FindFirstChild("HumanoidRootPart")
		return hum and hrp and hum.Health > 0
	end

	local function refreshBots()
		if not S.AimBots then
			table.clear(botList)
			return
		end
		table.clear(botList)
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("Model") and isBotModel(inst) then
				table.insert(botList, inst)
			end
		end
	end

	local function screenDist(part)
		local pos, onScreen = Cam:WorldToViewportPoint(part.Position)
		if not onScreen then
			return math.huge
		end
		local center = Cam.ViewportSize / 2
		return (Vector2.new(pos.X, pos.Y) - Vector2.new(center.X, center.Y)).Magnitude
	end

	local function isVisible(part, char)
		if not S.VisibleCheck then
			return true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local hit = workspace:Raycast(Cam.CFrame.Position, part.Position - Cam.CFrame.Position, params)
		return hit and hit.Instance:IsDescendantOf(char)
	end

	local function resolveHitPart(char)
		if S.HitPart == "Head" then
			return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		elseif S.HitPart == "Torso" then
			return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
		elseif S.HitPart == "Random" then
			local pool = {}
			for _, n in ipairs(AIM_PARTS) do
				local p = char:FindFirstChild(n)
				if p then
					table.insert(pool, p)
				end
			end
			if #pool == 0 then
				return char:FindFirstChild("HumanoidRootPart")
			end
			return pool[math.random(1, #pool)]
		else
			local best, bestD = nil, math.huge
			for _, n in ipairs(AIM_PARTS) do
				local p = char:FindFirstChild(n)
				if p then
					local d = screenDist(p)
					if d < bestD then
						bestD = d
						best = p
					end
				end
			end
			return best or char:FindFirstChild("Head")
		end
	end

	local function isEnemyPlayer(plr)
		if plr == LP then
			return false
		end
		local char = plr.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if not char or not hum or hum.Health <= 0 then
			return false
		end
		if S.Team and plr.Team and LP.Team and plr.Team == LP.Team then
			return false
		end
		return true
	end

	local function collectTargets()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemyPlayer(plr) and plr.Character then
				table.insert(list, { char = plr.Character, plr = plr })
			end
		end
		if S.AimBots then
			if tick() - botScanAt > 1.5 then
				botScanAt = tick()
				refreshBots()
			end
			for _, model in ipairs(botList) do
				if model.Parent then
					table.insert(list, { char = model, plr = nil })
				end
			end
		end
		return list
	end

	local function getBestTarget()
		local best, bestScore = nil, math.huge
		local fov = math.max(S.FOV, 1)

		for _, entry in ipairs(collectTargets()) do
			local char = entry.char
			if not char or not char.Parent then
				continue
			end
			local part = resolveHitPart(char)
			if not part then
				continue
			end

			local dist2d = screenDist(part)
			if dist2d > fov then
				continue
			end
			if not isVisible(part, char) then
				continue
			end

			local dist3d = (Cam.CFrame.Position - part.Position).Magnitude
			if dist3d > S.MaxDist then
				continue
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

			if score < bestScore then
				bestScore = score
				best = { part = part, char = char, plr = entry.plr }
			end
		end
		return best
	end

	local function aimCamera(targetPos)
		if silentPhase > 0 then
			return
		end
		local goal = CFrame.new(Cam.CFrame.Position, targetPos)
		local alpha = math.clamp((1 - S.Smooth) * 0.22, 0.012, 0.45)
		if S.AimCurve then
			local j = (math.noise(tick() * 2.5, jitterSeed) - 0.5) * 0.35
			alpha = math.clamp(alpha * (1 + j * S.Smooth), 0.008, 0.5)
		end
		Cam.CFrame = Cam.CFrame:Lerp(goal, alpha)
	end

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

	local function isHostileModel(model)
		if not model then
			return false
		end
		local hum = model:FindFirstChild("Humanoid")
		if not hum or hum.Health <= 0 then
			return false
		end
		local plr = Players:GetPlayerFromCharacter(model)
		if plr then
			if plr == LP then
				return false
			end
			if S.Team and plr.Team and LP.Team and plr.Team == LP.Team then
				return false
			end
			return true
		end
		return S.AimBots and isBotModel(model)
	end

	local function rayHostile()
		local center = Cam.ViewportSize / 2
		local ray = Cam:ViewportPointToRay(center.X, center.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not isHostileModel(model) then
			return nil
		end
		if S.VisibleCheck and not isVisible(hit.Instance, model) then
			return nil
		end
		return model
	end

	local function fireClick()
		local center = Cam.ViewportSize / 2
		VIM:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
		task.defer(function()
			VIM:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
		end)
	end

	UIS.InputBegan:Connect(function(input, processed)
		local key = getTriggerKey()
		if S.TriggerMode == "Toggle" and key and input.KeyCode == key and not processed then
			triggerToggled = not triggerToggled
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not S.Silent then
			return
		end

		local tgt = getBestTarget()
		if not tgt then
			return
		end

		silentRestore = Cam.CFrame
		Cam.CFrame = CFrame.new(silentRestore.Position, tgt.part.Position)
		silentPhase = 1
	end)

	RS.RenderStepped:Connect(function()
		updFOV()
		updStatus()

		if silentPhase == 1 then
			silentPhase = 2
		elseif silentPhase == 2 and silentRestore then
			Cam.CFrame = silentRestore
			silentRestore = nil
			silentPhase = 0
		end

		if S.Aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and silentPhase == 0 then
			local tgt = getBestTarget()
			if tgt then
				aimCamera(tgt.part.Position)
			end
		end
	end)

	RS.Heartbeat:Connect(function()
		if not triggerArmed() then
			return
		end
		local delaySec = math.max(S.TriggerDelay or 0, 1) / 1000
		if tick() - lastTrigger < delaySec then
			return
		end
		if rayHostile() then
			lastTrigger = tick()
			fireClick()
		end
	end)
end

return Aim
