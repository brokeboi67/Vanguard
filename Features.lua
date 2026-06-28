-- Plik: workspace/Vanguard/Features.lua

local Features = {}

function Features.Init(S, ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local Cross = C("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 5, 0, 5),
		BackgroundColor3 = S.V,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Cross })

	local HitGroup = C("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 18, 0, 18),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 41,
		Parent = ParentGUI,
	})
	for i = 1, 4 do
		local ln = C("Frame", {
			Size = UDim2.new(0, 7, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Rotation = (i - 1) * 90 + 45,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = HitGroup,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ln })
	end

	local SpecPanel = C("Frame", {
		Name = "Spectators",
		Size = UDim2.new(0, 170, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -184, 0, 72),
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = 35,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SpecPanel })
	C("UIStroke", { Color = Color3.fromRGB(40, 40, 48), Thickness = 1, Parent = SpecPanel })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = SpecPanel,
	})
	local SpecTitle = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "SPECTATORS",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(130, 130, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = SpecPanel,
	})
	local SpecList = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = SpecPanel,
	})
	C("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SpecList })

	local DmgPanel = C("Frame", {
		Name = "DamageLog",
		Size = UDim2.new(0, 200, 0, 100),
		Position = UDim2.new(0, 14, 1, -114),
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 35,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = DmgPanel })
	C("UIStroke", { Color = Color3.fromRGB(40, 40, 48), Thickness = 1, Parent = DmgPanel })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = DmgPanel,
	})
	local DmgList = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = DmgPanel,
	})
	C("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = DmgList })

	local dmgEntries = {}
	local hitHideToken = 0

	local function flashHitmarker(dmg)
		hitHideToken = hitHideToken + 1
		local token = hitHideToken
		HitGroup.Visible = true
		for _, ch in ipairs(HitGroup:GetChildren()) do
			if ch:IsA("Frame") then
				ch.BackgroundColor3 = dmg >= 50 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
			end
		end
		task.delay(0.18, function()
			if token == hitHideToken then
				HitGroup.Visible = false
			end
		end)
	end

	local function addDmgLog(name, dmg)
		local row = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = string.format("-%.0f  %s", dmg, name),
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(220, 220, 228),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = DmgList,
		})
		table.insert(dmgEntries, 1, row)
		if #dmgEntries > 6 then
			local old = table.remove(dmgEntries)
			pcall(function() old:Destroy() end)
		end
		for i, lbl in ipairs(dmgEntries) do
			lbl.LayoutOrder = i
		end
	end

	local humWatch = {}

	local function bindHum(hum, plrName)
		if humWatch[hum] then
			return
		end
		local last = hum.Health
		humWatch[hum] = hum.HealthChanged:Connect(function(hp)
			if not S.Hitmarker and not S.DamageLog then
				last = hp
				return
			end
			if S.LastShotAt and tick() - S.LastShotAt > 0.45 then
				last = hp
				return
			end
			if hp < last then
				local dmg = last - hp
				if S.Hitmarker then
					flashHitmarker(dmg)
				end
				if S.DamageLog then
					addDmgLog(plrName or "Target", dmg)
				end
			end
			last = hp
		end)
		hum.AncestryChanged:Connect(function(_, parent)
			if not parent and humWatch[hum] then
				humWatch[hum]:Disconnect()
				humWatch[hum] = nil
			end
		end)
	end

	local function scanHumanoids()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP and plr.Character then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					bindHum(hum, plr.Name)
				end
			end
		end
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local hrp = model:FindFirstChild("HumanoidRootPart")
				if hum and hrp and model ~= LP.Character then
					bindHum(hum, model.Name)
				end
			end
		end
	end

	local function rayHum()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
		if hit and hit.Instance then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model then
				return model:FindFirstChildOfClass("Humanoid")
			end
		end
		return nil
	end

	UIS.InputBegan:Connect(function(input, processed)
		if S.MenuOpen or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.LastShotAt = tick()
			local hum = rayHum()
			if hum then
				S.LastShotHum = hum
			end
		end
	end)

	local function isLikelySpectating(plr)
		if plr == LP then
			return false
		end
		if plr:GetAttribute("Spectating") == true then
			return true
		end
		local char = plr.Character
		if not char then
			return true
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			return true
		end
		return false
	end

	local function updSpectators()
		if not S.Spectators then
			SpecPanel.Visible = false
			return
		end
		SpecPanel.Visible = true
		for _, ch in ipairs(SpecList:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		local found = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if isLikelySpectating(plr) then
				table.insert(found, plr.Name)
			end
		end
		if #found == 0 then
			C("TextLabel", {
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "Brak (heurystyka)",
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(90, 90, 100),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Parent = SpecList,
			})
		else
			for i, name in ipairs(found) do
				C("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					Text = name,
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(200, 200, 210),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = i,
					Parent = SpecList,
				})
			end
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			task.defer(function()
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					bindHum(hum, plr.Name)
				end
			end)
		end)
	end)

	RS.Heartbeat:Connect(function()
		Cross.Visible = S.Crosshair and not S.MenuOpen
		DmgPanel.Visible = S.DamageLog and not S.MenuOpen
		if S.Crosshair then
			local sz = math.clamp(S.CrosshairSize or 5, 2, 12)
			Cross.Size = UDim2.new(0, sz, 0, sz)
			Cross.BackgroundColor3 = S.V
		end
	end)

	local specAt = 0
	RS.Heartbeat:Connect(function()
		if tick() - specAt < 0.5 then
			return
		end
		specAt = tick()
		scanHumanoids()
		updSpectators()
	end)
end

return Features
