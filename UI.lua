-- Plik: workspace/Vanguard/UI.lua

local UI = {}

function UI.Init(S, ParentGUI)
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local ACC = S.V
	local ACC_SOFT = Color3.new(
		math.clamp(ACC.R * 0.22 + 0.04, 0, 1),
		math.clamp(ACC.G * 0.22 + 0.06, 0, 1),
		math.clamp(ACC.B * 0.22 + 0.04, 0, 1)
	)

	local C = function(class, props)
		local inst = Instance.new(class)
		for k, v in pairs(props) do inst[k] = v end
		return inst
	end

	local function Tween(obj, info, props)
		return TS:Create(obj, info, props)
	end

	local function TweenPlay(obj, info, props)
		local tw = Tween(obj, info, props)
		tw:Play()
		return tw
	end

	-- // Loading overlay
	local Loader = C("Frame", {
		Name = "Loader",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = ParentGUI,
	})

	local LoaderCard = C("Frame", {
		Size = UDim2.new(0, 440, 0, 250),
		Position = UDim2.new(0.5, -220, 0.5, -125),
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = Loader,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 14), Parent = LoaderCard })
	C("UIStroke", {
		Color = Color3.fromRGB(38, 38, 48),
		Thickness = 1,
		Transparency = 0.15,
		Parent = LoaderCard,
	})

	local LoaderGlow = C("Frame", {
		Size = UDim2.new(1, 24, 0, 2),
		Position = UDim2.new(0, -12, 0, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = LoaderCard,
	})
	C("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(0.35, ACC),
			ColorSequenceKeypoint.new(0.65, ACC),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = LoaderGlow,
	})

	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(245, 245, 250),
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local LoaderSub = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 88),
		BackgroundTransparency = 1,
		Text = "PRO ESP STUDIO",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = ACC,
		TextTransparency = 0.15,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local LoaderStatus = C("TextLabel", {
		Size = UDim2.new(1, -48, 0, 16),
		Position = UDim2.new(0, 24, 0, 148),
		BackgroundTransparency = 1,
		Text = "Initializing…",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(130, 130, 142),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local LoaderPct = C("TextLabel", {
		Size = UDim2.new(0, 48, 0, 16),
		Position = UDim2.new(1, -72, 0, 148),
		BackgroundTransparency = 1,
		Text = "0%",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	local Track = C("Frame", {
		Size = UDim2.new(1, -48, 0, 6),
		Position = UDim2.new(0, 24, 0, 178),
		BackgroundColor3 = Color3.fromRGB(28, 28, 36),
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
	C("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 180, 110)),
			ColorSequenceKeypoint.new(1, ACC),
		}),
		Parent = Fill,
	})

	local LoaderHint = C("TextLabel", {
		Size = UDim2.new(1, -48, 0, 14),
		Position = UDim2.new(0, 24, 1, -28),
		BackgroundTransparency = 1,
		Text = "Secured module bootstrap",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(70, 70, 82),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderCard,
	})

	-- // Main menu (hidden until load finishes)
	local MenuRoot = C("CanvasGroup", {
		Name = "MenuRoot",
		Size = UDim2.new(0, 680, 0, 420),
		Position = UDim2.new(0.5, -340, 0.5, -210),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = ParentGUI,
	})

	local Shadow = C("Frame", {
		Size = UDim2.new(1, 10, 1, 10),
		Position = UDim2.new(0, 5, 0, 8),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = MenuRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Shadow })

	local Menu = C("Frame", {
		Name = "Menu",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(11, 11, 14),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 2,
		Parent = MenuRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Menu })
	C("UIStroke", {
		Color = Color3.fromRGB(42, 42, 52),
		Thickness = 1,
		Transparency = 0.2,
		Parent = Menu,
	})

	local Top = C("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Top })

	local TopMask = C("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Top,
	})

	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(34, 34, 42),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Top,
	})

	local AccentBar = C("Frame", {
		Size = UDim2.new(0, 3, 0, 22),
		Position = UDim2.new(0, 18, 0.5, -11),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Top,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = AccentBar })

	C("TextLabel", {
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 30, 0, 0),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Top,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 120, 1, 0),
		Position = UDim2.new(0, 118, 0, 0),
		BackgroundTransparency = 1,
		Text = "ESP STUDIO",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = ACC,
		TextTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Top,
	})

	local VerBadge = C("Frame", {
		Size = UDim2.new(0, 52, 0, 20),
		Position = UDim2.new(1, -68, 0.5, -10),
		BackgroundColor3 = ACC_SOFT,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Top,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = VerBadge })
	C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.65, Parent = VerBadge })
	C("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "v2.0",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = ACC,
		ZIndex = 5,
		Parent = VerBadge,
	})

	local Side = C("Frame", {
		Size = UDim2.new(0, 158, 1, -52),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(13, 13, 17),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})

	C("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(34, 34, 42),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Side,
	})

	local SidePad = C("Frame", {
		Size = UDim2.new(1, -20, 1, -24),
		Position = UDim2.new(0, 10, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = Side,
	})
	C("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SidePad })

	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "NAVIGATION",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(75, 75, 88),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		ZIndex = 4,
		Parent = SidePad,
	})

	local Pages = C("Frame", {
		Size = UDim2.new(0, 268, 1, -72),
		Position = UDim2.new(0, 174, 0, 62),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = Menu,
	})

	local Pgs = {}
	local ActiveTabBtn = nil
	local ActiveIndicator = nil

	local PrvP = C("Frame", {
		Size = UDim2.new(0, 210, 1, -72),
		Position = UDim2.new(1, -224, 0, 62),
		BackgroundColor3 = Color3.fromRGB(9, 9, 12),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = PrvP })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Parent = PrvP })

	C("TextLabel", {
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.new(0, 14, 0, 12),
		BackgroundTransparency = 1,
		Text = "LIVE PREVIEW",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(95, 95, 108),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = PrvP,
	})

	local Grid = C("Frame", {
		Size = UDim2.new(1, -28, 1, -52),
		Position = UDim2.new(0, 14, 0, 36),
		BackgroundColor3 = Color3.fromRGB(7, 7, 10),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = PrvP,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Grid })
	C("UIStroke", { Color = Color3.fromRGB(26, 26, 34), Thickness = 1, Parent = Grid })

	for i = 0, 7 do
		local line = C("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, i / 8, 0),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = Grid,
		})
		line.Size = UDim2.new(1, 0, 0, 1)
	end
	for i = 0, 5 do
		C("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(i / 6, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(22, 22, 28),
			BackgroundTransparency = 0.35,
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
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = M_Box,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 2), Parent = M_Cham })
	C("UIStroke", { Thickness = S.Th, Color = ACC, Parent = M_Box })

	local M_Nm = C("TextLabel", {
		Size = UDim2.new(1, 20, 0, 14),
		Position = UDim2.new(0.5, -46, 0, -18),
		BackgroundTransparency = 1,
		Text = "Enemy  ·  15m",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = ACC,
		ZIndex = 7,
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
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = M_Tr })

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
				local x1, y1 = sk.from.X.Scale * w + sk.from.X.Offset, sk.from.Y.Scale * h + sk.from.Y.Offset
				local x2, y2 = sk.to.X.Scale * w + sk.to.X.Offset, sk.to.Y.Scale * h + sk.to.Y.Offset
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
		M_Box.Visible = S.Box or S.Name or S.Health or S.Trace or S.Skel or S.Chams
		M_Cham.Visible = S.Chams
		M_Nm.Visible = S.Name
		M_Tr.Visible = S.Trace
		M_HB.Visible = S.Health
		M_Box:FindFirstChildOfClass("UIStroke").Enabled = S.Box or S.Chams
		UpdSkelPreview()
	end
	UpdPreview()

	M_Box:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdSkelPreview)

	local Footer = C("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 1, -34),
		BackgroundColor3 = Color3.fromRGB(13, 13, 17),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Menu,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(34, 34, 42),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Footer,
	})

	local StatusDot = C("Frame", {
		Size = UDim2.new(0, 7, 0, 7),
		Position = UDim2.new(0, 18, 0.5, -3),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Footer,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = StatusDot })

	C("TextLabel", {
		Size = UDim2.new(0, 160, 1, 0),
		Position = UDim2.new(0, 32, 0, 0),
		BackgroundTransparency = 1,
		Text = "System ready",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(120, 120, 132),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Footer,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(1, -214, 0, 0),
		BackgroundTransparency = 1,
		Text = "RIGHT SHIFT  ·  toggle menu",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(75, 75, 88),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
		Parent = Footer,
	})

	local function SetTabActive(btn, page)
		for b, p in pairs(Pgs) do
			b.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
			b.TextColor3 = Color3.fromRGB(110, 110, 122)
			if b:FindFirstChild("Indicator") then
				b.Indicator.BackgroundTransparency = 1
			end
			p.Visible = false
		end
		btn.BackgroundColor3 = ACC_SOFT
		btn.TextColor3 = Color3.fromRGB(245, 245, 250)
		if btn:FindFirstChild("Indicator") then
			btn.Indicator.BackgroundTransparency = 0
		end
		page.Visible = true
		ActiveTabBtn = btn
	end

	local function MakeTab(name, default)
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = default and ACC_SOFT or Color3.fromRGB(18, 18, 24),
			Text = "  " .. name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = default and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(110, 110, 122),
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = default and 1 or 2,
			ZIndex = 5,
			Parent = SidePad,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = B })
		local Ind = C("Frame", {
			Name = "Indicator",
			Size = UDim2.new(0, 3, 0, 18),
			Position = UDim2.new(0, 4, 0.5, -9),
			BackgroundColor3 = ACC,
			BackgroundTransparency = default and 0 or 1,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = B,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Ind })

		local P = C("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = ACC,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Visible = default,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = Pages,
		})
		C("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = P })
		C("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), Parent = P })

		B.MouseEnter:Connect(function()
			if B ~= ActiveTabBtn then
				TweenPlay(B, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(22, 22, 28) })
			end
		end)
		B.MouseLeave:Connect(function()
			if B ~= ActiveTabBtn then
				TweenPlay(B, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 18, 24) })
			end
		end)
		B.MouseButton1Click:Connect(function()
			SetTabActive(B, P)
		end)

		Pgs[B] = P
		if default then ActiveTabBtn = B end
		return P
	end

	local function MakeSection(page, title, order)
		C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(80, 80, 92),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
	end

	local function MakeTog(page, label, key, order)
		local on = S[key] == true
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Color3.fromRGB(16, 16, 21),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Row })
		C("UIStroke", {
			Color = Color3.fromRGB(34, 34, 42),
			Thickness = 1,
			Transparency = 0.35,
			Parent = Row,
		})

		local Title = C("TextLabel", {
			Size = UDim2.new(1, -58, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(210, 210, 218),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local SwitchBg = C("Frame", {
			Size = UDim2.new(0, 40, 0, 22),
			Position = UDim2.new(1, -50, 0.5, -11),
			BackgroundColor3 = on and ACC or Color3.fromRGB(38, 38, 46),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchBg })

		local SwitchDot = C("Frame", {
			Size = UDim2.new(0, 16, 0, 16),
			Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
			BackgroundColor3 = Color3.fromRGB(250, 250, 255),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = SwitchBg,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchDot })

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(20, 20, 26) })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(16, 16, 21) })
		end)

		Row.MouseButton1Click:Connect(function()
			S[key] = not S[key]
			local enabled = S[key]
			TweenPlay(SwitchBg, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				BackgroundColor3 = enabled and ACC or Color3.fromRGB(38, 38, 46),
			})
			TweenPlay(SwitchDot, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
			})
			TweenPlay(Title, TweenInfo.new(0.15), {
				TextColor3 = enabled and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(210, 210, 218),
			})
			UpdPreview()
		end)
	end

	local T1 = MakeTab("Visuals", true)
	local T2 = MakeTab("Settings", false)

	MakeSection(T1, "CORE", 1)
	MakeTog(T1, "Master ESP", "ESP", 2)
	MakeSection(T1, "OVERLAYS", 3)
	MakeTog(T1, "Bounding Boxes", "Box", 4)
	MakeTog(T1, "Player Names", "Name", 5)
	MakeTog(T1, "Health Bars", "Health", 6)
	MakeSection(T1, "ADVANCED", 7)
	MakeTog(T1, "Skeleton", "Skel", 8)
	MakeTog(T1, "Tracers", "Trace", 9)
	MakeTog(T1, "Chams Fill", "Chams", 10)

	MakeSection(T2, "FILTERS", 1)
	MakeTog(T2, "Team Colors", "RealTeamColor", 2)
	MakeTog(T2, "Hide Teammates", "Team", 3)
	MakeTog(T2, "Line of Sight", "LoS", 4)

	-- // Drag + toggle
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
			local delta = input.Position - dragStart
			MenuRoot.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
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
			local show = not MenuRoot.Visible or MenuRoot.GroupTransparency > 0.5
			if show then
				MenuRoot.Visible = true
				TweenPlay(MenuRoot, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					GroupTransparency = 0,
				})
				TweenPlay(Menu, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(1, 0, 1, 0),
				})
			else
				local tw = TweenPlay(MenuRoot, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
					GroupTransparency = 1,
				})
				tw.Completed:Connect(function()
					MenuRoot.Visible = false
				end)
			end
		end
	end)

	-- // Loading sequence
	task.spawn(function()
		local steps = {
			{ text = "Authenticating session…", pct = 0.18 },
			{ text = "Loading ESP modules…", pct = 0.42 },
			{ text = "Compiling render pipeline…", pct = 0.68 },
			{ text = "Building interface…", pct = 0.88 },
			{ text = "Launch complete", pct = 1 },
		}

		for _, step in ipairs(steps) do
			LoaderStatus.Text = step.text
			LoaderPct.Text = math.floor(step.pct * 100) .. "%"
			TweenPlay(Fill, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.pct, 0, 1, 0),
			})
			task.wait(0.38)
		end

		task.wait(0.15)

		TweenPlay(LoaderCard, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -220, 0.5, -135),
		})
		TweenPlay(Loader, TweenInfo.new(0.35), { BackgroundTransparency = 1 })

		task.wait(0.2)
		Loader:Destroy()

		MenuRoot.Visible = true
		MenuRoot.Size = UDim2.new(0, 680, 0, 420)
		MenuRoot.Position = UDim2.new(0.5, -340, 0.5, -210)

		TweenPlay(MenuRoot, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
		})
	end)

	-- Subtle status pulse
	task.spawn(function()
		while StatusDot.Parent do
			TweenPlay(StatusDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.45,
			})
			task.wait(0.9)
			TweenPlay(StatusDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0,
			})
			task.wait(0.9)
		end
	end)
end

return UI
