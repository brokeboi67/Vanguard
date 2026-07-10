-- Plik: workspace/Vanguard/Movement.lua

local Movement = {}

function Movement.Init(S)
	local RS    = game:GetService("RunService")
	local UIS   = game:GetService("UserInputService")
	local LP    = game:GetService("Players").LocalPlayer
	local Cam   = workspace.CurrentCamera

	local strafeDir     = 1
	local flyActive     = false
	local flyBV         = nil
	local flyBG         = nil
	local noclipConn    = nil
	local origWalkSpeed = nil
	local origJumpPow   = nil
	local origJumpHeight = nil

	-- ── helpers ────────────────────────────────────────────────────────────

	local function getHum()
		local char = LP.Character
		return char and char:FindFirstChildOfClass("Humanoid"), char
	end

	local function getHRP()
		local char = LP.Character
		return char and char:FindFirstChild("HumanoidRootPart"), char
	end

	local function isAirborne(hum)
		local s = hum:GetState()
		return s == Enum.HumanoidStateType.Freefall
			or s == Enum.HumanoidStateType.Jumping
			or s == Enum.HumanoidStateType.Flying
	end

	-- ── Fly ─────────────────────────────────────────────────────────────────

	local function stopFly()
		flyActive = false
		if flyBV and flyBV.Parent then flyBV:Destroy() end
		if flyBG and flyBG.Parent then flyBG:Destroy() end
		flyBV, flyBG = nil, nil
		local hum = getHum()
		if hum then
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end

	local function startFly()
		local hrp, char = getHRP()
		if not hrp then return end
		flyActive = true

		flyBV = Instance.new("BodyVelocity")
		flyBV.Velocity    = Vector3.zero
		flyBV.MaxForce    = Vector3.new(1e5, 1e5, 1e5)
		flyBV.Parent      = hrp

		flyBG = Instance.new("BodyGyro")
		flyBG.MaxTorque   = Vector3.new(1e5, 1e5, 1e5)
		flyBG.P           = 1e4
		flyBG.CFrame      = hrp.CFrame
		flyBG.Parent      = hrp

		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
		end
	end

	local function updateFly()
		if not flyBV or not flyBV.Parent then return end
		local speed = (S.FlySpeed or 40)
		local camCF = Cam.CFrame
		local moveDir = Vector3.zero

		if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.yAxis end

		flyBV.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * speed or Vector3.zero
		flyBG.CFrame   = camCF
	end

	-- ── Noclip ──────────────────────────────────────────────────────────────

	local function applyNoclip()
		local char = LP.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function() part.CanCollide = false end)
			end
		end
	end

	local function stopNoclip()
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	end

	local function startNoclip()
		stopNoclip()
		noclipConn = RS.Stepped:Connect(applyNoclip)
	end

	-- ── Infinite Stamina ────────────────────────────────────────────────────
	-- Criminality stores stamina in player attributes OR as a NumberValue.
	-- We max it every frame by checking common locations.

	local function refillStamina()
		local char = LP.Character
		if not char then return end

		-- Try player attribute (common in newer Criminality versions)
		for _, key in ipairs({ "Stamina", "stamina", "STAMINA", "Sprint", "Energy" }) do
			local ok, val = pcall(function() return LP:GetAttribute(key) end)
			if ok and type(val) == "number" and val < 100 then
				pcall(function() LP:SetAttribute(key, 100) end)
			end
			local ok2, val2 = pcall(function() return char:GetAttribute(key) end)
			if ok2 and type(val2) == "number" and val2 < 100 then
				pcall(function() char:SetAttribute(key, 100) end)
			end
		end

		-- Try NumberValue inside character / player
		for _, key in ipairs({ "Stamina", "Sprint", "Energy", "Stam" }) do
			local nv = char:FindFirstChild(key) or LP:FindFirstChild(key)
			if nv and nv:IsA("NumberValue") and nv.Value < nv.MaxValue then
				pcall(function() nv.Value = nv.MaxValue end)
			end
		end
	end

	-- ── No Fall Damage ───────────────────────────────────────────────────────

	local fallDmgConn = nil

	local function startNoFallDmg()
		local hum = getHum()
		if not hum then return end
		if fallDmgConn then fallDmgConn:Disconnect() end
		-- Prevent Landed state from triggering fall damage scripts
		fallDmgConn = hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall then
				pcall(function()
					hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end)
			end
		end)
	end

	local function stopNoFallDmg()
		if fallDmgConn then fallDmgConn:Disconnect(); fallDmgConn = nil end
		local hum = getHum()
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			end)
		end
	end

	-- ── WalkSpeed / JumpPower ────────────────────────────────────────────────

	local function applySpeed(hum)
		if not hum then return end
		if S.Speed then
			if origWalkSpeed == nil then origWalkSpeed = hum.WalkSpeed end
			pcall(function() hum.WalkSpeed = S.SpeedValue or 25 end)
		else
			if origWalkSpeed ~= nil then
				pcall(function() hum.WalkSpeed = origWalkSpeed end)
				origWalkSpeed = nil
			end
		end

		if S.JumpPower then
			if origJumpPow == nil then
				origJumpPow    = hum.JumpPower
				origJumpHeight = hum.JumpHeight
			end
			pcall(function()
				hum.UseJumpPower = true
				hum.JumpPower = S.JumpPowerValue or 50
			end)
		else
			if origJumpPow ~= nil then
				pcall(function()
					hum.JumpPower  = origJumpPow
					hum.JumpHeight = origJumpHeight
				end)
				origJumpPow, origJumpHeight = nil, nil
			end
		end
	end

	-- ── Fly toggle key ───────────────────────────────────────────────────────

	UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		local key = S.FlyKey or "E"
		if inp.KeyCode == Enum.KeyCode[key] or tostring(inp.KeyCode):sub(14) == key then
			if not S.Fly then return end
			if flyActive then stopFly() else startFly() end
		end
	end)

	-- ── CharacterAdded — re-apply persistent states ──────────────────────────

	LP.CharacterAdded:Connect(function(_char)
		flyActive = false
		flyBV, flyBG = nil, nil
		origWalkSpeed, origJumpPow, origJumpHeight = nil, nil, nil
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		if fallDmgConn then fallDmgConn:Disconnect(); fallDmgConn = nil end

		task.wait(0.5)

		if S.Noclip then startNoclip() end
		if S.NoFallDmg then startNoFallDmg() end
		if S.Fly then startFly() end
	end)

	-- ── Main loop ────────────────────────────────────────────────────────────

	RS.RenderStepped:Connect(function()
		local needBHop    = S.BHop
		local needStrafe  = S.AutoStrafe
		local needFly     = S.Fly
		local needNoclip  = S.Noclip
		local needStamina = S.InfStamina
		local needFallDmg = S.NoFallDmg
		local needSpeed   = S.Speed or S.JumpPower

		if not (needBHop or needStrafe or needFly or needNoclip or needStamina or needFallDmg or needSpeed) then
			return
		end

		local hum, char = getHum()
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")

		-- ── fly update
		if needFly and flyActive then
			updateFly()
		elseif not needFly and flyActive then
			stopFly()
		end

		-- ── noclip sync
		if needNoclip then
			if not noclipConn then startNoclip() end
		else
			stopNoclip()
		end

		if not hum or hum.Health <= 0 then return end

		-- ── walk speed / jump power
		if needSpeed then
			applySpeed(hum)
		else
			applySpeed(hum)   -- will restore originals if S.Speed/S.JumpPower is false
		end

		-- ── bhop
		if needBHop and hum.MoveDirection.Magnitude >= 0.08 then
			local st = hum:GetState()
			if st == Enum.HumanoidStateType.Running
				or st == Enum.HumanoidStateType.RunningNoPhysics
				or st == Enum.HumanoidStateType.Landed then
				hum.Jump = true
			end
		end

		-- ── auto strafe
		if needStrafe and hrp and isAirborne(hum) then
			local delta = UIS:GetMouseDelta()
			if math.abs(delta.X) > 0.04 then
				strafeDir = delta.X > 0 and 1 or -1
			end
			local vel = hrp.AssemblyLinearVelocity
			local flatSpd = Vector3.new(vel.X, 0, vel.Z).Magnitude
			if flatSpd > 3 or hum.MoveDirection.Magnitude > 0.08 then
				hum:Move(Vector3.new(strafeDir, 0, -1), true)
			end
		end

		-- ── infinite stamina
		if needStamina then
			refillStamina()
		end

		-- ── no fall damage
		if needFallDmg then
			if not fallDmgConn then startNoFallDmg() end
		else
			stopNoFallDmg()
		end
	end)
end

return Movement
