-- Plik: workspace/Vanguard/Animations.lua

local Animations = {}

Animations.LIST = {
	{ label = "Twerk", icon = "◎", procedural = "twerk", visibleToOthers = false, rig = "both" },
	{ label = "Floss", icon = "◎", chat = "floss", visibleToOthers = true, rig = "both", r15 = { 1071434727, 5917570207 }, r6 = { 182436842 }, ids = { 1071434727 } },
	{ label = "Griddy", icon = "◎", procedural = "griddy", visibleToOthers = false, rig = "both" },
	{ label = "Spin", icon = "◎", procedural = "spin", visibleToOthers = false, rig = "both" },
	{ label = "Thunder", icon = "◎", procedural = "thunder", visibleToOthers = false, rig = "both" },
	{ label = "Matrix", icon = "◎", procedural = "matrix", visibleToOthers = false, rig = "both" },
	{ label = "Disco", icon = "◎", procedural = "disco", visibleToOthers = false, rig = "both" },
	{ label = "Levitate", icon = "◎", procedural = "levitate", visibleToOthers = false, rig = "both" },
	{ label = "Dance", icon = "✦", chat = "dance", visibleToOthers = true, rig = "both", folders = { "dance", "dance2", "dance3" }, r15 = { 507771019, 507776879, 507777623 }, r6 = { 182435998, 182436014 } },
	{ label = "Dance 2", icon = "✦", chat = "dance2", visibleToOthers = true, rig = "both", folders = { "dance2" }, r15 = { 507776879, 507776043 }, r6 = { 182436014 } },
	{ label = "Dance 3", icon = "✦", chat = "dance3", visibleToOthers = true, rig = "both", folders = { "dance3" }, r15 = { 507777623, 507777268 }, r6 = { 182435998 } },
	{ label = "Wave", icon = "✦", chat = "wave", once = true, visibleToOthers = true, rig = "both", folders = { "wave" }, r15 = { 507770239 }, r6 = { 182435936 } },
	{ label = "Point", icon = "✦", chat = "point", once = true, visibleToOthers = true, rig = "both", folders = { "point" }, r15 = { 507770453 }, r6 = { 182435380 } },
	{ label = "Laugh", icon = "✦", chat = "laugh", once = true, visibleToOthers = true, rig = "both", folders = { "laugh" }, r15 = { 507770818 }, r6 = { 182435844 } },
	{ label = "Cheer", icon = "✦", chat = "cheer", visibleToOthers = true, rig = "both", folders = { "cheer" }, r15 = { 507770677 }, r6 = { 182436086 } },
	{ label = "Sit", icon = "✦", chat = "sit", visibleToOthers = true, rig = "both", folders = { "sit" }, r15 = { 2506281703, 507767968 }, r6 = { 182435239 } },
	{ label = "Robot", icon = "✦", chat = "robot", visibleToOthers = true, rig = "r15", r15 = { 616088955, 616102148 } },
	{ label = "Zombie", icon = "✦", visibleToOthers = true, rig = "both", r15 = { 616161997 }, r6 = { 182435388 } },
}

Animations.MOVEMENT = {
	{
		label = "Default",
		icon = "↺",
		reset = true,
		visibleToOthers = true,
	},
	{
		label = "Ninja",
		icon = "🥷",
		visibleToOthers = true,
		r15 = {
			idle = { 656117400, 656118341 },
			walk = 656121766,
			run = 656118852,
			jump = 656117878,
		},
		r6 = {
			idle = { 126607648 },
			walk = 126606216,
			run = 626714693,
			jump = 126626749,
		},
	},
	{
		label = "Robot",
		icon = "🤖",
		visibleToOthers = true,
		r15 = {
			idle = { 616008936, 616013216 },
			walk = 616026330,
			run = 616010382,
			jump = 616008936,
		},
		r6 = {
			idle = { 126607648 },
			walk = 126606216,
			run = 626714693,
			jump = 126626749,
		},
	},
	{
		label = "Levitation",
		icon = "☁",
		visibleToOthers = true,
		r15 = {
			idle = { 616006778, 616008936 },
			walk = 616013216,
			run = 616010382,
			jump = 616008936,
		},
		r6 = {
			idle = { 126607648 },
			walk = 126606216,
			run = 626714693,
			jump = 126626749,
		},
	},
	{
		label = "Zombie",
		icon = "🧟",
		visibleToOthers = true,
		r15 = {
			idle = { 616158929, 616160636 },
			walk = 616168032,
			run = 616163682,
			jump = 616161997,
		},
		r6 = {
			idle = { 126607648 },
			walk = 126606216,
			run = 626714693,
			jump = 126626749,
		},
	},
}

function Animations.GetRigLabel()
	if Animations._rigLabel then
		return Animations._rigLabel
	end
	return "?"
end

function Animations.GetEntryMeta(entry)
	if not entry then
		return { rig = "?", visible = "?", icon = "?" }
	end
	local rig = entry.rig or "both"
	local rigLabel = rig == "both" and "R6+R15" or string.upper(rig)
	local visible
	if entry.visibleToOthers == false or entry.procedural then
		visible = "Local"
	else
		visible = "Others"
	end
	return {
		icon = entry.icon or (entry.procedural and "◎" or "✦"),
		rig = rigLabel,
		visible = visible,
	}
end

function Animations.Init(S)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local CP = game:GetService("ContentProvider")
	local Debris = game:GetService("Debris")
	local Lighting = game:GetService("Lighting")
	local LP = Players.LocalPlayer

	local currentTrack = nil
	local currentAnim = nil
	local proceduralConn = nil
	local proceduralStop = false
	local fxHighlight = nil
	local fxBloom = nil
	local fxCC = nil
	local trailAnchor = nil
	local animateDisabled = false
	local savedAnimateIds = nil
	local lifeConns = {}

	Animations._rigLabel = "?"

	local accent = function()
		return S.V or Color3.fromRGB(0, 255, 150)
	end

	local function disconnectLife()
		for _, conn in ipairs(lifeConns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(lifeConns)
	end

	local function getRigKey(hum)
		if hum and hum.RigType == Enum.HumanoidRigType.R6 then
			return "r6"
		end
		return "r15"
	end

	local function refreshRigLabel(hum)
		local key = getRigKey(hum)
		Animations._rigLabel = key == "r6" and "R6" or "R15"
	end

	local function idsForEntry(entry, hum)
		local key = getRigKey(hum)
		local list = entry[key] or entry.ids or {}
		if typeof(list) ~= "table" then
			return {}
		end
		return list
	end

	local function clearFx()
		if fxHighlight then
			pcall(function() fxHighlight:Destroy() end)
			fxHighlight = nil
		end
		if fxBloom then
			pcall(function() fxBloom:Destroy() end)
			fxBloom = nil
		end
		if fxCC then
			pcall(function() fxCC:Destroy() end)
			fxCC = nil
		end
		if trailAnchor then
			pcall(function() trailAnchor:Destroy() end)
			trailAnchor = nil
		end
	end

	local function setAnimateEnabled(char, enabled)
		local animate = char and char:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = not enabled
			animateDisabled = not enabled
		end
	end

	local function restoreAnimateScript(char)
		if not char or not savedAnimateIds then
			return
		end
		local animate = char:FindFirstChild("Animate")
		if not animate then
			return
		end
		for path, id in pairs(savedAnimateIds) do
			local node = animate
			for part in string.gmatch(path, "[^%.]+") do
				node = node and node:FindFirstChild(part)
			end
			if node and node:IsA("Animation") then
				node.AnimationId = id
			end
		end
	end

	local function snapshotAnimate(char)
		local animate = char and char:FindFirstChild("Animate")
		if not animate then
			return nil
		end
		local snap = {}
		local function walk(node, prefix)
			for _, ch in ipairs(node:GetChildren()) do
				local path = prefix == "" and ch.Name or (prefix .. "." .. ch.Name)
				if ch:IsA("Animation") and ch.AnimationId ~= "" then
					snap[path] = ch.AnimationId
				elseif not ch:IsA("LocalScript") then
					walk(ch, path)
				end
			end
		end
		walk(animate, "")
		return snap
	end

	local function setAnimateId(animate, folder, child, id)
		local f = animate:FindFirstChild(folder)
		local anim = f and f:FindFirstChild(child)
		if anim and anim:IsA("Animation") then
			anim.AnimationId = "rbxassetid://" .. tostring(id)
			return true
		end
		return false
	end

	local function applyMovementIds(animate, packIds)
		if packIds.idle then
			local idles = packIds.idle
			if typeof(idles) == "table" then
				if idles[1] then
					setAnimateId(animate, "idle", "Animation1", idles[1])
				end
				if idles[2] then
					setAnimateId(animate, "idle", "Animation2", idles[2])
				end
			end
		end
		if packIds.walk then
			setAnimateId(animate, "walk", "WalkAnim", packIds.walk)
		end
		if packIds.run then
			setAnimateId(animate, "run", "RunAnim", packIds.run)
		end
		if packIds.jump then
			setAnimateId(animate, "jump", "JumpAnim", packIds.jump)
		end
	end

	function Animations.ApplyMovement(pack)
		if not pack then
			return false, "Brak packa"
		end
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hum then
			return false, "Brak postaci"
		end
		local animate = char:FindFirstChild("Animate")
		if not animate then
			return false, "Brak Animate — ta gra może nie wspierać movement packów"
		end
		if not savedAnimateIds then
			savedAnimateIds = snapshotAnimate(char)
		end
		if pack.reset then
			restoreAnimateScript(char)
			S.AnimMovementPack = ""
			return true
		end
		local key = getRigKey(hum)
		local packIds = pack[key]
		if not packIds then
			return false, "Pack niedostępny dla " .. key:upper()
		end
		applyMovementIds(animate, packIds)
		S.AnimMovementPack = pack.label
		return true
	end

	local function reapplyMovementPack()
		if S.AnimMovementPack == nil or S.AnimMovementPack == "" then
			return
		end
		for _, pack in ipairs(Animations.MOVEMENT) do
			if pack.label == S.AnimMovementPack then
				task.defer(function()
					Animations.ApplyMovement(pack)
				end)
				return
			end
		end
	end

	local function startEmoteFx(char)
		clearFx()
		if not char then
			return
		end
		local col = accent()
		fxHighlight = Instance.new("Highlight")
		fxHighlight.Name = "VG_AnimFX"
		fxHighlight.Adornee = char
		fxHighlight.FillColor = col
		fxHighlight.OutlineColor = Color3.new(1, 1, 1)
		fxHighlight.FillTransparency = 0.55
		fxHighlight.OutlineTransparency = 0.2
		fxHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		fxHighlight.Parent = Lighting

		fxBloom = Instance.new("BloomEffect")
		fxBloom.Name = "VG_AnimBloom"
		fxBloom.Intensity = 0.8
		fxBloom.Size = 20
		fxBloom.Threshold = 0.85
		fxBloom.Parent = Lighting

		fxCC = Instance.new("ColorCorrectionEffect")
		fxCC.Name = "VG_AnimCC"
		fxCC.Saturation = 0.25
		fxCC.TintColor = col
		fxCC.Parent = Lighting

		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			trailAnchor = Instance.new("Part")
			trailAnchor.Name = "VG_AnimTrail"
			trailAnchor.Anchored = true
			trailAnchor.CanCollide = false
			trailAnchor.CanQuery = false
			trailAnchor.CanTouch = false
			trailAnchor.Transparency = 1
			trailAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
			trailAnchor.CFrame = root.CFrame
			trailAnchor.Parent = workspace
			local em = Instance.new("ParticleEmitter")
			em.Texture = "rbxassetid://243660064"
			em.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
			em.LightEmission = 1
			em.Rate = 35
			em.Lifetime = NumberRange.new(0.3, 0.7)
			em.Speed = NumberRange.new(1, 4)
			em.SpreadAngle = Vector2.new(30, 30)
			em.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(1, 0),
			})
			em.Parent = trailAnchor
		end
	end

	local function pulseHighlight()
		if not fxHighlight then
			return
		end
		local t = tick()
		fxHighlight.FillTransparency = 0.45 + math.sin(t * 8) * 0.15
		if fxCC then
			fxCC.Brightness = math.sin(t * 6) * 0.08
		end
		if fxBloom then
			fxBloom.Intensity = 0.7 + math.sin(t * 5) * 0.25
		end
	end

	local function stopCurrent()
		proceduralStop = true
		if proceduralConn then
			proceduralConn:Disconnect()
			proceduralConn = nil
		end
		if currentTrack then
			pcall(function()
				currentTrack:Stop(0.15)
			end)
			currentTrack = nil
		end
		if currentAnim then
			pcall(function()
				currentAnim:Destroy()
			end)
			currentAnim = nil
		end
		if animateDisabled and LP.Character then
			setAnimateEnabled(LP.Character, true)
		end
		clearFx()
	end

	local function waitForAnimator(hum, timeout)
		timeout = timeout or 6
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			return animator
		end
		local ok, result = pcall(function()
			return hum:WaitForChild("Animator", timeout)
		end)
		if ok and result then
			return result
		end
		return nil
	end

	local function collectAnimateRoots()
		local roots = {}
		local char = LP.Character
		if char then
			local a = char:FindFirstChild("Animate")
			if a then
				table.insert(roots, a)
			end
		end
		local sp = game:GetService("StarterPlayer")
		local sc = sp:FindFirstChild("StarterCharacterScripts")
		if sc then
			local a = sc:FindFirstChild("Animate")
			if a then
				table.insert(roots, a)
			end
		end
		local rep = game:GetService("ReplicatedStorage")
		for _, name in ipairs({ "Animate", "Animations", "Emotes" }) do
			local f = rep:FindFirstChild(name, true)
			if f then
				table.insert(roots, f)
			end
		end
		return roots
	end

	local function findGameAnimation(entry)
		local names = entry.folders or {}
		for _, root in ipairs(collectAnimateRoots()) do
			for _, folderName in ipairs(names) do
				local folder = root:FindFirstChild(folderName, true)
				if folder then
					local anim = folder:FindFirstChildWhichIsA("Animation", true)
					if anim and anim.AnimationId ~= "" then
						return anim:Clone()
					end
				end
			end
		end
		return nil
	end

	local function tryGetObjects(id)
		local getter = game.GetObjects or (typeof(getobjects) == "function" and getobjects) or nil
		if not getter then
			return nil
		end
		local ok, objs = pcall(function()
			return getter("rbxassetid://" .. tostring(id))
		end)
		if not ok or not objs or not objs[1] then
			return nil
		end
		local root = objs[1]
		if root:IsA("Animation") then
			return root:Clone()
		end
		local anim = root:FindFirstChildWhichIsA("Animation", true)
		if anim then
			return anim:Clone()
		end
		return nil
	end

	local function makeAnimation(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(id)
		return anim
	end

	local function tryLoadTrack(animator, anim)
		pcall(function()
			CP:PreloadAsync({ anim })
		end)
		local ok, result = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok then
			return result
		end
		return nil
	end

	local function tryChatEmote(entry)
		if not entry.chat then
			return false
		end
		return pcall(function()
			local msg = "/e " .. entry.chat
			if LP.Chat then
				LP:Chat(msg)
			else
				local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
				local say = ev and ev:FindFirstChild("SayMessageRequest")
				if say then
					say:FireServer(msg, "All")
				else
					error("no chat")
				end
			end
		end)
	end

	local function shouldLoop(entry)
		if entry.once then
			return false
		end
		if S.AnimLoop == false then
			return false
		end
		if entry.procedural then
			return true
		end
		return true
	end

	local function playTrack(track, entry, char)
		currentTrack = track
		currentTrack.Priority = Enum.AnimationPriority.Action4
		currentTrack.Looped = shouldLoop(entry)
		local weight = math.clamp(S.AnimWeight or 1, 0.05, 1)
		local speed = math.clamp(S.AnimSpeed or 1, 0.1, 3)
		currentTrack:Play(0.15, weight, speed)
		setAnimateEnabled(char, false)
		if not shouldLoop(entry) then
			currentTrack.Stopped:Connect(function()
				if currentTrack == track and LP.Character == char then
					setAnimateEnabled(char, true)
				end
			end)
		end
		S.LastAnim = entry.label
		startEmoteFx(char)
	end

	local function getRigParts(char)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		return hrp
	end

	local function spawnProceduralBurst(hrp, col)
		if not hrp then
			return
		end
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = hrp.CFrame
		p.Parent = workspace
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxassetid://243660064"
		em.Color = ColorSequence.new(col)
		em.LightEmission = 1
		em.Rate = 0
		em.Lifetime = NumberRange.new(0.3, 0.6)
		em.Speed = NumberRange.new(6, 14)
		em.SpreadAngle = Vector2.new(360, 360)
		em.Parent = p
		em:Emit(12)
		Debris:AddItem(p, 1)
	end

	local function playProcedural(kind, entry)
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return false, "Brak postaci"
		end
		local hrp = getRigParts(char)
		if not hrp then
			return false, "Brak HRP"
		end

		proceduralStop = false
		local baseCF = hrp.CFrame
		local tStart = tick()
		local savedAuto = hum.AutoRotate
		hum.AutoRotate = false
		setAnimateEnabled(char, false)
		startEmoteFx(char)
		local col = accent()
		local burstTick = 0
		local speedMul = math.clamp(S.AnimSpeed or 1, 0.1, 3)

		local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end
		proceduralConn = RS.RenderStepped:Connect(perfWrap("Animations.Procedural", function()
			if proceduralStop or not char.Parent or hum.Health <= 0 then
				return
			end
			local now = tick()
			local t = now * speedMul
			local elapsed = (now - tStart) * speedMul
			if trailAnchor and hrp.Parent then
				trailAnchor.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0)
			end
			pulseHighlight()

			if t - burstTick > 0.35 then
				burstTick = t
				if kind == "thunder" or kind == "disco" or kind == "spin" then
					spawnProceduralBurst(hrp, col)
				end
			end

			if kind == "twerk" then
				local w = math.sin(t * 18)
				hrp.CFrame = baseCF * CFrame.new(0, math.abs(w) * 0.12, 0) * CFrame.Angles(w * 0.42, 0, w * 0.35)
			elseif kind == "floss" then
				local w = math.sin(t * 12)
				hrp.CFrame = baseCF * CFrame.Angles(0, w * 0.95, w * 0.28)
			elseif kind == "griddy" then
				local w = math.sin(t * 14)
				hrp.CFrame = baseCF
					* CFrame.new(w * 0.22, math.abs(math.sin(t * 10)) * 0.14, 0)
					* CFrame.Angles(0, w * 0.35, w * 0.12)
			elseif kind == "spin" then
				hrp.CFrame = baseCF * CFrame.Angles(math.sin(t * 4) * 0.15, elapsed * 9, math.cos(t * 4) * 0.12)
			elseif kind == "thunder" then
				local shake = math.sin(t * 28) * 0.08
				hrp.CFrame = baseCF
					* CFrame.new(shake, math.abs(math.sin(t * 20)) * 0.1, shake * 0.5)
					* CFrame.Angles(shake * 2, elapsed * 2.5, shake)
			elseif kind == "matrix" then
				local hover = math.sin(t * 3) * 0.15
				hrp.CFrame = baseCF
					* CFrame.new(0, hover + 0.4, 0)
					* CFrame.Angles(math.rad(90), elapsed * 1.2, 0)
			elseif kind == "disco" then
				local w = math.sin(t * 16)
				hrp.CFrame = baseCF
					* CFrame.new(0, math.abs(w) * 0.1, 0)
					* CFrame.Angles(0, elapsed * 12, w * 0.4)
				if fxHighlight then
					fxHighlight.FillColor = Color3.fromHSV((t * 0.8) % 1, 0.9, 1)
				end
			elseif kind == "levitate" then
				local bob = math.sin(t * 2.5) * 0.25
				hrp.CFrame = baseCF * CFrame.new(0, 1.2 + bob, 0) * CFrame.Angles(0, elapsed * 1.5, 0)
			end
		end))

		S.LastAnim = entry.label .. " (local FX)"
		Animations._stopProcedural = function()
			proceduralStop = true
			if proceduralConn then
				proceduralConn:Disconnect()
				proceduralConn = nil
			end
			hum.AutoRotate = savedAuto
			if hrp and hrp.Parent then
				hrp.CFrame = baseCF
			end
			setAnimateEnabled(char, true)
			clearFx()
		end
		return true
	end

	local function tryPlayAssets(entry, hum, char)
		local animator = waitForAnimator(hum)
		if not animator then
			return false, "Brak Animator (serwer) — animacja nie zreplikuje"
		end

		local gameAnim = findGameAnimation(entry)
		if gameAnim then
			local track = tryLoadTrack(animator, gameAnim)
			if track then
				currentAnim = gameAnim
				playTrack(track, entry, char)
				return true
			end
			pcall(function() gameAnim:Destroy() end)
		end

		for _, id in ipairs(idsForEntry(entry, hum)) do
			local fromObjects = tryGetObjects(id)
			if fromObjects then
				local track = tryLoadTrack(animator, fromObjects)
				if track then
					currentAnim = fromObjects
					playTrack(track, entry, char)
					return true
				end
				pcall(function() fromObjects:Destroy() end)
			end

			local anim = makeAnimation(id)
			local track = tryLoadTrack(animator, anim)
			if track then
				currentAnim = anim
				playTrack(track, entry, char)
				return true
			end
			pcall(function() anim:Destroy() end)
		end

		return false
	end

	function Animations.Play(entry)
		if not entry then
			return false, "Brak animacji"
		end
		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return false, "Brak postaci"
		end
		refreshRigLabel(hum)

		local rigKey = getRigKey(hum)
		if entry.rig == "r15" and rigKey == "r6" then
			return false, entry.label .. " wymaga R15"
		end
		if entry.rig == "r6" and rigKey == "r15" then
			return false, entry.label .. " wymaga R6"
		end

		stopCurrent()
		if Animations._stopProcedural then
			pcall(Animations._stopProcedural)
			Animations._stopProcedural = nil
		end

		if S.AnimPreferChat ~= false and entry.chat then
			if tryChatEmote(entry) then
				S.LastAnim = entry.label .. " (chat)"
				startEmoteFx(char)
				return true
			end
		end

		if not entry.procedural then
			local ok, err = tryPlayAssets(entry, hum, char)
			if ok then
				return true
			end
			if err and err ~= false then
				-- continue to fallbacks
			end
		end

		if entry.procedural then
			local ok, err = playProcedural(entry.procedural, entry)
			if ok then
				return true
			end
			if err then
				return false, err
			end
		end

		if S.AnimPreferChat == false and entry.chat then
			if tryChatEmote(entry) then
				S.LastAnim = entry.label .. " (chat)"
				startEmoteFx(char)
				return true
			end
		end

		if entry.procedural then
			return playProcedural(entry.procedural, entry)
		end

		return false, "Gra blokuje animacje — spróbuj /e lub procedural (◎)"
	end

	function Animations.Stop()
		stopCurrent()
		if Animations._stopProcedural then
			pcall(Animations._stopProcedural)
			Animations._stopProcedural = nil
		end
		S.LastAnim = nil
		return true
	end

	local function bindCharacter(char)
		disconnectLife()
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		refreshRigLabel(hum)
		savedAnimateIds = nil

		table.insert(lifeConns, hum.Died:Connect(function()
			Animations.Stop()
		end))
		table.insert(lifeConns, hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Physics or new == Enum.HumanoidStateType.Ragdoll then
				Animations.Stop()
			end
		end))
		table.insert(lifeConns, char.AncestryChanged:Connect(function(_, parent)
			if not parent then
				Animations.Stop()
			end
		end))

		task.defer(function()
			Animations.Stop()
			reapplyMovementPack()
		end)
	end

	LP.CharacterAdded:Connect(bindCharacter)
	if LP.Character then
		task.defer(function()
			bindCharacter(LP.Character)
		end)
	end

	if _G.VANGUARD then
		_G.VANGUARD.registerCleanup(function()
			Animations.Stop()
			if LP.Character then
				restoreAnimateScript(LP.Character)
			end
		end)
	end
end

return Animations
