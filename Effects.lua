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
	local SMOKE_TEX = "rbxassetid://1084963537"
	local watched = {}

	local accent = function()
		return S.V or Color3.fromRGB(0, 255, 150)
	end

	local function ensureColor(col, fallback)
		if typeof(col) == "Color3" then
			return col
		end
		if typeof(fallback) == "Color3" then
			return fallback
		end
		return accent()
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

	local function getBloom()
		local b = Lighting:FindFirstChild("VG_Bloom")
		if not b then
			b = Instance.new("BloomEffect")
			b.Name = "VG_Bloom"
			b.Enabled = false
			b.Intensity = 0
			b.Size = 24
			b.Threshold = 0.8
			b.Parent = Lighting
		end
		return b
	end

	local function getCC()
		local cc = Lighting:FindFirstChild("VG_CC")
		if not cc then
			cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "VG_CC"
			cc.Enabled = false
			cc.Parent = Lighting
		end
		return cc
	end

	local function screenFlash(col, bright, sat, life)
		life = life or 0.22
		local cc = getCC()
		cc.Enabled = true
		cc.TintColor = col
		cc.Brightness = bright or 0.35
		cc.Saturation = sat or 0.55
		cc.Contrast = 0.15
		TS:Create(cc, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 0,
			Saturation = 0,
			Contrast = 0,
		}):Play()

		local bloom = getBloom()
		bloom.Enabled = true
		bloom.Intensity = 1.4
		TS:Create(bloom, TweenInfo.new(life * 1.2), { Intensity = 0 }):Play()

		task.delay(life + 0.05, function()
			cc.Enabled = false
			bloom.Enabled = false
		end)
	end

	local function camShake(intensity, duration)
		task.spawn(function()
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if not hum then
				return
			end
			local t0 = tick()
			while tick() - t0 < duration do
				local decay = 1 - (tick() - t0) / duration
				local ox = (math.random() - 0.5) * intensity * decay
				local oy = (math.random() - 0.5) * intensity * decay
				hum.CameraOffset = Vector3.new(ox, oy, 0)
				task.wait(0.03)
			end
			hum.CameraOffset = Vector3.zero
		end)
	end

	local function addHighlight(char, col, life, fillStart)
		local hl = Instance.new("Highlight")
		hl.Name = "VG_FX"
		hl.Adornee = char
		hl.FillColor = col
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = fillStart or 0.05
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

	local function makeEmitter(anchor, props)
		local em = Instance.new("ParticleEmitter")
		em.Texture = props.Texture or SPARK_TEX
		em.Color = props.Color or ColorSequence.new(accent(), Color3.new(1, 1, 1))
		em.LightEmission = props.LightEmission or 1
		em.Rate = 0
		em.Speed = props.Speed or NumberRange.new(10, 24)
		em.Lifetime = props.Lifetime or NumberRange.new(0.4, 1.2)
		em.SpreadAngle = props.SpreadAngle or Vector2.new(360, 360)
		em.Drag = props.Drag or 1.2
		em.RotSpeed = props.RotSpeed or NumberRange.new(-180, 180)
		em.Size = props.Size or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(0.4, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		})
		em.Parent = anchor
		return em
	end

	local function makeBurst(pos, col, count, speed, tex)
		col = ensureColor(col)
		local anchor = spawnAnchor(pos, 4)
		local em = makeEmitter(anchor, {
			Texture = tex or SPARK_TEX,
			Color = ColorSequence.new(col, Color3.new(1, 1, 1)),
			Speed = NumberRange.new(speed or 12, (speed or 12) + 22),
		})
		em:Emit(count or 80)
		return anchor
	end

	local function makeSmoke(pos, col, count)
		col = ensureColor(col)
		local anchor = spawnAnchor(pos, 4)
		local em = makeEmitter(anchor, {
			Texture = SMOKE_TEX,
			Color = ColorSequence.new(col, Color3.fromRGB(30, 30, 40)),
			Speed = NumberRange.new(2, 8),
			Lifetime = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.4,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 2.5),
				NumberSequenceKeypoint.new(1, 5),
			}),
		})
		em:Emit(count or 25)
	end

	local function shockRings(pos, col, count, maxDiam, delayStep)
		col = ensureColor(col)
		count = count or 4
		maxDiam = maxDiam or 22
		delayStep = delayStep or 0.07
		for i = 1, count do
			task.delay((i - 1) * delayStep, function()
				local ring = Instance.new("Part")
				ring.Name = "VG_FX"
				ring.Shape = Enum.PartType.Cylinder
				ring.Anchored = true
				ring.CanCollide = false
				ring.CanQuery = false
				ring.CanTouch = false
				ring.Material = Enum.Material.Neon
				ring.Color = col
				ring.Transparency = 0.15 + (i - 1) * 0.08
				local startD = 1.5 + i * 0.5
				ring.Size = Vector3.new(0.2, startD, startD)
				ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
				ring.Parent = workspace
				local target = maxDiam + i * 2
				TS:Create(ring, TweenInfo.new(0.75 + i * 0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.06, target, target),
					Transparency = 1,
				}):Play()
				Debris:AddItem(ring, 1)
			end)
		end
	end

	local function flashBillboard(char, col, sizeMult)
		col = ensureColor(col)
		local root = getRoot(char)
		if not root then
			return
		end
		sizeMult = sizeMult or 1
		local bb = Instance.new("BillboardGui")
		bb.Name = "VG_FX"
		bb.Adornee = root
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(7 * sizeMult, 0, 7 * sizeMult, 0)
		bb.StudsOffset = Vector3.new(0, 1.2, 0)
		bb.Parent = root
		local img = Instance.new("Frame")
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundColor3 = col
		img.BackgroundTransparency = 0.2
		img.BorderSizePixel = 0
		img.Parent = bb
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = img
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
		stroke.Transparency = 0.2
		stroke.Parent = img
		TS:Create(img, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			Size = UDim2.new(2.2, 0, 2.2, 0),
		}):Play()
		TS:Create(stroke, TweenInfo.new(0.55), { Transparency = 1 }):Play()
		Debris:AddItem(bb, 0.65)
	end

	local function forkLightning(fromPos, toPos, col, forks)
		col = ensureColor(col)
		forks = forks or 3
		for f = 1, forks do
			local mid = fromPos:Lerp(toPos, 0.35 + math.random() * 0.3)
			mid = mid + Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, (math.random() - 0.5) * 6)
			local top = spawnAnchor(fromPos, 0.5)
			local midA = spawnAnchor(mid, 0.5)
			local bot = spawnAnchor(toPos, 0.5)
			local function beam(a0, a1, w)
				local b = Instance.new("Beam")
				b.Attachment0 = Instance.new("Attachment", a0)
				b.Attachment1 = Instance.new("Attachment", a1)
				b.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
				b.LightEmission = 1
				b.Width0 = w
				b.Width1 = w * 0.3
				b.FaceCamera = true
				b.CurveSize0 = (math.random() - 0.5) * 4
				b.CurveSize1 = (math.random() - 0.5) * 4
				b.Parent = a0
			end
			beam(top, midA, 1.4 - f * 0.15)
			beam(midA, bot, 1.0 - f * 0.1)
		end
	end

	local function ghostAscend(char, col)
		col = ensureColor(col)
		local root = getRoot(char)
		if not root then
			return
		end
		local ghost = char:Clone()
		ghost.Name = "VG_Ghost"
		for _, d in ipairs(ghost:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Material = Enum.Material.Neon
				d.Color = col
				d.Transparency = 0.35
			elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
				d:Destroy()
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d:Destroy()
			end
		end
		ghost:PivotTo(char:GetPivot())
		ghost.Parent = workspace
		local start = ghost:GetPivot()
		task.spawn(function()
			local t0 = tick()
			while tick() - t0 < 1.2 do
				local a = (tick() - t0) / 1.2
				ghost:PivotTo(start * CFrame.new(0, a * 8, 0))
				for _, p in ipairs(ghost:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Transparency = 0.35 + a * 0.65
					end
				end
				task.wait(0.03)
			end
			ghost:Destroy()
		end)
	end

	local function effectNovaBurst(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = Color3.fromRGB(255, 55, 190)
		local col2 = Color3.fromRGB(255, 240, 255)
		local pos = root.Position + Vector3.new(0, 1.5, 0)
		shockRings(pos, col, 6, 34, 0.05)
		shockRings(pos, col2, 3, 22, 0.09)
		makeBurst(pos, col, 140, 26)
		makeBurst(pos, col2, 55, 18)
		makeSmoke(pos, Color3.fromRGB(80, 20, 60), 40)
		screenFlash(col, 0.55, 0.85, 0.32)
		camShake(0.42, 0.4)
		addHighlight(char, col, 1.2, 0)
		flashBillboard(char, col2, 1.6)
		ghostAscend(char, col)
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
		local col = ensureColor(accent())
		local col2 = Color3.fromRGB(100, 255, 230)
		addHighlight(char, col, 1.2, 0)
		flashBillboard(char, col2, 1.2)
		screenFlash(col2, 0.25, 0.4, 0.18)
		local root = getRoot(char)
		if root then
			local pos = root.Position + Vector3.new(0, 1.5, 0)
			shockRings(pos, col, 2, 14)
			makeBurst(pos, col, 70, 12)
			makeBurst(pos, col2, 35, 10)
			ghostAscend(char, col2)
		end
		camShake(0.2, 0.25)
	end

	local function effectParticleBurst(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = Color3.fromRGB(255, 140, 30)
		local col2 = Color3.fromRGB(255, 220, 80)
		local pos = root.Position
		makeBurst(pos, col, 120, 24)
		makeBurst(pos + Vector3.new(0, 2.5, 0), col2, 70, 18)
		makeBurst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(35, 35, 42), 50, 8)
		makeSmoke(pos, Color3.fromRGB(50, 45, 40), 45)
		shockRings(pos + Vector3.new(0, 0.5, 0), col, 2, 16)
		addHighlight(char, col, 0.55, 0.15)
		flashBillboard(char, col2, 1.15)
		screenFlash(col, 0.35, 0.55, 0.22)
		camShake(0.32, 0.32)
	end

	local function effectAscension(char)
		local col = Color3.fromRGB(170, 120, 255)
		local col2 = Color3.fromRGB(255, 230, 140)
		addHighlight(char, col, 1.6, 0)
		screenFlash(col2, 0.35, 0.6, 0.25)
		trackPosition(char, 1.8, function(pos, elapsed)
			makeBurst(pos + Vector3.new(0, elapsed * 7, 0), col2, 12, 5)
			if math.floor(elapsed * 10) % 3 == 0 then
				makeBurst(pos + Vector3.new(0, elapsed * 7, 0), col, 6, 3)
			end
		end)
		local root = getRoot(char)
		if root then
			shockRings(root.Position, col, 3, 14)
			makeBurst(root.Position, col2, 40, 6)
			ghostAscend(char, col)
		end
		camShake(0.22, 0.4)
	end

	local function effectShockRing(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = Color3.fromRGB(60, 180, 255)
		local col2 = Color3.fromRGB(200, 240, 255)
		local pos = root.Position
		shockRings(pos, col, 8, 36, 0.04)
		shockRings(pos, col2, 4, 24, 0.07)
		makeBurst(pos + Vector3.new(0, 0.5, 0), col2, 25, 10)
		addHighlight(char, col, 0.7, 0.2)
		flashBillboard(char, col, 1.35)
		screenFlash(col, 0.38, 0.45, 0.2)
		camShake(0.35, 0.38)
	end

	local function effectLightningHit(char)
		local head = Util and Util.resolveBodyPart(char, "Head") or char:FindFirstChild("Head")
		local root = getRoot(char)
		local target = head or root
		if not target then
			return
		end
		local col = accent()
		local topPos = target.Position + Vector3.new(0, 18 + math.random() * 6, 0)
		forkLightning(topPos, target.Position, col, 4)
		makeBurst(target.Position, col, 55, 16)
		makeBurst(target.Position + Vector3.new(0, 1, 0), Color3.new(1, 1, 1), 20, 12)
		shockRings(target.Position, col, 2, 12, 0.05)
		addHighlight(char, col, 0.55, 0)
		flashBillboard(char, col, 1.15)
		screenFlash(col, 0.32, 0.65, 0.16)
		camShake(0.18, 0.2)
	end

	local function effectSparkHit(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		local pos = root.Position + Vector3.new(0, 1.2, 0)
		makeBurst(pos, col, 55, 14)
		makeBurst(pos, Color3.fromRGB(255, 220, 100), 25, 10)
		shockRings(pos, col, 2, 10)
		flashBillboard(char, col)
		screenFlash(col, 0.18, 0.35, 0.12)
		camShake(0.12, 0.15)
	end

	local function effectNovaHit(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		local pos = root.Position + Vector3.new(0, 1.4, 0)
		shockRings(pos, col, 3, 14, 0.05)
		makeBurst(pos, col, 75, 18)
		makeBurst(pos, Color3.new(1, 1, 1), 25, 12)
		addHighlight(char, col, 0.45, 0.05)
		flashBillboard(char, col, 1.2)
		screenFlash(col, 0.28, 0.5, 0.18)
		camShake(0.22, 0.22)
	end

	local function effectImpactHit(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		local pos = root.Position
		shockRings(pos, col, 4, 16, 0.04)
		makeBurst(pos + Vector3.new(0, 0.8, 0), col, 65, 20)
		makeSmoke(pos, Color3.fromRGB(60, 60, 70), 20)
		addHighlight(char, Color3.fromRGB(255, 80, 80), 0.35, 0.1)
		flashBillboard(char, Color3.fromRGB(255, 120, 80), 1.25)
		screenFlash(Color3.fromRGB(255, 100, 80), 0.22, 0.4, 0.14)
		camShake(0.25, 0.28)
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
		local col = accent()
		makeBurst(root.Position, col, 70, 16)
		shockRings(root.Position, col, 3, 14)
		addHighlight(char, col, 0.75, 0.1)
		screenFlash(col, 0.2, 0.45, 0.15)
		camShake(0.15, 0.2)
	end

	local KILL_FX = {
		Neon = effectNeonDissolve,
		Burst = effectParticleBurst,
		Ascension = effectAscension,
		Shock = effectShockRing,
		Nova = effectNovaBurst,
	}

	local HIT_FX = {
		Lightning = effectLightningHit,
		Sparks = effectSparkHit,
		Nova = effectNovaHit,
		Impact = effectImpactHit,
	}

	local function pickKillFx()
		local style = S.KillEffectStyle or "Neon"
		if style == "Random" then
			style = ({ "Neon", "Burst", "Ascension", "Shock", "Nova" })[math.random(1, 5)]
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
		if lastHitFxChar == char and tick() - lastHitFxAt < 0.25 then
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
		if S.Unloaded then
			return
		end
		if tick() - scanAt > 2 then
			scanAt = tick()
			scanChars()
		end
	end)
end

return Effects
