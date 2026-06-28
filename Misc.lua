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
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BasePart") and string.sub(inst.Name, 1, #VG_PREFIX) == VG_PREFIX then
				inst:Destroy()
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
			box.Parent = char
		end
		box.Size = anchor.Size * mul
		box.CFrame = anchor.CFrame
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
		end

		if S.HitboxSize then
			for _, name in ipairs(HITBOX_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				if anchor and ensureExpand(char, anchor, name, boxMul) then
					any = true
				end
			end
			for _, inst in ipairs(char:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Name:lower():find("hitbox", 1, true) then
					local slot = "X_" .. inst.Name
					if ensureExpand(char, inst, slot, boxMul) then
						any = true
					end
				end
			end
		end

		if not S.HeadSize and not S.HitboxSize then
			clearExpands(char)
			return
		end

		if not S.HeadSize then
			for _, name in ipairs(HEAD_SLOTS) do
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if box then
					box:Destroy()
				end
			end
		end

		if not S.HitboxSize then
			for _, name in ipairs(HITBOX_SLOTS) do
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if box then
					box:Destroy()
				end
			end
			for _, inst in ipairs(char:GetDescendants()) do
				if inst:IsA("BasePart") and string.sub(inst.Name, 1, #VG_PREFIX) == VG_PREFIX then
					if string.find(inst.Name, "X_", #VG_PREFIX + 1, true) then
						inst:Destroy()
					end
				end
			end
		end

		if any then
			trackedChars[char] = true
		end
	end

	local function resyncExpands(char)
		if not trackedChars[char] then
			return
		end
		local headMul = math.clamp(S.HeadSizeScale or 2, 1, 6)
		local boxMul = math.clamp(S.HitboxSizeScale or 1.5, 1, 5)
		if S.HeadSize then
			for _, name in ipairs(HEAD_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if anchor and box and box:IsA("BasePart") then
					box.Size = anchor.Size * headMul
					box.CFrame = anchor.CFrame
				end
			end
		end
		if S.HitboxSize then
			for _, name in ipairs(HITBOX_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				local box = char:FindFirstChild(VG_PREFIX .. name)
				if anchor and box and box:IsA("BasePart") then
					box.Size = anchor.Size * boxMul
					box.CFrame = anchor.CFrame
				end
			end
		end
	end

	local function scan()
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
				resyncExpands(plr.Character)
			end
		end

		if S.MiscBots ~= false then
			if tick() - botScanAt > 1.5 then
				botScanAt = tick()
				Util.refreshBotList(botList, true, LP)
			end
			for _, model in ipairs(botList) do
				if model.Parent and isAliveChar(model) then
					applyChar(model, nil)
					resyncExpands(model)
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
		plr.CharacterAdded:Connect(function(char)
			char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					clearExpands(char)
				end
			end)
		end)
	end

	RS.Heartbeat:Connect(function()
		pcall(scan)
	end)
end

return Misc
