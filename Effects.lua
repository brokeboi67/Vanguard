-- Plik: workspace/Vanguard/Effects.lua

local Effects = {}

function Effects.Init(S, Util)
	local TS = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local Players = game:GetService("Players")
	local Lighting = game:GetService("Lighting")
	local RS = game:GetService("RunService")
	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local SPARK_TEX = "rbxassetid://243660064"
	local watched = {}

	local accent = function()
		return S.V or Color3.fromRGB(0, 255, 150)
	end

	local function isEnemyChar(char)
		if not char or not char:IsA("Model") or char == LP.Character then
			return false
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		return hum and hum.Health > 0
	end

	local function getRoot(char)
		if not char then
			return nil
		end
		return Util and Util.resolveBodyPart(char, "HumanoidRootPart")
			or char:FindFirstChild("HumanoidRootPart")
	end

	local function getCrosshairVictim()
		if not Cam then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 900, params)
		if hit and hit.Instance then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if isEnemyChar(model) then
				return model
			end
		end
		local best, bestD = nil, math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP and plr.Character and isEnemyChar(plr.Character) then
				local root = getRoot(plr.Character)
				if root then
					local d = (Cam.CFrame.Position - root.Position).Magnitude
					if d < bestD then
						bestD = d
						best = plr.Character
					end
				end
			end
		end
		return best
	end

	local function recentShotWindow(maxAge)
		maxAge = maxAge or 2.5
		local t = tonumber(S.LastShotAt)
		return t and (tick() - t) <= maxAge
	end

	local function shotMatchesChar(char)
		if not char or not recentShotWindow(3) then
			return false
		end
		if S.LastShotChar and S.LastShotChar == char then
			return true
		end
		if S.LastShotHum and S.LastShotHum.Parent == char then
			return true
		end
		return false
	end

	local function addHighlight(char, col, life)
		local hl = Instance.new("Highlight")
		hl.Name = "VG_FX"
		hl.Adornee = char
		hl.FillColor = col
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.1
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = Lighting
		TS:Create(hl, TweenInfo.new(life or 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		}):Play()
		Debris:AddItem(hl, (life or 0.85) + 0.2)
		return hl
	end

	local function spawnAnchor(pos, lifetime)
		local p = Instance.new("Part")
		p.Name = "VG_FX"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(pos)
		p.Parent = workspace
		Debris:AddItem(p, lifetime or 2)
		return p
	end

	local function makeBurst(pos, col, count, speed)
		local anchor = spawnAnchor(pos, 3)
		local em = Instance.new("ParticleEmitter")
		em.Texture = SPARK_TEX
		em.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		em.LightEmission = 1
		em.Rate = 0
		em.Speed = NumberRange.new(speed or 8, (speed or 8) + 16)
		em.Lifetime = NumberRange.new(0.5, 1.1)
		em.SpreadAngle = Vector2.new(360, 360)
		em.Drag = 1.5
		em.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		em.Parent = anchor
		em:Emit(count or 60)
	end

	local function flashBillboard(char, col)
		local root = getRoot(char)
		if not root then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "VG_FX"
		bb.Adornee = root
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(6, 0, 6, 0)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.Parent = root
		local img = Instance.new("Frame")
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundColor3 = col
		img.BackgroundTransparency = 0.35
		img.BorderSizePixel = 0
		img.Parent = bb
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = img
		TS:Create(img, TweenInfo.new(0.5), { BackgroundTransparency = 1, Size = UDim2.new(1.6, 0, 1.6, 0) }):Play()
		Debris:AddItem(bb, 0.6)
	end

	local function trackPosition(char, seconds, stepFn)
		task.spawn(function()
			local t0 = tick()
			while tick() - t0 < seconds do
				if not char or not char.Parent then
					break
				end
				local root = getRoot(char)
				if not root then
					break
				end
				stepFn(root.Position, tick() - t0)
				task.wait(0.03)
			end
		end)
	end

	local function effectNeonDissolve(char)
		local col = accent()
		addHighlight(char, col, 0.95)
		flashBillboard(char, col)
		local root = getRoot(char)
		if root then
			makeBurst(root.Position + Vector3.new(0, 1.5, 0), col, 50, 10)
		end
	end

	local function effectParticleBurst(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		makeBurst(root.Position, col, 70, 16)
		makeBurst(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(40, 40, 48), 35, 8)
		addHighlight(char, col, 0.4)
	end

	local function effectAscension(char)
		local col = accent()
		addHighlight(char, col, 1.4)
		trackPosition(char, 1.5, function(pos, elapsed)
			makeBurst(pos + Vector3.new(0, elapsed * 6, 0), col, 6, 4)
		end)
		local root = getRoot(char)
		if root then
			makeBurst(root.Position, col, 25, 6)
		end
	end

	local function effectShockRing(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local ring = Instance.new("Part")
		ring.Name = "VG_FX"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = accent()
		ring.Transparency = 0.2
		ring.Size = Vector3.new(0.15, 1, 1)
		ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		TS:Create(ring, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.08, 16, 16),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.75)
	end

	local function effectLightningHit(char)
		local head = Util and Util.resolveBodyPart(char, "Head") or char:FindFirstChild("Head")
		local root = getRoot(char)
		local target = head or root
		if not target then
			return
		end
		local col = accent()
		local top = spawnAnchor(target.Position + Vector3.new(0, 14, 0), 0.4)
		local bot = spawnAnchor(target.Position, 0.4)
		local beam = Instance.new("Beam")
		beam.Attachment0 = Instance.new("Attachment", top)
		beam.Attachment1 = Instance.new("Attachment", bot)
		beam.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		beam.LightEmission = 1
		beam.Width0 = 1.2
		beam.Width1 = 0.2
		beam.FaceCamera = true
		beam.Parent = top
		makeBurst(target.Position, col, 30, 12)
		addHighlight(char, col, 0.35)
		flashBillboard(char, col)
	end

	local function effectSparkHit(char)
		local root = getRoot(char)
		if not root then
			return
		end
		makeBurst(root.Position + Vector3.new(0, 1.2, 0), accent(), 35, 10)
		flashBillboard(char, accent())
	end

	local function effectSelfAura()
		local char = LP.Character
		if not char then
			return
		end
		local root = getRoot(char)
		if not root then
			return
		end
		makeBurst(root.Position, accent(), 40, 12)
		addHighlight(char, accent(), 0.55)
	end

	local KILL_FX = {
		Neon = effectNeonDissolve,
		Burst = effectParticleBurst,
		Ascension = effectAscension,
		Shock = effectShockRing,
	}

	local HIT_FX = {
		Lightning = effectLightningHit,
		Sparks = effectSparkHit,
	}

	local function pickKillFx()
		local style = S.KillEffectStyle or "Neon"
		if style == "Random" then
			style = ({ "Neon", "Burst", "Ascension", "Shock" })[math.random(1, 4)]
		end
		return KILL_FX[style] or effectNeonDissolve
	end

	local function pickHitFx()
		return HIT_FX[S.HitEffectStyle or "Lightning"] or effectLightningHit
	end

	local lastHitFxChar = nil
	local lastHitFxAt = 0
	local lastKillFxChar = nil
	local lastKillFxAt = 0

	local function playHitFx(char)
		if not char or not isEnemyChar(char) then
			return
		end
		if lastHitFxChar == char and tick() - lastHitFxAt < 0.3 then
			return
		end
		lastHitFxChar = char
		lastHitFxAt = tick()
		pcall(function()
			pickHitFx()(char)
		end)
	end

	local function playKillFx(char)
		if not char or char == LP.Character then
			return
		end
		if lastKillFxChar == char and tick() - lastKillFxAt < 0.5 then
			return
		end
		lastKillFxChar = char
		lastKillFxAt = tick()
		pcall(function()
			pickKillFx()(char)
		end)
		if S.SelfKillFX then
			pcall(effectSelfAura)
		end
	end

	function S.NotifyShot(char)
		if not char or not isEnemyChar(char) then
			return
		end
		S.LastShotChar = char
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			S.LastShotHum = hum
		end
		if S.HitEffects then
			playHitFx(char)
		end
	end

	local function bindChar(char)
		if not char or watched[char] then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		watched[char] = true

		hum.Died:Connect(function()
			if not S.KillEffects then
				return
			end
			if shotMatchesChar(char) then
				playKillFx(char)
			end
		end)

		local lastHp = hum.Health
		hum.HealthChanged:Connect(function(hp)
			if not S.KillEffects and not S.HitEffects then
				lastHp = hp
				return
			end
			if hp < lastHp and shotMatchesChar(char) then
				if S.HitEffects then
					playHitFx(char)
				end
				if hp <= 0 and S.KillEffects then
					playKillFx(char)
				end
			end
			lastHp = hp
		end)
	end

	local function scanChars()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP and plr.Character then
				bindChar(plr.Character)
			end
		end
	end

	function S.OnLocalHit(hum, dmg)
		if not S.HitEffects or not hum or not hum.Parent then
			return
		end
		if shotMatchesChar(hum.Parent) then
			playHitFx(hum.Parent)
		end
	end

	function S.OnLocalKill(hum, plrName)
		if not S.KillEffects or not hum or not hum.Parent then
			return
		end
		if shotMatchesChar(hum.Parent) then
			playKillFx(hum.Parent)
		end
	end

	function S.TestKillEffect()
		local char = getCrosshairVictim()
		if not char then
			return false, "Celuj w wroga (crosshair)"
		end
		playKillFx(char)
		return true
	end

	function S.TestHitEffect()
		local char = getCrosshairVictim()
		if not char then
			return false, "Celuj w wroga (crosshair)"
		end
		playHitFx(char)
		return true
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				bindChar(char)
			end)
		end)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			task.defer(function()
				bindChar(plr.Character)
			end)
		end
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				bindChar(char)
			end)
		end)
	end

	local scanAt = 0

	RS.Heartbeat:Connect(function()
		if tick() - scanAt > 2 then
			scanAt = tick()
			scanChars()
		end
	end)
end

return Effects
