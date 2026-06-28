-- Plik: workspace/Vanguard/Features.lua

local Features = {}

function Features.Init(S, _ParentGUI)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera
	local ACC = S.V

	local CG = pcall(function() return game:GetService("CoreGui").Name end)
		and game:GetService("CoreGui")
		or LP:WaitForChild("PlayerGui")
	pcall(function() CG.VanguardHUD:Destroy() end)

	local HudGui = Instance.new("ScreenGui")
	HudGui.Name = "VanguardHUD"
	HudGui.IgnoreGuiInset = true
	HudGui.ResetOnSpawn = false
	HudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	HudGui.DisplayOrder = 50
	HudGui.Parent = CG

	local Z = {
		cross = 10,
		hit = 11,
		spec = 20,
		specRow = 21,
		dmg = 20,
		dmgRow = 21,
	}

	local PANEL_BG = Color3.fromRGB(22, 22, 28)
	local ROW_BG = Color3.fromRGB(32, 32, 40)

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

	local function tagZ(inst, z)
		inst.ZIndex = z
		return inst
	end

	local Cross = tagZ(C("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 5, 0, 5),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Visible = false,
		Parent = HudGui,
	}), Z.cross)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Cross })

	local HitGroup = tagZ(C("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 18, 0, 18),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = HudGui,
	}), Z.hit)
	for i = 1, 4 do
		local ln = tagZ(C("Frame", {
			Size = UDim2.new(0, 7, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Rotation = (i - 1) * 90 + 45,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = HitGroup,
		}), Z.hit + 1)
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ln })
	end

	local SpecPanel = tagZ(C("Frame", {
		Name = "Spectators",
		Size = UDim2.new(0, 252, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -268, 0, 88),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Parent = HudGui,
	}), Z.spec)
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = SpecPanel })
	C("UIStroke", { Color = ACC, Thickness = 1.5, Transparency = 0.35, Parent = SpecPanel })

	local SpecHeader = C("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		ZIndex = Z.spec + 1,
		Parent = SpecPanel,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Color3.fromRGB(55, 55, 65),
		BorderSizePixel = 0,
		ZIndex = Z.spec + 1,
		Parent = SpecHeader,
	})
	tagZ(C("TextLabel", {
		Size = UDim2.new(1, -50, 0, 14),
		Position = UDim2.new(0, 14, 0, 10),
		BackgroundTransparency = 1,
		Text = "SPECTATORS",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = SpecHeader,
	}), Z.spec + 2)
	local SpecCount = tagZ(C("TextLabel", {
		Size = UDim2.new(0, 28, 0, 20),
		Position = UDim2.new(1, -38, 0, 9),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Text = "0",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = ACC,
		Parent = SpecHeader,
	}), Z.spec + 2)
	C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = SpecCount })

	local SpecBody = C("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 10, 0, 42),
		BackgroundTransparency = 1,
		ZIndex = Z.spec + 1,
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

	local SpecEmpty = tagZ(C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "Nikt nie obserwuje",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(160, 160, 175),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		LayoutOrder = 0,
		Parent = SpecBody,
	}), Z.spec + 2)

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
		local row = tagZ(C("Frame", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = ROW_BG,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = SpecBody,
		}), Z.specRow)
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
		C("UIStroke", { Color = Color3.fromRGB(60, 60, 72), Thickness = 1, Parent = row })

		local avWrap = tagZ(C("Frame", {
			Size = UDim2.new(0, 34, 0, 34),
			Position = UDim2.new(0, 6, 0.5, -17),
			BackgroundColor3 = Color3.fromRGB(45, 45, 55),
			BorderSizePixel = 0,
			Parent = row,
		}), Z.specRow + 1)
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avWrap })
		C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.4, Parent = avWrap })
		local avImg = tagZ(C("ImageLabel", {
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = Color3.fromRGB(50, 50, 60),
			BackgroundTransparency = 0,
			Image = "",
			Parent = avWrap,
		}), Z.specRow + 2)
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avImg })
		loadAvatar(avImg, plr.UserId)

		tagZ(C("TextLabel", {
			Size = UDim2.new(1, -52, 0, 16),
			Position = UDim2.new(0, 48, 0, 7),
			BackgroundTransparency = 1,
			Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " @" .. plr.Name) or plr.Name,
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		}), Z.specRow + 2)
		tagZ(C("TextLabel", {
			Size = UDim2.new(1, -52, 0, 12),
			Position = UDim2.new(0, 48, 0, 25),
			BackgroundTransparency = 1,
			Text = "Obserwuje",
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = ACC,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}), Z.specRow + 2)

		tagZ(C("Frame", {
			Size = UDim2.new(0, 6, 0, 6),
			Position = UDim2.new(1, -14, 0.5, -3),
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			Parent = row,
		}), Z.specRow + 2)

		row.Position = UDim2.new(0, 10, 0, 0)
		Tween(row, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		})

		return row
	end

	local function removeSpecRow(userId)
		local row = specRows[userId]
		if not row then
			return
		end
		specRows[userId] = nil
		local tw = Tween(row, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 0),
		})
		tw.Completed:Connect(function()
			pcall(function() row:Destroy() end)
		end)
	end

	local DmgPanel = tagZ(C("Frame", {
		Name = "DamageLog",
		Size = UDim2.new(0, 264, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -180),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Parent = HudGui,
	}), Z.dmg)
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = DmgPanel })
	C("UIStroke", { Color = ACC, Thickness = 1.5, Transparency = 0.35, Parent = DmgPanel })
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

	tagZ(C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "DAMAGE",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(200, 200, 215),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = DmgPanel,
	}), Z.dmg + 1)

	local DmgList = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = Z.dmg + 1,
		Parent = DmgPanel,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = DmgList,
	})

	local dmgEntries = {}
	local hitHideToken = 0
	local dmgVisible = false

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
		task.delay(0.18, function()
			if token == hitHideToken then
				HitGroup.Visible = false
			end
		end)
	end

	local function setDmgPanelVisible(on)
		if on == dmgVisible then
			return
		end
		dmgVisible = on
		DmgPanel.Visible = on
	end

	local function addDmgLog(name, dmg, incoming)
		if not S.DamageLog then
			return
		end
		setDmgPanelVisible(true)
		local isHead = dmg >= 50
		local row = tagZ(C("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = incoming and Color3.fromRGB(44, 28, 28) or ROW_BG,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = DmgList,
		}), Z.dmgRow)
		C("UICorner", { CornerRadius = UDim.new(0, 7), Parent = row })
		C("UIStroke", {
			Color = incoming and Color3.fromRGB(120, 60, 60) or Color3.fromRGB(60, 60, 72),
			Thickness = 1,
			Parent = row,
		})

		local dmgText = incoming and string.format("+%.0f", dmg) or string.format("-%.0f", dmg)
		local nameText = incoming and ("from " .. name) or name
		local dmgColor = incoming and Color3.fromRGB(255, 130, 130)
			or (isHead and Color3.fromRGB(255, 120, 120) or ACC)

		tagZ(C("TextLabel", {
			Size = UDim2.new(0, 58, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1,
			Text = dmgText,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = dmgColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}), Z.dmgRow + 1)
		tagZ(C("TextLabel", {
			Size = UDim2.new(1, -74, 1, 0),
			Position = UDim2.new(0, 66, 0, 0),
			BackgroundTransparency = 1,
			Text = nameText,
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextColor3 = incoming and Color3.fromRGB(255, 210, 210) or Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		}), Z.dmgRow + 1)

		row.Position = UDim2.new(0, -14, 0, 0)
		Tween(row, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		})

		table.insert(dmgEntries, 1, row)
		for i, entry in ipairs(dmgEntries) do
			entry.LayoutOrder = i
		end
		if #dmgEntries > 5 then
			local old = table.remove(dmgEntries)
			pcall(function() old:Destroy() end)
		end

		task.delay(4.5, function()
			if row.Parent then
				Tween(row, TweenInfo.new(0.25), { BackgroundTransparency = 1, Position = UDim2.new(0, -10, 0, 0) })
				task.delay(0.28, function()
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
	local localHumConn = nil

	local function findLikelyAttacker()
		local myChar = LP.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHRP then
			return "Unknown"
		end
		local bestName, bestScore = nil, math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP and plr.Character then
				local char = plr.Character
				local head = char:FindFirstChild("Head")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local ref = head or hrp
				if ref then
					local toMe = myHRP.Position - ref.Position
					local dist = toMe.Magnitude
					if dist > 1 and dist < bestScore then
						local look = ref.CFrame.LookVector
						if look:Dot(toMe.Unit) > 0.55 then
							bestScore = dist
							bestName = plr.Name
						end
					end
				end
			end
		end
		return bestName or "Unknown"
	end

	local function bindLocalHum()
		if localHumConn then
			localHumConn:Disconnect()
			localHumConn = nil
		end
		local char = LP.Character
		if not char then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local last = hum.Health
		localHumConn = hum.HealthChanged:Connect(function(hp)
			if not S.DamageLog then
				last = hp
				return
			end
			if hp < last then
				local dmg = last - hp
				addDmgLog(findLikelyAttacker(), dmg, true)
			end
			last = hp
		end)
	end

	LP.CharacterAdded:Connect(function()
		task.defer(bindLocalHum)
	end)
	bindLocalHum()

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
					addDmgLog(plrName or "Target", dmg, false)
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
