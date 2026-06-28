-- Plik: workspace/Vanguard/Features.lua

local Features = {}

function Features.Init(S, ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera
	local ACC = S.V

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local function Tween(obj, info, props)
		local tw = TS:Create(obj, info, props)
		tw:Play()
		return tw
	end

	local Cross = C("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 5, 0, 5),
		BackgroundColor3 = ACC,
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

	-- // Spectator panel
	local SpecPanel = C("Frame", {
		Name = "Spectators",
		Size = UDim2.new(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -266, 0, 88),
		BackgroundColor3 = Color3.fromRGB(26, 26, 32),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 35,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = SpecPanel })
	C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.65, Parent = SpecPanel })

	local SpecHeader = C("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = SpecPanel,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		Parent = SpecHeader,
	})
	local SpecTitle = C("TextLabel", {
		Size = UDim2.new(1, -50, 0, 14),
		Position = UDim2.new(0, 14, 0, 10),
		BackgroundTransparency = 1,
		Text = "SPECTATORS",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextStrokeTransparency = 0.7,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = SpecHeader,
	})
	local SpecCount = C("TextLabel", {
		Size = UDim2.new(0, 28, 0, 20),
		Position = UDim2.new(1, -38, 0, 9),
		BackgroundColor3 = Color3.fromRGB(36, 36, 44),
		Text = "0",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = ACC,
		Parent = SpecHeader,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = SpecCount })

	local SpecBody = C("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 10, 0, 42),
		BackgroundTransparency = 1,
		Parent = SpecPanel,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = SpecBody,
	})
	C("UIPadding", {
		PaddingBottom = UDim.new(0, 10),
		Parent = SpecBody,
	})

	local SpecEmpty = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "Nikt nie obserwuje",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(150, 150, 162),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		LayoutOrder = 0,
		Parent = SpecBody,
	})

	local specRows = {}
	local avatarCache = {}

	local function loadAvatar(img, userId)
		if avatarCache[userId] then
			img.Image = avatarCache[userId]
			return
		end
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok and content and img.Parent then
				avatarCache[userId] = content
				img.Image = content
			end
		end)
	end

	local function createSpecRow(plr, order)
		local row = C("Frame", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Color3.fromRGB(34, 34, 42),
			BackgroundTransparency = 0,
			LayoutOrder = order,
			Parent = SpecBody,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
		C("UIStroke", { Color = Color3.fromRGB(50, 50, 60), Thickness = 1, Parent = row })

		row.Position = UDim2.new(0, 14, 0, 0)
		row.BackgroundTransparency = 1
		Tween(row, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
			Position = UDim2.new(0, 0, 0, 0),
		})

		local avWrap = C("Frame", {
			Size = UDim2.new(0, 34, 0, 34),
			Position = UDim2.new(0, 6, 0.5, -17),
			BackgroundColor3 = Color3.fromRGB(28, 28, 36),
			BorderSizePixel = 0,
			Parent = row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avWrap })
		C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.55, Parent = avWrap })
		local avImg = C("ImageLabel", {
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundTransparency = 1,
			Image = "",
			Parent = avWrap,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avImg })
		loadAvatar(avImg, plr.UserId)

		C("TextLabel", {
			Size = UDim2.new(1, -52, 0, 14),
			Position = UDim2.new(0, 48, 0, 8),
			BackgroundTransparency = 1,
			Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " @" .. plr.Name) or plr.Name,
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(245, 245, 250),
			TextStrokeTransparency = 0.75,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		C("TextLabel", {
			Size = UDim2.new(1, -52, 0, 12),
			Position = UDim2.new(0, 48, 0, 26),
			BackgroundTransparency = 1,
			Text = "Obserwuje",
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = ACC,
			TextStrokeTransparency = 0.8,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local pulse = C("Frame", {
			Size = UDim2.new(0, 6, 0, 6),
			Position = UDim2.new(1, -14, 0.5, -3),
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			BackgroundTransparency = 0.3,
			Parent = row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pulse })
		Tween(pulse, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundTransparency = 0.85,
			Size = UDim2.new(0, 4, 0, 4),
			Position = UDim2.new(1, -13, 0.5, -2),
		})

		return row
	end

	local function removeSpecRow(userId)
		local row = specRows[userId]
		if not row then
			return
		end
		specRows[userId] = nil
		local tw = Tween(row, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 16, 0, 0),
		})
		tw.Completed:Connect(function()
			pcall(function() row:Destroy() end)
		end)
	end

	-- // Damage log
	local DmgPanel = C("Frame", {
		Name = "DamageLog",
		Size = UDim2.new(0, 260, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -168),
		BackgroundColor3 = Color3.fromRGB(26, 26, 32),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 35,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = DmgPanel })
	C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.6, Parent = DmgPanel })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = DmgPanel,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = DmgPanel,
	})

	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "DAMAGE",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		TextStrokeTransparency = 0.75,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = DmgPanel,
	})

	local DmgList = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = DmgPanel,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = DmgList,
	})

	local dmgEntries = {}
	local hitHideToken = 0

	local function flashHitmarker(dmg)
		hitHideToken = hitHideToken + 1
		local token = hitHideToken
		HitGroup.Visible = true
		local col = dmg >= 50 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 255, 255)
		for _, ch in ipairs(HitGroup:GetChildren()) do
			if ch:IsA("Frame") then
				ch.BackgroundColor3 = col
			end
		end
		HitGroup.Size = UDim2.new(0, 14, 0, 14)
		Tween(HitGroup, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 20, 0, 20),
		})
		task.delay(0.16, function()
			if token == hitHideToken then
				Tween(HitGroup, TweenInfo.new(0.12), { Size = UDim2.new(0, 14, 0, 14) })
				task.delay(0.12, function()
					if token == hitHideToken then
						HitGroup.Visible = false
					end
				end)
			end
		end)
	end

	local dmgVisible = false

	local function setDmgPanelVisible(on)
		if on == dmgVisible then
			return
		end
		dmgVisible = on
		DmgPanel.Visible = on
	end

	local function addDmgLog(name, dmg)
		setDmgPanelVisible(true)
		local isHead = dmg >= 50
		local row = C("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(36, 36, 44),
			BackgroundTransparency = 0,
			LayoutOrder = 1,
			Parent = DmgList,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 7), Parent = row })
		C("UIStroke", { Color = Color3.fromRGB(55, 55, 65), Thickness = 1, Parent = row })

		local dmgLbl = C("TextLabel", {
			Size = UDim2.new(0, 56, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1,
			Text = string.format("-%.0f", dmg),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextColor3 = isHead and Color3.fromRGB(255, 110, 110) or ACC,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		C("TextLabel", {
			Size = UDim2.new(1, -72, 1, 0),
			Position = UDim2.new(0, 64, 0, 0),
			BackgroundTransparency = 1,
			Text = name,
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(240, 240, 246),
			TextStrokeTransparency = 0.75,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, -18, 0, 0)
		Tween(row, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
			Position = UDim2.new(0, 0, 0, 0),
		})
		Tween(dmgLbl, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			TextSize = 15,
		})
		task.delay(0.15, function()
			if dmgLbl.Parent then
				Tween(dmgLbl, TweenInfo.new(0.12), { TextSize = 13 })
			end
		end)

		table.insert(dmgEntries, 1, row)
		for i, entry in ipairs(dmgEntries) do
			entry.LayoutOrder = i
		end
		if #dmgEntries > 5 then
			local old = table.remove(dmgEntries)
			Tween(old, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
			task.delay(0.2, function()
				pcall(function() old:Destroy() end)
			end)
		end

		task.delay(4.5, function()
			if row.Parent then
				Tween(row, TweenInfo.new(0.28), { BackgroundTransparency = 1, Position = UDim2.new(0, -12, 0, 0) })
				task.delay(0.32, function()
					pcall(function() row:Destroy() end)
					for i, entry in ipairs(dmgEntries) do
						if entry == row then
							table.remove(dmgEntries, i)
							break
						end
					end
					if #dmgEntries == 0 then
						setDmgPanelVisible(false)
					end
				end)
			end
		end)
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

	local lastSpecIds = {}
	local specPanelVisible = false

	local function setSpecPanelVisible(on)
		if on == specPanelVisible then
			return
		end
		specPanelVisible = on
		SpecPanel.Visible = on
	end

	local function updSpectators()
		if not S.Spectators or S.MenuOpen then
			setSpecPanelVisible(false)
			return
		end

		local current = {}
		local order = 1
		for _, plr in ipairs(Players:GetPlayers()) do
			if isLikelySpectating(plr) then
				current[plr.UserId] = { plr = plr, order = order }
				order = order + 1
			end
		end

		local count = order - 1
		SpecCount.Text = tostring(count)
		SpecEmpty.Visible = count == 0

		for userId, row in pairs(specRows) do
			if not current[userId] then
				removeSpecRow(userId)
			end
		end

		for userId, data in pairs(current) do
			if not specRows[userId] then
				specRows[userId] = createSpecRow(data.plr, data.order)
			else
				specRows[userId].LayoutOrder = data.order
			end
		end

		setSpecPanelVisible(true)
		lastSpecIds = current
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
		if not S.DamageLog or S.MenuOpen then
			if dmgVisible then
				setDmgPanelVisible(false)
			end
		end
		if S.Crosshair then
			local sz = math.clamp(S.CrosshairSize or 5, 2, 12)
			Cross.Size = UDim2.new(0, sz, 0, sz)
			Cross.BackgroundColor3 = ACC
		end
	end)

	local specAt = 0
	RS.Heartbeat:Connect(function()
		if tick() - specAt < 0.45 then
			return
		end
		specAt = tick()
		scanHumanoids()
		updSpectators()
	end)
end

return Features
