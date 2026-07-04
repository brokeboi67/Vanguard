-- Plik: workspace/Vanguard/UI.lua

local UI = {}

function UI.Init(S, ParentGUI, ConfigModule, TF, AnimationsModule, WorldModule, MenusModule, GameSupportModule)
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")

	local ACC = S.V
	local ACC_SOFT = Color3.new(
		math.clamp(ACC.R * 0.12 + 0.08, 0, 1),
		math.clamp(ACC.G * 0.12 + 0.08, 0, 1),
		math.clamp(ACC.B * 0.12 + 0.08, 0, 1)
	)

	local pageThemes = {}
	local tabBtnThemes = {}
	local TAB_THEMES = {
		Visuals = Color3.fromRGB(90, 175, 255),
		Legit = Color3.fromRGB(80, 255, 160),
		Rage = Color3.fromRGB(255, 85, 85),
		Anim = Color3.fromRGB(255, 150, 230),
		World = Color3.fromRGB(130, 210, 110),
		Settings = Color3.fromRGB(175, 175, 195),
		Misc = Color3.fromRGB(255, 195, 75),
		Config = Color3.fromRGB(155, 135, 255),
		Menus = Color3.fromRGB(255, 120, 180),
	}

	local function tabSoft(col)
		return Color3.new(
			math.clamp(col.R * 0.14 + 0.07, 0, 1),
			math.clamp(col.G * 0.14 + 0.07, 0, 1),
			math.clamp(col.B * 0.14 + 0.07, 0, 1)
		)
	end

	local Cam = workspace.CurrentCamera
	local W_FULL, W_COMPACT, H = 800, 600, 540
	local SIDE_W = 136
	local RS = game:GetService("RunService")

	ParentGUI.DisplayOrder = 999999
	ParentGUI.ZIndexBehavior = Enum.ZIndexBehavior.Global

	local function refreshLayout()
		local vp = Cam.ViewportSize
		W_FULL = math.clamp(math.floor(vp.X * 0.58), 660, 900)
		W_COMPACT = math.clamp(math.floor(vp.X * 0.48), 540, 660)
		H = math.clamp(math.floor(vp.Y * 0.68), 500, 640)
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

	-- // Loading overlay — minimalist top bar
	local Loader = C("Frame", {
		Name = "Loader",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = ParentGUI,
	})

	local LoaderTop = C("Frame", {
		Name = "LoaderTop",
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 15),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = Loader,
	})

	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(38, 38, 46),
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = LoaderTop,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 140, 0, 16),
		Position = UDim2.new(0, 20, 0, 12),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderTop,
	})

	local LoaderStatus = C("TextLabel", {
		Size = UDim2.new(1, -180, 0, 14),
		Position = UDim2.new(0, 20, 0, 30),
		BackgroundTransparency = 1,
		Text = "Initializing",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(105, 105, 115),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderTop,
	})

	local LoaderPct = C("TextLabel", {
		Size = UDim2.new(0, 44, 0, 14),
		Position = UDim2.new(1, -64, 0, 30),
		BackgroundTransparency = 1,
		Text = "0%",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 102,
		Parent = LoaderTop,
	})

	local Track = C("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		ZIndex = 103,
		Parent = LoaderTop,
	})

	local Fill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 104,
		Parent = Track,
	})

	local LoaderGame = C("Frame", {
		Name = "LoaderGame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.54, 0),
		Size = UDim2.new(0, 320, 0, 88),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 101,
		Parent = Loader,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = LoaderGame })
	C("UIStroke", {
		Color = Color3.fromRGB(38, 38, 48),
		Thickness = 1,
		Parent = LoaderGame,
	})

	local LoaderGameIcon = C("ImageLabel", {
		Size = UDim2.new(0, 56, 0, 56),
		Position = UDim2.new(0, 14, 0.5, -28),
		BackgroundColor3 = Color3.fromRGB(22, 22, 28),
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 102,
		Parent = LoaderGame,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = LoaderGameIcon })

	local LoaderGameName = C("TextLabel", {
		Size = UDim2.new(1, -92, 0, 22),
		Position = UDim2.new(0, 82, 0, 16),
		BackgroundTransparency = 1,
		Text = "Loading game info...",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 102,
		Parent = LoaderGame,
	})

	local LoaderSupportBadge = C("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16),
		Position = UDim2.new(0, 82, 0, 40),
		BackgroundTransparency = 1,
		Text = "NO DATA",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 145),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
		Parent = LoaderGame,
	})

	local LoaderSupportNote = C("TextLabel", {
		Size = UDim2.new(1, -92, 0, 28),
		Position = UDim2.new(0, 82, 0, 56),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(105, 105, 115),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 102,
		Parent = LoaderGame,
	})

	local function refreshLoaderGameInfo()
		local placeId = game.PlaceId
		local gameId = game.GameId
		local fallbackThumb = GameSupportModule
			and GameSupportModule.getThumbnail(nil, gameId)
			or (gameId > 0 and ("rbxthumb://type=GameThumbnail&id=" .. gameId .. "&w=150&h=150") or "")
		LoaderGameIcon.Image = fallbackThumb
		LoaderGameName.Text = game.Name ~= "" and game.Name or ("Place " .. tostring(placeId))

		if not GameSupportModule then
			LoaderSupportBadge.Text = "NO DATA"
			LoaderSupportBadge.TextColor3 = Color3.fromRGB(130, 130, 145)
			LoaderSupportNote.Text = ""
			return
		end

		local status, note = GameSupportModule.getStatus(placeId, gameId)
		local badge, badgeColor = GameSupportModule.getStatusDisplay(status)
		LoaderSupportBadge.Text = badge
		LoaderSupportBadge.TextColor3 = badgeColor
		LoaderSupportNote.Text = note or ""

		task.spawn(function()
			local name, thumb = GameSupportModule.getGameInfo(placeId, gameId)
			LoaderGameName.Text = name
			if thumb and thumb ~= "" then
				LoaderGameIcon.Image = thumb
			end
		end)
	end

	refreshLoaderGameInfo()

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
		Size = UDim2.new(0, SIDE_W, 1, -48),
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
		Size = UDim2.new(0, 360, 1, -82),
		Position = UDim2.new(0, SIDE_W + 10, 0, 58),
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
			M_Cham.BackgroundColor3 = S.V
		end
		M_BoxStroke.Color = S.V
		M_BoxStroke.Thickness = S.Th
		M_Nm.TextColor3 = S.V
		M_Tr.Size = UDim2.new(0, S.Th, 0, 52)
		M_Tr.BackgroundColor3 = S.V
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
	local colorRegistry = {}

	local function formatBindName(name)
		if name == "MouseButton1" then
			return "M1"
		end
		if name == "MouseButton2" then
			return "M2"
		end
		if name == "MouseButton3" then
			return "M3"
		end
		return name or "None"
	end

	local function espCustomColorsEnabled()
		return not S.LoS and not S.ChamsRainbow and not S.RealTeamColor
	end

	local updateEspColorControls

	local function CancelTweens(list)
		for _, tw in ipairs(list) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(list)
	end

	local function ApplyLayout(showPreview, animate, keepPosition)
		refreshLayout()
		local targetW = showPreview and W_FULL or W_COMPACT
		local previewW = showPreview and 212 or 0
		local targetContentW = targetW - SIDE_W - previewW - 28

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
		local accent = tabBtnThemes[btn] or ACC
		local soft = tabSoft(accent)
		TweenPlay(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
			BackgroundColor3 = active and soft or Color3.fromRGB(18, 18, 22),
			TextColor3 = active and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(105, 105, 115),
		})
		local ind = btn:FindFirstChild("Indicator")
		if ind then
			ind.BackgroundColor3 = accent
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
		local tabAccent = TAB_THEMES[name] or ACC
		local tabSoftCol = tabSoft(tabAccent)
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = default and tabSoftCol or Color3.fromRGB(18, 18, 22),
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
		tabBtnThemes[B] = tabAccent
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = B })
		C("Frame", {
			Name = "Indicator",
			Size = UDim2.new(0, 2, 0, 16),
			Position = UDim2.new(0, 0, 0.5, -8),
			BackgroundColor3 = tabAccent,
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
		C("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = P })
		C("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = P })
		pageThemes[P] = tabAccent

		B.MouseEnter:Connect(function()
			if B ~= ActiveTabBtn then
				TweenPlay(B, TweenInfo.new(0.12), { BackgroundColor3 = tabSoft(tabAccent) })
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

	local function MakeCard(page, title, subtitle, order)
		local tabCol = pageThemes[page] or ACC
		local Card = C("Frame", {
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(16, 16, 20),
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Card })
		local strokeCol = Color3.new(
			math.clamp(tabCol.R * 0.35 + 0.12, 0, 1),
			math.clamp(tabCol.G * 0.35 + 0.12, 0, 1),
			math.clamp(tabCol.B * 0.35 + 0.12, 0, 1)
		)
		C("UIStroke", { Color = strokeCol, Thickness = 1, Transparency = 0.45, Parent = Card })
		C("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = Card,
		})
		C("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Card })

		C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 12),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = tabCol,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			ZIndex = 6,
			Parent = Card,
		})

		if subtitle then
			C("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = subtitle,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextColor3 = Color3.fromRGB(92, 92, 102),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 2,
				ZIndex = 6,
				Parent = Card,
			})
		end

		local Body = C("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			ZIndex = 6,
			Parent = Card,
		})
		C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Body })
		return Body
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
		local list = toggleRegistry[key]
		if not list then
			return
		end
		for _, t in ipairs(list) do
			TweenPlay(t.SwitchBg, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				BackgroundColor3 = enabled and ACC or Color3.fromRGB(36, 36, 44),
			})
			TweenPlay(t.SwitchDot, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
			})
		end
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

	local LEGIT_KEYS = { "Aimbot", "Silent", "Trigger" }
	local LEGIT_LABELS = { Aimbot = "Aimbot", Silent = "Silent Aim", Trigger = "Triggerbot" }

	local function applyRageLegitExclusivity(fromKey, turningOn)
		if not turningOn then
			return
		end
		if fromKey == "MasterRage" then
			local off = {}
			for _, k in ipairs(LEGIT_KEYS) do
				if S[k] then
					S[k] = false
					setToggleVisual(k, false)
					table.insert(off, LEGIT_LABELS[k])
				end
			end
			if #off > 0 then
				showNotify("Wyłączono Legit: " .. table.concat(off, ", "))
			end
		elseif fromKey == "Aimbot" or fromKey == "Silent" or fromKey == "Trigger" then
			if S.MasterRage then
				S.MasterRage = false
				setToggleVisual("MasterRage", false)
				showNotify("Wyłączono: Master Rage")
			end
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
			lbl.Text = formatBindName(S[key])
		end
		if updateEspColorControls then
			updateEspColorControls()
		end
		if S.RebindSilent then
			pcall(S.RebindSilent)
		end
		UpdPreview()
	end

	local mouseUnlockConn = nil
	local mouseUnlockHB = nil
	local mouseRestoreConn = nil

	local function MakeTog(page, label, key, order, opts)
		opts = opts or {}
		local flat = opts.flat
		local on = S[key] == true
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, flat and 32 or 36),
			BackgroundColor3 = flat and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(17, 17, 21),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		if not flat then
			C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })
		end

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
				applyRageLegitExclusivity(key, true)
			end

			setToggleVisual(key, enabled)
			UpdPreview()
			if key == "LoS" or key == "RealTeamColor" or key == "ChamsRainbow" then
				if updateEspColorControls then
					updateEspColorControls()
				end
			end
			if opts.onChange then
				pcall(opts.onChange, enabled)
			end
		end)

		if not toggleRegistry[key] then
			toggleRegistry[key] = {}
		end
		table.insert(toggleRegistry[key], { SwitchBg = SwitchBg, SwitchDot = SwitchDot })
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

	local function MakeBind(page, label, key, order, opts)
		opts = opts or {}
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
			Text = formatBindName(S[key]),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = ACC,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = KeyLbl })

		local listenConn
		local function finishBind(name)
			S[key] = name
			KeyLbl.Text = formatBindName(name)
			KeyLbl.TextColor3 = ACC
			bindListening = false
			if listenConn then
				listenConn:Disconnect()
				listenConn = nil
			end
			if opts.onChange then
				pcall(opts.onChange, name)
			end
		end

		Row.MouseButton1Click:Connect(function()
			if bindListening then
				return
			end
			bindListening = true
			KeyLbl.Text = "…"
			KeyLbl.TextColor3 = Color3.fromRGB(200, 200, 120)
			listenConn = UIS.InputBegan:Connect(function(input, processed)
				if processed then
					return
				end
				if input.KeyCode ~= Enum.KeyCode.Unknown then
					finishBind(input.KeyCode.Name)
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					finishBind("MouseButton1")
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					finishBind("MouseButton2")
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
					finishBind("MouseButton3")
				end
			end)
		end)
		bindRegistry[key] = KeyLbl
	end

	local function MakeColorPicker(page, label, key, order)
		local host = C("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = host,
		})

		local Head = C("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			BorderSizePixel = 0,
			LayoutOrder = 1,
			ZIndex = 5,
			Parent = host,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Head })

		C("TextLabel", {
			Size = UDim2.new(1, -52, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Head,
		})

		local Swatch = C("Frame", {
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(1, -36, 0.5, -12),
			BackgroundColor3 = S[key] or Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Head,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = Swatch })
		C("UIStroke", { Color = Color3.fromRGB(50, 50, 58), Thickness = 1, Parent = Swatch })

		local sliders = {}
		local function applyColor()
			local r = sliders.R and sliders.R.val or 0
			local g = sliders.G and sliders.G.val or 0
			local b = sliders.B and sliders.B.val or 0
			S[key] = Color3.fromRGB(r, g, b)
			Swatch.BackgroundColor3 = S[key]
			UpdPreview()
		end

		local function addChannel(ch, channelKey, layoutOrder)
			local min, max = 0, 255
			local Row = C("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(17, 17, 21),
				BorderSizePixel = 0,
				LayoutOrder = layoutOrder,
				ZIndex = 5,
				Parent = host,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })

			local cur = math.floor((S[key] or Color3.new(1, 1, 1))[channelKey] * 255 + 0.5)
			local ValLbl = C("TextLabel", {
				Size = UDim2.new(0, 36, 0, 14),
				Position = UDim2.new(1, -44, 0, 8),
				BackgroundTransparency = 1,
				Text = tostring(cur),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = ACC,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 6,
				Parent = Row,
			})

			C("TextLabel", {
				Size = UDim2.new(1, -52, 0, 14),
				Position = UDim2.new(0, 12, 0, 8),
				BackgroundTransparency = 1,
				Text = ch,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(200, 200, 208),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6,
				Parent = Row,
			})

			local Track = C("TextButton", {
				Size = UDim2.new(1, -24, 0, 6),
				Position = UDim2.new(0, 12, 0, 22),
				BackgroundColor3 = Color3.fromRGB(28, 28, 36),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 6,
				Parent = Row,
			})
			C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Track })

			local Fill = C("Frame", {
				Size = UDim2.new(cur / max, 0, 1, 0),
				BackgroundColor3 = ACC,
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = Track,
			})
			C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Fill })

			local reg = { val = cur, row = Row, track = Track, fill = Fill, valLbl = ValLbl, active = true }
			sliders[ch] = reg

			local dragging = false
			local function setVal(raw)
				local val = math.clamp(math.floor(raw + 0.5), min, max)
				reg.val = val
				ValLbl.Text = tostring(val)
				Fill.Size = UDim2.new(val / max, 0, 1, 0)
				applyColor()
			end
			local function fromInput(x)
				local ax = Track.AbsolutePosition.X
				local aw = Track.AbsoluteSize.X
				if aw <= 0 then
					return
				end
				setVal(min + (max - min) * math.clamp((x - ax) / aw, 0, 1))
			end

			Track.MouseButton1Down:Connect(function()
				if not reg.active then
					return
				end
				dragging = true
				fromInput(UIS:GetMouseLocation().X)
			end)
			Track.MouseButton1Up:Connect(function()
				dragging = false
			end)
			Track.MouseButton1Click:Connect(function()
				if reg.active then
					fromInput(UIS:GetMouseLocation().X)
				end
			end)
			UIS.InputChanged:Connect(function(input)
				if dragging and reg.active and input.UserInputType == Enum.UserInputType.MouseMovement then
					fromInput(input.Position.X)
				end
			end)
		end

		addChannel("R", "R", 2)
		addChannel("G", "G", 3)
		addChannel("B", "B", 4)

		table.insert(colorRegistry, {
			host = host,
			swatch = Swatch,
			sliders = sliders,
			setEnabled = function(on)
				for _, reg in pairs(sliders) do
					reg.active = on
					reg.row.BackgroundTransparency = on and 0 or 0.35
				end
				Head.BackgroundTransparency = on and 0 or 0.35
			end,
			refresh = function()
				local col = S[key] or Color3.new(1, 1, 1)
				Swatch.BackgroundColor3 = col
				for ch, channelKey in pairs({ R = "R", G = "G", B = "B" }) do
					local reg = sliders[ch]
					if reg then
						local val = math.floor(col[channelKey] * 255 + 0.5)
						reg.val = val
						reg.valLbl.Text = tostring(val)
						reg.fill.Size = UDim2.new(val / 255, 0, 1, 0)
					end
				end
			end,
		})
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
	local T3 = MakeTab("Legit", false, false, 2)
	local TR = MakeTab("Rage", false, false, 3)
	local TAnim = MakeTab("Anim", false, false, 4)
	local TWorld = MakeTab("World", false, false, 5)
	local T2 = MakeTab("Settings", false, false, 6)
	local TM = MakeTab("Misc", false, false, 7)
	local T4 = MakeTab("Config", false, false, 8)
	local TMenu = MakeTab("Menus", false, false, 9)

	local VCore = MakeCard(T1, "ESP", nil, 1)
	MakeTog(VCore, "Master ESP", "ESP", 1, { flat = true })
	local VFilter = MakeCard(T1, "FILTERS", "Ukrywanie teammateów i znajomych z ESP.", 2)
	MakeTog(VFilter, "Hide Teammates", "Team", 1, { flat = true })
	MakeHint(VFilter, "Ctrl+Click na gracza dodaje znajomego — ukryty jak teammate (Settings).", 2)

	local VDist = MakeCard(T1, "DISTANCE", nil, 3)
	MakeTog(VDist, "Show Distance", "DistView", 1, { flat = true })
	MakeSlider(VDist, "Distance Limit", "MaxDist", 50, 1500, 2)
	local VOver = MakeCard(T1, "OVERLAYS", nil, 4)
	MakeTog(VOver, "Bounding Boxes", "Box", 1, { flat = true })
	MakeChoice(VOver, "Box Type", "BoxType", {
		{ label = "Full", value = "Full" },
		{ label = "Corner", value = "Corner" },
	}, 2)
	MakeTog(VOver, "Player Names", "Name", 3, { flat = true })
	MakeTog(VOver, "Health Bars", "Health", 4, { flat = true })
	MakeTog(VOver, "Health Text", "HealthText", 5, { flat = true })
	MakeTog(VOver, "Weapon ESP", "Weapon", 6, { flat = true })

	local VAdv = MakeCard(T1, "ADVANCED", "Rainbow / Team Colors / LoS się wykluczają.", 5)
	MakeTog(VAdv, "Render Bots", "RenderBots", 1, { flat = true })
	MakeTog(VAdv, "Skeleton", "Skel", 2, { flat = true })
	MakeTog(VAdv, "Tracers", "Trace", 3, { flat = true })
	MakeTog(VAdv, "Chams Fill", "Chams", 4, { flat = true })
	MakeTog(VAdv, "Chams Rainbow", "ChamsRainbow", 5, { flat = true })
	MakeTog(VAdv, "Offscreen Arrows", "OffscreenArrows", 6, { flat = true })
	MakeHint(VAdv, "Strzałki na krawędzi ekranu wskazują wrogów poza FOV (wymaga ESP).", 7)

	local VTrace = MakeCard(T1, "SHOT TRACERS", "Neonowa linia od broni do celu — tylko Ty widzisz.", 6)
	MakeTog(VTrace, "Bullet Tracers", "ShotTracers", 1, { flat = true })
	MakeTog(VTrace, "Kill Tracer (grubszy + glow)", "KillShotTracers", 2, { flat = true })
	MakeHint(VTrace, "Linia od crosshaira przez cel (przebija postać). Kill = grubsza czerwona + kula.", 3)

	local LAim = MakeCard(T3, "AIMBOT", "Aimbot i Silent się wykluczają.", 1)
	MakeTog(LAim, "Aimbot", "Aimbot", 1, { flat = true })
	MakeTog(LAim, "Silent Aim (flick)", "Silent", 2, {
		flat = true,
		onChange = function()
			if S.RebindSilent then
				pcall(S.RebindSilent)
			end
		end,
	})
	MakeTog(LAim, "Triggerbot", "Trigger", 3, { flat = true })

	local LAimBind = MakeCard(T3, "KEYBINDS", "Kliknij wiersz i naciśnij klawisz lub M1/M2/M3.", 2)
	MakeBind(LAimBind, "Aimbot Key", "AimKey", 1)
	MakeBind(LAimBind, "Silent Key", "SilentKey", 2, {
		onChange = function()
			if S.RebindSilent then
				pcall(S.RebindSilent)
			end
		end,
	})

	local LTrig = MakeCard(T3, "TRIGGERBOT", nil, 3)
	MakeChoice(LTrig, "Trigger Mode", "TriggerMode", {
		{ label = "Hold", value = "Hold" },
		{ label = "Toggle", value = "Toggle" },
	}, 1)
	MakeBind(LTrig, "Trigger Key", "TriggerKey", 2)
	MakeSlider(LTrig, "Trigger Delay", "TriggerDelay", 1, 500, 3, { suffix = "ms", step = 1 })
	MakeTog(LTrig, "Compatibility Mode", "TriggerCompat", 4, { flat = true })
	MakeTog(LTrig, "Trigger Status HUD", "ShowTriggerHud", 5, { flat = true })
	MakeTog(LTrig, "Minimal Trigger HUD", "TriggerHudMinimal", 6, { flat = true })
	MakeHint(LTrig, "Domyślnie strzela gdy wróg jest pod celownikiem — bez ruszania kamery. Compatibility = śledzi cel w FOV i strzela (gry z własnym hitregiem).", 7)

	local LTarget = MakeCard(T3, "TARGETING", nil, 4)
	MakeTog(LTarget, "Exclude Teammates & Friends", "ExcludeTeam", 1, { flat = true })
	MakeTog(LTarget, "Visible Check", "VisibleCheck", 2, { flat = true })
	MakeTog(LTarget, "Target Bots", "AimBots", 3, { flat = true })
	MakeChoice(LTarget, "Target Priority", "TargetMode", {
		{ label = "FOV", value = "FOV" },
		{ label = "Dist", value = "Distance" },
		{ label = "HP", value = "Health" },
	}, 4)
	MakeChoice(LTarget, "Hit Part", "HitPart", {
		{ label = "Head", value = "Head" },
		{ label = "Torso", value = "Torso" },
		{ label = "Random", value = "Random" },
		{ label = "Closest", value = "Closest" },
	}, 5)

	local LFov = MakeCard(T3, "FOV & SMOOTH", "Smooth działa tylko z Aimbot (hold keybind).", 5)
	MakeTog(LFov, "Show FOV Circle", "ShowFOV", 1, { flat = true })
	MakeSlider(LFov, "FOV Size", "FOV", 20, 300, 2, { suffix = "px", step = 5 })
	MakeSlider(LFov, "Smoothing", "Smooth", 0.05, 0.95, 3, {
		suffix = "",
		step = 0.05,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})
	MakeTog(LFov, "Aim Curve + Jitter", "AimCurve", 4, { flat = true })

	local RMaster = MakeCard(TR, "MASTER", "Wyłącza wszystkie funkcje Legit.", 1)
	MakeTog(RMaster, "Master Rage", "MasterRage", 1, { flat = true })

	local RAA = MakeCard(TR, "ANTI-AIM", "Obrót postaci od kamery + offsety.", 2)
	MakeTog(RAA, "Anti-Aim", "AntiAim", 1, { flat = true })
	MakeTog(RAA, "Spin", "AASpin", 2, { flat = true })
	MakeSlider(RAA, "Spin Speed", "AASpinSpeed", 1, 20, 3, { suffix = "", step = 1 })
	MakeSlider(RAA, "Yaw Offset", "AAYaw", -180, 180, 4, { suffix = "°", step = 5 })
	MakeSlider(RAA, "Pitch Offset", "AAPitch", -89, 89, 5, { suffix = "°", step = 5 })
	MakeTog(RAA, "Yaw Jitter", "AAJitter", 6, { flat = true })
	MakeSlider(RAA, "Jitter Range", "AAJitterRange", 5, 180, 7, { suffix = "°", step = 5 })

	local RBot = MakeCard(TR, "RAGEBOT", "Bez FOV — strzela gdy hitbox widoczny z kamery.", 3)
	MakeTog(RBot, "Ragebot", "RageBot", 1, { flat = true })
	MakeChoice(RBot, "Rage Mode", "RageMode", {
		{ label = "Hold", value = "Hold" },
		{ label = "Toggle", value = "Toggle" },
	}, 2)
	MakeBind(RBot, "Rage Key", "RageKey", 3)
	MakeSlider(RBot, "Rage Delay", "RageDelay", 1, 500, 4, { suffix = "ms", step = 1 })
	MakeTog(RBot, "Rage Status HUD", "ShowRageHud", 5, { flat = true })
	MakeTog(RBot, "Minimal Rage HUD", "RageHudMinimal", 6, { flat = true })
	MakeChoice(RBot, "Aim Mode", "RageAimMode", {
		{ label = "Silent", value = "Silent" },
		{ label = "Track", value = "Track" },
		{ label = "Snap", value = "Snap" },
	}, 7)
	MakeSlider(RBot, "Track Smooth", "RageTrackSmooth", 0.05, 0.95, 8, {
		suffix = "",
		step = 0.05,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})
	MakeTog(RBot, "Compatibility Mode", "RageCompat", 9, { flat = true })
	MakeHint(RBot, "Silent = krótki flick + powrót kamery. Track = lock. Snap = celuj i strzelaj. Compatibility = track + strzał dla gier z własnym hitregiem.", 10)

	local RTarget = MakeCard(TR, "TARGETING", nil, 4)
	MakeTog(RTarget, "Exclude Teammates & Friends", "ExcludeTeam", 1, { flat = true })
	MakeTog(RTarget, "Visible Check", "RageVisibleCheck", 2, { flat = true })
	MakeTog(RTarget, "Target Bots", "RageBots", 3, { flat = true })
	MakeChoice(RTarget, "Hit Part", "RageHitPart", {
		{ label = "Head", value = "Head" },
		{ label = "Torso", value = "Torso" },
		{ label = "Random", value = "Random" },
		{ label = "Closest", value = "Closest" },
	}, 4)
	MakeSlider(RTarget, "Max Distance", "RageMaxDist", 50, 1500, 5, { suffix = "m", step = 25 })

	local WEnv = MakeCard(TWorld, "ENVIRONMENT", "Zmiany tylko u Ciebie (lokalne).", 1)
	MakeTog(WEnv, "FullBright", "FullBright", 1, { flat = true })
	MakeTog(WEnv, "No Fog", "NoFog", 2, { flat = true })
	MakeTog(WEnv, "Lock Time", "WorldTimeLock", 3, { flat = true })
	MakeSlider(WEnv, "Clock Time", "WorldTime", 0, 24, 4, {
		suffix = "h",
		step = 0.25,
		fmt = function(v) return string.format("%.1f", v) end,
	})
	MakeHint(WEnv, "FullBright wyłącza cienie i podbija Ambient. No Fog czyści Atmosphere.", 5)

	local WLight = MakeCard(TWorld, "CUSTOM LIGHT", "Kolor otoczenia (ColorShift).", 2)
	MakeTog(WLight, "Custom Tint", "WorldCustomLight", 1, { flat = true })
	MakeSlider(WLight, "Tint Hue", "WorldColorHue", 0, 1, 2, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 360) .. "°" end,
	})
	MakeSlider(WLight, "Tint Saturation", "WorldColorSat", 0, 1, 3, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})

	local WUi = MakeCard(TWorld, "MENU", nil, 3)
	MakeTog(WUi, "Menu Blur", "MenuBlur", 1, { flat = true })
	MakeSlider(WUi, "Blur Strength", "MenuBlurSize", 4, 48, 2, { suffix = "px", step = 1 })

	local APlay = MakeCard(TAnim, "EMOTES", "Animacje przez Humanoid — inni widzą je w większości gier.", 1)
	MakeButton(APlay, "Stop Animation", 1, function()
		if AnimationsModule then
			AnimationsModule.Stop()
			showNotify("Animacja zatrzymana")
		end
	end)
	local animOrder = 2
	if AnimationsModule and AnimationsModule.LIST then
		for _, entry in ipairs(AnimationsModule.LIST) do
			local e = entry
			MakeButton(APlay, e.label, animOrder, function()
				if not AnimationsModule then
					return
				end
				local ok, err = AnimationsModule.Play(e)
				if ok then
					showNotify("Animacja: " .. e.label)
				else
					showNotify(err or "Błąd animacji")
				end
			end)
			animOrder += 1
		end
	end
	MakeHint(APlay, "Procedural: Twerk, Floss, Griddy, Spin, Thunder, Matrix, Disco, Levitate. Reszta = Animate gry lub /e chat.", animOrder)

	local MMove = MakeCard(TM, "MOVEMENT", "Auto Strafe działa w powietrzu (razem z BHop).", 1)
	MakeTog(MMove, "Bunny Hop", "BHop", 1, { flat = true })
	MakeTog(MMove, "Auto Strafe", "AutoStrafe", 2, { flat = true })

	local MHit = MakeCard(TM, "HITBOX EXPANDER", "Niewidoczne hitboxy — nie powiększa modelu postaci.", 2)
	MakeTog(MHit, "Head Size", "HeadSize", 1, { flat = true })
	MakeSlider(MHit, "Head Scale", "HeadSizeScale", 1, 6, 2, {
		suffix = "x",
		step = 0.1,
		fmt = function(v) return string.format("%.1fx", v) end,
	})
	MakeTog(MHit, "Hitbox Size", "HitboxSize", 3, { flat = true })
	MakeSlider(MHit, "Hitbox Scale", "HitboxSizeScale", 1, 5, 4, {
		suffix = "x",
		step = 0.1,
		fmt = function(v) return string.format("%.1fx", v) end,
	})
	MakeTog(MHit, "Include Friends / Team", "MiscAffectFriends", 5, { flat = true })
	MakeTog(MHit, "Apply To Bots", "MiscBots", 6, { flat = true })
	MakeHint(MHit, "Powiększa hitboxy lokalnie dla aim/trigger (folder VG_Hitboxes). Nie zmienia serwera.", 7)
	MakeHint(MHit, "Domyślnie pomija teammateów i znajomych (zgodnie z Exclude Team).", 8)

	local MSec = MakeCard(TM, "SECURITY", "gethui + protect_gui + losowe nazwy GUI (bez lagujących hooków).", 3)
	MakeTog(MSec, "Anti-Cheat Bypass", "AntiBypass", 1, { flat = true })
	MakeHint(MSec, "267 = gra wykrywa skrypt/executor. Używaj gethui i nie ładuj 2 cheatów naraz.", 2)

	local MFX = MakeCard(TM, "LOCAL FX", "Tylko Ty widzisz — efekty przy hit / kill.", 4)
	MakeTog(MFX, "Kill Effects", "KillEffects", 1, { flat = true })
	MakeChoice(MFX, "Kill Style", "KillEffectStyle", {
		{ label = "Neon", value = "Neon" },
		{ label = "Burst", value = "Burst" },
		{ label = "Ascend", value = "Ascension" },
		{ label = "Shock", value = "Shock" },
		{ label = "Nova", value = "Nova" },
		{ label = "Random", value = "Random" },
	}, 2)
	MakeTog(MFX, "Hit Effects", "HitEffects", 3, { flat = true })
	MakeChoice(MFX, "Hit Style", "HitEffectStyle", {
		{ label = "Lightning", value = "Lightning" },
		{ label = "Sparks", value = "Sparks" },
		{ label = "Nova", value = "Nova" },
		{ label = "Impact", value = "Impact" },
	}, 4)
	MakeTog(MFX, "Self Aura On Kill", "SelfKillFX", 5, { flat = true })
	MakeButton(MFX, "Test Kill FX", 6, function()
		if S.TestKillEffect then
			local ok, err = S.TestKillEffect()
			if ok == false then
				showNotify(err or "Brak celu")
			else
				showNotify("Kill FX na wrogu w crosshair")
			end
		end
	end)
	MakeButton(MFX, "Test Hit FX", 7, function()
		if S.TestHitEffect then
			local ok, err = S.TestHitEffect()
			if ok == false then
				showNotify(err or "Brak celu")
			else
				showNotify("Hit FX na wrogu w crosshair")
			end
		end
	end)
	MakeHint(MFX, "Hit FX = od razu przy strzale cheata. Kill FX = przy śmierci wroga. Test = cel w crosshair.", 8)

	local SFriend = MakeCard(T2, "FRIENDS", "Ctrl + Click na gracza — dodaj / usuń z wykluczeń.", 1)
	MakeTog(SFriend, "Ctrl + Click Friend", "FriendClick", 1, { flat = true })

	local FriendListHost = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = SFriend,
	})
	C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = FriendListHost })

	local function refreshFriendList()
		for _, ch in ipairs(FriendListHost:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
		local ids = S.FriendIds or {}
		if #ids == 0 then
			C("TextLabel", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = "Brak znajomych na liście",
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(95, 95, 105),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				ZIndex = 7,
				Parent = FriendListHost,
			})
			return
		end
		local sorted = {}
		for _, id in ipairs(ids) do
			table.insert(sorted, id)
		end
		table.sort(sorted)
		for i, uid in ipairs(sorted) do
			local row = C("Frame", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 7,
				Parent = FriendListHost,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = row })
			local avWrap = C("Frame", {
				Size = UDim2.new(0, 24, 0, 24),
				Position = UDim2.new(0, 6, 0.5, -12),
				BackgroundColor3 = Color3.fromRGB(40, 40, 48),
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = row,
			})
			C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avWrap })
			local avImg = C("ImageLabel", {
				Size = UDim2.new(1, -2, 1, -2),
				Position = UDim2.new(0, 1, 0, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
				Image = string.format(
					"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=48&height=48&format=png",
					uid
				),
				ZIndex = 9,
				Parent = avWrap,
			})
			C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avImg })
			local nameLbl = C("TextLabel", {
				Size = UDim2.new(1, -62, 1, 0),
				Position = UDim2.new(0, 36, 0, 0),
				BackgroundTransparency = 1,
				Text = "User " .. tostring(uid),
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(190, 190, 200),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 8,
				Parent = row,
			})
			task.spawn(function()
				local ok, name = pcall(function()
					return game:GetService("Players"):GetNameFromUserIdAsync(uid)
				end)
				if ok and nameLbl.Parent then
					nameLbl.Text = name
				end
			end)
			local rm = C("TextButton", {
				Size = UDim2.new(0, 22, 0, 22),
				Position = UDim2.new(1, -26, 0.5, -11),
				BackgroundColor3 = Color3.fromRGB(40, 40, 48),
				Text = "×",
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(200, 200, 210),
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = row,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 4), Parent = rm })
			rm.MouseButton1Click:Connect(function()
				if TF then
					TF.removeFriend(S, uid)
				else
					for j, id in ipairs(S.FriendIds or {}) do
						if id == uid then
							table.remove(S.FriendIds, j)
							break
						end
					end
				end
				refreshFriendList()
				showNotify("Usunięto z listy")
			end)
		end
	end

	MakeButton(SFriend, "Wyczyść listę", 3, function()
		if TF then
			TF.clearFriends(S)
		else
			S.FriendIds = {}
		end
		refreshFriendList()
		showNotify("Lista znajomych wyczyszczona")
	end)
	refreshFriendList()
	if TF then
		TF.Init(S, ParentGUI, ACC, refreshFriendList)
	end

	local SFilt = MakeCard(T2, "ESP COLORS", "Tryby kolorów — wykluczają się nawzajem.", 2)
	MakeTog(SFilt, "Team Colors", "RealTeamColor", 1, { flat = true })
	MakeTog(SFilt, "Line of Sight", "LoS", 2, { flat = true })
	MakeHint(SFilt, "Custom kolory (V/O) działają tylko gdy wyłączone: Team Colors, LoS i Chams Rainbow.", 3)
	MakeColorPicker(SFilt, "Visible Color", "V", 4)
	MakeColorPicker(SFilt, "Hidden Color", "O", 5)
	MakeSlider(SFilt, "Line Thickness", "Th", 0.5, 4, 6, {
		suffix = "px",
		step = 0.1,
		fmt = function(v)
			return string.format("%.1f px", v)
		end,
	})

	updateEspColorControls = function()
		local on = espCustomColorsEnabled()
		for _, reg in ipairs(colorRegistry) do
			reg.setEnabled(on)
			if on then
				reg.refresh()
			end
		end
	end
	updateEspColorControls()

	local SHud = MakeCard(T2, "HUD", nil, 3)
	MakeTog(SHud, "Crosshair", "Crosshair", 1, { flat = true })
	MakeChoice(SHud, "Crosshair Style", "CrosshairStyle", {
		{ label = "Dot", value = "Dot" },
		{ label = "Cross", value = "Cross" },
		{ label = "X", value = "X" },
		{ label = "Circle", value = "Circle" },
		{ label = "Dot+Cross", value = "DotCross" },
	}, 2)
	MakeChoice(SHud, "Crosshair Color", "CrosshairColorMode", {
		{ label = "Accent", value = "Accent" },
		{ label = "White", value = "White" },
		{ label = "Green", value = "Green" },
		{ label = "Red", value = "Red" },
		{ label = "Custom", value = "Custom" },
	}, 3)
	MakeColorPicker(SHud, "Custom Color", "CrosshairColor", 4)
	MakeSlider(SHud, "Crosshair Size", "CrosshairSize", 2, 14, 5, { suffix = "px", step = 1 })
	MakeTog(SHud, "Spectator List", "Spectators", 6, { flat = true })
	MakeTog(SHud, "Target Info Panel", "TargetInfo", 7, { flat = true })
	MakeTog(SHud, "Hitmarker", "Hitmarker", 8, { flat = true })
	MakeTog(SHud, "Hit Sound", "HitSound", 9, { flat = true })
	MakeSlider(SHud, "Hit Sound Volume", "HitSoundVolume", 0.1, 1, 10, {
		suffix = "",
		step = 0.05,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})
	MakeButton(SHud, "Test Hitmarker + Sound", 11, function()
		if S.TestHitFeedback then
			S.TestHitFeedback()
			showNotify("Test hitmarker / dźwięku")
		else
			showNotify("Features nie załadowane")
		end
	end)
	MakeHint(SHud, "Hitmarker: krzyżyk na środku ekranu po trafieniu (1.5s od strzału). Damage log pokazuje -HP.", 12)
	MakeTog(SHud, "Damage Log", "DamageLog", 13, { flat = true })
	MakeTog(SHud, "3D Damage Numbers", "DamageNumbers", 14, { flat = true })
	MakeTog(SHud, "Watermark", "Watermark", 15, { flat = true })
	MakeTog(SHud, "Keybind List", "KeybindList", 16, { flat = true })
	MakeTog(SHud, "Session Stats", "SessionStats", 17, { flat = true })
	MakeTog(SHud, "Kill Feed", "KillFeed", 18, { flat = true })
	MakeHint(SHud, "Spectator list pokazuje tylko graczy, którzy faktycznie Cię obserwują (atrybuty / kamera).", 19)

	local SettingsAutoloadLbl
	local SAuto = MakeCard(T2, "AUTOLOAD", "Config ładuje się przy starcie skryptu.", 4)

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
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = SAuto,
	})
	MakeButton(SAuto, "Załaduj autoload teraz", 2, function()
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

	local SSession = MakeCard(T2, "SESSION", "Zarządzanie skryptem.", 6)
	MakeButton(SSession, "Unload Vanguard", 1, function()
		if S.Unload then
			showNotify("Vanguard wyładowany — możesz reinject")
			task.delay(0.15, function()
				pcall(S.Unload)
			end)
		else
			showNotify("Unload niedostępny")
		end
	end)
	MakeTog(SSession, "Transfer Script", "TransferScript", 2, {
		flat = true,
		onChange = function(enabled)
			if S.ApplyTransferScript then
				local ok, err = S.ApplyTransferScript()
				if not ok then
					S.TransferScript = false
					setToggleVisual("TransferScript", false)
					showNotify(err or "Executor nie wspiera transferu")
					return
				end
			end
			if enabled then
				showNotify("Transfer ON — działa tylko z queue_on_teleport executora")
			else
				showNotify("Transfer wyłączony — kolejka wyczyszczona")
			end
		end,
	})
	MakeHint(SSession, "Transfer: wymaga queue_on_teleport. Blokuje inne gry (GameId). Teleport w grze = autoload. Inject ręczny = bez autoload przy wyjściu.", 3)
	MakeButton(SSession, "Rejoin Game", 4, function()
		showNotify("Rejoin...")
		if S.RejoinGame then
			local ok, err = S.RejoinGame()
			if not ok then
				showNotify(err or "Błąd rejoin")
			end
		else
			showNotify("Rejoin niedostępny")
		end
	end)
	MakeButton(SSession, "Server Hop", 5, function()
		showNotify("Szukam serwera...")
		if S.ServerHop then
			local ok, err = S.ServerHop()
			if not ok then
				showNotify(err or "Błąd server hop")
			end
		else
			showNotify("Server hop niedostępny")
		end
	end)
	MakeHint(SSession, "Unload usuwa menu, HUD i hooki. Po reinject menu załaduje się od nowa.", 6)

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
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") then
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
			local selected = ConfigNameBox and ConfigNameBox.Text == name
			local row = C("TextButton", {
				Size = UDim2.new(1, -8, 0, 22),
				BackgroundColor3 = selected and Color3.fromRGB(28, 32, 38) or Color3.fromRGB(20, 20, 26),
				BackgroundTransparency = selected and 0.1 or 0.35,
				AutoButtonColor = false,
				Text = "  " .. name .. mark,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = name == autoload and ACC or Color3.fromRGB(170, 170, 180),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
				ZIndex = 6,
				Parent = ConfigListHost,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 4), Parent = row })
			row.MouseEnter:Connect(function()
				if not selected then
					TweenPlay(row, TweenInfo.new(0.1), { BackgroundTransparency = 0.15 })
				end
			end)
			row.MouseLeave:Connect(function()
				if not (ConfigNameBox and ConfigNameBox.Text == name) then
					TweenPlay(row, TweenInfo.new(0.1), { BackgroundTransparency = 0.35 })
				end
			end)
			row.MouseButton1Click:Connect(function()
				if ConfigNameBox then
					ConfigNameBox.Text = name
				end
				showNotify("Config: " .. name)
				refreshConfigList()
			end)
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

	local MLoad = MakeCard(TMenu, "ADMIN MENUS", "Zewnętrzne skrypty — Vanguard zostaje włączony.", 1)

	local function loadMenuScript(key, label)
		if not MenusModule or not MenusModule.loadScript then
			showNotify("Moduł Menus niedostępny")
			return
		end
		showNotify("Ładowanie " .. label .. "...")
		task.spawn(function()
			local ok, msg = MenusModule.loadScript(key)
			if ok then
				showNotify(msg .. " załadowany")
				setFooterStatus("Menus · " .. msg)
			else
				showNotify("Błąd " .. label .. ": " .. tostring(msg))
			end
		end)
	end

	local menuOrder = 1
	if MenusModule and MenusModule.getScriptList then
		for _, entry in ipairs(MenusModule.getScriptList()) do
			MakeButton(MLoad, "Load " .. entry.label, menuOrder, function()
				loadMenuScript(entry.key, entry.label)
			end)
			menuOrder += 1
		end
	else
		MakeButton(MLoad, "Load Infinite Yield", menuOrder, function()
			loadMenuScript("InfiniteYield", "Infinite Yield")
		end)
		menuOrder += 1
	end
	MakeHint(MLoad, "Każde menu to osobny skrypt. Nie wyładowuje Vanguarda.", menuOrder)

	local MTools = MakeCard(TMenu, "TOOLS", "Pomoc przy wolniejszym internecie.", 2)

	local PreloadWidget = C("Frame", {
		Name = "AssetPreloader",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 268, 0, 96),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Visible = false,
		Active = false,
		ZIndex = 50,
		Parent = ParentGUI,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = PreloadWidget })
	C("UIStroke", {
		Color = Color3.fromRGB(42, 42, 52),
		Thickness = 1,
		Parent = PreloadWidget,
	})

	C("TextLabel", {
		Size = UDim2.new(1, -52, 0, 18),
		Position = UDim2.new(0, 12, 0, 8),
		BackgroundTransparency = 1,
		Text = "ASSET PRELOAD",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(230, 230, 235),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
		Parent = PreloadWidget,
	})

	local PreloadCloseBtn = C("TextButton", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -30, 0, 6),
		BackgroundTransparency = 1,
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(140, 140, 150),
		AutoButtonColor = false,
		Active = true,
		ZIndex = 52,
		Parent = PreloadWidget,
	})

	local PreloadStatus = C("TextLabel", {
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.new(0, 12, 0, 26),
		BackgroundTransparency = 1,
		Text = "Skanowanie...",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(120, 120, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 51,
		Parent = PreloadWidget,
	})

	local PreloadPct = C("TextLabel", {
		Size = UDim2.new(0, 40, 0, 14),
		Position = UDim2.new(1, -52, 0, 56),
		BackgroundTransparency = 1,
		Text = "0%",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 51,
		Parent = PreloadWidget,
	})

	local PreloadTrack = C("Frame", {
		Size = UDim2.new(1, -24, 0, 5),
		Position = UDim2.new(0, 12, 0, 58),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 51,
		Parent = PreloadWidget,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PreloadTrack })

	local PreloadFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 52,
		Parent = PreloadTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PreloadFill })

	local PreloadCancelBtn = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 22),
		Position = UDim2.new(1, -84, 1, -30),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		BorderSizePixel = 0,
		Text = "Anuluj",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(210, 210, 215),
		AutoButtonColor = false,
		Active = true,
		ZIndex = 52,
		Parent = PreloadWidget,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = PreloadCancelBtn })

	local preloadCancel = false
	local preloadRunning = false

	local function closePreloader()
		PreloadWidget.Visible = false
		preloadRunning = false
		preloadCancel = false
	end

	local function setPreloadBar(processed, total, phase)
		if phase == "scan" then
			PreloadPct.Text = "..."
			PreloadFill.Size = UDim2.new(0.12, 0, 1, 0)
			return
		end
		processed = tonumber(processed) or 0
		total = tonumber(total) or 0
		local pct = total > 0 and math.clamp(processed / total, 0, 1) or 0
		PreloadPct.Text = math.floor(pct * 100) .. "%"
		PreloadFill.Size = UDim2.new(pct, 0, 1, 0)
	end

	local function updatePreloader(state)
		if not state then
			return
		end
		local total = tonumber(state.total) or 0
		local processed = tonumber(state.processed) or tonumber(state.loaded) or 0
		if state.phase == "scan" then
			PreloadStatus.Text = state.label or "Skanowanie gry..."
			setPreloadBar(0, 0, "scan")
			return
		elseif state.phase == "start" then
			PreloadStatus.Text = state.label or ("Do załadowania: " .. total)
		elseif state.phase == "item" then
			PreloadStatus.Text = state.label or "Ładowanie..."
		elseif state.phase == "progress" then
			PreloadStatus.Text = state.label or (processed .. " / " .. total)
		elseif state.phase == "error" then
			PreloadStatus.Text = "Błąd: " .. tostring(state.label or "?")
		elseif state.phase == "done" then
			local failed = tonumber(state.failed) or 0
			PreloadStatus.Text = state.label
				or (failed > 0 and ("Gotowe · " .. failed .. " błędów") or ("Gotowe · " .. processed .. " assetów"))
			PreloadCancelBtn.Text = "OK"
			preloadRunning = false
			setPreloadBar(processed, total > 0 and total or processed, "done")
			task.delay(8, function()
				if PreloadWidget.Visible and not preloadRunning and PreloadCancelBtn.Text == "OK" then
					closePreloader()
				end
			end)
			return
		end
		setPreloadBar(processed, total, state.phase)
	end

	PreloadCloseBtn.MouseButton1Click:Connect(function()
		if preloadRunning then
			preloadCancel = true
			PreloadStatus.Text = "Anulowanie..."
		else
			closePreloader()
		end
	end)

	PreloadCancelBtn.MouseButton1Click:Connect(function()
		if preloadRunning then
			preloadCancel = true
			PreloadStatus.Text = "Anulowanie..."
		else
			closePreloader()
		end
	end)

	MakeButton(MTools, "Preload Game Assets", 1, function()
		if preloadRunning then
			PreloadWidget.Visible = true
			showNotify("Preload trwa — panel w prawym dolnym rogu")
			return
		end
		if not MenusModule or not MenusModule.preloadAssets then
			showNotify("Moduł preload niedostępny")
			return
		end
		preloadCancel = false
		preloadRunning = true
		PreloadCancelBtn.Text = "Anuluj"
		PreloadStatus.Text = "Skanowanie assetów..."
		PreloadPct.Text = "0%"
		PreloadFill.Size = UDim2.new(0, 0, 1, 0)
		PreloadWidget.Visible = true
		task.spawn(function()
			MenusModule.preloadAssets(function(state)
				task.defer(function()
					if preloadCancel and state.phase ~= "done" then
						return
					end
					updatePreloader(state)
				end)
			end, function()
				return preloadCancel
			end)
			if preloadCancel then
				task.defer(function()
					PreloadStatus.Text = "Anulowano"
					PreloadCancelBtn.Text = "OK"
					preloadRunning = false
				end)
			end
		end)
	end)
	MakeHint(MTools, "Mały panel w prawym dolnym rogu — nie blokuje ruchu ani myszki. Możesz grać normalnie.", 2)

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
		LoaderTop.Position = UDim2.new(0, 0, 0, -52)
		TweenPlay(LoaderTop, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		})

		local steps = {
			{ text = "Loading modules", pct = 0.25 },
			{ text = "Initializing ESP", pct = 0.55 },
			{ text = "Preparing interface", pct = 0.82 },
			{ text = "Ready", pct = 1 },
		}

		for _, step in ipairs(steps) do
			LoaderStatus.Text = step.text
			LoaderPct.Text = math.floor(step.pct * 100) .. "%"
			TweenPlay(Fill, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.pct, 0, 1, 0),
			})
			task.wait(0.22)
		end

		task.wait(0.08)
		TweenPlay(LoaderTop, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0, -56),
		})
		TweenPlay(LoaderGame, TweenInfo.new(0.22), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.52, 0),
		})
		TweenPlay(Loader, TweenInfo.new(0.28), { BackgroundTransparency = 1 })
		task.wait(0.28)
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
