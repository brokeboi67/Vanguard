-- Plik: workspace/Vanguard/Effects.lua

local Effects = {}

function Effects.Init(S, Util)
	local TS = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local Players = game:GetService("Players")
	local LP = Players.LocalPlayer

	local accent = function()
		return S.V or Color3.fromRGB(0, 255, 150)
	end

	local function getRoot(char)
		if not char then
			return nil
		end
		return Util and Util.resolveBodyPart(char, "HumanoidRootPart")
			or char:FindFirstChild("HumanoidRootPart")
	end

	local function bodyParts(char)
		local list = {}
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BasePart") and string.sub(inst.Name, 1, 7) ~= "VG_HBX_" then
				table.insert(list, inst)
			end
		end
		return list
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
		local anchor = spawnAnchor(pos, 2.5)
		local em = Instance.new("ParticleEmitter")
		em.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		em.LightEmission = 1
		em.Rate = 0
		em.Speed = NumberRange.new(speed or 10, (speed or 10) + 12)
		em.Lifetime = NumberRange.new(0.35, 0.85)
		em.SpreadAngle = Vector2.new(360, 360)
		em.Drag = 2
		em.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		em.Parent = anchor
		em:Emit(count or 45)
	end

	local function effectNeonDissolve(char)
		local col = accent()
		local parts = bodyParts(char)
		if #parts == 0 then
			return
		end
		for _, p in ipairs(parts) do
			p.Material = Enum.Material.Neon
			p.Color = col
			TS:Create(p, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
		end
		local root = getRoot(char)
		if root then
			makeBurst(root.Position, col, 30, 8)
		end
	end

	local function effectParticleBurst(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		makeBurst(root.Position, col, 55, 14)
		makeBurst(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(30, 30, 35), 25, 6)
	end

	local function effectAscension(char)
		local root = getRoot(char)
		if not root then
			return
		end
		local col = accent()
		local hl = Instance.new("Highlight")
		hl.FillColor = col
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0.1
		hl.Adornee = char
		hl.Parent = char
		Debris:AddItem(hl, 3)

		task.spawn(function()
			for _ = 1, 50 do
				if not root.Parent then
					break
				end
				root.CFrame = root.CFrame * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.rad(8), 0)
				task.wait(0.03)
			end
			pcall(function() hl:Destroy() end)
		end)
		makeBurst(root.Position, col, 20, 5)
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
		ring.Transparency = 0.35
		ring.Size = Vector3.new(0.15, 1, 1)
		ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace
		TS:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.08, 14, 14),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.7)
	end

	local function effectLightningHit(char)
		local head = Util and Util.resolveBodyPart(char, "Head") or char:FindFirstChild("Head")
		local root = getRoot(char)
		local target = head or root
		if not target then
			return
		end
		local col = accent()
		local top = spawnAnchor(target.Position + Vector3.new(0, 12, 0), 0.35)
		local bot = spawnAnchor(target.Position, 0.35)
		local beam = Instance.new("Beam")
		beam.Attachment0 = Instance.new("Attachment", top)
		beam.Attachment1 = Instance.new("Attachment", bot)
		beam.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		beam.LightEmission = 1
		beam.Width0 = 0.8
		beam.Width1 = 0.15
		beam.FaceCamera = true
		beam.Parent = top
		makeBurst(target.Position, col, 18, 10)
	end

	local function effectSparkHit(char)
		local root = getRoot(char)
		if not root then
			return
		end
		makeBurst(root.Position + Vector3.new(0, 1.2, 0), accent(), 22, 8)
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
		makeBurst(root.Position, accent(), 35, 12)
		local hl = Instance.new("Highlight")
		hl.FillColor = accent()
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.5
		hl.Adornee = char
		hl.Parent = char
		TS:Create(hl, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
		Debris:AddItem(hl, 0.6)
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
			local keys = { "Neon", "Burst", "Ascension", "Shock" }
			style = keys[math.random(1, #keys)]
		end
		return KILL_FX[style] or effectNeonDissolve
	end

	local function pickHitFx()
		return HIT_FX[S.HitEffectStyle or "Lightning"] or effectLightningHit
	end

	local function recentKill()
		local t = tonumber(S.LastShotAt)
		return t and (tick() - t) <= 2.5
	end

	local function recentHit()
		local t = tonumber(S.LastShotAt)
		return t and (tick() - t) <= 1.5
	end

	function S.OnLocalHit(hum, dmg)
		if not S.HitEffects or not hum or not hum.Parent then
			return
		end
		if not recentHit() then
			return
		end
		if S.LastShotHum and hum ~= S.LastShotHum then
			return
		end
		local char = hum.Parent
		if not char or not char:IsA("Model") then
			return
		end
		pcall(function()
			pickHitFx()(char)
		end)
	end

	function S.OnLocalKill(hum, plrName)
		if not S.KillEffects or not hum or not hum.Parent then
			return
		end
		if not recentKill() then
			return
		end
		local char = hum.Parent
		if not char or not char:IsA("Model") then
			return
		end
		pcall(function()
			pickKillFx()(char)
		end)
		if S.SelfKillFX then
			pcall(effectSelfAura)
		end
	end

	function S.TestKillEffect()
		local char = LP.Character
		if char then
			pcall(function()
				pickKillFx()(char)
			end)
		end
	end

	function S.TestHitEffect()
		local char = LP.Character
		if char then
			pcall(function()
				pickHitFx()(char)
			end)
		end
	end
end

return Effects
