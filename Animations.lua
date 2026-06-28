-- Plik: workspace/Vanguard/Animations.lua

local Animations = {}

Animations.LIST = {
	{ label = "Dance", chat = "dance", folders = { "dance", "dance2", "dance3" }, ids = { 507771019, 507776879, 507777623, 507771955, 507772104 } },
	{ label = "Dance 2", chat = "dance2", folders = { "dance2" }, ids = { 507776879, 507776043, 507776720 } },
	{ label = "Dance 3", chat = "dance3", folders = { "dance3" }, ids = { 507777623, 507777268, 507777451 } },
	{ label = "Wave", chat = "wave", folders = { "wave" }, ids = { 507770239 } },
	{ label = "Point", chat = "point", folders = { "point" }, ids = { 507770453 } },
	{ label = "Laugh", chat = "laugh", folders = { "laugh" }, ids = { 507770818 } },
	{ label = "Cheer", chat = "cheer", folders = { "cheer" }, ids = { 507770677 } },
	{ label = "Sit", chat = "sit", folders = { "sit" }, ids = { 2506281703, 507767968 } },
}

function Animations.Init(S)
	local Players = game:GetService("Players")
	local CP = game:GetService("ContentProvider")
	local LP = Players.LocalPlayer

	local currentTrack = nil
	local currentAnim = nil

	local function stopCurrent()
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
	end

	local function ensureAnimator(hum)
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		return animator
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
		local rs = game:GetService("ReplicatedStorage")
		for _, name in ipairs({ "Animate", "Animations", "Emotes" }) do
			local f = rs:FindFirstChild(name, true)
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

	local function makeAnimation(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(id)
		return anim
	end

	local function tryLoadTrack(animator, anim)
		local track
		pcall(function()
			CP:PreloadAsync({ anim })
		end)
		local ok, result = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok then
			track = result
		end
		return track
	end

	local function tryChatEmote(entry)
		if not entry.chat then
			return false
		end
		local ok = pcall(function()
			local msg = "/e " .. entry.chat
			if LP.Chat then
				LP:Chat(msg)
			else
				local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
				local say = ev and ev:FindFirstChild("SayMessageRequest")
				if say then
					say:FireServer(msg, "All")
				end
			end
		end)
		return ok
	end

	local function playTrack(track, entry)
		currentTrack = track
		currentTrack.Priority = Enum.AnimationPriority.Action
		currentTrack.Looped = entry.chat ~= "point" and entry.chat ~= "wave" and entry.chat ~= "laugh"
		currentTrack:Play(0.15, 1, 1)
		S.LastAnim = entry.label
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
		local animator = ensureAnimator(hum)
		stopCurrent()

		local gameAnim = findGameAnimation(entry)
		if gameAnim then
			local ok, track = pcall(function()
				return tryLoadTrack(animator, gameAnim)
			end)
			if ok and track then
				currentAnim = gameAnim
				playTrack(track, entry)
				return true
			end
			pcall(function() gameAnim:Destroy() end)
		end

		for _, id in ipairs(entry.ids or {}) do
			local anim = makeAnimation(id)
			local ok, track = pcall(function()
				return tryLoadTrack(animator, anim)
			end)
			if ok and track then
				currentAnim = anim
				playTrack(track, entry)
				return true
			end
			pcall(function() anim:Destroy() end)
		end

		if tryChatEmote(entry) then
			S.LastAnim = entry.label .. " (chat)"
			return true
		end

		return false, "Gra blokuje animacje — użyj /e " .. (entry.chat or "?")
	end

	function Animations.Stop()
		stopCurrent()
		S.LastAnim = nil
		return true
	end

	LP.CharacterAdded:Connect(function()
		task.defer(stopCurrent)
	end)
end

return Animations
