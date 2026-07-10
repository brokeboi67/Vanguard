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
	local triggerNextShotAt = 0
	local triggerFiring = false
	local triggerLock = nil
	local triggerLockUntil = 0
	local lastTogglePress = 0
	local triggerToggled = false
	local botList = {}
	local botScanAt = 0
	local shotBusy = false
	local silentRestoreCF = nil
	local silentRestoreAt = 0
	local silentSnapTarget = nil

	local AIM_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }
	local fovLimit = function()
		return math.max(S.FOV or 80, 1)
	end

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

	local MOUSE_BINDS = {
		MouseButton1 = Enum.UserInputType.MouseButton1,
		MouseButton2 = Enum.UserInputType.MouseButton2,
		MouseButton3 = Enum.UserInputType.MouseButton3,
	}

	local function resolveMouseBind(name)
		return MOUSE_BINDS[name]
	end

	local function resolveKeyBind(name)
		if not name or name == "" or name == "None" then
			return nil
		end
		local ok, key = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok then
			return key
		end
		return nil
	end

	local function getAimBindName()
		return S.AimKey or "MouseButton2"
	end

	local function getSilentBindName()
		return S.SilentKey or "MouseButton1"
	end

	local function inputMatchesBind(input, bindName)
		if not bindName or bindName == "" or bindName == "None" then
			return false
		end
		local mouse = resolveMouseBind(bindName)
		if mouse then
			return input.UserInputType == mouse
		end
		local key = resolveKeyBind(bindName)
		if key then
			return input.KeyCode == key
		end
		return false
	end

	local function isBindDown(bindName)
		if not bindName or bindName == "" or bindName == "None" then
			return false
		end
		local mouse = resolveMouseBind(bindName)
		if mouse then
			return UIS:IsMouseButtonPressed(mouse)
		end
		local key = resolveKeyBind(bindName)
		if key then
			return UIS:IsKeyDown(key)
		end
		return false
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

	local function screenDist(part, char)
		local pos3 = Util.getFirePosition(char, part) or Util.getPartPosition(part)
		if not pos3 then
			return math.huge
		end
		local pos, onScreen = Cam:WorldToViewportPoint(pos3)
		if not onScreen then
			return math.huge
		end
		local center = Cam.ViewportSize / 2
		local d = (Vector2.new(pos.X, pos.Y) - Vector2.new(center.X, center.Y)).Magnitude
		if part and part:IsA("BasePart") and string.sub(part.Name, 1, 8) == "VG_HBX_" then
			local right = Cam.CFrame.RightVector * (part.Size.X * 0.5)
			local edgePos = Cam:WorldToViewportPoint(part.Position + right)
			local screenRadius = (Vector2.new(edgePos.X, edgePos.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
			d = math.max(0, d - screenRadius * 0.9)
		end
		return d
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
					local d = screenDist(p, char)
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
		if not Util.isValidTarget(char, plr) then
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

	local function isVisible(part, char)
		if not S.VisibleCheck then
			return true
		end
		local partPos = Util.getFirePosition(char, part)
		if not partPos then
			return false
		end
		return Util.rayHasLOS(Cam.CFrame.Position, partPos, char, LP.Character)
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
				if Util.isValidTarget(model, nil) then
					table.insert(list, { char = model, plr = nil })
				end
			end
		end
		return list
	end

	local function scoreTarget(entry, maxFov)
		local char = entry.char
		if not Util.isValidTarget(char, entry.plr) then
			return nil
		end
		local part = resolveHitPart(char)
		if not part then
			return nil
		end

		local dist2d = screenDist(part, char)
		if dist2d > maxFov then
			return nil
		end
		if not isVisible(part, char) then
			return nil
		end

		local partPos = Util.getFirePosition(char, part)
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

	local function pickBestTarget(maxFov)
		local best, bestScore = nil, math.huge
		for _, entry in ipairs(collectTargets()) do
			local cand = scoreTarget(entry, maxFov)
			if cand and cand.score < bestScore then
				bestScore = cand.score
				best = cand
			end
		end
		return best
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

	local function finishTriggerShot()
		triggerNextShotAt = tick() + math.max(S.TriggerDelay or 1, 1) / 1000
		triggerFiring = false
	end

	local function clearTriggerLock()
		triggerLock = nil
		triggerLockUntil = 0
	end

	local function validateTriggerTargetStrict(tgt)
		if not tgt or not tgt.char then
			return nil
		end
		return scoreTarget({ char = tgt.char, plr = tgt.plr }, fovLimit())
	end

	local function validateTriggerLockSoft(tgt)
		if not tgt or not tgt.char then
			return nil
		end
		if not Util.isValidTarget(tgt.char, tgt.plr) then
			return nil
		end
		local part = resolveHitPart(tgt.char)
		if not part then
			return nil
		end
		if screenDist(part, tgt.char) > fovLimit() then
			return nil
		end
		local partPos = Util.getFirePosition(tgt.char, part)
		if not partPos then
			return nil
		end
		if (Cam.CFrame.Position - partPos).Magnitude > S.MaxDist then
			return nil
		end
		return { char = tgt.char, plr = tgt.plr, part = part }
	end

	local function acquireTriggerTarget()
		if triggerLock and tick() < triggerLockUntil then
			local locked
			if S.TriggerCompat then
				locked = validateTriggerLockSoft(triggerLock)
			else
				locked = validateTriggerTargetStrict(triggerLock)
			end
			if locked then
				triggerLock = locked
				return locked
			end
			clearTriggerLock()
		end

		local fresh = pickBestTarget(fovLimit())
		if fresh then
			triggerLock = fresh
			triggerLockUntil = tick() + (S.TriggerCompat and 0.5 or 0.35)
		end
		return fresh
	end

	local function getCompatTrackTarget()
		if triggerLock and tick() < triggerLockUntil then
			local soft = validateTriggerLockSoft(triggerLock)
			if soft then
				return soft
			end
		end
		return pickBestTarget(fovLimit())
	end

	local function updateTriggerCompatAim()
		if not S.TriggerCompat or not triggerArmed() or triggerFiring then
			return
		end
		local tgt = getCompatTrackTarget()
		if not tgt or not tgt.part or not tgt.char then
			return
		end
		local pos = Util.getFirePosition(tgt.char, tgt.part)
		if pos then
			aimCamera(pos)
		end
	end

	local function captureShotRay(aimPos)
		local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		S.LastShotRayOrigin = ray.Origin
		S.LastShotRayDir = ray.Direction
		if aimPos then
			S.LastShotPos = aimPos
		end
	end

	local function markShot(char, aimPos)
		S.LastShotAt = tick()
		captureShotRay(aimPos)
		if char then
			S.LastShotChar = char
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				S.LastShotHum = hum
			end
			if not aimPos then
				local head = char:FindFirstChild("Head")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local part = head or hrp
				if part then
					S.LastShotPos = part.Position
				end
			end
			if S.NotifyShot then
				pcall(S.NotifyShot, char)
			end
		end
	end

	local function snapSilentCamera(tgt)
		if not tgt or not tgt.part or not tgt.char then
			return false
		end
		local pos = Util.getFirePosition(tgt.char, tgt.part)
		if not pos then
			return false
		end
		silentRestoreCF = Cam.CFrame
		silentRestoreAt = tick()
		silentSnapTarget = tgt
		Cam.CFrame = CFrame.new(Cam.CFrame.Position, pos)
		return true
	end

	local function restoreSilentCamera()
		if silentRestoreCF then
			Cam.CFrame = silentRestoreCF
			silentRestoreCF = nil
			silentSnapTarget = nil
		end
	end

	local function runSilentShot(tgt)
		if shotBusy or not tgt or not tgt.part or not tgt.char then
			return false
		end
		if not Util.isValidTarget(tgt.char, tgt.plr) then
			return false
		end
		local pos = Util.getFirePosition(tgt.char, tgt.part)
		if not pos then
			return false
		end
		shotBusy = true
		task.spawn(function()
			markShot(tgt.char, pos)
			pcall(function()
				Util.performSilentShot(RS, Cam, VIM, pos, 2, UIS, LP)
			end)
			shotBusy = false
		end)
		return true
	end

	local function runTriggerShot(tgt)
		if not tgt or not tgt.part or not tgt.char then
			finishTriggerShot()
			return
		end
		if not Util.isValidTarget(tgt.char, tgt.plr) then
			clearTriggerLock()
			finishTriggerShot()
			return
		end

		task.spawn(function()
			local char = tgt.char
			local plr = tgt.plr
			local strict = scoreTarget({ char = char, plr = plr }, fovLimit())
			if not strict then
				clearTriggerLock()
				finishTriggerShot()
				return
			end
			local part = strict.part
			if not part or not Util.isValidTarget(char, plr) then
				clearTriggerLock()
				finishTriggerShot()
				return
			end

			local pos = Util.getFirePosition(char, part)
			if not pos then
				clearTriggerLock()
				finishTriggerShot()
				return
			end

			if S.TriggerCompat then
				markShot(char, pos)
				pcall(function()
					Util.performCompatTriggerShot(RS, Cam, VIM, pos, 1, UIS, LP)
				end)
			else
				markShot(char, pos)
				Util.fireTriggerClick(LP, VIM, Cam, UIS)
			end
			finishTriggerShot()
		end)
	end

	local function tryTriggerShot()
		if S.MenuOpen or S.MasterRage then
			return
		end
		if not triggerArmed() then
			return
		end
		if triggerFiring or tick() < triggerNextShotAt then
			return
		end

		local tgt = acquireTriggerTarget()
		if not tgt or not tgt.part or not tgt.char then
			return
		end

		local strict = validateTriggerTargetStrict(tgt)
		if not strict then
			return
		end

		triggerFiring = true
		runTriggerShot(strict)
	end

	local function bindSilentAction()
		pcall(function()
			CAS:UnbindAction("VanguardSilent")
		end)
		if not S.Silent then
			return
		end
		local bindName = getSilentBindName()
		local mouse = resolveMouseBind(bindName)
		if not mouse then
			return
		end
		CAS:BindActionAtPriority("VanguardSilent", function(_, state, input)
			if S.MenuOpen or S.MasterRage or not S.Silent then
				return Enum.ContextActionResult.Pass
			end
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if input.UserInputType ~= mouse then
				return Enum.ContextActionResult.Pass
			end
			pcall(function()
				local tgt = pickBestTarget(fovLimit())
				if tgt and snapSilentCamera(tgt) then
					local pos = Util.getFirePosition(tgt.char, tgt.part)
					markShot(tgt.char, pos)
				end
			end)
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.High.Value, mouse)
	end

	pcall(function()
		CAS:UnbindAction("VanguardSilent")
	end)
	bindSilentAction()

	UIS.InputBegan:Connect(function(input, processed)
		if processed or S.MenuOpen or S.MasterRage or not S.Silent then
			return
		end
		local bindName = getSilentBindName()
		if resolveMouseBind(bindName) then
			return
		end
		if not inputMatchesBind(input, bindName) then
			return
		end
		local tgt = pickBestTarget(fovLimit())
		if tgt then
			runSilentShot(tgt)
		end
	end)

	S.RebindSilent = bindSilentAction

	UIS.InputBegan:Connect(function(input)
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

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.RenderStepped:Connect(perfWrap("Aim.Main", function()
		updFOV()
		updTriggerHud()

		if silentRestoreCF and tick() - silentRestoreAt >= 0.035 then
			restoreSilentCamera()
		end

		if not S.Trigger then
			triggerToggled = false
			triggerFiring = false
			triggerNextShotAt = 0
			clearTriggerLock()
		end

		if S.MenuOpen or S.MasterRage then
			return
		end

		updateTriggerCompatAim()
		pcall(tryTriggerShot)

		if S.Aimbot and not S.Silent and isBindDown(getAimBindName()) then
			pcall(function()
				local tgt = pickBestTarget(fovLimit())
				if tgt and tgt.part and tgt.char then
					local pos = Util.getFirePosition(tgt.char, tgt.part)
					if pos then
						aimCamera(pos)
					end
				end
			end)
		end
	end))

	S.GetAimTarget = function()
		if S.MasterRage and S.RageBot and S.GetRageTarget then
			return S.GetRageTarget()
		end
		if S.Aimbot or S.Silent or S.Trigger or S.TargetInfo then
			return pickBestTarget(fovLimit())
		end
		return nil
	end
end

return Aim
