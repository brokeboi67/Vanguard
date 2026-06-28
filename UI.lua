-- Plik: workspace/Vanguard/UI.lua

local UI = {}

function UI.Init(S, ParentGUI, ConfigModule)
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local ACC = S.V
	local ACC_SOFT = Color3.new(
		math.clamp(ACC.R * 0.18 + 0.05, 0, 1),
		math.clamp(ACC.G * 0.18 + 0.05, 0, 1),
		math.clamp(ACC.B * 0.18 + 0.05, 0, 1)
	)

	local Cam = workspace.CurrentCamera
	local W_FULL, W_COMPACT, H = 720, 520, 500
	local RS = game:GetService("RunService")

	ParentGUI.DisplayOrder = 100

	local function refreshLayout()
		local vp = Cam.ViewportSize
		W_FULL = math.clamp(math.floor(vp.X * 0.54), 600, 780)
		W_COMPACT = math.clamp(math.floor(vp.X * 0.42), 500, 580)
		H = math.clamp(math.floor(vp.Y * 0.64), 460, 580)
	end
	refreshLayout()

	local C = function(class, props)
		local inst = Instance.new(class)
		for k, v in pairs(props) do inst[k] = v end
		return inst
	end

	local function TweenPlay(obj, info, props)
		local tw = TS:Create(obj, info, props)
		tw:Play()
		return tw
	end

	local function centerPos(w)
		return UDim2.new(0.5, -w / 2, 0.5, -H / 2)
	end

	-- // Loading overlay
	local Loader = C("Frame", {
		Name = "Loader",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = ParentGUI,
	})

	local LoaderCard = C("Frame", {
		Size = UDim2.new(0, 400, 0, 220),
		Position = UDim2.new(0.5, -200, 0.5, -110),
		BackgroundColor3 = Color3.fromRGB(14, 14, 17),
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = Loader,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = LoaderCard })
	C("UIStroke", { Color = Color3.fromRGB(40, 40, 48), Thickness = 1, Parent = LoaderCard })

	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(240, 240, 245),
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local LoaderStatus = C("TextLabel", {
		Size = UDim2.new(1, -40, 0, 14),
		Position = UDim2.new(0, 20, 0, 130),
		BackgroundTransparency = 1,
		Text = "Initializing…",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(120, 120, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local LoaderPct = C("TextLabel", {
		Size = UDim2.new(0, 40, 0, 14),
		Position = UDim2.new(1, -60, 0, 130),
		BackgroundTransparency = 1,
		Text = "0%",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local Track = C("Frame", {
		Size = UDim2.new(1, -40, 0, 4),
		Position = UDim2.new(0, 20, 0, 158),
		BackgroundColor3 = Color3.fromRGB(30, 30, 36),
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = LoaderCard,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Track })

	local Fill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 103,
		Parent = Track,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Fill })

	-- // Main menu
	local MenuRoot = C("CanvasGroup", {
		Name = "MenuRoot",
		Size = UDim2.new(0, W_FULL, 0, H),
		Position = centerPos(W_FULL),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = ParentGUI,
	})

	local MenuScale = C("UIScale", { Scale = 1, Parent = MenuRoot })

	local Shadow = C("Frame", {
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.new(0, 4, 0, 6),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = MenuRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = Shadow })

	local Menu = C("Frame", {
		Name = "Menu",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(13, 13, 16),
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = MenuRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = Menu })
	C("UIStroke", { Color = Color3.fromRGB(38, 38, 46), Thickness = 1, Parent = Menu })

	local Top = C("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(17, 17, 21),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = Top })
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = Color3.fromRGB(17, 17, 21),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Top,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Top,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(240, 240, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Top,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.new(0, 104, 0, 0),
		BackgroundTransparency = 1,
		Text = "ESP STUDIO",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Top,
	})

	local VersionLbl = C("TextLabel", {
		Size = UDim2.new(0, 48, 0, 18),
		Position = UDim2.new(1, -56, 0.5, -9),
		BackgroundTransparency = 1,
		Text = "v" .. (S.Version or "?"),
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(90, 90, 100),
		ZIndex = 4,
		Parent = Top,
	})

	local Side = C("Frame", {
		Size = UDim2.new(0, 150, 1, -48),
		Position = UDim2.new(0, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Side,
	})

	local SidePad = C("Frame", {
		Size = UDim2.new(1, -16, 1, -20),
		Position = UDim2.new(0, 8, 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = Side,
	})
	C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SidePad })

	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Text = "NAVIGATION",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		TextColor3 = Color3.fromRGB(70, 70, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		ZIndex = 4,
		Parent = SidePad,
	})

	local Content = C("Frame", {
		Name = "Content",
		Size = UDim2.new(0, 300, 1, -82),
		Position = UDim2.new(0, 162, 0, 58),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = Menu,
	})

	local PrvWrap = C("CanvasGroup", {
		Name = "PreviewWrap",
		Size = UDim2.new(0, 210, 1, -82),
		Position = UDim2.new(1, -224, 0, 58),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		ZIndex = 3,
		Parent = Menu,
	})

	local PrvP = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(11, 11, 14),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = PrvWrap,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = PrvP })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Parent = PrvP })

	C("TextLabel", {
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Text = "LIVE PREVIEW",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		TextColor3 = Color3.fromRGB(85, 85, 95),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = PrvP,
	})

	local Grid = C("Frame", {
		Size = UDim2.new(1, -24, 1, -44),
		Position = UDim2.new(0, 12, 0, 32),
		BackgroundColor3 = Color3.fromRGB(9, 9, 12),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = PrvP,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Grid })
	C("UIStroke", { Color = Color3.fromRGB(28, 28, 36), Thickness = 1, Parent = Grid })

	for i = 0, 7 do
		C("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, i / 8, 0),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = Grid,
		})
	end
	for i = 0, 5 do
		C("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(i / 6, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = Grid,
		})
	end

	local M_Box = C("Frame", {
		Size = UDim2.new(0, 72, 0, 118),
		Position = UDim2.new(0.5, -36, 0.5, -68),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Grid,
	})
	local M_Cham = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = ACC,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = M_Box,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 2), Parent = M_Cham })
	local M_BoxStroke = C("UIStroke", { Thickness = S.Th, Color = ACC, Parent = M_Box })

	local M_Corners = {}
	for i = 1, 8 do
		M_Corners[i] = C("Frame", {
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 7,
			Parent = M_Box,
		})
	end

	local function UpdPrevCorner(w, h)
		local th = 2
		local len = math.min(w, h) * 0.24
		local specs = {
			{ 0, 0, len, th }, { 0, 0, th, len },
			{ w - len, 0, len, th }, { w - th, 0, th, len },
			{ 0, h - th, len, th }, { 0, h - len, th, len },
			{ w - len, h - th, len, th }, { w - th, h - len, th, len },
		}
		for i, spec in ipairs(specs) do
			M_Corners[i].Size = UDim2.new(0, spec[3], 0, spec[4])
			M_Corners[i].Position = UDim2.new(0, spec[1], 0, spec[2])
		end
	end
	UpdPrevCorner(72, 118)

	local M_Nm = C("TextLabel", {
		Size = UDim2.new(1, 20, 0, 14),
		Position = UDim2.new(0.5, -46, 0, -18),
		BackgroundTransparency = 1,
		Text = "Enemy",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = ACC,
		ZIndex = 7,
		Parent = M_Box,
	})

	local M_Dist = C("TextLabel", {
		Size = UDim2.new(1, 20, 0, 12),
		Position = UDim2.new(0.5, -46, 0, -6),
		BackgroundTransparency = 1,
		Text = "[15m]",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(160, 160, 170),
		ZIndex = 7,
		Parent = M_Box,
	})

	local M_Wpn = C("TextLabel", {
		Size = UDim2.new(1, 24, 0, 12),
		Position = UDim2.new(0.5, -48, 1, 4),
		BackgroundTransparency = 1,
		Text = "AK-47",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(170, 170, 180),
		ZIndex = 7,
		Parent = M_Box,
	})

	local M_HT = C("TextLabel", {
		Size = UDim2.new(0, 30, 0, 12),
		Position = UDim2.new(0, -36, 0.5, -6),
		BackgroundTransparency = 1,
		Text = "85 HP",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		TextColor3 = Color3.fromRGB(210, 210, 218),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = M_Box,
	})

	local M_Tr = C("Frame", {
		Size = UDim2.new(0, S.Th, 0, 52),
		Position = UDim2.new(0.5, -S.Th / 2, 1, 4),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = M_Box,
	})

	local M_HB = C("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.new(0, -8, 0, 0),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = M_Box,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 2), Parent = M_HB })
	local M_HF = C("Frame", {
		Size = UDim2.new(1, 0, 0.72, 0),
		Position = UDim2.new(0, 0, 0.28, 0),
		BackgroundColor3 = Color3.fromRGB(80, 220, 120),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = M_HB,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 2), Parent = M_HF })

	local SkelLines = {}
	local skelPairs = {
		{ UDim2.new(0.5, 0, 0, 8), UDim2.new(0.5, 0, 0.35, 0) },
		{ UDim2.new(0.5, 0, 0.35, 0), UDim2.new(0.2, 0, 0.55, 0) },
		{ UDim2.new(0.5, 0, 0.35, 0), UDim2.new(0.8, 0, 0.55, 0) },
		{ UDim2.new(0.5, 0, 0.35, 0), UDim2.new(0.5, 0, 0.65, 0) },
		{ UDim2.new(0.5, 0, 0.65, 0), UDim2.new(0.28, 0, 1, -6) },
		{ UDim2.new(0.5, 0, 0.65, 0), UDim2.new(0.72, 0, 1, -6) },
	}

	for _, pair in ipairs(skelPairs) do
		local ln = C("Frame", {
			Size = UDim2.new(0, 1.5, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 7,
			Parent = M_Box,
		})
		table.insert(SkelLines, { line = ln, from = pair[1], to = pair[2] })
	end

	local function UpdSkelPreview()
		local w, h = M_Box.AbsoluteSize.X, M_Box.AbsoluteSize.Y
		if w < 2 or h < 2 then return end
		for _, sk in ipairs(SkelLines) do
			if S.Skel then
				local x1 = sk.from.X.Scale * w + sk.from.X.Offset
				local y1 = sk.from.Y.Scale * h + sk.from.Y.Offset
				local x2 = sk.to.X.Scale * w + sk.to.X.Offset
				local y2 = sk.to.Y.Scale * h + sk.to.Y.Offset
				local dx, dy = x2 - x1, y2 - y1
				local mag = math.sqrt(dx * dx + dy * dy)
				sk.line.Size = UDim2.new(0, 1.5, 0, mag)
				sk.line.Position = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
				sk.line.Rotation = math.deg(math.atan2(dy, dx)) + 90
				sk.line.Visible = true
			else
				sk.line.Visible = false
			end
		end
	end

	local function UpdPreview()
		local showBox = S.Box
		M_Box.Visible = showBox or S.Name or S.DistView or S.Health or S.HealthText or S.Weapon or S.Trace or S.Skel or S.Chams
		M_Cham.Visible = S.Chams
		if S.Chams and S.ChamsRainbow then
			M_Cham.BackgroundColor3 = Color3.fromHSV((tick() * 0.45) % 1, 0.9, 1)
		else
			M_Cham.BackgroundColor3 = ACC
		end
		M_Nm.Visible = S.Name
		M_Dist.Visible = S.DistView
		M_Nm.Position = UDim2.new(0.5, -46, 0, S.DistView and -22 or -14)
		M_Wpn.Visible = S.Weapon
		M_Tr.Visible = S.Trace
		M_HB.Visible = S.Health
		M_HT.Visible = S.HealthText
		local corner = showBox and S.BoxType == "Corner"
		M_BoxStroke.Enabled = showBox and not corner
		for _, c in ipairs(M_Corners) do
			c.Visible = corner
		end
		UpdSkelPreview()
	end
	UpdPreview()
	M_Box:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		UpdSkelPreview()
		UpdPrevCorner(M_Box.AbsoluteSize.X, M_Box.AbsoluteSize.Y)
	end)
	RS.RenderStepped:Connect(function()
		if S.Chams and S.ChamsRainbow and M_Cham.Visible then
			M_Cham.BackgroundColor3 = Color3.fromHSV((tick() * 0.45) % 1, 0.9, 1)
		end
	end)

	local Footer = C("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 1, -32),
		BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Footer,
	})
	C("TextLabel", {
		Name = "FooterStatus",
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Text = "v" .. (S.Version or "?") .. "  ·  Ready",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Footer,
	})
	C("TextLabel", {
		Size = UDim2.new(0, 180, 1, 0),
		Position = UDim2.new(1, -196, 0, 0),
		BackgroundTransparency = 1,
		Text = "RIGHT SHIFT  ·  toggle",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(70, 70, 80),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
		Parent = Footer,
	})

	-- // State
	local ActiveTabBtn = nil
	local ActivePageWrap = nil
	local previewVisible = true
	local menuOpen = false
	local menuTweens = {}
	local layoutTweens = {}
	local tabBusy = false
	local savedMouse = {}
	local GuiService = game:GetService("GuiService")
	local toggleRegistry = {}
	local choiceRegistry = {}
	local sliderRegistry = {}
	local bindRegistry = {}

	local function CancelTweens(list)
		for _, tw in ipairs(list) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(list)
	end

	local function ApplyLayout(showPreview, animate, keepPosition)
		refreshLayout()
		local targetW = showPreview and W_FULL or W_COMPACT
		local targetContentW = showPreview and math.floor(W_FULL * 0.42) or (W_COMPACT - 172)

		CancelTweens(layoutTweens)

		local info = TweenInfo.new(animate and 0.22 or 0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		local menuProps = { Size = UDim2.new(0, targetW, 0, H) }
		if not keepPosition then
			menuProps.Position = centerPos(targetW)
		end

		table.insert(layoutTweens, TweenPlay(MenuRoot, info, menuProps))
		table.insert(layoutTweens, TweenPlay(Content, info, {
			Size = UDim2.new(0, targetContentW, 1, -82),
		}))

		if showPreview then
			PrvWrap.Visible = true
			table.insert(layoutTweens, TweenPlay(PrvWrap, info, { GroupTransparency = 0 }))
		else
			local tw = TweenPlay(PrvWrap, info, { GroupTransparency = 1 })
			table.insert(layoutTweens, tw)
			if animate then
				tw.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and not previewVisible then
						PrvWrap.Visible = false
					end
				end)
			else
				PrvWrap.Visible = false
			end
		end

		previewVisible = showPreview
	end

	local function StyleTab(btn, active)
		TweenPlay(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
			BackgroundColor3 = active and ACC_SOFT or Color3.fromRGB(18, 18, 22),
			TextColor3 = active and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(105, 105, 115),
		})
		local ind = btn:FindFirstChild("Indicator")
		if ind then
			TweenPlay(ind, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
				BackgroundTransparency = active and 0 or 1,
			})
		end
	end

	local function SwitchTab(btn, pageWrap, showPreview)
		if ActiveTabBtn == btn or tabBusy then
			return
		end
		tabBusy = true

		local oldWrap = ActivePageWrap
		local oldBtn = ActiveTabBtn
		local inInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		if oldBtn then
			StyleTab(oldBtn, false)
		end
		StyleTab(btn, true)

		if showPreview ~= previewVisible then
			ApplyLayout(showPreview, true, true)
		end

		if oldWrap and oldWrap ~= pageWrap then
			oldWrap.Visible = false
			oldWrap.GroupTransparency = 1
			oldWrap.Position = UDim2.new(0, 0, 0, 0)
			local oldScale = oldWrap:FindFirstChild("PageScale")
			if oldScale then
				oldScale.Scale = 1
			end
		end

		ActiveTabBtn = btn
		ActivePageWrap = pageWrap

		pageWrap.Visible = true
		pageWrap.GroupTransparency = 1
		pageWrap.Position = UDim2.new(0, 6, 0, 0)
		local newScale = pageWrap:FindFirstChild("PageScale")
		if newScale then
			newScale.Scale = 0.98
		end
		TweenPlay(pageWrap, inInfo, {
			GroupTransparency = 0,
			Position = UDim2.new(0, 0, 0, 0),
		})
		if newScale then
			TweenPlay(newScale, inInfo, { Scale = 1 })
		end

		task.delay(0.18, function()
			tabBusy = false
		end)
	end

	local function MakeTab(name, default, showPreview, layoutOrder)
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = default and ACC_SOFT or Color3.fromRGB(18, 18, 22),
			Text = "  " .. name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = default and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(105, 105, 115),
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = layoutOrder or 1,
			ZIndex = 5,
			Parent = SidePad,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = B })
		C("Frame", {
			Name = "Indicator",
			Size = UDim2.new(0, 2, 0, 16),
			Position = UDim2.new(0, 0, 0.5, -8),
			BackgroundColor3 = ACC,
			BackgroundTransparency = default and 0 or 1,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = B,
		})

		local Wrap = C("CanvasGroup", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			GroupTransparency = default and 0 or 1,
			Visible = default,
			ZIndex = 4,
			Parent = Content,
		})
		C("UIScale", { Name = "PageScale", Scale = 1, Parent = Wrap })

		local P = C("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = Wrap,
		})
		C("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = P })
		C("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = P })

		B.MouseEnter:Connect(function()
			if B ~= ActiveTabBtn then
				TweenPlay(B, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(22, 22, 26) })
			end
		end)
		B.MouseLeave:Connect(function()
			if B ~= ActiveTabBtn then
				TweenPlay(B, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) })
			end
		end)
		B.MouseButton1Click:Connect(function()
			SwitchTab(B, Wrap, showPreview)
		end)

		if default then
			ActiveTabBtn = B
			ActivePageWrap = Wrap
		end

		return P
	end

	local function MakeSection(page, title, order)
		C("TextLabel", {
			Size = UDim2.new(1, -4, 0, 14),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(75, 75, 85),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
	end

	local function MakeHint(page, text, order)
		C("TextLabel", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(88, 88, 98),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
	end

	local function setToggleVisual(key, enabled)
		local t = toggleRegistry[key]
		if not t then
			return
		end
		TweenPlay(t.SwitchBg, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundColor3 = enabled and ACC or Color3.fromRGB(36, 36, 44),
		})
		TweenPlay(t.SwitchDot, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
		})
	end

	local NotifyRoot = C("Frame", {
		Name = "NotifyRoot",
		Size = UDim2.new(0, 320, 0, 200),
		Position = UDim2.new(0.5, -160, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 90,
		Parent = ParentGUI,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = NotifyRoot,
	})

	local function showNotify(msg)
		local card = C("TextLabel", {
			Size = UDim2.new(0, 300, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(14, 14, 18),
			BackgroundTransparency = 0.08,
			Text = "  " .. msg .. "  ",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 228),
			TextWrapped = true,
			ZIndex = 91,
			Parent = NotifyRoot,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
		C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.35, Parent = card })
		C("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			Parent = card,
		})
		task.delay(3.2, function()
			if card.Parent then
				TweenPlay(card, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 })
				task.delay(0.3, function()
					pcall(function() card:Destroy() end)
				end)
			end
		end)
	end

	local function applyEspColorExclusivity(fromKey, turningOn)
		if not turningOn then
			return
		end
		local off = {}
		local pairsList
		if fromKey == "ChamsRainbow" then
			pairsList = {
				{ "LoS", "Line of Sight" },
				{ "RealTeamColor", "Team Colors" },
			}
		elseif fromKey == "LoS" then
			pairsList = {
				{ "ChamsRainbow", "Chams Rainbow" },
				{ "RealTeamColor", "Team Colors" },
			}
		elseif fromKey == "RealTeamColor" then
			pairsList = {
				{ "ChamsRainbow", "Chams Rainbow" },
				{ "LoS", "Line of Sight" },
			}
		else
			return
		end
		for _, pair in ipairs(pairsList) do
			local k, label = pair[1], pair[2]
			if S[k] then
				S[k] = false
				setToggleVisual(k, false)
				table.insert(off, label)
			end
		end
		if #off > 0 then
			showNotify("Wyłączono: " .. table.concat(off, ", "))
		end
	end

	local function applyAimExclusivity(fromKey, turningOn)
		if not turningOn then
			return
		end
		if fromKey == "Silent" and S.Aimbot then
			S.Aimbot = false
			setToggleVisual("Aimbot", false)
			showNotify("Wyłączono: Aimbot")
		elseif fromKey == "Aimbot" and S.Silent then
			S.Silent = false
			setToggleVisual("Silent", false)
			showNotify("Wyłączono: Silent Aim")
		end
	end

	local function isLockedMouseBehavior(behavior)
		return behavior == Enum.MouseBehavior.LockCenter
			or behavior == Enum.MouseBehavior.LockCurrentPosition
	end

	local function isFreeCursorState()
		if UIS.MouseBehavior == Enum.MouseBehavior.Default then
			return true
		end
		if UIS.MouseIconEnabled then
			return true
		end
		return false
	end

	local function captureMouseState()
		local LP = game:GetService("Players").LocalPlayer
		savedMouse.behavior = UIS.MouseBehavior
		savedMouse.icon = UIS.MouseIconEnabled
		savedMouse.cameraMode = LP.CameraMode
		savedMouse.wasFree = isFreeCursorState()
	end

	local function forceMenuCursor()
		pcall(function()
			GuiService:SetMenuIsOpen(true)
		end)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		pcall(function()
			game:GetService("Players").LocalPlayer.DevEnableMouseLock = false
		end)
		pcall(function()
			GuiService.SelectedObject = nil
		end)
	end

	local function applyFreeCursor()
		pcall(function()
			GuiService:SetMenuIsOpen(false)
		end)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end

	local function applyLockedCursor()
		pcall(function()
			GuiService:SetMenuIsOpen(false)
		end)
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
	end

	local function restoreMouseState()
		if savedMouse.wasFree then
			applyFreeCursor()
		else
			applyLockedCursor()
		end
		local LP = game:GetService("Players").LocalPlayer
		if savedMouse.cameraMode ~= nil then
			pcall(function()
				LP.CameraMode = savedMouse.cameraMode
			end)
		end
	end

	local function refreshAllControls()
		for key, _ in pairs(toggleRegistry) do
			setToggleVisual(key, S[key] == true)
		end
		for key, reg in pairs(choiceRegistry) do
			local cur = S[key]
			for val, btn in pairs(reg.btns) do
				local on = val == cur
				btn.BackgroundColor3 = on and ACC_SOFT or Color3.fromRGB(24, 24, 30)
				btn.TextColor3 = on and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(110, 110, 120)
				local stroke = btn:FindFirstChildOfClass("UIStroke")
				if on and not stroke then
					C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.5, Parent = btn })
				elseif not on and stroke then
					stroke:Destroy()
				end
			end
		end
		for key, reg in pairs(sliderRegistry) do
			if reg.setValue and S[key] ~= nil then
				reg.setValue(S[key])
			end
		end
		for key, lbl in pairs(bindRegistry) do
			lbl.Text = S[key] or "None"
		end
		UpdPreview()
	end

	local mouseUnlockConn = nil
	local mouseUnlockHB = nil
	local mouseRestoreConn = nil

	local function MakeTog(page, label, key, order)
		local on = S[key] == true
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })

		local Title = C("TextLabel", {
			Size = UDim2.new(1, -54, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local SwitchBg = C("Frame", {
			Size = UDim2.new(0, 38, 0, 20),
			Position = UDim2.new(1, -48, 0.5, -10),
			BackgroundColor3 = on and ACC or Color3.fromRGB(36, 36, 44),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchBg })

		local SwitchDot = C("Frame", {
			Size = UDim2.new(0, 14, 0, 14),
			Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(245, 245, 250),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = SwitchBg,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchDot })

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(17, 17, 21) })
		end)

		Row.MouseButton1Click:Connect(function()
			S[key] = not S[key]
			local enabled = S[key]

			if enabled then
				applyEspColorExclusivity(key, true)
				applyAimExclusivity(key, true)
			end

			setToggleVisual(key, enabled)
			UpdPreview()
		end)

		toggleRegistry[key] = { SwitchBg = SwitchBg, SwitchDot = SwitchDot }
	end

	local function MakeChoice(page, label, key, options, order)
		local rowH = #options >= 4 and 64 or (#options >= 3 and 60 or 52)
		local Row = C("Frame", {
			Size = UDim2.new(1, 0, 0, rowH),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })

		C("TextLabel", {
			Size = UDim2.new(1, -16, 0, 14),
			Position = UDim2.new(0, 12, 0, 8),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local BtnWrap = C("Frame", {
			Size = UDim2.new(1, -24, 0, 24),
			Position = UDim2.new(0, 12, 0, rowH - 30),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = Row,
		})
		C("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = BtnWrap,
		})

		local btns = {}
		local btnScale = 1 / #options
		for i, opt in ipairs(options) do
			local active = S[key] == opt.value
			local B = C("TextButton", {
				Size = UDim2.new(btnScale, -3, 1, 0),
				BackgroundColor3 = active and ACC_SOFT or Color3.fromRGB(24, 24, 30),
				Text = opt.label,
				Font = Enum.Font.GothamSemibold,
				TextSize = #options >= 3 and 9 or 10,
				TextColor3 = active and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(110, 110, 120),
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 7,
				Parent = BtnWrap,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = B })
			if active then
				C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.5, Parent = B })
			end
			btns[opt.value] = B
			B.MouseButton1Click:Connect(function()
				S[key] = opt.value
				for val, btn in pairs(btns) do
					local on = val == opt.value
					btn.BackgroundColor3 = on and ACC_SOFT or Color3.fromRGB(24, 24, 30)
					btn.TextColor3 = on and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(110, 110, 120)
					local stroke = btn:FindFirstChildOfClass("UIStroke")
					if on and not stroke then
						C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.5, Parent = btn })
					elseif not on and stroke then
						stroke:Destroy()
					end
				end
				UpdPreview()
			end)
		end
		choiceRegistry[key] = { btns = btns }
	end

	local bindListening = false

	local function MakeBind(page, label, key, order)
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })

		C("TextLabel", {
			Size = UDim2.new(1, -80, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local KeyLbl = C("TextLabel", {
			Size = UDim2.new(0, 56, 0, 22),
			Position = UDim2.new(1, -64, 0.5, -11),
			BackgroundColor3 = Color3.fromRGB(24, 24, 30),
			Text = S[key] or "None",
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = ACC,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = KeyLbl })

		Row.MouseButton1Click:Connect(function()
			if bindListening then
				return
			end
			bindListening = true
			KeyLbl.Text = "…"
			KeyLbl.TextColor3 = Color3.fromRGB(200, 200, 120)
			local conn
			conn = UIS.InputBegan:Connect(function(input, processed)
				if processed then
					return
				end
				if input.KeyCode ~= Enum.KeyCode.Unknown then
					S[key] = input.KeyCode.Name
					KeyLbl.Text = S[key]
					KeyLbl.TextColor3 = ACC
					bindListening = false
					conn:Disconnect()
				end
			end)
		end)
		bindRegistry[key] = KeyLbl
	end

	local function MakeSlider(page, label, key, min, max, order, opts)
		opts = opts or {}
		local suffix = opts.suffix or "m"
		local fmt = opts.fmt or function(v)
			return tostring(v) .. suffix
		end
		local step = opts.step or 1

		local Row = C("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })

		local ValLbl = C("TextLabel", {
			Size = UDim2.new(0, 64, 0, 14),
			Position = UDim2.new(1, -72, 0, 8),
			BackgroundTransparency = 1,
			Text = fmt(S[key]),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = ACC,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -72, 0, 14),
			Position = UDim2.new(0, 12, 0, 8),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local Track = C("TextButton", {
			Size = UDim2.new(1, -24, 0, 6),
			Position = UDim2.new(0, 12, 0, 32),
			BackgroundColor3 = Color3.fromRGB(28, 28, 36),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Track })

		local Fill = C("Frame", {
			Size = UDim2.new((S[key] - min) / (max - min), 0, 1, 0),
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = Track,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Fill })

		local Knob = C("Frame", {
			Size = UDim2.new(0, 10, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((S[key] - min) / (max - min), 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(245, 245, 250),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = Track,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Knob })

		local draggingSlider = false

		local function setValue(raw)
			local pct = math.clamp(raw, 0, 1)
			local val = min + (max - min) * pct
			if step >= 1 then
				val = math.floor(val / step + 0.5) * step
			else
				val = math.floor(val * 100 + 0.5) / 100
			end
			val = math.clamp(val, min, max)
			S[key] = val
			ValLbl.Text = fmt(val)
			local p = (val - min) / (max - min)
			Fill.Size = UDim2.new(p, 0, 1, 0)
			Knob.Position = UDim2.new(p, 0, 0.5, 0)
		end

		local function fromInput(x)
			if Track.AbsoluteSize.X < 1 then return end
			local rel = math.clamp((x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
			setValue(rel)
		end

		Track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSlider = true
				fromInput(input.Position.X)
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
				fromInput(input.Position.X)
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSlider = false
			end
		end)

		sliderRegistry[key] = {
			setValue = function(val)
				local p = (val - min) / (max - min)
				setValue(p)
			end,
		}
	end

	local function MakeButton(page, label, order, callback)
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			Text = label,
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 228),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })
		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(22, 22, 28) })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(17, 17, 21) })
		end)
		Row.MouseButton1Click:Connect(function()
			callback()
		end)
	end

	local FooterStatus = Footer:FindFirstChild("FooterStatus")

	local function setFooterStatus(text)
		if FooterStatus then
			FooterStatus.Text = "v" .. (S.Version or "?") .. "  ·  " .. text
		end
	end

	local T1 = MakeTab("Visuals", true, true, 1)
	local T3 = MakeTab("Aim", false, false, 2)
	local T2 = MakeTab("Settings", false, false, 3)
	local T4 = MakeTab("Config", false, false, 4)

	MakeSection(T1, "CORE", 1)
	MakeTog(T1, "Master ESP", "ESP", 2)
	MakeSection(T1, "DISTANCE", 3)
	MakeTog(T1, "Show Distance", "DistView", 4)
	MakeSlider(T1, "Distance Limit", "MaxDist", 50, 1500, 5)
	MakeSection(T1, "OVERLAYS", 6)
	MakeTog(T1, "Bounding Boxes", "Box", 7)
	MakeChoice(T1, "Box Type", "BoxType", {
		{ label = "Full", value = "Full" },
		{ label = "Corner", value = "Corner" },
	}, 8)
	MakeTog(T1, "Player Names", "Name", 9)
	MakeTog(T1, "Health Bars", "Health", 10)
	MakeTog(T1, "Health Text", "HealthText", 11)
	MakeTog(T1, "Weapon ESP", "Weapon", 12)
	MakeSection(T1, "ADVANCED", 13)
	MakeTog(T1, "Render Bots", "RenderBots", 14)
	MakeTog(T1, "Skeleton", "Skel", 15)
	MakeTog(T1, "Tracers", "Trace", 16)
	MakeTog(T1, "Chams Fill", "Chams", 17)
	MakeTog(T1, "Chams Rainbow", "ChamsRainbow", 18)
	MakeHint(T1, "Chams Rainbow, Team Colors i Line of Sight wykluczają się — włączenie jednego wyłącza pozostałe.", 19)

	MakeSection(T3, "AIMBOT", 1)
	MakeTog(T3, "Aimbot (hold RMB)", "Aimbot", 2)
	MakeTog(T3, "Silent Aim (flick)", "Silent", 3)
	MakeSlider(T3, "Silent Aim Delay", "SilentFrames", 1, 8, 4, {
		suffix = " fr",
		step = 1,
		fmt = function(v) return math.floor(v) .. " frames" end,
	})
	MakeChoice(T3, "Silent Mode", "SilentMode", {
		{ label = "Viewport", value = "Viewport" },
		{ label = "Flick", value = "Flick" },
	}, 5)
	MakeHint(T3, "Viewport = bez ruszania kamery (trigger). Flick = celuje kamerą przed strzałem (LMB / wolne gry).", 6)
	MakeHint(T3, "Aimbot i Silent wykluczają się — włączenie jednego wyłącza drugie.", 7)
	MakeTog(T3, "Triggerbot", "Trigger", 8)
	MakeChoice(T3, "Trigger Mode", "TriggerMode", {
		{ label = "Hold", value = "Hold" },
		{ label = "Toggle", value = "Toggle" },
	}, 9)
	MakeBind(T3, "Trigger Key", "TriggerKey", 10)
	MakeSlider(T3, "Trigger Delay", "TriggerDelay", 1, 500, 11, { suffix = "ms", step = 1 })
	MakeTog(T3, "Trigger Status HUD", "ShowTriggerHud", 12)
	MakeTog(T3, "Minimal Trigger HUD", "TriggerHudMinimal", 13)
	MakeHint(T3, "Włączone = mała kropka po prawej (jasna = aktywny, szara = czeka). Wyłączone = pełna etykieta tekstowa.", 14)
	MakeHint(T3, "Hold = strzela gdy trzymasz klawisz. Toggle = ON/OFF klawiszem, potem strzela w FOV.", 15)
	MakeSection(T3, "TARGETING", 16)
	MakeTog(T3, "Visible Check", "VisibleCheck", 17)
	MakeTog(T3, "Target Bots", "AimBots", 18)
	MakeChoice(T3, "Target Priority", "TargetMode", {
		{ label = "FOV", value = "FOV" },
		{ label = "Dist", value = "Distance" },
		{ label = "HP", value = "Health" },
	}, 19)
	MakeChoice(T3, "Hit Part", "HitPart", {
		{ label = "Head", value = "Head" },
		{ label = "Torso", value = "Torso" },
		{ label = "Random", value = "Random" },
		{ label = "Closest", value = "Closest" },
	}, 20)
	MakeSection(T3, "FOV & SMOOTH", 21)
	MakeTog(T3, "Show FOV Circle", "ShowFOV", 22)
	MakeSlider(T3, "FOV Size", "FOV", 20, 300, 23, { suffix = "px", step = 5 })
	MakeSlider(T3, "Smoothing", "Smooth", 0.05, 0.95, 24, {
		suffix = "",
		step = 0.05,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})
	MakeTog(T3, "Aim Curve + Jitter", "AimCurve", 25)
	MakeHint(T3, "Smoothing działa tylko z Aimbot (RMB). Silent = flick przy strzale, bez trackingu.", 26)

	MakeSection(T2, "MOVEMENT", 1)
	MakeTog(T2, "Bunny Hop", "BHop", 2)
	MakeHint(T2, "Auto-skok tylko gdy się poruszasz (WASD). Stojąc w miejscu — nic nie robi.", 3)
	MakeSection(T2, "FILTERS", 4)
	MakeTog(T2, "Team Colors", "RealTeamColor", 5)
	MakeTog(T2, "Hide Teammates", "Team", 6)
	MakeTog(T2, "Line of Sight", "LoS", 7)

	MakeSection(T2, "HUD", 8)
	MakeTog(T2, "Crosshair Dot", "Crosshair", 9)
	MakeSlider(T2, "Crosshair Size", "CrosshairSize", 2, 12, 10, { suffix = "px", step = 1 })
	MakeTog(T2, "Spectator List", "Spectators", 11)
	MakeHint(T2, "Spectator = heurystyka (brak postaci / martwy / atrybut Spectating). Nie każda gra to wspiera.", 12)
	MakeTog(T2, "Hitmarker", "Hitmarker", 13)
	MakeTog(T2, "Damage Log", "DamageLog", 14)
	MakeHint(T2, "Pokazuje zadane (-) i otrzymane (+) obrażenia. Kto strzelił = heurystyka.", 15)

	local SettingsAutoloadLbl
	MakeSection(T2, "AUTOLOAD", 16)
	SettingsAutoloadLbl = C("TextLabel", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "Autoload: brak",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = 17,
		ZIndex = 5,
		Parent = T2,
	})
	MakeButton(T2, "Załaduj autoload teraz", 18, function()
		if not ConfigModule then
			showNotify("Brak modułu config")
			return
		end
		local ok, msg = ConfigModule.Autoload(S)
		if ok then
			refreshAllControls()
			showNotify("Autoload: " .. tostring(msg))
			setFooterStatus("Autoload · " .. tostring(msg))
			refreshConfigList()
			if SettingsAutoloadLbl then
				SettingsAutoloadLbl.Text = "Autoload: " .. tostring(msg)
			end
		else
			showNotify("Brak autoload lub błąd wczytywania")
		end
	end)
	MakeHint(T2, "Autoload wczytuje się automatycznie przy każdym uruchomieniu skryptu (nowa gra = reinject). Ustaw w zakładce Config.", 19)

	-- // Config tab
	local ConfigNameBox
	local ConfigListHost
	local AutoloadLbl

	local function getConfigName()
		if ConfigNameBox then
			return ConfigNameBox.Text
		end
		return ""
	end

	local function refreshConfigList()
		if not ConfigListHost or not ConfigModule then
			return
		end
		for _, ch in ipairs(ConfigListHost:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		local list, autoload = ConfigModule.List()
		if AutoloadLbl then
			if autoload ~= "" then
				AutoloadLbl.Text = "Autoload: " .. autoload
			else
				AutoloadLbl.Text = "Autoload: brak"
			end
		end
		if SettingsAutoloadLbl then
			if autoload ~= "" then
				SettingsAutoloadLbl.Text = "Autoload: " .. autoload .. " (ładuje się przy starcie skryptu)"
			else
				SettingsAutoloadLbl.Text = "Autoload: brak — ustaw w zakładce Config"
			end
		end
		if #list == 0 then
			C("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = "Brak zapisanych configów",
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(90, 90, 100),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				ZIndex = 6,
				Parent = ConfigListHost,
			})
			return
		end
		for i, name in ipairs(list) do
			local mark = (name == autoload) and " ★" or ""
			C("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = name .. mark,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = name == autoload and ACC or Color3.fromRGB(170, 170, 180),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
				ZIndex = 6,
				Parent = ConfigListHost,
			})
		end
	end

	MakeSection(T4, "CONFIG", 1)
	if ConfigModule and not ConfigModule.CanPersist() then
		MakeHint(T4, "Twój executor nie wspiera writefile — zapis configów niedostępny.", 2)
	end

	local NameRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(17, 17, 21),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 5,
		Parent = T4,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = NameRow })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = NameRow })
	C("TextLabel", {
		Size = UDim2.new(0, 80, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = "Nazwa",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(200, 200, 208),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = NameRow,
	})
	ConfigNameBox = C("TextBox", {
		Size = UDim2.new(1, -104, 0, 24),
		Position = UDim2.new(0, 92, 0.5, -12),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Text = "default",
		PlaceholderText = "np. legit, rage, hvh",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(230, 230, 235),
		PlaceholderColor3 = Color3.fromRGB(80, 80, 90),
		ClearTextOnFocus = false,
		ZIndex = 6,
		Parent = NameRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = ConfigNameBox })
	C("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = ConfigNameBox })

	MakeButton(T4, "Zapisz config", 4, function()
		if not ConfigModule then return end
		local ok, msg = ConfigModule.Save(getConfigName(), S)
		if ok then
			showNotify("Zapisano: " .. msg)
			setFooterStatus("Config · " .. msg)
			refreshConfigList()
		else
			showNotify(msg or "Błąd zapisu")
		end
	end)
	MakeButton(T4, "Wczytaj config", 5, function()
		if not ConfigModule then return end
		local ok, msg = ConfigModule.Load(getConfigName(), S)
		if ok then
			refreshAllControls()
			showNotify("Wczytano: " .. msg)
			setFooterStatus("Loaded · " .. msg)
		else
			showNotify(msg or "Błąd wczytywania")
		end
	end)
	MakeButton(T4, "Usuń config", 6, function()
		if not ConfigModule then return end
		local ok, msg = ConfigModule.Delete(getConfigName())
		if ok then
			showNotify("Usunięto: " .. msg)
			refreshConfigList()
		else
			showNotify(msg or "Błąd usuwania")
		end
	end)
	MakeButton(T4, "Ustaw autoload", 7, function()
		if not ConfigModule then return end
		local ok, msg = ConfigModule.SetAutoload(getConfigName())
		if ok then
			showNotify("Autoload: " .. getConfigName())
			refreshConfigList()
		else
			showNotify(msg or "Błąd autoload")
		end
	end)
	MakeButton(T4, "Wyłącz autoload", 8, function()
		if not ConfigModule then return end
		local ok, msg = ConfigModule.ClearAutoload()
		if ok then
			showNotify("Autoload wyłączony")
			refreshConfigList()
		else
			showNotify(msg or "Błąd")
		end
	end)

	MakeSection(T4, "ZAPISANE", 9)
	AutoloadLbl = C("TextLabel", {
		Size = UDim2.new(1, -8, 0, 14),
		BackgroundTransparency = 1,
		Text = "Autoload: brak",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 10,
		ZIndex = 5,
		Parent = T4,
	})
	ConfigListHost = C("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BorderSizePixel = 0,
		LayoutOrder = 11,
		ZIndex = 5,
		Parent = T4,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ConfigListHost })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Parent = ConfigListHost })
	C("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ConfigListHost,
	})
	C("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = ConfigListHost,
	})
	MakeHint(T4, "Pliki w folderze Vanguard/configs. Autoload ładuje się przy każdym uruchomieniu skryptu (reinject w nowej grze).", 12)
	refreshConfigList()

	ApplyLayout(true, false)

	-- // Menu show / hide
	local function SetMenuOpen(open)
		if open == menuOpen then
			return
		end
		menuOpen = open
		S.MenuOpen = open

		CancelTweens(menuTweens)
		MenuRoot.Visible = true

		local LP = game:GetService("Players").LocalPlayer
		local showInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local hideInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

		if open then
			if mouseRestoreConn then
				mouseRestoreConn:Disconnect()
				mouseRestoreConn = nil
			end

			captureMouseState()
			forceMenuCursor()

			if mouseUnlockConn then
				mouseUnlockConn:Disconnect()
			end
			if mouseUnlockHB then
				mouseUnlockHB:Disconnect()
			end
			local unlockBeat = false
			mouseUnlockConn = RS.RenderStepped:Connect(function()
				if not menuOpen then
					return
				end
				forceMenuCursor()
			end)
			mouseUnlockHB = RS.Heartbeat:Connect(function()
				if not menuOpen then
					return
				end
				unlockBeat = not unlockBeat
				if unlockBeat then
					forceMenuCursor()
				end
			end)

			task.defer(forceMenuCursor)
			task.delay(0.05, function()
				if menuOpen then
					forceMenuCursor()
				end
			end)

			MenuScale.Scale = 0.985
			MenuRoot.GroupTransparency = 1
			table.insert(menuTweens, TweenPlay(MenuRoot, showInfo, { GroupTransparency = 0 }))
			table.insert(menuTweens, TweenPlay(MenuScale, showInfo, { Scale = 1 }))
		else
			dragging = false

			if mouseUnlockConn then
				mouseUnlockConn:Disconnect()
				mouseUnlockConn = nil
			end
			if mouseUnlockHB then
				mouseUnlockHB:Disconnect()
				mouseUnlockHB = nil
			end

			restoreMouseState()

			local restoreFrames = 0
			if mouseRestoreConn then
				mouseRestoreConn:Disconnect()
			end
			local framesTarget = savedMouse.wasFree and 10 or 14
			mouseRestoreConn = RS.RenderStepped:Connect(function()
				if menuOpen then
					mouseRestoreConn:Disconnect()
					mouseRestoreConn = nil
					return
				end
				restoreMouseState()
				restoreFrames = restoreFrames + 1
				if restoreFrames >= framesTarget then
					mouseRestoreConn:Disconnect()
					mouseRestoreConn = nil
				end
			end)

			task.defer(restoreMouseState)
			task.delay(0.05, function()
				if not menuOpen then
					restoreMouseState()
				end
			end)

			table.insert(menuTweens, TweenPlay(MenuRoot, hideInfo, { GroupTransparency = 1 }))
			table.insert(menuTweens, TweenPlay(MenuScale, hideInfo, { Scale = 0.985 }))
			task.delay(0.12, function()
				if not menuOpen then
					MenuRoot.Visible = false
				end
			end)
		end
	end

	-- // Drag
	local dragging, dragStart, startPos
	Top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = MenuRoot.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - dragStart
			MenuRoot.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			SetMenuOpen(not menuOpen)
		end
	end)

	-- // Loading
	task.spawn(function()
		local steps = {
			{ text = "Loading modules…", pct = 0.3 },
			{ text = "Initializing ESP…", pct = 0.6 },
			{ text = "Preparing UI…", pct = 0.85 },
			{ text = "Done", pct = 1 },
		}

		for _, step in ipairs(steps) do
			LoaderStatus.Text = step.text
			LoaderPct.Text = math.floor(step.pct * 100) .. "%"
			TweenPlay(Fill, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.pct, 0, 1, 0),
			})
			task.wait(0.3)
		end

		task.wait(0.1)
		TweenPlay(LoaderCard, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -200, 0.5, -105),
		})
		TweenPlay(Loader, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		task.wait(0.2)
		Loader:Destroy()

		if ConfigModule then
			refreshConfigList()
			local autoload = ConfigModule.GetAutoload()
			if autoload ~= "" then
				refreshAllControls()
				setFooterStatus("Autoload · " .. autoload)
			end
		end

		menuOpen = false
		MenuRoot.Visible = true
		MenuRoot.GroupTransparency = 1
		MenuScale.Scale = 0.985
		SetMenuOpen(true)
	end)

	Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		refreshLayout()
		ApplyLayout(previewVisible, false, true)
	end)
end

return UI
