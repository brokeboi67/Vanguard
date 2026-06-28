-- Plik: workspace/Vanguard/Misc.lua

local Misc = {}

function Misc.Init(S, TF, Util)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local LP = Players.LocalPlayer

	local origSizes = {}
	local trackedChars = {}

	local HEAD_NAMES = { "Head" }
	local HITBOX_NAMES = {
		"HumanoidRootPart",
		"UpperTorso",
		"Torso",
		"LowerTorso",
		"Hitbox",
		"HeadHB",
		"RootHitbox",
	}

	local function rememberSize(part)
		if not origSizes[part] then
			origSizes[part] = part.Size
		end
	end

	local function restorePart(part)
		local orig = origSizes[part]
		if orig and part.Parent then
			part.Size = orig
		end
	end

	local function restoreChar(char)
		for part, _ in pairs(origSizes) do
			if part.Parent and part:IsDescendantOf(char) then
				restorePart(part)
			end
		end
		trackedChars[char] = nil
	end

	local function shouldAffect(plr)
		if not plr or plr == LP then
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

	local function scalePart(part, mul)
		if not part or not part:IsA("BasePart") then
			return
		end
		rememberSize(part)
		part.Size = origSizes[part] * mul
		part.CanCollide = false
		part.Massless = true
	end

	local function applyChar(char, plr)
		if not char or char == LP.Character then
			return
		end
		if plr and not shouldAffect(plr) then
			restoreChar(char)
			return
		end

		local headMul = math.clamp(S.HeadSizeScale or 2, 1, 6)
		local boxMul = math.clamp(S.HitboxSizeScale or 1.5, 1, 5)

		if not S.HeadSize then
			for _, name in ipairs(HEAD_NAMES) do
				local part = Util.resolveBodyPart(char, name)
				if part then
					restorePart(part)
				end
			end
		else
			for _, name in ipairs(HEAD_NAMES) do
				local part = Util.resolveBodyPart(char, name)
				if part then
					scalePart(part, headMul)
				end
			end
		end

		if not S.HitboxSize then
			for _, name in ipairs(HITBOX_NAMES) do
				local part = Util.resolveBodyPart(char, name)
				if part then
					restorePart(part)
				end
			end
			for _, inst in ipairs(char:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Name:lower():find("hitbox", 1, true) then
					restorePart(inst)
				end
			end
		else
			for _, name in ipairs(HITBOX_NAMES) do
				local part = Util.resolveBodyPart(char, name)
				if part then
					scalePart(part, boxMul)
				end
			end
			for _, inst in ipairs(char:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Name:lower():find("hitbox", 1, true) then
					scalePart(inst, boxMul)
				end
			end
		end

		if S.HeadSize or S.HitboxSize then
			trackedChars[char] = true
		else
			trackedChars[char] = nil
		end
	end

	local function scan()
		if not S.HeadSize and not S.HitboxSize then
			for char in pairs(trackedChars) do
				if char.Parent then
					restoreChar(char)
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
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				applyChar(char, plr)
			end)
			char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					restoreChar(char)
				end
			end)
		end)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		plr.CharacterAdded:Connect(function(char)
			char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					restoreChar(char)
				end
			end)
		end)
	end

	RS.Heartbeat:Connect(function()
		scan()
	end)
end

return Misc
