-- Plik: workspace/Vanguard/Rage.lua

local Rage = {}

function Rage.Init(S, ParentGUI, TF, Util)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local VIM = game:GetService("VirtualInputManager")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local lastRageShot = 0
	local lastRageToggle = 0
	local rageToggled = false
	local rageLock = nil
	local rageLockUntil = 0
	local botList = {}
	local botScanAt = 0
	local savedAutoRotate = true
	local aaActive = false
	local rageShootingUntil = 0

	local AIM_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local function isPartVisibleFromCamera(part, char)
		if not part or not char then
			return false
		end
		if not S.RageVisibleCheck then
			return true
		end
		local partPos = Util.getPartPosition(part)
		if not partPos then
			return false
		end
		local origin = Cam.CFrame.Position
		local dir = partPos - origin
		local dist = dir.Magnitude
		if dist < 0.05 then
			return true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then
			return true
		end
		if hit.Instance == part or hit.Instance:IsDescendantOf(char) then
			return true
		end
		return false
	end

	local RageHud = C("Frame", {
		Name = "RageHud",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(1, -22, 0.52, 0),
		BackgroundColor3 = S.O,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = RageHud })
	C("UIStroke", {
		Name = "DotStroke",
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.35,
		Parent = RageHud,
	})

	local RageHudFull = C("TextLabel", {
		Name = "RageHudFull",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 120, 0, 22),
		Position = UDim2.new(1, -20, 0.52, 0),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.35,
		Text = "RAGE",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 140),
		Visible = false,
		ZIndex = 50,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = RageHudFull })
	C("UIStroke", { Color = Color3.fromRGB(40, 40, 48), Thickness = 1, Transparency = 0.5, Parent = RageHudFull })

	local function getRageKey()
		if not S.RageKey or S.RageKey == "" or S.RageKey == "None" then
			return nil
		end
		local ok, key = pcall(function()
			return Enum.KeyCode[S.RageKey]
		end)
		if ok then
			return key
		end
		return nil
	end

	local function rageArmed()
		if not S.MasterRage or not S.RageBot then
			return false
		end
		if S.RageMode == "Toggle" then
			return rageToggled
		end
		local key = getRageKey()
		if not key then
			return true
		end
		return UIS:IsKeyDown(key)
	end

	local function isMinimalHud()
		return S.RageHudMinimal ~= false
	end

	local function updRageHud()
		if not S.ShowRageHud or not S.MasterRage or not S.RageBot then
			RageHud.Visible = false
			RageHudFull.Visible = false
			return
		end

		local active = rageArmed()
		local label = "IDLE"
		if S.RageMode == "Toggle" then
			label = rageToggled and "ON" or "OFF"
		else
			label = active and "HOLD" or "IDLE"
		end

		if isMinimalHud() then
			RageHudFull.Visible = false
			RageHud.Visible = true
			local dotStroke = RageHud:FindFirstChild("DotStroke")
			if active then
				RageHud.Size = UDim2.new(0, 14, 0, 14)
				RageHud.BackgroundColor3 = S.O
				RageHud.BackgroundTransparency = 0
				if dotStroke then
					dotStroke.Transparency = 0.15
				end
			else
				RageHud.Size = UDim2.new(0, 9, 0, 9)
				RageHud.BackgroundColor3 = Color3.fromRGB(160, 160, 170)
				RageHud.BackgroundTransparency = 0.35
				if dotStroke then
					dotStroke.Transparency = 0.55
				end
			end
		else
			RageHud.Visible = false
			RageHudFull.Visible = true
			RageHudFull.Text = "RAGE · " .. label
			if active then
				RageHudFull.TextColor3 = S.O
				RageHudFull.BackgroundTransparency = 0.2
			else
				RageHudFull.TextColor3 = Color3.fromRGB(170, 170, 180)
				RageHudFull.BackgroundTransparency = 0.35
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
		return Util.isAimableCharacter(model)
	end

	local function refreshBots()
		if not S.RageBots then
			table.clear(botList)
			return
		end
		if tick() - botScanAt > 1.5 then
			botScanAt = tick()
			Util.refreshBotList(botList, true, LP)
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

	local function collectTargets()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemyPlayer(plr) and plr.Character then
				table.insert(list, { char = plr.Character, plr = plr })
			end
		end
		if S.RageBots then
			refreshBots()
			for _, model in ipairs(botList) do
				if model.Parent and isAliveChar(model) then
					table.insert(list, { char = model, plr = nil })
				end
			end
		end
		return list
	end

	local function worldDist(part)
		if not part then
			return math.huge
		end
		local partPos = Util.getPartPosition(part)
		if not partPos then
			return math.huge
		end
		return (Cam.CFrame.Position - partPos).Magnitude
	end

	local function getRageAimPart(char)
		if S.RageHitPart == "Head" then
			local head = Util.resolveAimPart(char, "Head")
			if head and isPartVisibleFromCamera(head, char) then
				return head
			end
			for _, name in ipairs(AIM_PARTS) do
				local p = Util.resolveAimPart(char, name)
				if p and isPartVisibleFromCamera(p, char) then
					return p
				end
			end
			return nil
		elseif S.RageHitPart == "Torso" then
			for _, name in ipairs({ "UpperTorso", "Torso", "HumanoidRootPart" }) do
				local p = Util.resolveAimPart(char, name)
				if isPartVisibleFromCamera(p, char) then
					return p
				end
			end
			return nil
		elseif S.RageHitPart == "Random" then
			local pool = {}
			for _, n in ipairs(AIM_PARTS) do
				local p = Util.resolveAimPart(char, n)
				if p and isPartVisibleFromCamera(p, char) then
					table.insert(pool, p)
				end
			end
			if #pool == 0 then
				return nil
			end
			return pool[math.random(1, #pool)]
		else
			local best, bestD = nil, math.huge
			for _, n in ipairs(AIM_PARTS) do
				local p = Util.resolveAimPart(char, n)
				if p and isPartVisibleFromCamera(p, char) then
					local d = worldDist(p)
					if d < bestD then
						bestD = d
						best = p
					end
				end
			end
			return best
		end
	end

	local function scoreRageTarget(entry)
		local char = entry.char
		if not isAliveChar(char) then
			return nil
		end

		local part = getRageAimPart(char)
		if not part then
			return nil
		end

		local dist3d = worldDist(part)
		if dist3d > (S.RageMaxDist or S.MaxDist) then
			return nil
		end

		return { part = part, char = char, plr = entry.plr, score = dist3d }
	end

	local function getBestRageTarget()
		local best, bestScore = nil, math.huge
		for _, entry in ipairs(collectTargets()) do
			local cand = scoreRageTarget(entry)
			if cand and cand.score < bestScore then
				bestScore = cand.score
				best = cand
			end
		end
		return best
	end

	local function getCrosshairRageTarget()
		if S.RageCrosshair == false then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		local maxDist = S.RageMaxDist or S.MaxDist or 500
		local hit = workspace:Raycast(ray.Origin, ray.Direction * maxDist, params)
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
		elseif not S.RageBots then
			return nil
		end
		local part = hit.Instance:IsA("BasePart") and hit.Instance or Util.resolveAimPart(model, "Head") or Util.resolveAimPart(model, "HumanoidRootPart")
		if not part then
			return nil
		end
		local dist3d = worldDist(part)
		if dist3d > maxDist then
			return nil
		end
		return { part = part, char = model, plr = plr, score = dist3d }
	end

	local function getStableRageTarget()
		if rageLock and tick() < rageLockUntil then
			local char = rageLock.char
			if char and isAliveChar(char) then
				local part = getRageAimPart(char) or rageLock.part
				if part and part.Parent and part:IsDescendantOf(char) then
					local visible = not S.RageVisibleCheck or isPartVisibleFromCamera(part, char)
					if visible then
						local dist3d = worldDist(part)
						if dist3d <= (S.RageMaxDist or S.MaxDist) then
							rageLock.part = part
							rageLock.score = dist3d
							return rageLock
						end
					end
				end
			end
		end
		rageLock = getBestRageTarget()
		if not rageLock then
			rageLock = getCrosshairRageTarget()
		end
		rageLockUntil = tick() + 0.45
		return rageLock
	end

	local function rotateCharacterTo(targetPos)
		local char = LP.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local pos = hrp.Position
		hrp.CFrame = CFrame.new(pos, Vector3.new(targetPos.X, pos.Y, targetPos.Z))
	end

	local function fireClick()
		local loc = UIS:GetMouseLocation()
		VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
		task.defer(function()
			VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
		end)
	end

	local function tryRageShot()
		if S.MenuOpen or not rageArmed() then
			return
		end

		local baseDelay = math.max(S.RageDelay or 1, 1) / 1000
		local jitter = baseDelay * (math.random() * 0.15 - 0.075)
		if tick() - lastRageShot < baseDelay + jitter then
			return
		end

		local tgt = getStableRageTarget()
		if not tgt or not tgt.part then
			rageLock = nil
			return
		end

		local part = tgt.part
		local char = tgt.char
		local lead = Util.getNetworkLead((S.RageDelay or 80) / 1000 + 0.06)
		local function getTarget()
			return Util.predictAimPoint(part, char, lead)
		end
		local targetPos = getTarget()
		if not targetPos then
			return
		end

		lastRageShot = tick()
		S.LastShotAt = tick()
		if char then
			S.LastShotHum = char:FindFirstChildOfClass("Humanoid")
		end

		rageShootingUntil = tick() + 0.14
		if S.RageSilent ~= false then
			Util.performSilentShot(RS, Cam, VIM, targetPos, 2, {
				getTarget = getTarget,
				noRestore = true,
			})
		else
			Util.fireAtWorld(VIM, Cam, targetPos)
		end
	end

	local function restoreAntiAim()
		if not aaActive then
			return
		end
		aaActive = false
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = savedAutoRotate
		end
	end

	local function applyAntiAim()
		if not S.MasterRage or not S.AntiAim then
			restoreAntiAim()
			return
		end

		if tick() < rageShootingUntil then
			return
		end

		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or not isAliveHumanoid(hum) then
			restoreAntiAim()
			return
		end

		if not aaActive then
			savedAutoRotate = hum.AutoRotate
			aaActive = true
		end
		hum.AutoRotate = false

		local spin = 0
		if S.AASpin then
			spin = tick() * math.rad(S.AASpinSpeed * 45)
		end

		local yaw = math.rad(S.AAYaw or 0)
		if S.AAJitter then
			yaw = yaw + math.rad((math.random() * 2 - 1) * (S.AAJitterRange or 45))
		end

		local pitch = math.rad(S.AAPitch or 0)
		local lookAway = -Cam.CFrame.LookVector
		local baseCF = CFrame.new(hrp.Position, hrp.Position + lookAway)
		hrp.CFrame = baseCF * CFrame.Angles(pitch, yaw + spin, 0)
	end

	UIS.InputBegan:Connect(function(input)
		if S.MenuOpen then
			return
		end
		local key = getRageKey()
		if S.MasterRage and S.RageBot and S.RageMode == "Toggle" and key and input.KeyCode == key then
			if tick() - lastRageToggle < 0.2 then
				return
			end
			lastRageToggle = tick()
			rageToggled = not rageToggled
		end
	end)

	RS.RenderStepped:Connect(function()
		updRageHud()

		if not S.MasterRage or not S.RageBot then
			rageToggled = false
		end

		if S.MasterRage then
			applyAntiAim()
		else
			restoreAntiAim()
		end

		if S.MenuOpen then
			return
		end
		pcall(tryRageShot)
	end)

	LP.CharacterAdded:Connect(function()
		aaActive = false
	end)
end

return Rage
