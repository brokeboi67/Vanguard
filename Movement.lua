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

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	local function stopNoclip()
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	end

	local function startNoclip()
		stopNoclip()
		noclipConn = RS.Stepped:Connect(perfWrap("Movement.Noclip", applyNoclip))
	end

	-- ── Spider ──────────────────────────────────────────────────────────────
	-- Continuous Truss climb gets rubberbanded (server has no climbable).
	-- Stealth = short wall-hops + pause on rubberband. Cannot fully bypass
	-- server position authority — only reduce corrections / ledge climbs.
	local spider = {
		folder = nil,
		truss = nil,
		lastPos = nil,
		lastAt = 0,
		cooldownUntil = 0,
		burstUntil = 0,
		burstStartY = nil,
		hopAt = 0,
	}

	local function clearSpider()
		if spider.truss then
			pcall(function()
				spider.truss:Destroy()
			end)
			spider.truss = nil
		end
		if spider.folder then
			pcall(function()
				spider.folder:Destroy()
			end)
			spider.folder = nil
		end
		spider.lastPos = nil
		spider.burstUntil = 0
		spider.burstStartY = nil
	end

	local function ensureSpiderFolder()
		if spider.folder and spider.folder.Parent then
			return spider.folder
		end
		local f = Instance.new("Folder")
		f.Name = "VG_Spider"
		f.Parent = workspace
		spider.folder = f
		return f
	end

	local function ensureSpiderTruss()
		if spider.truss and spider.truss.Parent then
			return spider.truss
		end
		local t = Instance.new("TrussPart")
		t.Name = "VG_SpiderTruss"
		t.Anchored = true
		t.CanCollide = true
		t.CanTouch = true
		t.CanQuery = false
		t.CastShadow = false
		t.Transparency = 1
		t.Size = Vector3.new(2, 6, 2)
		t.Parent = ensureSpiderFolder()
		spider.truss = t
		return t
	end

	local function parkSpiderTruss()
		if spider.truss then
			spider.truss.CFrame = CFrame.new(0, -500, 0)
		end
	end

	local function updateSpider()
		if not S.Spider then
			clearSpider()
			return
		end
		local hrp, char = getHRP()
		local hum = getHum()
		if not hrp or not hum or hum.Health <= 0 then
			return
		end

		local now = tick()
		local pos = hrp.Position
		local stealth = S.SpiderStealth ~= false

		-- Rubberband detect: server snapped us down/back hard
		if spider.lastPos then
			local dy = pos.Y - spider.lastPos.Y
			local flat = Vector3.new(pos.X - spider.lastPos.X, 0, pos.Z - spider.lastPos.Z).Magnitude
			if dy < -2.2 and flat < 6 and (now - spider.hopAt) < 1.2 then
				local cd = math.clamp(tonumber(S.SpiderCooldown) or 1.4, 0.6, 4)
				spider.cooldownUntil = now + cd
				spider.burstUntil = 0
				spider.burstStartY = nil
				parkSpiderTruss()
			end
		end
		spider.lastPos = pos
		spider.lastAt = now

		if now < spider.cooldownUntil then
			parkSpiderTruss()
			return
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local filter = { char, ensureSpiderFolder() }
		local clientBuild = workspace:FindFirstChild("VG_ClientBuild")
		if clientBuild then
			table.insert(filter, clientBuild)
		end
		params.FilterDescendantsInstances = filter

		local candidates = {
			hrp.CFrame.LookVector,
			-hrp.CFrame.LookVector,
			hrp.CFrame.RightVector,
			-hrp.CFrame.RightVector,
		}
		local best, bestDot = nil, -1
		local move = hum.MoveDirection
		for _, dir in ipairs(candidates) do
			local flatD = Vector3.new(dir.X, 0, dir.Z)
			if flatD.Magnitude > 0.05 then
				flatD = flatD.Unit
				local hit = workspace:Raycast(pos, flatD * 2.5, params)
				if hit and hit.Normal.Y < 0.35 and hit.Instance and hit.Instance.CanCollide then
					local into = 0
					if move.Magnitude > 0.08 then
						local away = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
						if away.Magnitude > 0.05 then
							into = move:Dot(-away.Unit)
						end
					end
					local score = into
					if into > 0.05 and flatD:Dot(hrp.CFrame.LookVector) > 0.5 then
						score += 0.2
					end
					if score > bestDot then
						bestDot = score
						best = hit
					end
				end
			end
		end

		if not best or bestDot < 0.2 then
			parkSpiderTruss()
			spider.burstUntil = 0
			spider.burstStartY = nil
			return
		end

		local flatN = Vector3.new(best.Normal.X, 0, best.Normal.Z)
		if flatN.Magnitude < 0.05 then
			return
		end
		flatN = flatN.Unit

		local climbSpd = math.clamp(tonumber(S.SpiderSpeed) or 14, 8, 24)
		local maxBurstH = math.clamp(tonumber(S.SpiderBurstHeight) or 7, 3, 14)
		local burstLen = stealth and 0.38 or 0.85

		if now > spider.burstUntil then
			if stealth and spider.burstStartY and (now - spider.hopAt) < 0.55 then
				parkSpiderTruss()
				return
			end
			spider.burstUntil = now + burstLen
			spider.burstStartY = pos.Y
			spider.hopAt = now
		end

		local climbed = pos.Y - (spider.burstStartY or pos.Y)
		if climbed >= maxBurstH then
			spider.burstUntil = 0
			spider.cooldownUntil = now + (stealth and 0.55 or 0.2)
			parkSpiderTruss()
			return
		end

		local truss = ensureSpiderTruss()
		truss.Size = Vector3.new(2, stealth and 5 or 10, 2)
		local tpos = Vector3.new(best.Position.X, pos.Y + 1.2, best.Position.Z) + flatN * 0.65
		truss.CFrame = CFrame.lookAt(tpos, tpos + flatN)

		local v = hrp.AssemblyLinearVelocity
		local pulse = stealth and (climbSpd * 0.9) or climbSpd
		if v.Y < pulse then
			hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.7, pulse, v.Z * 0.7) - flatN * 1.5
		end
		if stealth and (now - spider.hopAt) < 0.08 then
			pcall(function()
				hum.Jump = true
			end)
		end
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
		clearSpider()

		task.wait(0.5)

		if S.Noclip then startNoclip() end
		if S.NoFallDmg then startNoFallDmg() end
		if S.Fly then startFly() end
	end)

	-- ── Main loop ────────────────────────────────────────────────────────────

	local perfWrap2 = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.RenderStepped:Connect(perfWrap2("Movement.Main", function()
		-- Invis anim-desync owns HRP/camera — don't fight it with fly/spider/noclip
		local invisOn = S.Invisibility == true
		local needBHop    = S.BHop and not invisOn
		local needStrafe  = S.AutoStrafe and not invisOn
		local needFly     = S.Fly and not invisOn
		local needNoclip  = S.Noclip and not invisOn
		local needStamina = S.InfStamina
		local needFallDmg = S.NoFallDmg
		local needSpeed   = (S.Speed or S.JumpPower) and not invisOn
		local needSpider  = S.Spider and not invisOn

		if invisOn and flyActive then
			stopFly()
		end
		if invisOn and noclipConn then
			stopNoclip()
		end

		if not (needBHop or needStrafe or needFly or needNoclip or needStamina or needFallDmg or needSpeed or needSpider) then
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

		-- ── spider (stealth wall hops)
		if needSpider then
			updateSpider()
		else
			clearSpider()
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
	end))
end

return Movement
