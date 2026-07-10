-- Plik: workspace/Vanguard/Misc.lua

local Misc = {}

local VG_PREFIX = "VG_HBX_"

function Misc.Init(S, TF, Util)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local LP = Players.LocalPlayer

	local expandRoot = nil
	local expandParts = {}
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

	local function getRoot()
		if expandRoot and expandRoot.Parent then
			return expandRoot
		end
		expandRoot = workspace:FindFirstChild("VG_Hitboxes")
		if not expandRoot then
			expandRoot = Instance.new("Folder")
			expandRoot.Name = "VG_Hitboxes"
			expandRoot.Parent = workspace
		end
		return expandRoot
	end

	local function charId(char)
		return tostring(char:GetDebugId())
	end

	local function boxName(char, slotName)
		return VG_PREFIX .. charId(char) .. "_" .. slotName
	end

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
		if expandParts[char] then
			for _, data in pairs(expandParts[char]) do
				if data.part and data.part.Parent then
					data.part:Destroy()
				end
			end
			expandParts[char] = nil
		end
		local root = workspace:FindFirstChild("VG_Hitboxes")
		if root and char then
			local id = charId(char)
			for _, ch in ipairs(root:GetChildren()) do
				if string.find(ch.Name, id, 1, true) then
					ch:Destroy()
				end
			end
		end
	end

	local function ensureExpand(char, anchor, slotName, mul)
		if not anchor or not anchor:IsA("BasePart") or not anchor.Parent then
			return nil
		end
		local name = boxName(char, slotName)
		local root = getRoot()
		local box = root:FindFirstChild(name)
		if not box then
			box = Instance.new("Part")
			box.Name = name
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = true
			box.CanTouch = false
			box.Massless = true
			box.Transparency = 1
			box.CastShadow = false
			box.Material = Enum.Material.SmoothPlastic
			box.Parent = root
		end
		box.Size = anchor.Size * mul
		box.CFrame = anchor.CFrame

		expandParts[char] = expandParts[char] or {}
		expandParts[char][slotName] = {
			part = box,
			anchor = anchor,
			mul = mul,
		}
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

		if S.HeadSize then
			for _, name in ipairs(HEAD_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				if anchor then
					ensureExpand(char, anchor, name, headMul)
				end
			end
		else
			if expandParts[char] then
				for _, name in ipairs(HEAD_SLOTS) do
					local data = expandParts[char][name]
					if data and data.part then
						data.part:Destroy()
						expandParts[char][name] = nil
					end
				end
			end
		end

		if S.HitboxSize then
			for _, name in ipairs(HITBOX_SLOTS) do
				local anchor = Util.resolveBodyPart(char, name)
				if anchor then
					ensureExpand(char, anchor, name, boxMul)
				end
			end
		else
			if expandParts[char] then
				for _, name in ipairs(HITBOX_SLOTS) do
					local data = expandParts[char][name]
					if data and data.part then
						data.part:Destroy()
						expandParts[char][name] = nil
					end
				end
			end
		end

		if expandParts[char] and next(expandParts[char]) == nil then
			expandParts[char] = nil
		end
	end

	local function refreshAll()
		if not S.HeadSize and not S.HitboxSize then
			for char in pairs(expandParts) do
				if char.Parent then
					clearExpands(char)
				end
			end
			table.clear(expandParts)
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

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.RenderStepped:Connect(perfWrap("Misc.Render", function()
		if S.Unloaded then
			return
		end
		if not S.HeadSize and not S.HitboxSize then
			return
		end
		for char, slots in pairs(expandParts) do
			if not char or not char.Parent then
				clearExpands(char)
			else
				for slotName, data in pairs(slots) do
					local anchor = Util.resolveBodyPart(char, slotName)
					if anchor and data.part and data.part.Parent then
						data.part.CFrame = anchor.CFrame
						data.part.Size = anchor.Size * data.mul
						data.anchor = anchor
					elseif data.part then
						data.part:Destroy()
						slots[slotName] = nil
					end
				end
			end
		end
	end))

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

	RS.Heartbeat:Connect(perfWrap("Misc.Refresh", function()
		if S.Unloaded then
			return
		end
		if not S.HeadSize and not S.HitboxSize then
			return
		end
		if tick() - lastRefresh < 1 then
			return
		end
		lastRefresh = tick()
		pcall(refreshAll)
	end))

	if _G.VANGUARD then
		_G.VANGUARD.registerCleanup(function()
			for char in pairs(expandParts) do
				if char and char.Parent then
					clearExpands(char)
				end
			end
			table.clear(expandParts)
			pcall(function()
				local root = workspace:FindFirstChild("VG_Hitboxes")
				if root then
					root:Destroy()
				end
			end)
		end)
	end
end

return Misc
