-- Invisibility.lua
-- R6 anim-desync. Master toggle arms the feature; keybind toggles visibility.
-- Turning Invisibility OFF disables everything.
-- Desync: Heartbeat applies pose, RenderStepped restores (no Wait — no hitch).
-- InvisResolver: upright others only on tilted network frames (don't freeze CFrame).

local Invisibility = {}

function Invisibility.Init(S, ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local StarterGui = game:GetService("StarterGui")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local ANIM_ID = "rbxassetid://215384594"
	local active = false -- currently desynced / "invisible"
	local usable = true
	local track = nil
	local lastToggle = 0
	local char, hum, hrp = nil, nil, nil
	local savedTrans = {}
	local ghostApplied = false

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
		for part, t in pairs(savedTrans) do
			if part and part.Parent then
				pcall(function()
					part.Transparency = t
				end)
			end
			savedTrans[part] = nil
		end
		table.clear(savedTrans)
		if char then
			for _, v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
					if v.Transparency == 0.5 then
						v.Transparency = 0
					end
				end
			end
		end
	end

	local function applyLocalGhost()
		if not char or not active then
			return
		end
		if ghostApplied then
			return
		end
		local allSet = true
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and v.Transparency ~= 1 then
				if savedTrans[v] == nil then
					savedTrans[v] = v.Transparency
					allSet = false
				end
				if v.Transparency ~= 0.5 then
					v.Transparency = 0.5
					allSet = false
				end
			end
		end
		ghostApplied = allSet
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

	-- Stop desync / ghost, but keep master feature flag alone.
	local function stopActive()
		active = false
		ghostApplied = false
		stopTrack()
		if hum then
			pcall(function()
				Cam.CameraSubject = hum
			end)
		end
		resetTransparency()
		WarnLabel.Visible = false
	end

	local function startActive()
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
		Cam.CameraSubject = hrp
		loadTrack()
		return true
	end

	-- Master feature off: wipe everything.
	local function disableFeature()
		S.Invisibility = false
		stopActive()
	end

	-- Master feature on: arm keybind; do not auto-start invis.
	local function enableFeature()
		refreshRefs()
		if char and hum and not isR6() then
			usable = false
			S.Invisibility = false
			notify("Invisibility", "Wymaga avatara R6 (Torso).")
			return false
		end
		usable = true
		S.Invisibility = true
		return true
	end

	local function setFeature(on)
		if on then
			if not enableFeature() then
				stopActive()
			end
		else
			disableFeature()
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
		ghostApplied = false
		table.clear(savedTrans)
		task.wait()
		refreshRefs()
		if not hum then
			task.wait(0.4)
			refreshRefs()
		end
		if not hum then
			usable = false
			stopActive()
			return
		end
		if hum.RigType ~= Enum.HumanoidRigType.R6 then
			usable = false
			if active or S.Invisibility then
				disableFeature()
				notify("Invisibility", "R15 wykryty — wyłączone.")
			end
			return
		end
		usable = true
		-- Feature stays armed if still on; stay visible until keybind.
		if active then
			stopActive()
		end
		resetTransparency()
	end)

	LP.CharacterRemoving:Connect(function()
		stopTrack()
		track = nil
		ghostApplied = false
		resetTransparency()
		WarnLabel.Visible = false
		active = false
	end)

	LP.CharacterAdded:Connect(function(newChar)
		newChar.ChildAdded:Connect(function()
			if active then
				ghostApplied = false
			end
		end)
	end)
	if LP.Character then
		LP.Character.ChildAdded:Connect(function()
			if active then
				ghostApplied = false
			end
		end)
	end

	UIS.InputBegan:Connect(function(input, processed)
		if processed or S.MenuOpen or S.Unloaded then
			return
		end
		-- Keybind only works while master Invisibility is ON
		if not S.Invisibility then
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
		if active then
			stopActive()
			notify("Invisibility", "Visible")
		else
			if startActive() then
				notify("Invisibility", "Invisible")
			end
		end
	end)

	if typeof(S._configApplyHooks) == "table" then
		table.insert(S._configApplyHooks, function()
			if S.Invisibility then
				-- Feature on: keep current active state; don't force invis
				if not usable then
					enableFeature()
				end
			else
				disableFeature()
			end
		end)
	end

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn)
		return fn
	end

	-- Desync without Heartbeat:Wait(RenderStepped) — that yield hitch'd the frame
	-- and inflated PERF. Heartbeat applies weird pose; next RenderStepped restores.
	local pendingRestore = false
	local savedCF = nil
	local savedCamOff = nil

	local function clearPendingRestore()
		if pendingRestore and hum and hrp then
			pcall(function()
				if typeof(savedCamOff) == "Vector3" then
					hum.CameraOffset = savedCamOff
				end
				if typeof(savedCF) == "CFrame" then
					hrp.CFrame = savedCF
				end
			end)
		end
		pendingRestore = false
		savedCF = nil
		savedCamOff = nil
	end

	local oldStopActive = stopActive
	stopActive = function()
		clearPendingRestore()
		oldStopActive()
	end

	RS.Heartbeat:Connect(perfWrap("Invis.Main", function(dt)
		if S.Unloaded then
			if active or S.Invisibility then
				disableFeature()
			end
			return
		end

		if not S.Invisibility then
			if active then
				stopActive()
			end
			WarnLabel.Visible = false
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

		savedCF = hrp.CFrame
		savedCamOff = hum.CameraOffset

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

		pendingRestore = true
	end))

	RS.RenderStepped:Connect(perfWrap("Invis.Restore", function()
		if not pendingRestore then
			return
		end
		pendingRestore = false

		local stillOn = active and S.Invisibility and not S.Unloaded
		if not stillOn then
			if hum and hum:IsDescendantOf(workspace) and typeof(savedCamOff) == "Vector3" then
				hum.CameraOffset = savedCamOff
			end
			if hrp and hrp:IsDescendantOf(workspace) and typeof(savedCF) == "CFrame" then
				hrp.CFrame = savedCF
			end
			stopTrack()
			resetTransparency()
			savedCF = nil
			savedCamOff = nil
			return
		end

		refreshRefs()
		if hum and hum:IsDescendantOf(workspace) and typeof(savedCamOff) == "Vector3" then
			hum.CameraOffset = savedCamOff
		end
		if hrp and hrp:IsDescendantOf(workspace) and typeof(savedCF) == "CFrame" then
			hrp.CFrame = savedCF
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
		savedCF = nil
		savedCamOff = nil
	end))

	-- UI toggle still uses SetInvisibility for master feature
	S.SetInvisibility = setFeature
	S.IsInvisibilityActive = function()
		return active == true
	end

	-- ── Invis Resolver (others using same R6 desync / ~90° tilt) ─────────────
	-- Network packets arrive tilted every ~50–100ms. Snapping upright to raw
	-- Position each packet looks like teleporting. Instead: capture net pose only
	-- while still tilted, then smooth-lerp + velocity extrapolate between packets.
	local RESOLVE_PITCH_MIN = math.rad(65)
	local RESOLVE_PITCH_MAX = math.rad(125)
	local RESOLVE_LOOK_Y = 0.82
	local RESOLVE_SUSTAIN = 3
	local RESOLVE_HOLD = 1.1
	local RESOLVE_FOLLOW = 18 -- higher = snappier follow of net target
	local RESOLVE_VEL_BLEND = 0.45
	local resolveState = {} -- [userId] = { hit, on, lastDesync, visPos, targetPos, lastVel, look }

	local function isDesyncPose(root)
		local pitch = select(1, root.CFrame:ToOrientation())
		local ap = math.abs(pitch)
		if ap >= RESOLVE_PITCH_MIN and ap <= RESOLVE_PITCH_MAX then
			return true
		end
		return math.abs(root.CFrame.LookVector.Y) >= RESOLVE_LOOK_Y
	end

	local function flatLookFromRoot(root)
		local up = root.CFrame.UpVector
		local look = root.CFrame.LookVector
		local flat = Vector3.new(up.X, 0, up.Z)
		if flat.Magnitude < 0.15 then
			flat = Vector3.new(look.X, 0, look.Z)
		end
		if flat.Magnitude < 0.15 then
			local r = root.CFrame.RightVector
			flat = Vector3.new(r.Z, 0, -r.X)
		end
		if flat.Magnitude < 0.05 then
			return Vector3.new(0, 0, -1)
		end
		return flat.Unit
	end

	local function uprightAt(pos, lookFlat)
		if typeof(lookFlat) ~= "Vector3" or lookFlat.Magnitude < 0.05 then
			return CFrame.new(pos)
		end
		return CFrame.lookAt(pos, pos + lookFlat.Unit)
	end

	S.IsInvisResolved = function(plr)
		if not plr then
			return false
		end
		local st = resolveState[plr.UserId]
		return st and st.on == true
	end

	local TAG_NAME = "VG_InvisTag"
	local TAG_TEXT = "⚠  INVISIBLE  ⚠"

	local function destroyTag(st)
		if st and st.tag then
			pcall(function()
				st.tag:Destroy()
			end)
			st.tag = nil
		end
	end

	local function ensureTag(st, root, char)
		if not root or not st then
			return
		end
		local adornee = (char and char:FindFirstChild("Head")) or root
		local tag = st.tag
		if tag and tag.Parent and tag.Adornee == adornee then
			return
		end
		destroyTag(st)
		local ok, bb = pcall(function()
			local gui = Instance.new("BillboardGui")
			gui.Name = TAG_NAME
			gui.AlwaysOnTop = true
			gui.Size = UDim2.new(0, 160, 0, 28)
			gui.StudsOffset = Vector3.new(0, 3.1, 0)
			gui.MaxDistance = 400
			gui.Adornee = adornee
			gui.Parent = root

			local lbl = Instance.new("TextLabel")
			lbl.Name = "Label"
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 15
			lbl.TextColor3 = Color3.fromRGB(255, 210, 40)
			lbl.TextStrokeTransparency = 0.35
			lbl.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
			lbl.Text = TAG_TEXT
			lbl.Parent = gui
			return gui
		end)
		if ok then
			st.tag = bb
		end
	end

	local function clearAllResolve()
		for _, st in pairs(resolveState) do
			destroyTag(st)
		end
		table.clear(resolveState)
	end

	RS.RenderStepped:Connect(perfWrap("Invis.Resolver", function(dt)
		if S.Unloaded or not S.InvisResolver then
			if next(resolveState) then
				clearAllResolve()
			end
			return
		end

		dt = math.clamp(typeof(dt) == "number" and dt or 0.016, 0.001, 0.05)
		local now = tick()
		local alpha = 1 - math.exp(-RESOLVE_FOLLOW * dt)
		local wantTag = S.InvisResolverTag ~= false
		local seen = {}

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP then
				local c = plr.Character
				local root = c and c:FindFirstChild("HumanoidRootPart")
				local humO = c and c:FindFirstChildOfClass("Humanoid")
				if root and humO and humO.Health > 0 and root:IsDescendantOf(workspace) then
					seen[plr.UserId] = true
					local st = resolveState[plr.UserId]
					if not st then
						st = {
							hit = 0,
							on = false,
							lastDesync = 0,
							visPos = nil,
							targetPos = nil,
							lastVel = Vector3.zero,
							look = Vector3.new(0, 0, -1),
							tag = nil,
						}
						resolveState[plr.UserId] = st
					end

					local tilted = isDesyncPose(root)
					if tilted then
						st.hit += 1
						st.lastDesync = now
						st.targetPos = root.Position
						local vel = root.AssemblyLinearVelocity
						if typeof(vel) == "Vector3" then
							st.lastVel = Vector3.new(vel.X, 0, vel.Z)
						end
						st.look = flatLookFromRoot(root)
						if st.hit >= RESOLVE_SUSTAIN then
							st.on = true
						end
						if not st.visPos then
							st.visPos = st.targetPos
						end
					elseif st.on then
						if st.targetPos then
							st.targetPos = st.targetPos + st.lastVel * dt
						end
						st.lastVel = st.lastVel * math.max(0, 1 - 2.5 * dt)
						if (now - st.lastDesync) > RESOLVE_HOLD then
							st.on = false
							st.hit = 0
							st.visPos = nil
							st.targetPos = nil
							destroyTag(st)
						end
					else
						st.hit = 0
						destroyTag(st)
					end

					if st.on and st.targetPos then
						local predicted = st.targetPos + st.lastVel * (dt * RESOLVE_VEL_BLEND)
						if not st.visPos then
							st.visPos = predicted
						else
							st.visPos = st.visPos:Lerp(predicted, alpha)
						end
						pcall(function()
							root.CFrame = uprightAt(st.visPos, st.look)
							root.AssemblyAngularVelocity = Vector3.zero
						end)
						if wantTag then
							ensureTag(st, root, c)
							-- blink warning accent
							if st.tag then
								local lbl = st.tag:FindFirstChild("Label")
								if lbl then
									local pulse = 0.55 + 0.45 * math.abs(math.sin(now * 6))
									lbl.TextTransparency = 1 - pulse
									lbl.TextColor3 = Color3.fromRGB(255, 200 + math.floor(40 * pulse), 30)
								end
							end
						else
							destroyTag(st)
						end
					else
						destroyTag(st)
					end
				end
			end
		end

		for uid, st in pairs(resolveState) do
			if not seen[uid] then
				destroyTag(st)
				resolveState[uid] = nil
			end
		end
	end))
end

return Invisibility
