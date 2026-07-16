-- Invisibility.lua  v2.45.0
-- R6 animation desync (EQR/kogo style) + "You are visible" when airborne.

local Invisibility = {}

function Invisibility.Init(S, ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local StarterGui = game:GetService("StarterGui")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local ANIM_ID = "rbxassetid://215384594"
	local active = false
	local usable = true
	local track = nil
	local lastToggle = 0
	local char, hum, hrp = nil, nil, nil

	local Animation = Instance.new("Animation")
	Animation.AnimationId = ANIM_ID

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local WarnGui = C("ScreenGui", {
		Name = "VanguardInvisWarn",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = ParentGUI,
	})
	local WarnLabel = C("TextLabel", {
		Name = "Warn",
		Size = UDim2.new(0, 220, 0, 28),
		Position = UDim2.new(0.5, -110, 0.86, 0),
		BackgroundTransparency = 1,
		Text = "YOU ARE VISIBLE",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 220, 40),
		TextStrokeTransparency = 0.45,
		Visible = false,
		ZIndex = 80,
		Parent = WarnGui,
	})

	local function notify(title, text)
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title,
				Text = text,
				Duration = 4,
			})
		end)
		if typeof(S.Notify) == "function" then
			pcall(S.Notify, title, text)
		end
	end

	local function refreshRefs()
		char = LP.Character
		if char then
			hrp = char:FindFirstChild("HumanoidRootPart")
			hum = char:FindFirstChildOfClass("Humanoid")
		else
			hrp, hum = nil, nil
		end
	end

	local function isR6()
		return char and char:FindFirstChild("Torso") ~= nil
			and hum
			and hum.RigType == Enum.HumanoidRigType.R6
	end

	local function grounded()
		return hum and hum:IsDescendantOf(workspace) and hum.FloorMaterial ~= Enum.Material.Air
	end

	local function resetTransparency()
		if not char then
			return
		end
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") and v.Transparency == 0.5 then
				v.Transparency = 0
			end
		end
	end

	local function applyLocalGhost()
		if not char then
			return
		end
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") and v.Transparency ~= 1 then
				v.Transparency = 0.5
			end
		end
	end

	local function stopTrack()
		if track then
			pcall(function()
				track:Stop()
			end)
		end
	end

	local function loadTrack()
		stopTrack()
		track = nil
		if not hum then
			return
		end
		local ok, result = pcall(function()
			return hum:LoadAnimation(Animation)
		end)
		if ok and result then
			track = result
			track.Priority = Enum.AnimationPriority.Action4
		end
	end

	local function disable()
		if not active then
			WarnLabel.Visible = false
			return
		end
		active = false
		S.Invisibility = false
		stopTrack()
		if hum then
			pcall(function()
				Cam.CameraSubject = hum
			end)
		end
		resetTransparency()
		WarnLabel.Visible = false
	end

	local function enable()
		refreshRefs()
		if not char or not hum or not hrp then
			return false
		end
		if not isR6() then
			usable = false
			notify("Invisibility", "Wymaga avatara R6 (Torso).")
			return false
		end
		usable = true
		active = true
		S.Invisibility = true
		Cam.CameraSubject = hrp
		loadTrack()
		return true
	end

	local function setEnabled(on)
		if on then
			if not enable() then
				S.Invisibility = false
			end
		else
			disable()
		end
	end

	local function getInvisKey()
		local name = S.InvisKey
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

	refreshRefs()
	if char and hum and not isR6() then
		usable = false
	end

	LP.CharacterAdded:Connect(function()
		stopTrack()
		track = nil
		task.wait()
		refreshRefs()
		if not hum then
			task.wait(0.4)
			refreshRefs()
		end
		if not hum then
			usable = false
			disable()
			return
		end
		if hum.RigType ~= Enum.HumanoidRigType.R6 then
			usable = false
			if active or S.Invisibility then
				disable()
				notify("Invisibility", "R15 wykryty — wyłączone.")
			end
			return
		end
		usable = true
		if S.Invisibility then
			enable()
		end
	end)

	LP.CharacterRemoving:Connect(function()
		stopTrack()
		track = nil
		WarnLabel.Visible = false
	end)

	UIS.InputBegan:Connect(function(input, processed)
		if processed or S.MenuOpen or S.Unloaded then
			return
		end
		local key = getInvisKey()
		if not key or input.KeyCode ~= key then
			return
		end
		if tick() - lastToggle < 0.25 then
			return
		end
		lastToggle = tick()
		setEnabled(not active)
	end)

	if typeof(S._configApplyHooks) == "table" then
		table.insert(S._configApplyHooks, function()
			if S.Invisibility then
				if not active then
					setEnabled(true)
				end
			elseif active then
				disable()
			end
		end)
	end

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn)
		return fn
	end

	RS.Heartbeat:Connect(perfWrap("Invis.Main", function(dt)
		if S.Unloaded then
			if active then
				disable()
			end
			return
		end

		-- Toggle from UI / config without key
		if S.Invisibility and not active then
			if not enable() then
				S.Invisibility = false
				return
			end
		elseif not S.Invisibility and active then
			disable()
			return
		end

		if not active or not usable then
			WarnLabel.Visible = false
			return
		end

		refreshRefs()
		if not char or not hum or not hrp or not hum:IsDescendantOf(workspace) or hum.Health <= 0 then
			WarnLabel.Visible = false
			return
		end

		local showWarn = S.InvisShowWarning ~= false and not grounded()
		WarnLabel.Visible = showWarn

		local speed = math.clamp(tonumber(S.InvisWalkSpeed) or 12, 6, 28)
		if hum.MoveDirection.Magnitude > 0 then
			hrp.CFrame = hrp.CFrame + hum.MoveDirection * speed * dt
		end

		local oldCF = hrp.CFrame
		local oldCamOff = hum.CameraOffset

		local _, yaw = Cam.CFrame:ToOrientation()
		hrp.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.fromOrientation(0, yaw, 0)
		hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
		hum.CameraOffset = Vector3.new(0, 1.44, 0)

		if track then
			local okPlay = pcall(function()
				if not track.IsPlaying then
					track:Play()
				end
				track:AdjustSpeed(0)
				track.TimePosition = 0.3
			end)
			if not okPlay then
				loadTrack()
			end
		elseif hum.Health > 0 then
			loadTrack()
		end

		RS.RenderStepped:Wait()

		if hum and hum:IsDescendantOf(workspace) then
			hum.CameraOffset = oldCamOff
		end
		if hrp and hrp:IsDescendantOf(workspace) then
			hrp.CFrame = oldCF
		end

		stopTrack()

		if hrp and hrp:IsDescendantOf(workspace) then
			local look = Cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.1 then
				flat = flat.Unit
				hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
			end
		end

		applyLocalGhost()
	end))

	S.SetInvisibility = setEnabled
	S.IsInvisibilityActive = function()
		return active
	end
end

return Invisibility
