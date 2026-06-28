-- Plik: workspace/Vanguard/Misc.lua

local Misc = {}

local VG_PREFIX = "VG_HBX_"

function Misc.Init(S, TF, Util)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local LP = Players.LocalPlayer

	local trackedChars = {}
	local botList = {}
	local botScanAt = 0
	local lastRefresh = 0

	local HEAD_SLOTS = { "Head" }
	local HITBOX_SLOTS = {
		"HumanoidRootPart",
		"UpperTorso",
		"Torso",
		"LowerTorso",
	}

	local function isAliveChar(char)
		if not char or not char.Parent then
			return false
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		return hum and hum.Health > 0
	end

	local function shouldAffect(plr)
		if not plr then
			return true
		end
		if plr == LP then
			return false
		end
		if S.MiscAffectFriends then
			return true
		end
		if TF and TF.shouldExclude(S, LP, plr) then
			return false
		end
		if S.ExcludeTeam and plr.Team and LP.Team and plr.Team == LP.Team then
			return false
		end
		return true
	end

	local function clearExpands(char)
		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("BasePart") and string.sub(ch.Name, 1, #VG_PREFIX) == VG_PREFIX then
				ch:Destroy()
			end
		end
		trackedChars[char] = nil
	end

	local function ensureExpand(char, anchor, slotName, mul)
		if not anchor or not anchor:IsA("BasePart") or not anchor.Parent then
			return nil
		end
		local boxName = VG_PREFIX .. slotName
		local box = char:FindFirstChild(boxName)
		if not box then
			box = Instance.new("Part")
			box.Name = boxName
			box.Anchored = false
			box.CanCollide = false
			box.CanQuery = true
			box.CanTouch = false
			box.Massless = true
			box.Transparency = 1
			box.CastShadow = false
			box.Material = Enum.Material.SmoothPlastic
			box.CFrame = anchor.CFrame
			box.Size = anchor.Size * mul
			box.Parent = char
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = box
			weld.Parent = box
		else
			box.Size = anchor.Size * mul
		end
		return box
	end

	local function applyChar(char, plr)
		if not char or char == LP.Character then
			return
		end
		if plr and not shouldAffect(plr) then
			clearExpands(char)
			return
		end

		if not S.HeadSize and not S.HitboxSize then
			clearExpands(char)
			return
		end

		local headMul = math.clamp(S.HeadSizeScale or 2, 1, 6)
		local boxMul = math.clamp(S.HitboxSizeScale or 1.5, 1, 5)
		local any = false

		if S.HeadSize then
			for _, name in ipairs(HEAD_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				if anchor and ensureExpand(char, anchor, name, headMul) then
					any = true
				end
			end
		else
			for _, name in ipairs(HEAD_SLOTS) do
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if box then
					box:Destroy()
				end
			end
		end

		if S.HitboxSize then
			for _, name in ipairs(HITBOX_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				if anchor and ensureExpand(char, anchor, name, boxMul) then
					any = true
				end
			end
		else
			for _, name in ipairs(HITBOX_SLOTS) do
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if box then
					box:Destroy()
				end
			end
		end

		if any then
			trackedChars[char] = { headMul = headMul, boxMul = boxMul }
		else
			trackedChars[char] = nil
		end
	end

	local function refreshAll()
		if not S.HeadSize and not S.HitboxSize then
			for char in pairs(trackedChars) do
				if char.Parent then
					clearExpands(char)
				end
			end
			table.clear(trackedChars)
			return
		end

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then
				applyChar(plr.Character, plr)
			end
		end

		if S.MiscBots ~= false then
			if tick() - botScanAt > 2 then
				botScanAt = tick()
				Util.refreshBotList(botList, true, LP)
			end
			for _, model in ipairs(botList) do
				if model.Parent and isAliveChar(model) then
					applyChar(model, nil)
				end
			end
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				applyChar(char, plr)
			end)
			char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					clearExpands(char)
				end
			end)
		end)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			task.defer(function()
				applyChar(plr.Character, plr)
			end)
		end
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				applyChar(char, plr)
			end)
			char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					clearExpands(char)
				end
			end)
		end)
	end

	RS.Heartbeat:Connect(function()
		if not S.HeadSize and not S.HitboxSize then
			return
		end
		if tick() - lastRefresh < 2 then
			return
		end
		lastRefresh = tick()
		pcall(refreshAll)
	end)
end

return Misc
