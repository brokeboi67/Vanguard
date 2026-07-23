-- Plik: workspace/Vanguard/UI.lua

local UI = {}

function UI.Init(S, ParentGUI, ConfigModule, TF, AnimationsModule, WorldModule, MenusModule, GameSupportModule, UIColorPicker, UIConfigMenus, MusicModule, UIMusicModule, I18nModule, AntiBypassModule, UISkinVaultModule)
	if AntiBypassModule then
		if AntiBypassModule.setUiBuilding then
			AntiBypassModule.setUiBuilding(true)
		end
		if AntiBypassModule.concealGui then
			AntiBypassModule.concealGui(ParentGUI)
		end
	end
	task.wait()

	local I18n = I18nModule
	local function L(key, ...)
		if I18n and I18n.t then
			return I18n.t(key, ...)
		end
		return tostring(key)
	end
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
		visuals = Color3.fromRGB(90, 175, 255),
		legit = Color3.fromRGB(80, 255, 160),
		rage = Color3.fromRGB(255, 85, 85),
		anim = Color3.fromRGB(255, 150, 230),
		world = Color3.fromRGB(130, 210, 110),
		friends = Color3.fromRGB(170, 90, 255),
		settings = Color3.fromRGB(175, 175, 195),
		misc = Color3.fromRGB(255, 195, 75),
		config = Color3.fromRGB(155, 135, 255),
		menus = Color3.fromRGB(255, 120, 180),
		music = Color3.fromRGB(29, 185, 84),
		criminality = Color3.fromRGB(255, 100, 60),
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
	local W_MUSIC, H_MUSIC = 860, 620
	local W_SKINS, H_SKINS = 1040, 800
	local SIDE_W = 136
	local FOOTER_PAD = 12
	local FOOTER_RIGHT_W = 196
	local tabLayoutProfiles = {}
	local RS = game:GetService("RunService")
	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	ParentGUI.DisplayOrder = 8
	ParentGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function refreshLayout()
		local vp = Cam.ViewportSize
		-- Match v2.52.40 menu scale
		W_FULL = math.clamp(math.floor(vp.X * 0.58), 660, 900)
		W_COMPACT = math.clamp(math.floor(vp.X * 0.48), 540, 660)
		H = math.clamp(math.floor(vp.Y * 0.68), 500, 640)
		W_MUSIC = math.clamp(math.floor(vp.X * 0.54), 760, 940)
		H_MUSIC = math.clamp(math.floor(vp.Y * 0.74), 580, 700)
		W_SKINS = math.clamp(math.floor(vp.X * 0.72), 960, 1180)
		H_SKINS = math.clamp(math.floor(vp.Y * 0.88), 740, 900)
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

	local function centerPos(w, h)
		h = h or H
		return UDim2.new(0.5, -w / 2, 0.5, -h / 2)
	end

	-- // Loading overlay — minimalist top bar (hidden until protected)
	local Loader = C("Frame", {
		Name = "Loader",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 100,
		Visible = false,
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

	if _G.VG_BOOT and _G.VG_BOOT.destroy then
		pcall(_G.VG_BOOT.destroy)
		_G.VG_BOOT = nil
	end

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
		local fallbackThumb = ""
		pcall(function()
			if GameSupportModule and GameSupportModule.getThumbnail then
				fallbackThumb = GameSupportModule.getThumbnail(nil, gameId) or ""
			elseif gameId > 0 then
				fallbackThumb = "rbxthumb://type=GameThumbnail&id=" .. gameId .. "&w=256&h=144"
			end
		end)
		pcall(function()
			LoaderGameIcon.Image = fallbackThumb
		end)
		LoaderGameName.Text = game.Name ~= "" and game.Name or ("Place " .. tostring(placeId))

		if not GameSupportModule then
			LoaderSupportBadge.Text = "NO DATA"
			LoaderSupportBadge.TextColor3 = Color3.fromRGB(130, 130, 145)
			LoaderSupportNote.Text = ""
			return
		end

		local status, note = "unknown", ""
		pcall(function()
			status, note = GameSupportModule.getStatus(placeId, gameId)
		end)
		local badge, badgeColor = "?", Color3.fromRGB(130, 130, 145)
		pcall(function()
			badge, badgeColor = GameSupportModule.getStatusDisplay(status)
		end)
		LoaderSupportBadge.Text = badge
		LoaderSupportBadge.TextColor3 = badgeColor
		LoaderSupportNote.Text = note or ""

		task.spawn(function()
			local name, thumb = nil, nil
			local ok = pcall(function()
				name, thumb = GameSupportModule.getGameInfo(placeId, gameId)
			end)
			if not ok then
				return
			end
			if name and name ~= "" then
				LoaderGameName.Text = name
			end
			if thumb and thumb ~= "" then
				pcall(function()
					LoaderGameIcon.Image = thumb
				end)
			end
		end)
	end

	-- Avoid Marketplace/thumbnail during UI build on Criminality (crash window after UI.Init)
	if game.GameId ~= 1494262959 then
		refreshLoaderGameInfo()
	else
		LoaderGameName.Text = game.Name ~= "" and game.Name or "Criminality"
		LoaderSupportBadge.Text = "CRIM"
		LoaderSupportNote.Text = ""
		LoaderGameIcon.Image = ""
	end

	task.wait()

	-- // Main menu (CanvasGroup like v2.52.40 — fade + scale open/close)
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

	local StudioSubtitle = C("TextLabel", {
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.new(0, 104, 0, 0),
		BackgroundTransparency = 1,
		Text = I18n and I18n.t("subtitle_studio") or "ESP STUDIO",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = Top,
	})
	if I18n and I18n.registerText then
		I18n.registerText(StudioSubtitle, "subtitle_studio")
	end

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
		Size = UDim2.new(0, SIDE_W, 1, -80),
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
		local previewClr = (S.FriendsESP and S.F) or S.V
		M_Box.Visible = showBox or S.Name or S.DistView or S.Health or S.HealthText or S.Weapon or S.Trace or S.Skel or S.Chams
		M_Cham.Visible = S.Chams
		if S.Chams and S.ChamsRainbow then
			M_Cham.BackgroundColor3 = Color3.fromHSV((tick() * 0.45) % 1, 0.9, 1)
		else
			M_Cham.BackgroundColor3 = previewClr
		end
		M_BoxStroke.Color = previewClr
		M_BoxStroke.Thickness = S.Th
		M_Nm.TextColor3 = previewClr
		M_Tr.Size = UDim2.new(0, S.Th, 0, 52)
		M_Tr.BackgroundColor3 = previewClr
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
	RS.RenderStepped:Connect(perfWrap("UI.PreviewChams", function()
		if S.Chams and S.ChamsRainbow and M_Cham.Visible then
			M_Cham.BackgroundColor3 = Color3.fromHSV((tick() * 0.45) % 1, 0.9, 1)
		end
	end))

	local Footer = C("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 1, -32),
		BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = Menu,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = Footer })
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Footer,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Footer,
	})
	local FooterStatus = C("TextLabel", {
		Name = "FooterStatus",
		Size = UDim2.new(1, -(SIDE_W + FOOTER_PAD + FOOTER_RIGHT_W), 1, 0),
		Position = UDim2.new(0, SIDE_W + FOOTER_PAD, 0, 0),
		BackgroundTransparency = 1,
		Text = "v" .. (S.Version or "?") .. "  ·  Ready",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = Footer,
	})
	local FooterRightLbl = C("TextLabel", {
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
	local activeLayoutProfile = "default"
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
	local MakeColorPicker = UIColorPicker.create({
		ParentGUI = ParentGUI,
		S = S,
		C = C,
		ACC = ACC,
		UIS = UIS,
		UpdPreview = UpdPreview,
		colorRegistry = colorRegistry,
	})

	local ApplyLayout
	local refreshConfigList
	local refreshConfigMenusLang
	local refreshAllControls
	local setFooterStatus

	local function buildControlsAndTabs()
		task.wait()

	local function formatBindName(name)
		if typeof(name) ~= "string" then
			return "None"
		end
		local m = string.match(name, "^MouseButton(%d+)$")
		if m then
			return "M" .. m
		end
		return name ~= "" and name or "None"
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

	local function ApplyLayout(showPreview, animate, keepPosition, layoutProfile)
		layoutProfile = layoutProfile or "default"
		refreshLayout()
		local targetW, targetH, previewW
		if layoutProfile == "music" then
			targetW = W_MUSIC
			targetH = H_MUSIC
			previewW = 0
			showPreview = false
		elseif layoutProfile == "skins" then
			targetW = W_SKINS
			targetH = H_SKINS
			previewW = 0
			showPreview = false
		else
			targetW = showPreview and W_FULL or W_COMPACT
			targetH = H
			previewW = showPreview and 212 or 0
		end
		local targetContentW = targetW - SIDE_W - previewW - 28

		CancelTweens(layoutTweens)

		local info = TweenInfo.new(animate and 0.28 or 0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

		local menuProps = { Size = UDim2.new(0, targetW, 0, targetH) }
		if not keepPosition then
			menuProps.Position = centerPos(targetW, targetH)
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
		activeLayoutProfile = layoutProfile

		if FooterStatus then
			local left = SIDE_W + FOOTER_PAD
			FooterStatus.Position = UDim2.new(0, left, 0, 0)
			if layoutProfile == "music" then
				FooterStatus.Size = UDim2.new(1, -(left + FOOTER_PAD), 1, 0)
			else
				FooterStatus.Size = UDim2.new(1, -(left + FOOTER_RIGHT_W), 1, 0)
			end
		end
		if FooterRightLbl then
			FooterRightLbl.Visible = layoutProfile ~= "music"
		end
		setFooterStatus(nil)
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

		local profile = tabLayoutProfiles[btn] or "default"
		local oldProfile = (oldBtn and tabLayoutProfiles[oldBtn]) or "default"
		local usePreview = (profile == "default") and showPreview
		if usePreview ~= previewVisible or profile ~= activeLayoutProfile or profile ~= oldProfile then
			ApplyLayout(usePreview, true, true, profile)
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

	local function MakeTab(nameKey, default, showPreview, layoutOrder, tabOpts)
		tabOpts = tabOpts or {}
		local tabAccent = TAB_THEMES[nameKey] or ACC
		local tabSoftCol = tabSoft(tabAccent)
		local tabLabel = I18n and I18n.t("tab_" .. nameKey) or nameKey
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = default and tabSoftCol or Color3.fromRGB(18, 18, 22),
			Text = "  " .. tabLabel,
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
		if tabOpts.layout then
			tabLayoutProfiles[B] = tabOpts.layout
		end
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

		local P
		if tabOpts.fixed then
			P = C("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 4,
				Parent = Wrap,
			})
		else
			P = C("ScrollingFrame", {
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
			C("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
				Parent = P,
			})
		end
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

		if I18n and I18n.registerTabButton then
			I18n.registerTabButton(nameKey, B)
		end

		return P
	end

	local function MakeCard(page, title, subtitleKey, order, cardOpts)
		cardOpts = cardOpts or {}
		local titleKey = cardOpts.titleKey
		local subtitle = subtitleKey and L(subtitleKey) or nil
		local displayTitle = titleKey and L(titleKey) or (title or "")
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

		local titleLbl = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 12),
			BackgroundTransparency = 1,
			Text = displayTitle,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = tabCol,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			ZIndex = 6,
			Parent = Card,
		})
		if titleKey and I18n and I18n.registerText then
			I18n.registerText(titleLbl, titleKey)
		end

		if subtitle then
			local subLbl = C("TextLabel", {
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
			if subtitleKey and I18n and I18n.registerText then
				I18n.registerText(subLbl, subtitleKey)
			end
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

	local function MakeHint(page, hintKey, order, argsFn)
		local text = argsFn and L(hintKey, argsFn()) or L(hintKey)
		local hintLbl = C("TextLabel", {
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
		if hintKey and I18n and I18n.registerText then
			I18n.registerText(hintLbl, hintKey, argsFn)
		end
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
			local dotOn = t.dotOn or UDim2.new(1, -16, 0.5, -7)
			local dotOff = t.dotOff or UDim2.new(0, 2, 0.5, -7)
			TweenPlay(t.SwitchDot, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = enabled and dotOn or dotOff,
			})
		end
	end

	local function setToggleDimmed(key, dimmed)
		local list = toggleRegistry[key]
		if not list then
			return
		end
		for _, t in ipairs(list) do
			if not t.requires then
				continue
			end
			if t.Title then
				t.Title.TextColor3 = dimmed and Color3.fromRGB(95, 95, 105) or t.titleColor
			end
			if t.Row then
				t.Row.BackgroundTransparency = dimmed and 0.35 or 0
			end
		end
	end

	local function refreshToggleVisual(key)
		local list = toggleRegistry[key]
		if not list then
			return
		end
		local requires = list[1] and list[1].requires
		local parentOff = requires and S[requires] ~= true
		local effectiveOn = not parentOff and S[key] == true
		setToggleVisual(key, effectiveOn)
		setToggleDimmed(key, parentOff)
	end

	local function refreshNestedToggles(parentKey)
		for key, list in pairs(toggleRegistry) do
			for _, t in ipairs(list) do
				if t.requires == parentKey then
					refreshToggleVisual(key)
					break
				end
			end
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

	-- Lucide icons (lucideblox) — ImageLabel assets render reliably where font glyphs do not.
	local NOTIFY_ICON_ASSETS = {
		info = "rbxassetid://7733964719",
		error = "rbxassetid://7743878496",
		success = "rbxassetid://7733710700",
		warn = "rbxassetid://7733658504",
	}

	local function createNotifyIcon(parent, nType, accent, zIndex)
		local iconHolder = C("Frame", {
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(0, 14, 0, 10),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BorderSizePixel = 0,
			ZIndex = zIndex,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = iconHolder })
		local iconImg = C("ImageLabel", {
			Size = UDim2.new(1, -10, 1, -10),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = NOTIFY_ICON_ASSETS[nType] or NOTIFY_ICON_ASSETS.info,
			ImageColor3 = accent,
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 1,
			Parent = iconHolder,
		})
		return iconHolder, iconImg
	end

	local function showNotify(msg, opts)
		opts = opts or {}
		local style = tostring(S.NotifyStyle or "pro"):lower()
		local nType = tostring(opts.type or "info"):lower()
		local accent = ACC
		local title = I18n and I18n.t("notify_info") or "Info"
		if nType == "error" then
			accent = Color3.fromRGB(255, 82, 96)
			title = I18n and I18n.t("notify_error") or "Error"
		elseif nType == "success" then
			accent = Color3.fromRGB(29, 185, 84)
			title = I18n and I18n.t("notify_success") or "Success"
		elseif nType == "warn" then
			accent = Color3.fromRGB(255, 195, 75)
			title = I18n and I18n.t("notify_warn") or "Warning"
		end
		if opts.title then
			title = opts.title
		end

		if style == "compact" then
			local card = C("TextLabel", {
				Size = UDim2.new(0, 300, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(14, 14, 18),
				BackgroundTransparency = 0.08,
				Text = "  " .. tostring(msg) .. "  ",
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(220, 220, 228),
				TextWrapped = true,
				ZIndex = 91,
				Parent = NotifyRoot,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
			C("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.35, Parent = card })
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
			return
		end

		local card = C("Frame", {
			Size = UDim2.new(0, 340, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(12, 12, 16),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 91,
			Parent = NotifyRoot,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
		C("UIStroke", { Color = Color3.fromRGB(42, 42, 50), Thickness = 1, Transparency = 0.25, Parent = card })

		local accentBar = C("Frame", {
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 92,
			Parent = card,
		})

		local _, iconImg = createNotifyIcon(card, nType, accent, 93)

		local titleLbl = C("TextLabel", {
			Size = UDim2.new(1, -58, 0, 14),
			Position = UDim2.new(0, 50, 0, 10),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(245, 245, 248),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 93,
			Parent = card,
		})

		local bodyLbl = C("TextLabel", {
			Size = UDim2.new(1, -58, 0, 0),
			Position = UDim2.new(0, 50, 0, 26),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = tostring(msg),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(170, 170, 182),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 93,
			Parent = card,
		})

		C("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			Parent = card,
		})

		card.BackgroundTransparency = 1
		titleLbl.TextTransparency = 1
		bodyLbl.TextTransparency = 1
		iconImg.ImageTransparency = 1
		accentBar.BackgroundTransparency = 1
		card.Position = UDim2.new(0, 0, 0, -8)
		TweenPlay(card, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.02,
			Position = UDim2.new(0, 0, 0, 0),
		})
		TweenPlay(titleLbl, TweenInfo.new(0.24), { TextTransparency = 0 })
		TweenPlay(bodyLbl, TweenInfo.new(0.24), { TextTransparency = 0 })
		TweenPlay(iconImg, TweenInfo.new(0.24), { ImageTransparency = 0 })
		TweenPlay(accentBar, TweenInfo.new(0.24), { BackgroundTransparency = 0 })

		task.delay(4.2, function()
			if card.Parent then
				TweenPlay(card, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0, -6),
				})
				TweenPlay(titleLbl, TweenInfo.new(0.22), { TextTransparency = 1 })
				TweenPlay(bodyLbl, TweenInfo.new(0.22), { TextTransparency = 1 })
				TweenPlay(iconImg, TweenInfo.new(0.22), { ImageTransparency = 1 })
				TweenPlay(accentBar, TweenInfo.new(0.22), { BackgroundTransparency = 1 })
				task.delay(0.32, function()
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
			showNotify(L("notify_disabled", table.concat(off, ", ")))
		end
	end

	local function applyAimExclusivity(fromKey, turningOn)
		if not turningOn then
			return
		end
		if fromKey == "Silent" and S.Aimbot then
			S.Aimbot = false
			setToggleVisual("Aimbot", false)
			showNotify(L("notify_disabled", "Aimbot"))
		elseif fromKey == "Aimbot" and S.Silent then
			S.Silent = false
			setToggleVisual("Silent", false)
			showNotify(L("notify_disabled", "Silent Aim"))
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
				showNotify(L("notify_disabled_legit", table.concat(off, ", ")))
			end
		elseif fromKey == "Aimbot" or fromKey == "Silent" or fromKey == "Trigger" then
			if S.MasterRage then
				S.MasterRage = false
				setToggleVisual("MasterRage", false)
				showNotify(L("notify_disabled_master_rage"))
			end
		end
	end

	local function isLockedMouseBehavior(behavior)
		return behavior == Enum.MouseBehavior.LockCenter
			or behavior == Enum.MouseBehavior.LockCurrentPosition
	end

	local function isFreeCursorState()
		-- Only MouseBehavior matters — MouseIconEnabled alone is unreliable (games scripts toggle it).
		return not isLockedMouseBehavior(UIS.MouseBehavior)
	end

	local function captureMouseState()
		local LP = game:GetService("Players").LocalPlayer
		savedMouse.behavior = UIS.MouseBehavior
		savedMouse.icon = UIS.MouseIconEnabled
		savedMouse.cameraMode = LP.CameraMode
		savedMouse.devMouseLock = LP.DevEnableMouseLock
		savedMouse.camMin = LP.CameraMinZoomDistance
		savedMouse.camMax = LP.CameraMaxZoomDistance
		savedMouse.wasFree = isFreeCursorState()
	end

	-- Official FP/ShiftLock unlock: GuiButton.Modal must be ON-SCREEN + Visible.
	local modalUnlockBtn = C("TextButton", {
		Name = "VGModalUnlock",
		Size = UDim2.fromOffset(2, 2),
		Position = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		Text = "",
		TextTransparency = 1,
		AutoButtonColor = false,
		Modal = false,
		Visible = false,
		Active = true,
		Selectable = false,
		ZIndex = 1,
		Parent = ParentGUI,
	})

	local softCursor = C("ImageLabel", {
		Name = "VGSoftCursor",
		Size = UDim2.fromOffset(18, 22),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
		Visible = false,
		ZIndex = 1000,
		Parent = ParentGUI,
	})

	local shiftSuppressConn = nil
	local shiftRestoreToken = 0

	local function setModalUnlock(on)
		modalUnlockBtn.Visible = on == true
		modalUnlockBtn.Modal = on == true
	end

	local function updateSoftCursor()
		if not softCursor.Visible then
			return
		end
		local pos = UIS:GetMouseLocation()
		softCursor.Position = UDim2.fromOffset(pos.X, pos.Y)
	end

	-- RightShift = menu key AND Roblox Shift Lock bind → suppress until Shift released.
	local function suppressShiftLockUntilReleased(thenRestoreDev)
		local LP = game:GetService("Players").LocalPlayer
		shiftRestoreToken += 1
		local token = shiftRestoreToken
		pcall(function()
			LP.DevEnableMouseLock = false
		end)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true

		if shiftSuppressConn then
			shiftSuppressConn:Disconnect()
			shiftSuppressConn = nil
		end

		local function tryRestore()
			if token ~= shiftRestoreToken then
				return
			end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
				return false
			end
			if shiftSuppressConn then
				shiftSuppressConn:Disconnect()
				shiftSuppressConn = nil
			end
			task.delay(0.08, function()
				if token ~= shiftRestoreToken or menuOpen then
					pcall(function()
						LP.DevEnableMouseLock = false
					end)
					return
				end
				if thenRestoreDev and savedMouse.devMouseLock ~= nil then
					pcall(function()
						LP.DevEnableMouseLock = savedMouse.devMouseLock
					end)
				end
				-- Never force LockCenter here — FP camera scripts re-lock if needed.
				-- Forcing LockCenter after RightShift felt like stuck Shift Lock.
				UIS.MouseBehavior = Enum.MouseBehavior.Default
			end)
			return true
		end

		if tryRestore() then
			return
		end
		shiftSuppressConn = UIS.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				tryRestore()
			end
		end)
		task.delay(1.2, function()
			if token == shiftRestoreToken then
				tryRestore()
			end
		end)
	end

	local function forceMenuCursor()
		local LP = game:GetService("Players").LocalPlayer
		setModalUnlock(true)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		pcall(function()
			LP.DevEnableMouseLock = false
		end)
		pcall(function()
			LP.CameraMode = Enum.CameraMode.Classic
		end)
		pcall(function()
			if LP.CameraMinZoomDistance < 5 then
				LP.CameraMinZoomDistance = 5
			end
			if LP.CameraMaxZoomDistance < 32 then
				LP.CameraMaxZoomDistance = 32
			end
		end)
		pcall(function()
			GuiService.SelectedObject = nil
		end)
		updateSoftCursor()
	end

	local function applyFreeCursor()
		setModalUnlock(false)
		pcall(function()
			GuiService:SetMenuIsOpen(false)
		end)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end

	local function restoreMouseState()
		softCursor.Visible = false
		setModalUnlock(false)
		pcall(function()
			GuiService:SetMenuIsOpen(false)
		end)
		local LP = game:GetService("Players").LocalPlayer
		-- Keep DevEnableMouseLock OFF until Shift released (menu key = RightShift = Shift Lock toggle)
		pcall(function()
			LP.DevEnableMouseLock = false
		end)
		if savedMouse.camMin ~= nil then
			pcall(function()
				LP.CameraMinZoomDistance = savedMouse.camMin
			end)
		end
		if savedMouse.camMax ~= nil then
			pcall(function()
				LP.CameraMaxZoomDistance = savedMouse.camMax
			end)
		end
		-- Always unlock on close; do not stamp LockCenter (Shift-Lock feel).
		applyFreeCursor()
		if savedMouse.cameraMode ~= nil then
			pcall(function()
				LP.CameraMode = savedMouse.cameraMode
			end)
		end
	end

	local function refreshAllControls()
		for key, _ in pairs(toggleRegistry) do
			refreshToggleVisual(key)
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
			if reg.setEnabled and reg.parentKey then
				reg.setEnabled(S[reg.parentKey] == true)
			end
		end
		for key, reg in pairs(sliderRegistry) do
			if reg.setValue and S[key] ~= nil then
				reg.setValue(S[key], true)
			end
		end
		for key, lbl in pairs(bindRegistry) do
			lbl.Text = formatBindName(S[key])
		end
		for _, reg in ipairs(colorRegistry) do
			if reg.refresh then
				reg.refresh()
			end
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
		local nested = opts.nested == true or (opts.requires ~= nil and opts.nested ~= false)
		local flat = opts.flat
		if nested then
			flat = true
		end
		local on = S[key] == true
		local rowH = nested and 28 or (flat and 32 or 36)
		local Row = C("TextButton", {
			Size = nested and UDim2.new(1, -12, 0, rowH) or UDim2.new(1, 0, 0, rowH),
			BackgroundColor3 = nested and Color3.fromRGB(17, 17, 21)
				or (flat and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(17, 17, 21)),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		if not flat and not nested then
			C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })
		end
		if nested then
			C("Frame", {
				Size = UDim2.new(0, 2, 0, 10),
				Position = UDim2.new(0, 8, 0.5, -5),
				BackgroundColor3 = Color3.fromRGB(58, 58, 68),
				BorderSizePixel = 0,
				ZIndex = 6,
				Parent = Row,
			})
		end

		local Title = C("TextLabel", {
			Size = UDim2.new(1, -54, 1, 0),
			Position = nested and UDim2.new(0, 18, 0, 0) or UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = nested and 10 or 11,
			TextColor3 = nested and Color3.fromRGB(165, 165, 178) or Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local switchW, switchH = nested and 34 or 38, nested and 18 or 20
		local dotSz = nested and 12 or 14
		local SwitchBg = C("Frame", {
			Size = UDim2.new(0, switchW, 0, switchH),
			Position = UDim2.new(1, nested and -42 or -48, 0.5, nested and -9 or -10),
			BackgroundColor3 = on and ACC or Color3.fromRGB(36, 36, 44),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchBg })

		local SwitchDot = C("Frame", {
			Size = UDim2.new(0, dotSz, 0, dotSz),
			Position = on and UDim2.new(1, -(dotSz + 2), 0.5, -(dotSz / 2)) or UDim2.new(0, 2, 0.5, -(dotSz / 2)),
			BackgroundColor3 = Color3.fromRGB(245, 245, 250),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = SwitchBg,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchDot })

		local dotOn = UDim2.new(1, -(dotSz + 2), 0.5, -(dotSz / 2))
		local dotOff = UDim2.new(0, 2, 0.5, -(dotSz / 2))
		local rowBg = Row.BackgroundColor3
		local rowHover = nested and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(20, 20, 25)

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = rowHover })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = rowBg })
		end)

		Row.MouseButton1Click:Connect(function()
			if opts.requires and S[opts.requires] ~= true then
				return
			end
			S[key] = not S[key]
			local enabled = S[key]

			if enabled then
				applyEspColorExclusivity(key, true)
				applyAimExclusivity(key, true)
				applyRageLegitExclusivity(key, true)
			end

			refreshToggleVisual(key)
			refreshNestedToggles(key)
			UpdPreview()
			if key == "LoS" or key == "RealTeamColor" or key == "ChamsRainbow" or key == "FriendsESP" then
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
		table.insert(toggleRegistry[key], {
			SwitchBg = SwitchBg,
			SwitchDot = SwitchDot,
			dotOn = dotOn,
			dotOff = dotOff,
			Row = Row,
			Title = Title,
			requires = opts.requires,
			nested = nested,
			titleColor = Title.TextColor3,
		})
		if opts.onRowCreated then
			opts.onRowCreated(Row, Title)
		end
	end

	local function MakeChoice(page, label, key, options, order, choiceOpts)
		choiceOpts = choiceOpts or {}
		local nOpts = #options
		-- Wrap into columns so long option lists don't crush labels into one row
		local perRow = nOpts <= 2 and nOpts or (nOpts <= 4 and 2 or 3)
		if nOpts >= 9 then
			perRow = 3
		end
		local numRows = math.max(1, math.ceil(nOpts / math.max(perRow, 1)))
		local btnH = 26
		local gap = 4
		local wrapH = numRows * btnH + (numRows - 1) * gap
		local rowH = 28 + wrapH

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

		local rowLabelKey = choiceOpts.labelKey
		local rowText = rowLabelKey and L(rowLabelKey) or (label or "")
		local rowLbl = C("TextLabel", {
			Size = UDim2.new(1, -16, 0, 14),
			Position = UDim2.new(0, 12, 0, 6),
			BackgroundTransparency = 1,
			Text = rowText,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})
		if rowLabelKey and I18n and I18n.registerText then
			I18n.registerText(rowLbl, rowLabelKey)
		end

		local BtnWrap = C("Frame", {
			Size = UDim2.new(1, -24, 0, wrapH),
			Position = UDim2.new(0, 12, 0, 24),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = Row,
		})
		C("UIGridLayout", {
			CellSize = UDim2.new(1 / perRow, -gap, 0, btnH),
			CellPadding = UDim2.new(0, gap, 0, gap),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = perRow,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = BtnWrap,
		})

		local btns = {}
		for i, opt in ipairs(options) do
			local active = S[key] == opt.value
			local btnText = opt.labelKey and L(opt.labelKey) or opt.label
			local B = C("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = active and ACC_SOFT or Color3.fromRGB(24, 24, 30),
				Text = btnText,
				Font = Enum.Font.GothamSemibold,
				TextSize = 10,
				TextColor3 = active and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(110, 110, 120),
				TextTruncate = Enum.TextTruncate.AtEnd,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 7,
				Parent = BtnWrap,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = B })
			C("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				Parent = B,
			})
			if active then
				C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.5, Parent = B })
			end
			if opt.labelKey and I18n and I18n.registerText then
				I18n.registerText(B, opt.labelKey)
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
				if choiceOpts.onChange then
					pcall(choiceOpts.onChange, opt.value)
				end
			end)
		end
		choiceRegistry[key] = { btns = btns }
	end

	local refreshConfigList
	local refreshConfigMenusLang

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
		local function stopListen()
			bindListening = false
			if listenConn then
				listenConn:Disconnect()
				listenConn = nil
			end
		end

		local function finishBind(name)
			S[key] = name
			KeyLbl.Text = formatBindName(name)
			KeyLbl.TextColor3 = ACC
			stopListen()
			if opts.onChange then
				pcall(opts.onChange, name)
			end
		end

		local function cancelBind()
			KeyLbl.Text = formatBindName(S[key])
			KeyLbl.TextColor3 = ACC
			stopListen()
		end

		local function isMouseBind(input)
			local n = input.UserInputType and input.UserInputType.Name
			return typeof(n) == "string" and string.match(n, "^MouseButton%d+$") ~= nil
		end

		Row.MouseButton1Click:Connect(function()
			if bindListening then
				return
			end
			bindListening = true
			KeyLbl.Text = "…"
			KeyLbl.TextColor3 = Color3.fromRGB(200, 200, 120)
			-- Defer so the LMB that opened this row is not captured as the bind
			task.defer(function()
				if not bindListening then
					return
				end
				listenConn = UIS.InputBegan:Connect(function(input, processed)
					if not bindListening then
						return
					end
					-- Esc = cancel
					if input.KeyCode == Enum.KeyCode.Escape then
						cancelBind()
						return
					end
					-- MouseButton1..N (Roblox has 1–3; some executors may expose more)
					if isMouseBind(input) then
						finishBind(input.UserInputType.Name)
						return
					end
					-- Keyboard: ignore chat/IME when processed, else take KeyCode
					if processed then
						return
					end
					if input.KeyCode ~= Enum.KeyCode.Unknown then
						finishBind(input.KeyCode.Name)
					end
				end)
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

		local TitleLbl = C("TextLabel", {
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
		local sliderEnabled = true

		local function setSliderEnabled(on)
			sliderEnabled = on == true
			Row.Active = sliderEnabled
			Track.Active = sliderEnabled
			TitleLbl.TextColor3 = sliderEnabled and Color3.fromRGB(200, 200, 208) or Color3.fromRGB(90, 90, 100)
			ValLbl.TextColor3 = sliderEnabled and ACC or Color3.fromRGB(90, 90, 100)
		end

		local function paintValue(val)
			ValLbl.Text = fmt(val)
			local p = (val - min) / (max - min)
			Fill.Size = UDim2.new(p, 0, 1, 0)
			Knob.Position = UDim2.new(p, 0, 0.5, 0)
		end

		local function setValue(raw, visualOnly)
			local pct = math.clamp(raw, 0, 1)
			local val = min + (max - min) * pct
			if step >= 1 then
				val = math.floor(val / step + 0.5) * step
			else
				val = math.floor(val * 100 + 0.5) / 100
			end
			val = math.clamp(val, min, max)
			if visualOnly then
				paintValue(val)
				return
			end
			if not sliderEnabled then
				return
			end
			S[key] = val
			paintValue(val)
			if opts.onChange then
				pcall(opts.onChange, val)
			end
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
			setValue = function(val, visualOnly)
				local p = (val - min) / (max - min)
				setValue(p, visualOnly == true)
			end,
			setEnabled = setSliderEnabled,
			parentKey = opts.requires,
		}
		if opts.onRowCreated then
			opts.onRowCreated(Row, TitleLbl, setSliderEnabled)
		end
	end

	local function MakeButton(page, label, order, callback, textKey)
		local text = textKey and L(textKey) or label
		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			Text = text,
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
		if textKey and I18n and I18n.registerText then
			I18n.registerText(Row, textKey)
		end
	end

	local lastFooterText = "Ready"

	local function truncateFooterPart(text, maxLen)
		text = tostring(text or "")
		if #text <= maxLen then
			return text
		end
		return string.sub(text, 1, maxLen - 2) .. "…"
	end

	local function musicFooterFromState()
		if not MusicModule or not MusicModule.GetState then
			return nil
		end
		local st = MusicModule.GetState()
		if not st or not st.title or st.title == "" then
			return nil
		end
		if not st.playing and not st.paused and not st.hasTrack then
			return nil
		end
		local title = tostring(st.title)
		if #title > 36 then
			title = string.sub(title, 1, 34) .. "…"
		end
		return "♪ " .. title
	end

	function setFooterStatus(text)
		if text ~= nil then
			lastFooterText = tostring(text)
		end
		if FooterStatus then
			local display
			if activeLayoutProfile == "music" then
				local trackText = musicFooterFromState()
				if trackText then
					display = trackText
				elseif lastFooterText:sub(1, 2) == "♪ " then
					display = truncateFooterPart(lastFooterText, 48)
				else
					display = "v" .. (S.Version or "?")
				end
			else
				display = "v" .. (S.Version or "?") .. "  ·  " .. lastFooterText
			end
			FooterStatus.Text = display
		end
	end

	local function buildTabPages()
		task.wait()
		local T1 = MakeTab("visuals", true, true, 1)
	local T3 = MakeTab("legit", false, false, 2)
	local TR = MakeTab("rage", false, false, 3)
	task.wait()
	local TAnim = MakeTab("anim", false, false, 4)
	local TWorld = MakeTab("world", false, false, 5)
	local TFriend = MakeTab("friends", false, false, 6)
	local T2 = MakeTab("settings", false, false, 7)
	local TM = MakeTab("misc", false, false, 8)
	local TMenu = MakeTab("menus", false, false, 9)
	local T4 = MakeTab("config", false, false, 10)
	task.wait()
	local TMusic = MakeTab("music", false, false, 11, { fixed = true, layout = "music" })

	-- Criminality tab — visible in ALL Criminality places (lobby + Casual + sub-places)
	-- Uses game.GameId (Universe ID = 1494262959) so it works after any in-game teleport.
	local TCrim = nil
	if game.GameId == 1494262959 then
		TCrim = MakeTab("criminality", false, false, 12, { fixed = true })
	end

	if UIMusicModule and MusicModule then
		UIMusicModule.build({
			TMusic = TMusic,
			S = S,
			C = C,
			ACC = ACC,
			tabCol = TAB_THEMES.music,
			Music = MusicModule,
			I18n = I18n,
			MakeCard = MakeCard,
			MakeSlider = MakeSlider,
			MakeTog = MakeTog,
			showNotify = showNotify,
			setFooterStatus = setFooterStatus,
			TweenPlay = TweenPlay,
		})
		UIMusicModule.buildWidget({
			ParentGUI = ParentGUI,
			S = S,
			C = C,
			Music = MusicModule,
			I18n = I18n,
			TweenPlay = TweenPlay,
		})
	end

	local function MakeCriminalitySubTabs(host)
		local crimCol = TAB_THEMES.criminality or ACC
		local crimSoft = tabSoft(crimCol)

		local Root = C("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = host,
		})

		local TabBar = C("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(13, 13, 17),
			BorderSizePixel = 0,
			Parent = Root,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = TabBar })
		C("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = TabBar,
		})

		local tabGap = 4
		local tabBtnW = 78

		local TabRow = C("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			Parent = TabBar,
		})
		C("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, tabGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = TabRow,
		})

		local Scroll = C("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -40),
			Position = UDim2.new(0, 0, 0, 40),
			BackgroundTransparency = 1,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			Parent = Root,
		})
		C("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 4),
			Parent = Scroll,
		})

		local panels = {}
		local tabBtns = {}
		local activeKey = nil
		local tabDefs = {
			{ key = "combat", labelKey = "crim_tab_combat" },
			{ key = "survival", labelKey = "crim_tab_survival" },
			{ key = "pickup", labelKey = "crim_tab_pickup" },
			{ key = "esp", labelKey = "crim_tab_esp" },
			{ key = "path", labelKey = "crim_tab_path" },
			{ key = "bounty", labelKey = "crim_tab_bounty" },
			{ key = "invsee", labelKey = "crim_tab_invsee" },
			{ key = "visual", labelKey = "crim_tab_visual" },
			{ key = "skins", labelKey = "crim_tab_skins" },
			{ key = "utility", labelKey = "crim_tab_utility" },
		}

		local function styleCrimTab(btn, on)
			TweenPlay(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quart), {
				BackgroundColor3 = on and crimSoft or Color3.fromRGB(20, 20, 25),
				TextColor3 = on and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(115, 115, 125),
			})
			local ind = btn:FindFirstChild("Indicator")
			if ind then
				ind.BackgroundTransparency = on and 0 or 1
			end
		end

		local function switchCrimTab(key)
			if activeKey == key then
				return
			end
			if tabBtns[activeKey] then
				styleCrimTab(tabBtns[activeKey], false)
			end
			if panels[activeKey] then
				panels[activeKey].Visible = false
			end
			activeKey = key
			if tabBtns[key] then
				styleCrimTab(tabBtns[key], true)
			end
			if panels[key] then
				panels[key].Visible = true
				Scroll.CanvasPosition = Vector2.new(0, 0)
			end
			-- Expand menu only on Skins vault; other Crim sub-tabs stay compact
			if key == "skins" then
				if ActiveTabBtn then
					tabLayoutProfiles[ActiveTabBtn] = "skins"
				end
				ApplyLayout(false, true, true, "skins")
			elseif activeLayoutProfile == "skins" then
				if ActiveTabBtn then
					tabLayoutProfiles[ActiveTabBtn] = nil
				end
				ApplyLayout(false, true, true, "default")
			end
			Scroll.ScrollingEnabled = key ~= "skins"
			if key == "skins" and type(_G.__VG_SkinVaultAutoRefreshOnce) == "function" then
				task.defer(_G.__VG_SkinVaultAutoRefreshOnce)
			end
		end

		for i, def in ipairs(tabDefs) do
			local label = L(def.labelKey)
			local btn = C("TextButton", {
				Size = UDim2.new(0, tabBtnW, 1, 0),
				BackgroundColor3 = Color3.fromRGB(20, 20, 25),
				Text = label,
				Font = Enum.Font.GothamSemibold,
				TextSize = 9,
				TextColor3 = Color3.fromRGB(115, 115, 125),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = TabRow,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
			C("Frame", {
				Name = "Indicator",
				Size = UDim2.new(1, -4, 0, 2),
				Position = UDim2.new(0, 2, 1, -3),
				BackgroundColor3 = crimCol,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = btn,
			})
			if I18n and I18n.registerText then
				I18n.registerText(btn, def.labelKey)
			end
			btn.MouseButton1Click:Connect(function()
				switchCrimTab(def.key)
			end)
			tabBtns[def.key] = btn

			local panel = C("Frame", {
				Size = UDim2.new(1, -2, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = false,
				Parent = Scroll,
			})
			C("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = panel,
			})
			panels[def.key] = panel
		end

		switchCrimTab("combat")
		return panels
	end

	-- ── Criminality tab content ────────────────────────────────────────────────
	if TCrim then
		local CP = MakeCriminalitySubTabs(TCrim)
		local CCombat = CP.combat
		local CSurv = CP.survival
		local CCrate = CP.pickup
		local CESP = CP.esp
		local CPath = CP.path
		local CBounty = CP.bounty
		local CInv = CP.invsee
		local CVIS = CP.visual
		local CSkins = CP.skins
		local CUtil = CP.utility

		MakeTog(CCombat, "Melee Aura", "CrimMeleeAura", 1, { flat = true })
		MakeSlider(CCombat, "Aura Range", "CrimMeleeRange", 2, 15, 3, {
			suffix = " st",
			step = 1,
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeTog(CCombat, "No Recoil", "CrimNoRecoil", 3, {
			flat = true,
			onChange = function(on)
				if S._crimRefreshGunMods then
					task.delay(0.2, S._crimRefreshGunMods)
				end
			end,
		})
		MakeTog(CCombat, "No Spread", "CrimNoSpread", 4, {
			flat = true,
			onChange = function()
				if S._crimRefreshGunMods then
					task.delay(0.2, S._crimRefreshGunMods)
				end
			end,
		})
		MakeTog(CCombat, "Quick Equip", "CrimQuickEquip", 5, {
			flat = true,
			onChange = function()
				if S._crimRefreshGunMods then
					task.delay(0.2, S._crimRefreshGunMods)
				end
			end,
		})
		MakeTog(CCombat, "Auto Reload", "CrimAutoReload", 6, { flat = true })
		MakeHint(CCombat, "hint_crim_norecoil", 7)
		MakeHint(CCombat, "hint_crim_nospread", 8)
		MakeHint(CCombat, "hint_crim_gunextra", 9)
		MakeHint(CCombat, "hint_crim_quickequip", 10)
		MakeTog(CCombat, "Aim Prediction", "CrimAimPrediction", 11, {
			flat = true,
			onChange = function(on)
				local reg = sliderRegistry.CrimAimPredictionLead
				if reg and reg.setEnabled then
					reg.setEnabled(on)
				end
			end,
		})
		MakeSlider(CCombat, "Prediction Lead", "CrimAimPredictionLead", 5, 35, 12, {
			suffix = "",
			step = 1,
			requires = "CrimAimPrediction",
			fmt = function(v) return string.format("%.2f", v / 100) end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimAimPrediction == true)
				end
			end,
		})
		MakeHint(CCombat, "hint_crim_prediction", 13)
		MakeSection(CCombat, L("crim_sub_wallbang"), 14)
		MakeChoice(CCombat, "Target Pick Mode", "CrimWallbangPickMode", {
			{ label = "Menu list", value = "Menu" },
			{ label = "`+Click", value = "AltClick" },
			{ label = "Both", value = "Both" },
		}, 15, {
			labelKey = "crim_wallbang_pick_mode",
			onChange = function()
				if S._wallbangSyncPickMode then
					pcall(S._wallbangSyncPickMode)
				end
			end,
		})
		local wbTargetLbl = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = L("crim_wallbang_none"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(160, 160, 175),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 16,
			ZIndex = 5,
			Parent = CCombat,
		})
		local function refreshWbTargetLbl(name)
			name = tostring(name or S.CrimWallbangTargetName or "")
			if name == "" then
				wbTargetLbl.Text = L("crim_wallbang_none")
				wbTargetLbl.TextColor3 = Color3.fromRGB(160, 160, 175)
			else
				wbTargetLbl.Text = L("crim_wallbang_target", name)
				wbTargetLbl.TextColor3 = Color3.fromRGB(255, 120, 130)
			end
		end
		S._wallbangTargetChanged = refreshWbTargetLbl
		refreshWbTargetLbl(S.CrimWallbangTargetName)

		local wbMenuBlock = C("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 17,
			ZIndex = 5,
			Parent = CCombat,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = wbMenuBlock,
		})

		local wbSearchHost = C("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ZIndex = 6,
			Parent = wbMenuBlock,
		})
		local wbSearchRow = C("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = wbSearchHost,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = wbSearchRow })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = wbSearchRow })
		local WbSearch = C("TextBox", {
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1,
			Text = "",
			PlaceholderText = L("crim_wallbang_search_ph"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(210, 210, 220),
			PlaceholderColor3 = Color3.fromRGB(95, 95, 105),
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = wbSearchRow,
		})

		local wbList = C("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 132),
			BackgroundColor3 = Color3.fromRGB(14, 14, 18),
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			ZIndex = 5,
			Parent = wbMenuBlock,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = wbList })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = wbList })
		C("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = wbList,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = wbList,
		})

		local function wbResolveFromText(text)
			text = string.lower((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
			if text == "" then
				return nil
			end
			local PlayersSvc = game:GetService("Players")
			local localPlr = PlayersSvc.LocalPlayer
			local exact, partial
			for _, plr in ipairs(PlayersSvc:GetPlayers()) do
				if plr ~= localPlr then
					local name = string.lower(plr.Name)
					local disp = string.lower(plr.DisplayName or "")
					if name == text or disp == text then
						exact = plr
						break
					end
					if not partial and (name:find(text, 1, true) or disp:find(text, 1, true)) then
						partial = plr
					end
				end
			end
			return exact or partial
		end

		local function wbSelectPlayer(plr)
			if not plr then
				return
			end
			if S._clientWallbangSetTarget then
				S._clientWallbangSetTarget(plr)
			else
				S.CrimWallbangTargetUserId = plr.UserId
				S.CrimWallbangTargetName = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
				refreshWbTargetLbl(S.CrimWallbangTargetName)
			end
			WbSearch.Text = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
		end

		local function rebuildWbPlayerList(filter)
			for _, ch in ipairs(wbList:GetChildren()) do
				if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
					ch:Destroy()
				end
			end
			filter = string.lower((filter or ""):gsub("^%s+", ""):gsub("%s+$", ""))
			local PlayersSvc = game:GetService("Players")
			local localPlr = PlayersSvc.LocalPlayer
			local cam = workspace.CurrentCamera
			local origin = cam and cam.CFrame.Position or Vector3.zero
			local rows = {}
			for _, plr in ipairs(PlayersSvc:GetPlayers()) do
				if plr ~= localPlr then
					local name = plr.Name
					local disp = plr.DisplayName or ""
					local lowN, lowD = string.lower(name), string.lower(disp)
					if filter == "" or lowN:find(filter, 1, true) or lowD:find(filter, 1, true) then
						local part = plr.Character
							and (plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Head"))
						local dist = part and (part.Position - origin).Magnitude or 1e9
						table.insert(rows, { plr = plr, dist = dist, name = name, disp = disp })
					end
				end
			end
			table.sort(rows, function(a, b)
				return a.dist < b.dist
			end)
			local selectedUid = tonumber(S.CrimWallbangTargetUserId) or 0
			for i, row in ipairs(rows) do
				if i > 24 then
					break
				end
				local selected = row.plr.UserId == selectedUid
				local label = row.disp ~= "" and row.disp ~= row.name and (row.disp .. "  ·  @" .. row.name) or row.name
				local distTxt = row.dist < 1e8 and string.format("  %.0fst", row.dist) or ""
				local btn = C("TextButton", {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = selected and Color3.fromRGB(42, 22, 26) or Color3.fromRGB(20, 20, 26),
					Text = label .. distTxt,
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextColor3 = selected and Color3.fromRGB(255, 140, 150) or Color3.fromRGB(190, 190, 200),
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					LayoutOrder = i,
					ZIndex = 6,
					Parent = wbList,
				})
				C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
				C("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = btn })
				btn.MouseEnter:Connect(function()
					if row.plr.UserId ~= (tonumber(S.CrimWallbangTargetUserId) or 0) then
						btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					end
				end)
				btn.MouseLeave:Connect(function()
					local sel = row.plr.UserId == (tonumber(S.CrimWallbangTargetUserId) or 0)
					btn.BackgroundColor3 = sel and Color3.fromRGB(42, 22, 26) or Color3.fromRGB(20, 20, 26)
				end)
				btn.MouseButton1Click:Connect(function()
					wbSelectPlayer(row.plr)
					rebuildWbPlayerList(WbSearch.Text)
				end)
			end
			if #rows == 0 then
				C("TextLabel", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = L("crim_wallbang_list_empty"),
					Font = Enum.Font.Gotham,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(110, 110, 120),
					LayoutOrder = 1,
					ZIndex = 6,
					Parent = wbList,
				})
			end
		end

		WbSearch:GetPropertyChangedSignal("Text"):Connect(function()
			rebuildWbPlayerList(WbSearch.Text)
		end)
		WbSearch.FocusLost:Connect(function(enter)
			if enter then
				local plr = wbResolveFromText(WbSearch.Text)
				if plr then
					wbSelectPlayer(plr)
					rebuildWbPlayerList("")
				end
			end
		end)
		rebuildWbPlayerList("")

		local wbMenuBtns = C("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			ZIndex = 5,
			Parent = wbMenuBlock,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = wbMenuBtns,
		})
		MakeButton(wbMenuBtns, nil, 1, function()
			rebuildWbPlayerList(WbSearch.Text)
		end, "btn_crim_wallbang_refresh_list")
		MakeButton(wbMenuBtns, nil, 2, function()
			if S._clientWallbangPick then
				S._clientWallbangPick()
				rebuildWbPlayerList(WbSearch.Text)
			end
		end, "btn_crim_wallbang_pick")

		local wbAltHint = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Text = L("hint_crim_wallbang_alt"),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(140, 140, 155),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 18,
			ZIndex = 5,
			Parent = CCombat,
		})

		local function syncWbPickModeUi()
			local mode = tostring(S.CrimWallbangPickMode or "Both")
			local showMenu = mode == "Menu" or mode == "Both"
			local showAlt = mode == "AltClick" or mode == "Both"
			wbMenuBlock.Visible = showMenu
			wbAltHint.Visible = showAlt
			if showMenu then
				rebuildWbPlayerList(WbSearch.Text)
			end
		end
		S._wallbangSyncPickMode = syncWbPickModeUi
		S._wallbangAfterPick = function()
			refreshWbTargetLbl(S.CrimWallbangTargetName)
			if wbMenuBlock.Visible then
				local name = tostring(S.CrimWallbangTargetName or "")
				if name ~= "" then
					WbSearch.Text = name
				end
				rebuildWbPlayerList(WbSearch.Text)
			end
		end
		syncWbPickModeUi()

		MakeButton(CCombat, nil, 19, function()
			if S._clientWallbangClearTarget then
				S._clientWallbangClearTarget()
			end
			WbSearch.Text = ""
			rebuildWbPlayerList("")
		end, "btn_crim_wallbang_clear")
		MakeButton(CCombat, nil, 20, function()
			if S._clientWallbangApply then
				S._clientWallbangApply()
			end
		end, "btn_crim_wallbang_open")
		MakeButton(CCombat, nil, 21, function()
			if S._clientWallbangRestore then
				S._clientWallbangRestore()
			end
		end, "btn_crim_wallbang_restore")
		MakeBind(CCombat, "Refresh Line Key", "CrimWallbangRefreshKey", 22, {
			onChange = function()
				if S._clientWallbangRebind then
					S._clientWallbangRebind()
				end
			end,
		})
		MakeBind(CCombat, "Pick Crosshair Key", "CrimWallbangPickKey", 23, {
			onChange = function()
				if S._clientWallbangRebind then
					S._clientWallbangRebind()
				end
			end,
		})
		MakeTog(CCombat, "Live Line Refresh", "CrimWallbangLive", 24, {
			flat = true,
			onChange = function(on)
				if S._clientWallbangSetLive then
					S._clientWallbangSetLive(on == true)
				end
			end,
		})
		MakeHint(CCombat, "hint_crim_wallbang", 25)

		MakeTog(CSurv, "No Fall Damage", "CrimNoFall", 1, { flat = true })
		MakeTog(CSurv, "No Spike Damage", "CrimNoSpike", 2, { flat = true })
		MakeTog(CSurv, "No Ragdoll", "CrimNoRagdoll", 3, {
			flat = true,
			onChange = function(on)
				if on and S.CrimRagdollDrag then
					S.CrimRagdollDrag = false
					refreshToggleVisual("CrimRagdollDrag")
					refreshNestedToggles("CrimRagdollDrag")
					local reg = sliderRegistry.CrimRagdollDragSpeed
					if reg and reg.setEnabled then
						reg.setEnabled(false)
					end
				end
			end,
		})
		MakeHint(CSurv, "hint_crim_noragdoll", 4)
		MakeTog(CSurv, "Ragdoll Drag", "CrimRagdollDrag", 5, {
			flat = true,
			onChange = function(on)
				if on and S.CrimNoRagdoll then
					S.CrimNoRagdoll = false
					refreshToggleVisual("CrimNoRagdoll")
					refreshNestedToggles("CrimNoRagdoll")
				end
				local reg = sliderRegistry.CrimRagdollDragSpeed
				if reg and reg.setEnabled then
					reg.setEnabled(on)
				end
			end,
		})
		MakeBind(CSurv, "Drag Key (hold)", "CrimRagdollDragKey", 6, {
			requires = "CrimRagdollDrag",
		})
		MakeSlider(CSurv, "Drag Speed", "CrimRagdollDragSpeed", 10, 120, 7, {
			suffix = " st/s",
			step = 5,
			requires = "CrimRagdollDrag",
			fmt = function(v)
				return string.format("%d st/s", v)
			end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimRagdollDrag == true)
				end
			end,
		})
		MakeHint(CSurv, "hint_crim_ragdolldrag", 8)
		MakeTog(CSurv, "Fast Acceleration", "CrimFastAccel", 9, {
			flat = true,
			onChange = function(on)
				local reg = sliderRegistry.CrimFastAccelValue
				if reg and reg.setEnabled then
					reg.setEnabled(on)
				end
			end,
		})
		MakeSlider(CSurv, "Accel Value", "CrimFastAccelValue", 0.5, 3, 10, {
			step = 0.1,
			requires = "CrimFastAccel",
			fmt = function(v) return string.format("%.1f", v) end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimFastAccel == true)
				end
			end,
		})
		MakeHint(CSurv, "hint_crim_fastaccel", 11)
		MakeTog(CSurv, "Infinite Stamina", "CrimInfStamina", 12, { flat = true })
		MakeHint(CSurv, "hint_crim_stamina", 13)
		MakeTog(CSurv, "Auto Respawn", "CrimAutoRespawn", 14, { flat = true })
		MakeHint(CSurv, "hint_crim_autorespawn", 15)

		MakeSection(CCrate, L("crim_sub_pickup_crates"), 1)
		MakeTog(CCrate, "Auto Pickup Crates", "CrimCratePickup", 2, {
			flat = true,
			onChange = function(on)
				for _, key in ipairs({ "CrimCratePickupDist", "CrimCratePickupDelay" }) do
					local reg = sliderRegistry[key]
					if reg and reg.setEnabled then
						reg.setEnabled(on)
					end
				end
			end,
		})
		MakeTog(CCrate, "Pickup Basic Crates", "CrimCratePickupBasic", 3, {
			flat = true,
			requires = "CrimCratePickup",
		})
		MakeTog(CCrate, "Pickup Rare Crates", "CrimCratePickupRare", 4, {
			flat = true,
			requires = "CrimCratePickup",
		})
		MakeTog(CCrate, "Pickup Airdrop Crates", "CrimCratePickupAirdrop", 5, {
			flat = true,
			requires = "CrimCratePickup",
		})
		MakeSlider(CCrate, "Pickup Range", "CrimCratePickupDist", 2, 8, 6, {
			suffix = " st",
			step = 0.5,
			requires = "CrimCratePickup",
			fmt = function(v) return string.format("%.1f st", v) end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimCratePickup == true)
				end
			end,
		})
		MakeSlider(CCrate, "Pickup Delay", "CrimCratePickupDelay", 80, 800, 7, {
			suffix = "ms",
			step = 20,
			requires = "CrimCratePickup",
			fmt = function(v) return string.format("%d ms", v) end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimCratePickup == true)
				end
			end,
		})
		MakeTog(CCrate, "Pickup Animation", "CrimCratePickupFx", 8, {
			flat = true,
			requires = "CrimCratePickup",
		})
		MakeHint(CCrate, "hint_crim_pickup", 9)
		MakeSection(CCrate, L("crim_sub_pickup_guns"), 10)
		MakeTog(CCrate, "Fast Pickup", "CrimFastPickup", 11, {
			flat = true,
			onChange = function(on)
				local reg = sliderRegistry.CrimFastPickupRange
				if reg and reg.setEnabled then
					reg.setEnabled(on)
				end
			end,
		})
		MakeTog(CCrate, "Pickup Guns", "CrimFastPickupGuns", 12, {
			flat = true,
			requires = "CrimFastPickup",
		})
		MakeTog(CCrate, "Pickup Melee", "CrimFastPickupMelee", 13, {
			flat = true,
			requires = "CrimFastPickup",
		})
		MakeTog(CCrate, "Pickup Armor", "CrimFastPickupArmor", 14, {
			flat = true,
			requires = "CrimFastPickup",
		})
		MakeSlider(CCrate, "Pickup Range", "CrimFastPickupRange", 2, 12, 15, {
			suffix = " st",
			step = 0.5,
			requires = "CrimFastPickup",
			fmt = function(v) return string.format("%.1f st", v) end,
			onRowCreated = function(_, __, setEnabled)
				if setEnabled then
					setEnabled(S.CrimFastPickup == true)
				end
			end,
		})
		MakeHint(CCrate, "hint_crim_fastpickup", 16)
		MakeSection(CCrate, L("crim_sub_pickup_money"), 17)
		MakeTog(CCrate, "Auto Pickup Money", "CrimMoneyPickup", 18, {
			flat = true,
			onChange = function(on)
				for _, key in ipairs({ "CrimMoneyPickupDist", "CrimMoneyPickupDelay" }) do
					local reg = sliderRegistry[key]
					if reg and reg.setEnabled then
						reg.setEnabled(on)
					end
				end
			end,
		})
		MakeSlider(CCrate, "Money Pickup Distance", "CrimMoneyPickupDist", 2, 25, 19, {
			suffix = " st",
			step = 1,
			requires = "CrimMoneyPickup",
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeSlider(CCrate, "Money Pickup Delay", "CrimMoneyPickupDelay", 500, 2500, 20, {
			suffix = "ms",
			step = 100,
			requires = "CrimMoneyPickup",
			fmt = function(v) return string.format("%d ms", v) end,
		})
		MakeHint(CCrate, "hint_crim_money", 21)
		MakeSection(CCrate, L("crim_sub_pickup_allowance"), 22)
		MakeTog(CCrate, "Auto Claim Allowance", "CrimAllowanceClaim", 23, {
			flat = true,
			onChange = function(on)
				for _, key in ipairs({ "CrimAllowanceClaimDist", "CrimAllowanceClaimDelay" }) do
					local reg = sliderRegistry[key]
					if reg and reg.setEnabled then
						reg.setEnabled(on)
					end
				end
			end,
		})
		MakeSlider(CCrate, "ATM Distance", "CrimAllowanceClaimDist", 4, 30, 24, {
			suffix = " st",
			step = 1,
			requires = "CrimAllowanceClaim",
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeSlider(CCrate, "Claim Delay", "CrimAllowanceClaimDelay", 1000, 10000, 25, {
			suffix = "ms",
			step = 500,
			requires = "CrimAllowanceClaim",
			fmt = function(v) return string.format("%d ms", v) end,
		})
		MakeHint(CCrate, "hint_crim_allowance", 26)
		MakeSection(CCrate, L("crim_sub_session"), 27)
		MakeTog(CCrate, "Session Economy HUD", "CrimSessionStats", 28, { flat = true })
		MakeButton(CCrate, nil, 29, function()
			if S._crimEcoReset then
				S._crimEcoReset()
			end
		end, "btn_crim_eco_reset")
		MakeHint(CCrate, "hint_crim_session", 30)

		MakeSection(CESP, L("crim_sub_world"), 1)
		MakeTog(CESP, "Safe ESP", "CrimSafeESP", 2, {
			flat = true,
			onChange = function()
				refreshNestedToggles("CrimSafeESP")
			end,
		})
		MakeTog(CESP, "Show Broken", "CrimSafeShowBroken", 3, {
			flat = true,
			requires = "CrimSafeESP",
		})
		MakeTog(CESP, "Dealer ESP", "CrimDealerESP", 4, {
			flat = true,
			onChange = function()
				if S._crimSyncDealerESP then
					pcall(S._crimSyncDealerESP)
				end
			end,
		})
		local DealerStockRow = C("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
			ZIndex = 5,
			Parent = CESP,
		})
		local DealerStockSearch = C("TextBox", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BorderSizePixel = 0,
			Text = tostring(S.CrimDealerStockFilter or ""),
			PlaceholderText = "Stock search (AKS, Mare, Bat…)",
			ClearTextOnFocus = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			PlaceholderColor3 = Color3.fromRGB(100, 100, 112),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = DealerStockRow,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = DealerStockSearch })
		C("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = DealerStockSearch })
		local DealerStockStatus = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(130, 140, 160),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 6,
			ZIndex = 5,
			Parent = CESP,
		})
		local function refreshDealerStockStatus()
			local n = 0
			if S._crimDealerStockCount then
				local ok, c = pcall(S._crimDealerStockCount)
				if ok and typeof(c) == "number" then
					n = c
				end
			end
			local q = tostring(S.CrimDealerStockFilter or "")
			if string.find(q, "%S") then
				DealerStockStatus.Text = string.format("%d dealer(s) with \"%s\"", n, q)
				DealerStockStatus.TextColor3 = n > 0 and Color3.fromRGB(140, 220, 150) or Color3.fromRGB(200, 120, 120)
			else
				DealerStockStatus.Text = "Empty filter = all dealers (normal ESP)"
				DealerStockStatus.TextColor3 = Color3.fromRGB(130, 140, 160)
			end
		end
		DealerStockSearch:GetPropertyChangedSignal("Text"):Connect(function()
			S.CrimDealerStockFilter = DealerStockSearch.Text or ""
			if S._crimSyncDealerESP then
				pcall(S._crimSyncDealerESP)
			end
			refreshDealerStockStatus()
			if ConfigModule and ConfigModule.SaveGlobals then
				pcall(ConfigModule.SaveGlobals, S)
			end
		end)
		MakeTog(CESP, "Stock Matches Only", "CrimDealerStockOnly", 7, {
			flat = true,
			requires = "CrimDealerESP",
			onChange = function()
				if S._crimSyncDealerESP then
					pcall(S._crimSyncDealerESP)
				end
				refreshDealerStockStatus()
			end,
		})
		MakeSlider(CESP, "Safe/Dealer Max Distance", "CrimESPMaxDist", 50, 600, 8, {
			suffix = " st",
			step = 10,
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeHint(CESP, "hint_crim_dealer", 9)
		MakeHint(CESP, "hint_crim_safe_broken", 10)
		MakeSection(CESP, L("crim_sub_guns"), 11)
		MakeTog(CESP, "Gun ESP", "CrimGunESP", 12, {
			flat = true,
			onChange = function(on)
				local dist = sliderRegistry.CrimGunESPMaxDist
				if dist and dist.setEnabled then
					dist.setEnabled(on)
				end
				refreshNestedToggles("CrimGunESP")
			end,
		})
		MakeTog(CESP, "Show Guns", "CrimGunESPGuns", 13, {
			flat = true,
			requires = "CrimGunESP",
			onChange = function()
				if S._crimSyncGunESP then S._crimSyncGunESP() end
			end,
		})
		MakeTog(CESP, "Show Melee", "CrimGunESPMelee", 14, {
			flat = true,
			requires = "CrimGunESP",
			onChange = function()
				if S._crimSyncGunESP then S._crimSyncGunESP() end
			end,
		})
		MakeSlider(CESP, "Gun View Distance", "CrimGunESPMaxDist", 30, 500, 15, {
			suffix = " st",
			step = 10,
			requires = "CrimGunESP",
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeSection(CESP, L("crim_sub_crates"), 16)
		MakeTog(CESP, "Crate ESP", "CrimCrateESP", 17, {
			flat = true,
			onChange = function(on)
				local dist = sliderRegistry.CrimCrateMaxDist
				if dist and dist.setEnabled then
					dist.setEnabled(on)
				end
			end,
		})
		MakeTog(CESP, "Basic Crates", "CrimCrateBasic", 18, {
			flat = true,
			requires = "CrimCrateESP",
		})
		MakeTog(CESP, "Rare Crates", "CrimCrateRare", 19, {
			flat = true,
			requires = "CrimCrateESP",
		})
		MakeTog(CESP, "Airdrop Crates", "CrimCrateAirdrop", 20, {
			flat = true,
			requires = "CrimCrateESP",
		})
		MakeSlider(CESP, "Crate View Distance", "CrimCrateMaxDist", 50, 2500, 21, {
			suffix = " st",
			step = 25,
			requires = "CrimCrateESP",
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeHint(CESP, "hint_crim_crate", 22)
		MakeHint(CESP, "hint_crim_gun", 23)
		task.defer(refreshDealerStockStatus)

		MakeSection(CPath, L("crim_sub_path"), 1)
		MakeTog(CPath, "Path Display", "CrimPathDisplay", 2, { flat = true })
		MakeChoice(CPath, "Path Target", "CrimPathTarget", {
			{ label = "Safe", value = "Safe" },
			{ label = "Dealer", value = "Dealer" },
			{ label = "Crate", value = "Crate" },
		}, 3)
		MakeTog(CPath, "Basic Crates", "CrimPathCrateBasic", 4, { flat = true })
		MakeTog(CPath, "Rare Crates", "CrimPathCrateRare", 5, { flat = true })
		MakeTog(CPath, "Airdrop Crates", "CrimPathCrateAirdrop", 6, { flat = true })
		MakeTog(CPath, "Full Paths Only", "CrimPathFullOnly", 7, { flat = true })
		MakeSlider(CPath, "Path Max Distance", "CrimPathMaxDist", 50, 600, 8, {
			suffix = " st",
			step = 10,
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeSlider(CPath, "Path Refresh", "CrimPathRefresh", 0.3, 1.5, 9, {
			suffix = "s",
			step = 0.05,
			fmt = function(v) return string.format("%.2fs", v) end,
		})
		MakeColorPicker(CPath, "Path Color", "CrimPathColor", 9)
		MakeColorPicker(CPath, "Jump Color", "CrimPathJumpColor", 10)
		MakeColorPicker(CPath, "End Color", "CrimPathEndColor", 11)
		MakeHint(CPath, "hint_crim_path", 12)

		MakeSection(CBounty, L("crim_sub_bounty"), 1)
		MakeTog(CBounty, "Bounty Tracker", "CrimBountyTracker", 2, { flat = true })
		MakeHint(CBounty, "hint_crim_bounty", 3)

		local BountyHeader = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "—",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(140, 140, 150),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
			ZIndex = 5,
			Parent = CBounty,
		})

		local BountyBox = C("Frame", {
			Size = UDim2.new(1, 0, 0, 300),
			BackgroundColor3 = Color3.fromRGB(15, 15, 19),
			BorderSizePixel = 0,
			LayoutOrder = 5,
			ZIndex = 5,
			Parent = CBounty,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = BountyBox })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = BountyBox })

		local BountyList = C("ScrollingFrame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.new(0, 4, 0, 4),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = BountyBox,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = BountyList,
		})
		_G.__VG_BountyList = BountyList
		_G.__VG_BountyHeader = BountyHeader

		-- ── Invsee (manual refresh) ───────────────────────────────────────────
		MakeHint(CInv, "hint_crim_invsee", 1)
		local InvRow = C("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			ZIndex = 5,
			Parent = CInv,
		})
		local InvSearch = C("TextBox", {
			Size = UDim2.new(1, -88, 1, 0),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Search player or item…",
			ClearTextOnFocus = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			PlaceholderColor3 = Color3.fromRGB(100, 100, 112),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = InvRow,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = InvSearch })
		C("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = InvSearch })
		local InvBtn = C("TextButton", {
			Size = UDim2.new(0, 80, 1, 0),
			Position = UDim2.new(1, -80, 0, 0),
			BackgroundColor3 = Color3.fromRGB(36, 42, 58),
			Text = L("btn_crim_invsee_refresh"),
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 225, 240),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = InvRow,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = InvBtn })
		if I18n and I18n.registerText then
			I18n.registerText(InvBtn, "btn_crim_invsee_refresh")
		end

		local InvStatus = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = L("crim_invsee_idle"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(140, 145, 160),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 3,
			ZIndex = 5,
			Parent = CInv,
		})

		local InvBox = C("Frame", {
			Size = UDim2.new(1, 0, 0, 380),
			BackgroundColor3 = Color3.fromRGB(14, 14, 18),
			BorderSizePixel = 0,
			LayoutOrder = 4,
			ZIndex = 5,
			Parent = CInv,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = InvBox })
		C("UIStroke", { Color = Color3.fromRGB(34, 34, 44), Thickness = 1, Transparency = 0.35, Parent = InvBox })

		local InvList = C("ScrollingFrame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.new(0, 4, 0, 4),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = InvBox,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = InvList,
		})
		C("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = InvList,
		})

		local invCache = {}
		local invFilter = ""

		local function clearInvList()
			for _, ch in ipairs(InvList:GetChildren()) do
				if ch:IsA("Frame") or ch:IsA("TextLabel") then
					ch:Destroy()
				end
			end
		end

		local function renderInvList()
			clearInvList()
			local q = string.lower(invFilter or "")
			local shownPlayers, shownTools = 0, 0
			local order = 0
			for _, row in ipairs(invCache) do
				local nameL = string.lower(row.name or "")
				local dispL = string.lower(row.display or "")
				local tools = row.tools or {}
				local nameHit = q == "" or string.find(nameL, q, 1, true) or string.find(dispL, q, 1, true)
				local matchedTools = {}
				if nameHit then
					matchedTools = tools
				else
					for _, t in ipairs(tools) do
						if string.find(string.lower(t.name or ""), q, 1, true) then
							matchedTools[#matchedTools + 1] = t
						end
					end
				end
				if nameHit or #matchedTools > 0 then
					order = order + 1
					shownPlayers = shownPlayers + 1
					shownTools = shownTools + #matchedTools

					local card = C("Frame", {
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = row.isLocal and Color3.fromRGB(22, 28, 38) or Color3.fromRGB(18, 18, 24),
						BorderSizePixel = 0,
						LayoutOrder = order,
						ZIndex = 7,
						Parent = InvList,
					})
					C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = card })
					C("UIListLayout", {
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
						Parent = card,
					})
					C("UIPadding", {
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						Parent = card,
					})

					local title = row.name
					if row.display and row.display ~= "" and row.display ~= row.name then
						title = row.name .. "  (" .. row.display .. ")"
					end
					if row.isLocal then
						title = title .. "  · you"
					end
					local handTxt = row.hand and ("  · hand: " .. row.hand) or ""
					C("TextLabel", {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = title .. handTxt,
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						TextColor3 = Color3.fromRGB(235, 238, 245),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						LayoutOrder = 1,
						ZIndex = 8,
						Parent = card,
					})

					if #matchedTools == 0 then
						C("TextLabel", {
							Size = UDim2.new(1, 0, 0, 14),
							BackgroundTransparency = 1,
							Text = "  (empty)",
							Font = Enum.Font.Gotham,
							TextSize = 10,
							TextColor3 = Color3.fromRGB(110, 115, 130),
							TextXAlignment = Enum.TextXAlignment.Left,
							LayoutOrder = 2,
							ZIndex = 8,
							Parent = card,
						})
					else
						for i, t in ipairs(matchedTools) do
							local prefix = t.equipped and "  [HAND] " or "  · "
							local col = t.equipped and Color3.fromRGB(120, 220, 150) or Color3.fromRGB(170, 175, 190)
							C("TextLabel", {
								Size = UDim2.new(1, 0, 0, 14),
								BackgroundTransparency = 1,
								Text = prefix .. t.name,
								Font = Enum.Font.GothamMedium,
								TextSize = 10,
								TextColor3 = col,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								LayoutOrder = 1 + i,
								ZIndex = 8,
								Parent = card,
							})
						end
					end
				end
			end
			if order == 0 then
				C("TextLabel", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = #invCache == 0 and L("crim_invsee_idle") or "No matches",
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Color3.fromRGB(110, 115, 130),
					LayoutOrder = 1,
					ZIndex = 7,
					Parent = InvList,
				})
			end
			InvStatus.Text = string.format("%d players · %d items%s", shownPlayers, shownTools, q ~= "" and (" · filter: " .. invFilter) or "")
		end

		local function doInvRefresh()
			local list = {}
			if S._crimInvseeScan then
				local ok, res = pcall(S._crimInvseeScan)
				if ok and typeof(res) == "table" then
					list = res
				end
			end
			invCache = list
			renderInvList()
			if showNotify then
				showNotify(string.format("Invsee: %d players", #list))
			end
		end

		InvBtn.MouseButton1Click:Connect(doInvRefresh)
		InvSearch:GetPropertyChangedSignal("Text"):Connect(function()
			invFilter = InvSearch.Text or ""
			renderInvList()
		end)

		MakeTog(CVIS, "FullBright", "CrimFullBright", 1, { flat = true })
		MakeHint(CVIS, "hint_crim_fullbright", 2)
		MakeTog(CVIS, "No Fog", "CrimNoFog", 3, { flat = true })
		MakeHint(CVIS, "hint_crim_nofog", 4)
		MakeTog(CVIS, "Skip Menu Intro", "CrimSkipMenuIntro", 5, {
			flat = true,
			onChange = function()
				if ConfigModule and ConfigModule.SaveGlobals then
					pcall(ConfigModule.SaveGlobals, S)
				end
			end,
		})
		MakeHint(CVIS, "hint_crim_skipintro", 6)

		if UISkinVaultModule and UISkinVaultModule.build then
			UISkinVaultModule.build({
				C = C,
				S = S,
				CSkins = CSkins,
				ConfigModule = ConfigModule,
				MakeTog = MakeTog,
				MakeSlider = MakeSlider,
				MakeButton = MakeButton,
				MakeHint = MakeHint,
				showNotify = showNotify,
			})
		end

		MakeTog(CVIS, "Hide Helmet Overlay", "CrimHideHelmetOverlay", 15, { flat = true })
		MakeHint(CVIS, "hint_crim_helmet", 16)
		MakeTog(CVIS, "Menu Meme Music", "CrimMenuMusic", 17, {
			flat = true,
			onChange = function(on)
				if ConfigModule and ConfigModule.SaveGlobals then
					pcall(ConfigModule.SaveGlobals, S)
				end
				if on and S._crimStartMenuMusic then
					pcall(S._crimStartMenuMusic)
				end
			end,
		})
		MakeChoice(CVIS, "Menu Track", "CrimMenuMusicTrack", {
			{ label = "Polskie Pola", value = "PolskiePola" },
			{ label = "Disco Polo", value = "DiscoPolo" },
			{ label = "Miguel Phonk", value = "Miguel" },
			{ label = "Polish Accordion", value = "Polka" },
			{ label = "Accordion Polka", value = "Accordion" },
			{ label = "Mountain Polka", value = "Mountain" },
			{ label = "Flute Oberek", value = "Oberek" },
			{ label = "Krakowiak", value = "Krakowiak" },
			{ label = "Mazurka", value = "Mazurka" },
			{ label = "Polish Hard Killer", value = "HardKiller" },
			{ label = "Polski Eleven", value = "Polski11" },
			{ label = "Panpipe Polka", value = "Panpipe" },
		}, 18, {
			onChange = function()
				if ConfigModule and ConfigModule.SaveGlobals then
					pcall(ConfigModule.SaveGlobals, S)
				end
				if S.CrimMenuMusic and S._crimStartMenuMusic then
					pcall(S._crimStartMenuMusic)
				end
			end,
		})
		MakeHint(CVIS, "hint_crim_menu_music", 19)
		MakeTog(CVIS, "Custom Hit Sounds", "CrimHitSoundSwap", 20, { flat = true })
		MakeChoice(CVIS, "Headshot Sound", "CrimHitSoundPreset", {
			{ label = "UT Announcer", value = "UT" },
			{ label = "CS:GO Dink", value = "CS" },
		}, 21, {
			onChange = function()
				if S.CrimHitSoundSwap and type(_G.__VG_ReapplyHitSounds) == "function" then
					pcall(_G.__VG_ReapplyHitSounds)
				end
			end,
		})
		MakeSlider(CVIS, "Headshot Cooldown", "CrimHitSoundCooldown", 0, 500, 22, {
			suffix = "ms",
			step = 10,
		})
		MakeButton(CVIS, nil, 23, function()
			if S._crimListGameSounds then
				S._crimListGameSounds()
			end
		end, "btn_crim_list_sounds")
		MakeHint(CVIS, "hint_crim_hitsounds", 24)

		local SoundHeader = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Click List → unique SoundIds here. Click row = copy ID · Play = preview",
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(130, 130, 140),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			LayoutOrder = 25,
			ZIndex = 5,
			Parent = CVIS,
		})

		local SoundSearch = C("TextBox", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Search sound name, ID or path…",
			ClearTextOnFocus = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			PlaceholderColor3 = Color3.fromRGB(100, 100, 112),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 26,
			ZIndex = 6,
			Parent = CVIS,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SoundSearch })
		C("UIStroke", {
			Color = Color3.fromRGB(38, 38, 48),
			Thickness = 1,
			Transparency = 0.35,
			Parent = SoundSearch,
		})
		C("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = SoundSearch,
		})

		local SoundBox = C("Frame", {
			Size = UDim2.new(1, 0, 0, 320),
			BackgroundColor3 = Color3.fromRGB(15, 15, 19),
			BorderSizePixel = 0,
			LayoutOrder = 27,
			ZIndex = 5,
			Parent = CVIS,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SoundBox })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = SoundBox })

		local SoundList = C("ScrollingFrame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.new(0, 4, 0, 4),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = SoundBox,
		})
		C("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = SoundList,
		})

		_G.__VG_SoundHeader = SoundHeader
		_G.__VG_SoundList = SoundList

		local previewSound = nil
		local function stopPreview()
			if previewSound then
				pcall(function()
					previewSound:Stop()
					previewSound:Destroy()
				end)
				previewSound = nil
			end
		end

		local function copyId(id)
			if not id or id == "" then
				return
			end
			if typeof(setclipboard) == "function" then
				pcall(setclipboard, id)
			elseif typeof(toclipboard) == "function" then
				pcall(toclipboard, id)
			end
		end

		local function playPreview(id)
			if not id or id == "" then
				return
			end
			stopPreview()
			local s = Instance.new("Sound")
			s.Name = "VG_SoundPreview"
			s.SoundId = id
			s.Volume = 0.7
			s.Parent = game:GetService("SoundService")
			previewSound = s
			pcall(function()
				s:Play()
			end)
			task.delay(4, function()
				if previewSound == s then
					stopPreview()
				end
			end)
		end

		local soundTotal = 0
		local soundUnique = 0
		local function applySoundSearch()
			local query = string.lower(SoundSearch.Text or "")
			local shown = 0
			for _, ch in ipairs(SoundList:GetChildren()) do
				if ch:IsA("Frame") and ch.Name == "SoundCard" then
					local haystack = ch:GetAttribute("SearchText") or ""
					local visible = query == "" or string.find(haystack, query, 1, true) ~= nil
					ch.Visible = visible
					if visible then
						shown += 1
					end
				end
			end
			SoundHeader.Text = string.format(
				"%d Sound · %d/%d shown  |  click = copy · ▶ = play",
				soundTotal,
				shown,
				soundUnique
			)
		end
		SoundSearch:GetPropertyChangedSignal("Text"):Connect(applySoundSearch)

		_G.__VG_FillSoundList = function(rows, totalN)
			stopPreview()
			for _, ch in ipairs(SoundList:GetChildren()) do
				if not ch:IsA("UIListLayout") then
					ch:Destroy()
				end
			end
			local uniq = type(rows) == "table" and #rows or 0
			soundTotal = tonumber(totalN) or 0
			soundUnique = uniq
			applySoundSearch()

			if uniq == 0 then
				local empty = C("TextLabel", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					Text = "No Sound found",
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Color3.fromRGB(120, 120, 130),
					LayoutOrder = 1,
					ZIndex = 7,
					Parent = SoundList,
				})
				return
			end

			task.spawn(function()
				for i, row in ipairs(rows) do
					local id = row.id or ""
					local idShow = id ~= "" and id or "(empty SoundId)"
					local playingTag = (row.playing or 0) > 0 and " ●PLAYING" or ""

					local card = C("Frame", {
						Name = "SoundCard",
						Size = UDim2.new(1, 0, 0, 52),
						BackgroundColor3 = Color3.fromRGB(20, 20, 26),
						BorderSizePixel = 0,
						LayoutOrder = i,
						ZIndex = 7,
						Parent = SoundList,
					})
					card:SetAttribute(
						"SearchText",
						string.lower(table.concat({
							tostring(row.names or ""),
							idShow,
							tostring(row.sample or ""),
						}, " "))
					)
					local query = string.lower(SoundSearch.Text or "")
					card.Visible = query == ""
						or string.find(card:GetAttribute("SearchText"), query, 1, true) ~= nil
					C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = card })

					local hit = C("TextButton", {
						Size = UDim2.new(1, -44, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						AutoButtonColor = false,
						ZIndex = 8,
						Parent = card,
					})

					C("TextLabel", {
						Size = UDim2.new(1, -8, 0, 14),
						Position = UDim2.new(0, 8, 0, 4),
						BackgroundTransparency = 1,
						Text = string.format("x%d%s  %s", row.count or 1, playingTag, row.names or "?"),
						Font = Enum.Font.GothamMedium,
						TextSize = 10,
						TextColor3 = Color3.fromRGB(210, 210, 220),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 9,
						Parent = card,
					})
					C("TextLabel", {
						Size = UDim2.new(1, -8, 0, 12),
						Position = UDim2.new(0, 8, 0, 20),
						BackgroundTransparency = 1,
						Text = idShow,
						Font = Enum.Font.Code,
						TextSize = 9,
						TextColor3 = ACC,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 9,
						Parent = card,
					})
					C("TextLabel", {
						Size = UDim2.new(1, -8, 0, 12),
						Position = UDim2.new(0, 8, 0, 34),
						BackgroundTransparency = 1,
						Text = tostring(row.sample or ""),
						Font = Enum.Font.Gotham,
						TextSize = 9,
						TextColor3 = Color3.fromRGB(110, 110, 120),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 9,
						Parent = card,
					})

					local playBtn = C("TextButton", {
						Size = UDim2.new(0, 36, 0, 36),
						Position = UDim2.new(1, -40, 0.5, -18),
						BackgroundColor3 = Color3.fromRGB(32, 32, 42),
						Text = "▶",
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(230, 230, 240),
						AutoButtonColor = false,
						BorderSizePixel = 0,
						ZIndex = 10,
						Parent = card,
					})
					C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = playBtn })

					hit.MouseButton1Click:Connect(function()
						copyId(id)
						SoundHeader.Text = "Copied: " .. idShow
					end)
					playBtn.MouseButton1Click:Connect(function()
						playPreview(id)
						SoundHeader.Text = "Playing: " .. idShow
					end)

					if i % 40 == 0 then
						applySoundSearch()
						task.wait()
					end
				end
				applySoundSearch()
			end)
		end

		MakeTog(CUtil, "Staff Detector", "CrimStaffDetect", 1, { flat = true })
		MakeTog(CUtil, "Staff Auto Kick", "CrimStaffAutoKick", 2, {
			flat = true,
			requires = "CrimStaffDetect",
		})
		MakeTog(CUtil, "No Fail Lockpick", "CrimNoFailLockpick", 3, { flat = true })
		MakeTog(CUtil, "Auto Open Doors", "CrimAutoOpenDoors", 4, { flat = true })
		MakeTog(CUtil, "Auto Unlock Doors", "CrimAutoUnlockDoors", 5, { flat = true })
		MakeTog(CUtil, "Remove Smoke Explosion", "CrimRemoveSmokeExplosion", 6, { flat = true })
		MakeSection(CUtil, "INVISIBILITY", 7)
		MakeTog(CUtil, "Invisibility", "Invisibility", 8, { flat = true })
		MakeTog(CUtil, "Visible Warning", "InvisShowWarning", 9, {
			flat = true,
			requires = "Invisibility",
		})
		MakeSlider(CUtil, "Invis Walk Speed", "InvisWalkSpeed", 6, 28, 10, {
			suffix = "",
			step = 1,
			fmt = function(v) return string.format("%d", v) end,
		})
		MakeBind(CUtil, "Visibility Key", "InvisKey", 11, { requires = "Invisibility" })
		MakeHint(CUtil, "hint_invis", 12)
		MakeTog(CUtil, "Invis Resolver", "InvisResolver", 13, { flat = true })
		MakeHint(CUtil, "hint_invis_resolver", 14)
		MakeTog(CUtil, "Remote Elevator", "CrimRemoteElevator", 15, { flat = true })
		MakeButton(CUtil, nil, 16, function()
			if S._crimElevatorTeleport then
				S._crimElevatorTeleport()
			end
		end, "btn_crim_elevator_tp")
		MakeBind(CUtil, "Elevator Key", "CrimRemoteElevatorKey", 17, {
			requires = "CrimRemoteElevator",
		})
		MakeSlider(CUtil, "Elevator Max Distance", "CrimRemoteElevatorMaxDist", 50, 800, 18, {
			suffix = " st",
			step = 25,
			fmt = function(v) return string.format("%d st", v) end,
		})
		MakeHint(CUtil, "hint_crim_elevator", 19)
		MakeSection(CUtil, L("crim_sub_clientbuild"), 20)
		MakeButton(CUtil, nil, 21, function()
			if S._clientBridgeStart then
				S._clientBridgeStart()
			end
		end, "btn_crim_bridge")
		MakeButton(CUtil, nil, 22, function()
			if S._clientBridgeClear then
				S._clientBridgeClear()
			end
		end, "btn_crim_bridge_clear")
		MakeButton(CUtil, nil, 23, function()
			if S._clientDeleteStart then
				S._clientDeleteStart()
			end
		end, "btn_crim_delete")
		MakeButton(CUtil, nil, 24, function()
			if S._clientDeleteRestore then
				S._clientDeleteRestore()
			end
		end, "btn_crim_delete_restore")
		MakeHint(CUtil, "hint_crim_clientbuild", 25)
		MakeHint(CUtil, "hint_crim_util", 26)
	end

	local function refreshWorld()
		if WorldModule and WorldModule.OnSettingChanged then
			pcall(WorldModule.OnSettingChanged)
		end
	end
	local worldChange = { onChange = refreshWorld }

	local VCore = MakeCard(T1, "ESP", nil, 1)
	MakeTog(VCore, "Master ESP", "ESP", 1, { flat = true })
	local VFilter = MakeCard(T1, "FILTERS", "card_vfilter_desc", 2)
	MakeTog(VFilter, "Hide Teammates", "Team", 1, { flat = true })
	MakeTog(VFilter, "Render Only Visible", "ESPRenderOnlyVisible", 2, { flat = true })
	MakeTog(VFilter, "Lower Opacity When Visible", "ESPLowerOpacityVisible", 3, {
		flat = true,
		onChange = function(on)
			local reg = sliderRegistry.ESPLowerOpacityAmount
			if reg and reg.setEnabled then
				reg.setEnabled(on)
			end
		end,
	})
	MakeSlider(VFilter, "Visible Fade Amount", "ESPLowerOpacityAmount", 10, 90, 4, {
		suffix = "%",
		step = 5,
		fmt = function(v)
			return string.format("%d%%", v)
		end,
		onRowCreated = function(_, __, setEnabled)
			if setEnabled then
				setEnabled(S.ESPLowerOpacityVisible == true)
			end
		end,
	})
	MakeTog(VFilter, "Ignore Self in LOS", "LOSIgnoreSelf", 5, { flat = true })
	MakeHint(VFilter, "hint_vfilter", 6)

	local VDist = MakeCard(T1, "DISTANCE", nil, 3)
	MakeTog(VDist, "Show Distance", "DistView", 1, { flat = true })
	MakeTog(VDist, "Limit Render Distance", "ESPRenderLimit", 2, {
		flat = true,
		onChange = function(on)
			local reg = sliderRegistry.ESPRenderDist
			if reg and reg.setEnabled then
				reg.setEnabled(on)
			end
		end,
	})
	MakeSlider(VDist, "Render Distance", "ESPRenderDist", 50, 2000, 3, {
		suffix = " st",
		step = 25,
		fmt = function(v)
			return string.format("%d st", v)
		end,
		onRowCreated = function(_, __, setEnabled)
			if setEnabled then
				setEnabled(S.ESPRenderLimit == true)
			end
		end,
	})

	local function formatTargetInput(plr)
		if not plr then
			return ""
		end
		if S.ESPDisplayName and plr.DisplayName and plr.DisplayName ~= "" then
			return plr.DisplayName
		end
		return plr.Name
	end

	local function resolveTargetFromText(text)
		text = string.lower((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		if text == "" then
			return nil
		end
		local PlayersSvc = game:GetService("Players")
		local localPlr = PlayersSvc.LocalPlayer
		local exact, partial
		for _, plr in ipairs(PlayersSvc:GetPlayers()) do
			if plr ~= localPlr then
				local name = string.lower(plr.Name)
				local disp = string.lower(plr.DisplayName or "")
				if name == text or disp == text then
					exact = plr
					break
				end
				if not partial and (name:find(text, 1, true) or disp:find(text, 1, true)) then
					partial = plr
				end
			end
		end
		return exact or partial
	end

	local VTarget = MakeCard(T1, "TARGET", "card_vtarget_desc", 4)
	local targetPickerHost = C("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = VTarget,
	})

	local targetInputRow = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(17, 17, 21),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = targetPickerHost,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = targetInputRow })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = targetInputRow })

	local TargetInput = C("TextBox", {
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = L("esp_target_ph"),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		PlaceholderColor3 = Color3.fromRGB(95, 95, 105),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = targetInputRow,
	})

	local TargetSuggestFloat = C("Frame", {
		Name = "VG_TargetSuggest",
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 250,
		Parent = MenuRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = TargetSuggestFloat })
	C("UIStroke", { Color = Color3.fromRGB(48, 48, 58), Thickness = 1, Transparency = 0.35, Parent = TargetSuggestFloat })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
		Parent = TargetSuggestFloat,
	})
	C("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = TargetSuggestFloat })

	local targetSuggestEntries = {}
	local targetSuggestLock = false
	local targetSuggestPickConn = nil

	local function positionTargetSuggestFloat()
		if not TargetSuggestFloat.Visible then
			return
		end
		local menuPos = MenuRoot.AbsolutePosition
		local pos = TargetInput.AbsolutePosition
		local size = TargetInput.AbsoluteSize
		TargetSuggestFloat.Position = UDim2.new(0, pos.X - menuPos.X, 0, pos.Y + size.Y + 2 - menuPos.Y)
		TargetSuggestFloat.Size = UDim2.new(0, size.X, 0, 0)
	end

	local function refreshTargetInputFromSetting()
		local uid = tonumber(S.ESPTargetUserId) or 0
		if uid <= 0 then
			TargetInput.Text = ""
			return
		end
		for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
			if plr.UserId == uid then
				TargetInput.Text = formatTargetInput(plr)
				return
			end
		end
	end

	local function hideTargetSuggestions()
		TargetSuggestFloat.Visible = false
		table.clear(targetSuggestEntries)
		for _, ch in ipairs(TargetSuggestFloat:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
				ch:Destroy()
			end
		end
		if targetSuggestPickConn then
			targetSuggestPickConn:Disconnect()
			targetSuggestPickConn = nil
		end
	end

	local function pickSuggestion(plr)
		if not plr or targetSuggestLock then
			return
		end
		targetSuggestLock = true
		S.ESPTargetUserId = plr.UserId
		TargetInput.Text = formatTargetInput(plr)
		hideTargetSuggestions()
		TargetInput:ReleaseFocus()
		showNotify(L("notify_esp_target_set", formatTargetInput(plr)))
		task.delay(0.25, function()
			targetSuggestLock = false
		end)
	end

	local function setEspTarget(plr)
		pickSuggestion(plr)
	end

	local function clearEspTargetUi()
		S.ESPTargetUserId = 0
		TargetInput.Text = ""
		hideTargetSuggestions()
		showNotify(L("notify_esp_target_cleared"))
	end

	S.OnEspTargetCleared = function()
		TargetInput.Text = ""
		hideTargetSuggestions()
	end

	local function isMouseOverSuggestions()
		local mouse = UIS:GetMouseLocation()
		for _, entry in ipairs(targetSuggestEntries) do
			local btn = entry.btn
			if btn and btn.Parent then
				local ap = btn.AbsolutePosition
				local as = btn.AbsoluteSize
				if mouse.X >= ap.X and mouse.X <= ap.X + as.X and mouse.Y >= ap.Y and mouse.Y <= ap.Y + as.Y then
					return true
				end
			end
		end
		return false
	end

	local function enableSuggestClickCapture()
		if targetSuggestPickConn then
			return
		end
		targetSuggestPickConn = UIS.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not TargetSuggestFloat.Visible then
				return
			end
			local mouse = UIS:GetMouseLocation()
			for _, entry in ipairs(targetSuggestEntries) do
				local btn = entry.btn
				if btn and btn.Parent then
					local ap = btn.AbsolutePosition
					local as = btn.AbsoluteSize
					if mouse.X >= ap.X and mouse.X <= ap.X + as.X and mouse.Y >= ap.Y and mouse.Y <= ap.Y + as.Y then
						pickSuggestion(entry.plr)
						return
					end
				end
			end
		end)
	end

	local function bindSuggestionButton(btn, plr)
		local function onPick()
			pickSuggestion(plr)
		end
		btn.Active = true
		pcall(function()
			btn.Selectable = true
		end)
		btn.MouseButton1Down:Connect(onPick)
		btn.MouseButton1Click:Connect(onPick)
		pcall(function()
			if btn.Activated then
				btn.Activated:Connect(onPick)
			end
		end)
	end

	local function showTargetSuggestions(query)
		hideTargetSuggestions()
		query = string.lower((query or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		if query == "" then
			return
		end
		local PlayersSvc = game:GetService("Players")
		local localPlr = PlayersSvc.LocalPlayer
		local matches = {}
		for _, plr in ipairs(PlayersSvc:GetPlayers()) do
			if plr ~= localPlr then
				local name = string.lower(plr.Name)
				local disp = string.lower(plr.DisplayName or "")
				if name:find(query, 1, true) or disp:find(query, 1, true) then
					table.insert(matches, plr)
				end
			end
		end
		table.sort(matches, function(a, b) return a.Name < b.Name end)
		local shown = 0
		for _, plr in ipairs(matches) do
			shown += 1
			if shown > 6 then
				break
			end
			local label = plr.DisplayName ~= plr.Name and (plr.DisplayName .. "  ·  " .. plr.Name) or plr.Name
			local btn = C("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.fromRGB(22, 22, 28),
				Text = label,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(190, 190, 200),
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = shown,
				ZIndex = 251,
				Parent = TargetSuggestFloat,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
			btn.MouseEnter:Connect(function()
				btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
			end)
			bindSuggestionButton(btn, plr)
			table.insert(targetSuggestEntries, { btn = btn, plr = plr })
		end
		if shown > 0 then
			TargetSuggestFloat.Visible = true
			task.defer(positionTargetSuggestFloat)
			enableSuggestClickCapture()
		end
	end

	if T1:IsA("ScrollingFrame") then
		T1:GetPropertyChangedSignal("CanvasPosition"):Connect(positionTargetSuggestFloat)
	end
	Cam:GetPropertyChangedSignal("ViewportSize"):Connect(positionTargetSuggestFloat)

	TargetInput:GetPropertyChangedSignal("Text"):Connect(function()
		if tonumber(S.ESPTargetUserId) and S.ESPTargetUserId > 0 then
			local uid = S.ESPTargetUserId
			for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
				if plr.UserId == uid and TargetInput.Text == formatTargetInput(plr) then
					return
				end
			end
		end
		showTargetSuggestions(TargetInput.Text)
	end)

	TargetInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local plr = resolveTargetFromText(TargetInput.Text)
			if plr then
				setEspTarget(plr)
			end
			return
		end
		task.delay(0.22, function()
			if targetSuggestLock or TargetInput:IsFocused() then
				return
			end
			if isMouseOverSuggestions() then
				return
			end
			hideTargetSuggestions()
		end)
	end)

	MakeButton(VTarget, nil, 2, clearEspTargetUi, "esp_target_clear")
	MakeColorPicker(VTarget, "Target Color", "T", 3, { targetColor = true })
	MakeHint(VTarget, "hint_vtarget", 4)
	refreshTargetInputFromSetting()

	local VOver = MakeCard(T1, "OVERLAYS", nil, 5)
	MakeTog(VOver, "Bounding Boxes", "Box", 1, { flat = true })
	MakeChoice(VOver, "Box Type", "BoxType", {
		{ label = "Full", value = "Full" },
		{ label = "Corner", value = "Corner" },
	}, 2)
	MakeTog(VOver, "Player Names", "Name", 3, { flat = true })
	MakeTog(VOver, "Display Name", "ESPDisplayName", 4, {
		flat = true,
		requires = "Name",
		onChange = function()
			refreshTargetInputFromSetting()
		end,
	})
	MakeTog(VOver, "Health Bars", "Health", 5, { flat = true })
	MakeTog(VOver, "Health Text", "HealthText", 6, { flat = true })
	MakeTog(VOver, "Weapon ESP", "Weapon", 7, { flat = true })

	local VColors = MakeCard(T1, "ESP COLORS", "card_vcolors_desc", 6)
	MakeTog(VColors, "Team Colors", "RealTeamColor", 1, { flat = true })
	MakeTog(VColors, "Line of Sight", "LoS", 2, { flat = true })
	MakeHint(VColors, "hint_vcolors", 3)
	MakeColorPicker(VColors, "Visible Color", "V", 4, { espColor = true })
	MakeColorPicker(VColors, "Hidden Color", "O", 5, { espColor = true })
	MakeSlider(VColors, "Line Thickness", "Th", 0.5, 4, 6, {
		suffix = "px",
		step = 0.1,
		fmt = function(v)
			return string.format("%.1f px", v)
		end,
	})

	updateEspColorControls = function()
		local on = espCustomColorsEnabled()
		for _, reg in ipairs(colorRegistry) do
			if reg.espOnly then
				reg.setEnabled(on)
				if on then
					reg.refresh()
				end
			elseif reg.friendOnly then
				reg.setEnabled(S.FriendsESP == true)
				if S.FriendsESP then
					reg.refresh()
				end
			elseif reg.targetOnly then
				reg.setEnabled(S.ESP == true)
				if S.ESP then
					reg.refresh()
				end
			end
		end
	end
	updateEspColorControls()

	local VAdv = MakeCard(T1, "ADVANCED", "card_vadv_desc", 7)
	MakeTog(VAdv, "Render Bots", "RenderBots", 1, { flat = true })
	MakeTog(VAdv, "Skeleton", "Skel", 2, { flat = true })
	MakeTog(VAdv, "Tracers", "Trace", 3, { flat = true })
	MakeTog(VAdv, "Chams Fill", "Chams", 4, { flat = true })
	MakeTog(VAdv, "Chams Rainbow", "ChamsRainbow", 5, { flat = true })
	local offscreenChildRows = {}
	local syncOffscreenTrackerUi
	MakeTog(VAdv, "Offscreen Arrows", "OffscreenArrows", 6, {
		flat = true,
		onChange = function(on)
			if not on then
				S.OffscreenArrowHighVis = false
				setToggleVisual("OffscreenArrowHighVis", false)
			end
			if syncOffscreenTrackerUi then
				syncOffscreenTrackerUi()
			end
		end,
	})
	local function greyTogRow(row, title, on)
		row.Active = on
		title.TextColor3 = on and Color3.fromRGB(200, 200, 208) or Color3.fromRGB(90, 90, 100)
	end
	syncOffscreenTrackerUi = function()
		local on = S.OffscreenArrows == true
		for _, pair in ipairs(offscreenChildRows) do
			greyTogRow(pair.Row, pair.Title, on)
		end
		local reg = sliderRegistry.OffscreenArrowScale
		if reg and reg.setEnabled then
			reg.setEnabled(on)
		end
	end
	MakeTog(VAdv, "Enhanced Trackers", "OffscreenArrowHighVis", 7, {
		flat = true,
		requires = "OffscreenArrows",
		onRowCreated = function(row, title)
			table.insert(offscreenChildRows, { Row = row, Title = title })
		end,
		onChange = function(on)
			if on and not S.OffscreenArrows then
				S.OffscreenArrows = true
				setToggleVisual("OffscreenArrows", true)
			end
			syncOffscreenTrackerUi()
		end,
	})
	MakeSlider(VAdv, "Tracker Size", "OffscreenArrowScale", 0.8, 2.5, 8, {
		step = 0.05,
		fmt = function(v)
			return string.format("%.0f%%", v * 100)
		end,
		onRowCreated = function(_, __, setEnabled)
			if setEnabled then
				setEnabled(S.OffscreenArrows == true)
			end
		end,
	})
	MakeTog(VAdv, "Tracker Name Label", "OffscreenArrowShowName", 9, {
		flat = true,
		requires = "OffscreenArrows",
		onRowCreated = function(row, title)
			table.insert(offscreenChildRows, { Row = row, Title = title })
		end,
	})
	syncOffscreenTrackerUi()
	MakeHint(VAdv, "hint_vadv", 10)

	local VTrace = MakeCard(T1, "SHOT TRACERS", "card_vtrace_desc", 8)
	MakeTog(VTrace, "Bullet Tracers", "ShotTracers", 1, { flat = true })
	MakeTog(VTrace, "Kill Tracer (grubszy + glow)", "KillShotTracers", 2, { flat = true })
	MakeHint(VTrace, "hint_vtrace", 3)

	local FFriend = MakeCard(TFriend, "FRIENDS", "card_sfriend_desc", 1)
	MakeTog(FFriend, "Ctrl + Click Friend", "FriendClick", 1, { flat = true })
	MakeHint(FFriend, "hint_friend_click", 2)

	local FriendListHost = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = FFriend,
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
				Text = L("friends_empty"),
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
				showNotify(L("notify_friend_removed"))
			end)
		end
	end

	MakeButton(FFriend, nil, 4, function()
		if TF then
			TF.clearFriends(S)
		else
			S.FriendIds = {}
		end
		refreshFriendList()
		showNotify(L("notify_friends_cleared"))
	end, "btn_clear_list")
	refreshFriendList()
	if TF then
		TF.Init(S, ParentGUI, ACC, refreshFriendList, AntiBypassModule)
	end

	local FEsp = MakeCard(TFriend, "FRIENDS ESP", "card_friend_esp_desc", 2)
	MakeTog(FEsp, "Friends ESP", "FriendsESP", 1, {
		flat = true,
		onChange = function()
			if updateEspColorControls then
				updateEspColorControls()
			end
			UpdPreview()
		end,
	})
	MakeTog(FEsp, "Skip Highlight When Visible", "FriendsESPSkipVisible", 2, {
		flat = true,
		requires = "FriendsESP",
	})
	MakeColorPicker(FEsp, "Friend Color", "F", 3, { friendColor = true })
	MakeHint(FEsp, "hint_friend_esp", 4)

	local FOver = MakeCard(TFriend, "FRIEND OVERLAYS", "card_friend_over_desc", 3)
	MakeTog(FOver, "Bounding Boxes", "FriendBox", 1, { flat = true, requires = "FriendsESP" })
	MakeTog(FOver, "Health Bars", "FriendHealth", 2, { flat = true, requires = "FriendsESP" })
	MakeTog(FOver, "Health Text", "FriendHealthText", 3, { flat = true, requires = "FriendsESP" })
	MakeTog(FOver, "Weapon ESP", "FriendWeapon", 4, { flat = true, requires = "FriendsESP" })
	MakeTog(FOver, "Show Distance", "FriendDistView", 5, { flat = true, requires = "FriendsESP" })
	MakeHint(FOver, "hint_friend_over", 6)

	local LAim = MakeCard(T3, "AIMBOT", "card_laim_desc", 1)
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

	local LAimBind = MakeCard(T3, "KEYBINDS", "card_laimbind_desc", 2)
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
	MakeHint(LTrig, "hint_ltrig", 7)

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
	MakeSlider(LTarget, "Max Distance", "MaxDist", 50, 1500, 6, { suffix = "m", step = 25 })

	local LFov = MakeCard(T3, "FOV & SMOOTH", "card_lfov_desc", 5)
	MakeTog(LFov, "Show FOV Circle", "ShowFOV", 1, { flat = true })
	MakeSlider(LFov, "FOV Size", "FOV", 20, 300, 2, { suffix = "px", step = 5 })
	MakeSlider(LFov, "Smoothing", "Smooth", 0.05, 0.95, 3, {
		suffix = "",
		step = 0.05,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
	})
	MakeTog(LFov, "Aim Curve + Jitter", "AimCurve", 4, { flat = true })

	local RMaster = MakeCard(TR, "MASTER", "card_rmaster_desc", 1)
	MakeTog(RMaster, "Master Rage", "MasterRage", 1, { flat = true })

	local RAA = MakeCard(TR, "ANTI-AIM", "card_raa_desc", 2)
	MakeTog(RAA, "Anti-Aim", "AntiAim", 1, { flat = true })
	MakeTog(RAA, "Spin", "AASpin", 2, { flat = true })
	MakeSlider(RAA, "Spin Speed", "AASpinSpeed", 1, 20, 3, { suffix = "", step = 1 })
	MakeSlider(RAA, "Yaw Offset", "AAYaw", -180, 180, 4, { suffix = "°", step = 5 })
	MakeSlider(RAA, "Pitch Offset", "AAPitch", -89, 89, 5, { suffix = "°", step = 5 })
	MakeTog(RAA, "Yaw Jitter", "AAJitter", 6, { flat = true })
	MakeSlider(RAA, "Jitter Range", "AAJitterRange", 5, 180, 7, { suffix = "°", step = 5 })

	local RBot = MakeCard(TR, "RAGEBOT", "card_rbot_desc", 3)
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
	MakeHint(RBot, "hint_rbot", 10)

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

	local WQuick = MakeCard(TWorld, "QUICK", "card_wquick_desc", 1)
	MakeTog(WQuick, "FullBright", "FullBright", 1, worldChange)
	MakeTog(WQuick, "No Fog", "NoFog", 2, worldChange)
	MakeTog(WQuick, "Lock Time", "WorldTimeLock", 3, worldChange)
	MakeSlider(WQuick, "Clock Time", "WorldTime", 0, 24, 4, {
		suffix = "h",
		step = 0.25,
		fmt = function(v) return string.format("%.1f", v) end,
		onChange = refreshWorld,
	})
	MakeHint(WQuick, "hint_wquick", 5)

	local WLight = MakeCard(TWorld, "LIGHTING", "card_wlight_desc", 2)
	MakeTog(WLight, "Custom Lighting", "WorldLight", 1, worldChange)
	MakeSlider(WLight, "Brightness", "WorldBrightness", 0, 10, 2, { suffix = "", step = 0.1, onChange = refreshWorld })
	MakeSlider(WLight, "Exposure", "WorldExposure", -3, 3, 3, { suffix = "", step = 0.05, onChange = refreshWorld })
	MakeTog(WLight, "Global Shadows", "WorldShadows", 4, worldChange)
	MakeColorPicker(WLight, "Ambient", "WorldAmbient", 5, worldChange)
	MakeColorPicker(WLight, "Outdoor Ambient", "WorldOutdoorAmbient", 6, worldChange)

	local WFog = MakeCard(TWorld, "FOG & ATMOSPHERE", "card_wfog_desc", 3)
	MakeTog(WFog, "Custom Fog", "WorldFog", 1, worldChange)
	MakeColorPicker(WFog, "Fog Color", "WorldFogColor", 2, worldChange)
	MakeSlider(WFog, "Fog Start", "WorldFogStart", 0, 1000, 3, { suffix = "m", step = 10, onChange = refreshWorld })
	MakeSlider(WFog, "Fog End", "WorldFogEnd", 100, 100000, 4, { suffix = "m", step = 500, onChange = refreshWorld })
	MakeColorPicker(WFog, "Atmosphere Color", "WorldAtmoColor", 5, worldChange)
	MakeSlider(WFog, "Atmo Density", "WorldAtmoDensity", 0, 1, 6, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
		onChange = refreshWorld,
	})
	MakeSlider(WFog, "Atmo Haze", "WorldAtmoHaze", 0, 10, 7, { suffix = "", step = 0.1, onChange = refreshWorld })
	MakeSlider(WFog, "Atmo Glare", "WorldAtmoGlare", 0, 10, 8, { suffix = "", step = 0.1, onChange = refreshWorld })
	MakeSlider(WFog, "Atmo Offset", "WorldAtmoOffset", 0, 1, 9, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
		onChange = refreshWorld,
	})

	local WGrade = MakeCard(TWorld, "COLOR GRADING", "card_wgrade_desc", 4)
	MakeTog(WGrade, "Custom Grading", "WorldGrade", 1, worldChange)
	MakeSlider(WGrade, "CC Brightness", "WorldCCBrightness", -1, 1, 2, { suffix = "", step = 0.01, onChange = refreshWorld })
	MakeSlider(WGrade, "CC Contrast", "WorldCCContrast", -1, 1, 3, { suffix = "", step = 0.01, onChange = refreshWorld })
	MakeSlider(WGrade, "CC Saturation", "WorldCCSaturation", -1, 1, 4, { suffix = "", step = 0.01, onChange = refreshWorld })
	MakeColorPicker(WGrade, "CC Tint", "WorldCCTint", 5, worldChange)
	MakeColorPicker(WGrade, "ColorShift Top", "WorldColorShiftTop", 6, worldChange)
	MakeColorPicker(WGrade, "ColorShift Bottom", "WorldColorShiftBottom", 7, worldChange)
	MakeTog(WGrade, "Quick Tint (HSV)", "WorldCustomLight", 8, worldChange)
	MakeSlider(WGrade, "Tint Hue", "WorldColorHue", 0, 1, 9, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 360) .. "°" end,
		onChange = refreshWorld,
	})
	MakeSlider(WGrade, "Tint Saturation", "WorldColorSat", 0, 1, 10, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
		onChange = refreshWorld,
	})
	MakeHint(WGrade, "hint_wgrade", 11)

	local WPost = MakeCard(TWorld, "POST PROCESSING", "card_wpost_desc", 5)
	MakeTog(WPost, "Custom Post FX", "WorldPost", 1, worldChange)
	MakeSlider(WPost, "Bloom Intensity", "WorldBloom", 0, 3, 2, { suffix = "", step = 0.05, onChange = refreshWorld })
	MakeSlider(WPost, "Sun Rays", "WorldSunRays", 0, 1, 3, {
		suffix = "",
		step = 0.01,
		fmt = function(v) return math.floor(v * 100) .. "%" end,
		onChange = refreshWorld,
	})

	local WUi = MakeCard(TWorld, "MENU", nil, 6)
	MakeTog(WUi, "Menu Blur", "MenuBlur", 1, worldChange)
	MakeSlider(WUi, "Blur Strength", "MenuBlurSize", 4, 48, 2, { suffix = "px", step = 1, onChange = refreshWorld })

	local APlayback = MakeCard(TAnim, "PLAYBACK", "card_aplayback_desc", 1)
	MakeSlider(APlayback, "Speed", "AnimSpeed", 0.25, 3, 1, {
		suffix = "x",
		step = 0.05,
		fmt = function(v)
			return string.format("%.2fx", v)
		end,
	})
	MakeSlider(APlayback, "Weight", "AnimWeight", 0.1, 1, 2, {
		suffix = "",
		step = 0.05,
		fmt = function(v)
			return string.format("%.0f%%", v * 100)
		end,
	})
	MakeTog(APlayback, "Loop Emotes", "AnimLoop", 3, { flat = true })
	MakeTog(APlayback, "Prefer /e Chat First", "AnimPreferChat", 4, { flat = true })
	MakeHint(APlayback, "hint_aplayback", 5, function()
		return AnimationsModule and AnimationsModule.GetRigLabel() or "?"
	end)

	local function MakeAnimRow(page, entry, order, onPlay)
		local meta = AnimationsModule and AnimationsModule.GetEntryMeta(entry) or { icon = "?", rig = "?", visible = "?" }
		local visColor = meta.visible == "Others" and Color3.fromRGB(100, 220, 150) or Color3.fromRGB(150, 150, 165)

		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
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
			Size = UDim2.new(0, 18, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			BackgroundTransparency = 1,
			Text = meta.icon,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 6,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -130, 1, 0),
			Position = UDim2.new(0, 30, 0, 0),
			BackgroundTransparency = 1,
			Text = entry.label,
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(220, 220, 228),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 52, 0, 12),
			Position = UDim2.new(1, -118, 0, 7),
			BackgroundTransparency = 1,
			Text = meta.rig,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(110, 110, 125),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 52, 0, 12),
			Position = UDim2.new(1, -118, 0, 21),
			BackgroundTransparency = 1,
			Text = meta.visible,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = visColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = Row,
		})

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(22, 22, 28) })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(17, 17, 21) })
		end)
		Row.MouseButton1Click:Connect(onPlay)
	end

	local AMove = MakeCard(TAnim, "MOVEMENT PACK", "card_amove_desc", 2)
	if AnimationsModule and AnimationsModule.MOVEMENT then
		local moveOrder = 1
		for _, pack in ipairs(AnimationsModule.MOVEMENT) do
			local p = pack
			MakeAnimRow(AMove, {
				label = p.label,
				icon = p.icon or "↺",
				rig = "both",
				visibleToOthers = p.visibleToOthers ~= false,
			}, moveOrder, function()
				if not AnimationsModule then
					return
				end
				local ok, err = AnimationsModule.ApplyMovement(p)
				if ok then
					showNotify(L("notify_movement", p.label))
					setFooterStatus("Anim · " .. p.label)
				else
					showNotify(err or L("notify_movement_err"))
				end
			end)
			moveOrder += 1
		end
	end

	local APlay = MakeCard(TAnim, "EMOTES", "card_aplay_desc", 3)
	MakeButton(APlay, "Stop Animation", 1, function()
		if AnimationsModule then
			AnimationsModule.Stop()
			showNotify(L("notify_anim_stopped"))
			setFooterStatus("Anim · stopped")
		end
	end)
	local animOrder = 2
	if AnimationsModule and AnimationsModule.LIST then
		for _, entry in ipairs(AnimationsModule.LIST) do
			local e = entry
			MakeAnimRow(APlay, e, animOrder, function()
				if not AnimationsModule then
					return
				end
				local ok, err = AnimationsModule.Play(e)
				if ok then
					showNotify(L("notify_anim", e.label))
					setFooterStatus("Anim · " .. e.label)
				else
					showNotify(err or L("notify_anim_err"))
				end
			end)
			animOrder += 1
		end
	end
	MakeHint(APlay, "hint_aplay", animOrder)

	local MMove = MakeCard(TM, "MOVEMENT", "card_mmove_desc", 1)
	MakeTog(MMove, "Bunny Hop", "BHop", 1, { flat = true })
	MakeTog(MMove, "Auto Strafe", "AutoStrafe", 2, { flat = true })
	MakeTog(MMove, "Walk Speed", "Speed", 3, { flat = true })
	MakeSlider(MMove, "Speed Value", "SpeedValue", 16, 200, 4, {
		suffix = " st/s",
		step = 1,
		fmt = function(v) return string.format("%d st/s", v) end,
	})
	MakeTog(MMove, "Jump Power", "JumpPower", 5, { flat = true })
	MakeSlider(MMove, "Jump Value", "JumpPowerValue", 10, 250, 6, {
		suffix = "",
		step = 5,
		fmt = function(v) return string.format("%d", v) end,
	})
	MakeTog(MMove, "Fly", "Fly", 7, { flat = true })
	MakeSlider(MMove, "Fly Speed", "FlySpeed", 10, 200, 8, {
		suffix = "",
		step = 5,
		fmt = function(v) return string.format("%d", v) end,
	})
	MakeTog(MMove, "Noclip", "Noclip", 9, { flat = true })
	MakeTog(MMove, "Ctrl + Click TP", "ClickTP", 10, { flat = true })
	MakeSlider(MMove, "Click TP Step", "ClickTPStep", 3, 20, 11, {
		suffix = " st",
		step = 1,
		fmt = function(v) return string.format("%d st", v) end,
		requires = "ClickTP",
	})
	MakeSlider(MMove, "Click TP Delay", "ClickTPDelay", 0.015, 0.1, 12, {
		suffix = "s",
		step = 0.005,
		fmt = function(v) return string.format("%.3fs", v) end,
		requires = "ClickTP",
	})
	MakeSlider(MMove, "Click TP Retries", "ClickTPRetries", 1, 12, 13, {
		suffix = "",
		step = 1,
		fmt = function(v) return string.format("%d", v) end,
		requires = "ClickTP",
	})
	MakeHint(MMove, "hint_clicktp", 14)
	MakeTog(MMove, "Spider", "Spider", 15, { flat = true })
	MakeTog(MMove, "Spider Stealth", "SpiderStealth", 16, {
		flat = true,
		requires = "Spider",
	})
	MakeSlider(MMove, "Spider Climb Speed", "SpiderSpeed", 8, 24, 17, {
		suffix = "",
		step = 1,
		fmt = function(v) return string.format("%d", v) end,
	})
	MakeSlider(MMove, "Spider Burst Height", "SpiderBurstHeight", 3, 14, 18, {
		suffix = " st",
		step = 1,
		fmt = function(v) return string.format("%d st", v) end,
	})
	MakeSlider(MMove, "Spider Cooldown", "SpiderCooldown", 0.6, 4, 19, {
		suffix = "s",
		step = 0.1,
		fmt = function(v) return string.format("%.1fs", v) end,
	})
	MakeHint(MMove, "hint_spider", 20)
	MakeTog(MMove, "Infinite Stamina", "InfStamina", 21, { flat = true })
	MakeTog(MMove, "No Fall Damage", "NoFallDmg", 22, { flat = true })

	local MHit = MakeCard(TM, "HITBOX EXPANDER", "card_mhit_desc", 2)
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
	MakeHint(MHit, "hint_mhit1", 7)
	MakeHint(MHit, "hint_mhit2", 8)

	local MSec = MakeCard(TM, "SECURITY", "card_msec_desc", 3)
	MakeTog(MSec, "Anti-Cheat Bypass", "AntiBypass", 1, { flat = true })
	MakeHint(MSec, "hint_msec", 2)

	local MFX = MakeCard(TM, "LOCAL FX", "card_mfx_desc", 4)
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
				showNotify(err or L("notify_no_target"))
			else
				showNotify(L("notify_kill_fx"))
			end
		end
	end)
	MakeButton(MFX, "Test Hit FX", 7, function()
		if S.TestHitEffect then
			local ok, err = S.TestHitEffect()
			if ok == false then
				showNotify(err or L("notify_no_target"))
			else
				showNotify(L("notify_hit_fx"))
			end
		end
	end)
	MakeHint(MFX, "hint_mfx", 8)

	local SInterface = MakeCard(T2, nil, nil, 1, { titleKey = "set_interface" })
	MakeChoice(SInterface, nil, "MenuLang", {
		{ labelKey = "lang_pl", value = "pl" },
		{ labelKey = "lang_en", value = "en" },
	}, 1, {
		labelKey = "set_menu_lang",
		onChange = function(val)
			S.MenuLang = val
			if I18n then
				I18n.setLang(val)
				I18n.refreshAll()
			end
			if UIMusicModule and UIMusicModule.refreshLang then
				UIMusicModule.refreshLang()
			end
			if refreshConfigMenusLang then
				refreshConfigMenusLang()
			end
			refreshFriendList()
			if StudioSubtitle then
				StudioSubtitle.Text = I18n and I18n.t("subtitle_studio") or "ESP STUDIO"
			end
			showNotify(I18n and I18n.t("lang_changed") or "Language updated.", { type = "info" })
		end,
	})
	MakeChoice(SInterface, nil, "NotifyStyle", {
		{ labelKey = "notify_pro", value = "pro" },
		{ labelKey = "notify_compact", value = "compact" },
	}, 2, {
		labelKey = "set_notify_style",
		onChange = function()
			showNotify(I18n and I18n.t("notify_style_changed") or "Notification style updated.", { type = "success" })
		end,
	})

	local SHud = MakeCard(T2, "HUD", nil, 2)
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
			showNotify(L("notify_test_hitmarker"))
		else
			showNotify(L("notify_features_missing"))
		end
	end)
	MakeHint(SHud, "hint_shud1", 12)
	MakeTog(SHud, "Damage Log", "DamageLog", 13, { flat = true })
	MakeTog(SHud, "3D Damage Numbers", "DamageNumbers", 14, { flat = true })
	MakeTog(SHud, "Watermark", "Watermark", 15, { flat = true })
	MakeTog(SHud, "Keybind List", "KeybindList", 16, { flat = true })
	MakeTog(SHud, "Session Stats", "SessionStats", 17, { flat = true })
	MakeTog(SHud, "Kill Feed", "KillFeed", 18, { flat = true })
	MakeHint(SHud, "hint_shud2", 19)

	local SettingsAutoloadLbl
	local SAuto = MakeCard(T2, "AUTOLOAD", "card_sauto_desc", 3)

	SettingsAutoloadLbl = C("TextLabel", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = L("cfg_autoload_settings_none"),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = SAuto,
	})
	MakeButton(SAuto, nil, 2, function()
		if not ConfigModule then
			showNotify(L("notify_no_config"))
			return
		end
		local ok, msg = ConfigModule.Autoload(S)
		if ok then
			refreshAllControls()
			showNotify(L("notify_autoload", tostring(msg)))
			setFooterStatus("Autoload · " .. tostring(msg))
			refreshConfigList()
			if SettingsAutoloadLbl then
				SettingsAutoloadLbl.Text = L("cfg_autoload_fmt", tostring(msg))
			end
		else
			showNotify(L("notify_autoload_fail"))
		end
	end, "btn_autoload_now")

	local SSession = MakeCard(T2, "SESSION", "card_ssession_desc", 6)
	MakeButton(SSession, "Unload Vanguard", 1, function()
		if S.Unload then
			showNotify(L("notify_unloaded"))
			task.delay(0.15, function()
				pcall(S.Unload)
			end)
		else
			showNotify(L("notify_unload_unavail"))
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
				showNotify(L("notify_transfer_on"))
			else
				showNotify(L("notify_transfer_off"))
			end
		end,
	})
	MakeTog(SSession, "Muzyka globalna", "MusicGlobalPersist", 3, {
		flat = true,
		onChange = function(enabled)
			if ConfigModule and ConfigModule.SaveGlobals then
				pcall(ConfigModule.SaveGlobals, S)
			end
			if enabled then
				showNotify(L("notify_music_global_on"))
				if MusicModule and MusicModule.SaveTransferState then
					task.defer(MusicModule.SaveTransferState)
				end
			else
				showNotify(L("notify_music_global_off"))
				if MusicModule and MusicModule.ClearGlobalPersist then
					pcall(MusicModule.ClearGlobalPersist)
				end
			end
		end,
	})
	MakeHint(SSession, "hint_music_global", 4)
	MakeHint(SSession, "hint_ssession1", 5)
	MakeTog(SSession, "log_to_file", "LogToFile", 8, {
		flat = true,
		onChange = function(on)
			local logMod = _G.__VG_LOGGER
			if logMod and logMod.setEnabled then
				logMod.setEnabled(on)
			end
		end,
	})
	MakeHint(SSession, "log_file_hint", 9)
	MakeButton(SSession, "log_clear", 10, function()
		local logMod = _G.__VG_LOGGER
		if logMod and logMod.clear then
			local ok = logMod.clear()
			if ok then
				showNotify(L("log_cleared"))
				if logMod.info then
					logMod.info("Log cleared by user")
				end
			else
				showNotify(L("log_clear_fail"))
			end
		else
			showNotify(L("log_clear_fail"))
		end
	end)
	MakeButton(SSession, "Rejoin Game", 6, function()
		showNotify(L("notify_rejoin"))
		if S.RejoinGame then
			local ok, err = S.RejoinGame()
			if not ok then
				showNotify(err or L("notify_rejoin_err"))
			end
		else
			showNotify(L("notify_rejoin_unavail"))
		end
	end)
	MakeButton(SSession, "Server Hop", 7, function()
		showNotify(L("notify_searching_server"))
		if S.ServerHop then
			local ok, err = S.ServerHop()
			if not ok then
				showNotify(err or L("notify_hop_err"))
			end
		else
			showNotify(L("notify_hop_unavail"))
		end
	end)
	MakeHint(SSession, "hint_ssession2", 6)

	refreshConfigList = UIConfigMenus.build({
		T4 = T4,
		TMenu = TMenu,
		C = C,
		ACC = ACC,
		S = S,
		ParentGUI = ParentGUI,
		ConfigModule = ConfigModule,
		MenusModule = MenusModule,
		I18n = I18n,
		L = L,
		MakeSection = MakeSection,
		MakeButton = MakeButton,
		MakeHint = MakeHint,
		MakeCard = MakeCard,
		showNotify = showNotify,
		setFooterStatus = setFooterStatus,
		refreshAllControls = refreshAllControls,
		SettingsAutoloadLbl = SettingsAutoloadLbl,
		TweenPlay = TweenPlay,
	}).refreshConfigList
	refreshConfigMenusLang = UIConfigMenus.refreshLang
	end
	buildTabPages()

	if AntiBypassModule and AntiBypassModule.concealGui then
		AntiBypassModule.concealGui(ParentGUI)
	end
	if AntiBypassModule and AntiBypassModule.setUiBuilding then
		AntiBypassModule.setUiBuilding(false)
	end

	ApplyLayout(true, false)

	local function setupMenuInput()
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
			-- Once: unlock for UI. Avoid SetMenuIsOpen spam (cursor/input desync).
			pcall(function()
				GuiService:SetMenuIsOpen(true)
			end)
			setModalUnlock(true)
			softCursor.Visible = true
			forceMenuCursor()
			-- RightShift toggles Roblox Shift Lock — keep it disabled while menu opens
			suppressShiftLockUntilReleased(false)

			if mouseUnlockConn then
				mouseUnlockConn:Disconnect()
				mouseUnlockConn = nil
			end
			if mouseUnlockHB then
				mouseUnlockHB:Disconnect()
				mouseUnlockHB = nil
			end
			pcall(function()
				RS:UnbindFromRenderStep("VG_MenuMouse")
			end)
			-- Later than Last — camera scripts often bind at Last
			RS:BindToRenderStep(
				"VG_MenuMouse",
				Enum.RenderPriority.Last.Value + 1,
				perfWrap("UI.MenuMouseRS", function()
					if not menuOpen then
						return
					end
					forceMenuCursor()
				end)
			)
			mouseUnlockConn = {
				Disconnect = function()
					pcall(function()
						RS:UnbindFromRenderStep("VG_MenuMouse")
					end)
				end,
			}

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

			if UIMusicModule and UIMusicModule.onMenuOpen then
				UIMusicModule.onMenuOpen()
			end
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
			pcall(function()
				RS:UnbindFromRenderStep("VG_MenuMouse")
			end)

			restoreMouseState()
			suppressShiftLockUntilReleased(true)

			local restoreFrames = 0
			if mouseRestoreConn then
				mouseRestoreConn:Disconnect()
			end
			local framesTarget = 8
			mouseRestoreConn = RS.RenderStepped:Connect(perfWrap("UI.MenuMouseRestore", function()
				if menuOpen then
					mouseRestoreConn:Disconnect()
					mouseRestoreConn = nil
					return
				end
				-- Keep unlocked while RightShift may still be held (Shift Lock bind)
				UIS.MouseBehavior = Enum.MouseBehavior.Default
				UIS.MouseIconEnabled = true
				pcall(function()
					game:GetService("Players").LocalPlayer.DevEnableMouseLock = false
				end)
				restoreFrames = restoreFrames + 1
				if restoreFrames >= framesTarget then
					mouseRestoreConn:Disconnect()
					mouseRestoreConn = nil
				end
			end))

			task.defer(restoreMouseState)
			task.delay(0.05, function()
				if not menuOpen then
					restoreMouseState()
				end
			end)
			-- Safety: free cursor if still locked after close (Shift Lock from RightShift)
			task.delay(0.25, function()
				if menuOpen then
					return
				end
				if isLockedMouseBehavior(UIS.MouseBehavior) then
					applyFreeCursor()
					pcall(function()
						game:GetService("Players").LocalPlayer.DevEnableMouseLock = false
					end)
				end
				pcall(function()
					GuiService:SetMenuIsOpen(false)
				end)
				setModalUnlock(false)
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
		local loaderTweens = {}
		local function uiLog(msg)
			pcall(function()
				if typeof(_G.__VG_LOG_FILE) == "function" then
					_G.__VG_LOG_FILE("INFO", "[VG:ui] " .. tostring(msg))
				end
			end)
		end
		local function LTween(obj, info, props)
			local tw = TweenPlay(obj, info, props)
			if tw then
				table.insert(loaderTweens, tw)
			end
			return tw
		end
		local function cancelLoaderTweens()
			for _, tw in ipairs(loaderTweens) do
				pcall(function()
					tw:Cancel()
				end)
			end
			table.clear(loaderTweens)
		end

		uiLog("loader start")
		task.wait()
		if AntiBypassModule then
			pcall(AntiBypassModule.concealGui, ParentGUI)
		end
		Loader.Visible = true
		uiLog("loader visible")

		Fill.Size = UDim2.new(0.72, 0, 1, 0)
		LoaderPct.Text = "72%"
		LoaderStatus.Text = "Modules loaded"

		LoaderTop.Position = UDim2.new(0, 0, 0, -52)
		LoaderGame.BackgroundTransparency = 1
		LoaderGame.Position = UDim2.new(0.5, 0, 0.58, 0)

		LTween(LoaderTop, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		})
		LTween(LoaderGame, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.15,
			Position = UDim2.new(0.5, 0, 0.54, 0),
		})

		task.wait(0.28)
		uiLog("before game info")
		local isCrim = game.GameId == 1494262959
		if isCrim then
			LoaderGameName.Text = game.Name ~= "" and game.Name or "Criminality"
			LoaderSupportBadge.Text = "CRIM"
			LoaderSupportNote.Text = "Criminality — thumbnail skipped"
			LoaderGameIcon.Image = ""
			uiLog("skipped refreshLoaderGameInfo (Criminality)")
		else
			pcall(refreshLoaderGameInfo)
			uiLog("after game info")
		end

		LoaderStatus.Text = "Game info"
		LTween(Fill, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.78, 0, 1, 0),
		})
		LoaderPct.Text = "78%"
		uiLog("78%")
		task.wait(0.2)

		local steps = {
			{ text = "Initializing ESP", pct = 0.88, wait = 0.2 },
			{ text = "Preparing interface", pct = 0.96, wait = 0.2 },
			{ text = "Ready", pct = 1, wait = 0.2 },
		}

		for _, step in ipairs(steps) do
			LoaderStatus.Text = step.text
			LoaderPct.Text = math.floor(step.pct * 100) .. "%"
			uiLog("step " .. step.text)
			LTween(Fill, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(step.pct, 0, 1, 0),
			})
			task.wait(step.wait)
		end

		uiLog("after Ready — teardown loader")
		-- CRITICAL: cancel tweens BEFORE Destroy. Destroying while TweenService
		-- still updates instances = native AV (c0000005 read @ null+0x28) on some clients.
		cancelLoaderTweens()
		pcall(function()
			Fill.Size = UDim2.new(1, 0, 1, 0)
			Loader.BackgroundTransparency = 1
			LoaderTop.Position = UDim2.new(0, 0, 0, -56)
			LoaderGame.BackgroundTransparency = 1
			Loader.Visible = false
		end)
		uiLog("loader hidden")
		task.wait()
		pcall(function()
			if Loader and Loader.Parent then
				Loader:Destroy()
			end
		end)
		uiLog("loader destroyed")

		if ConfigModule then
			refreshConfigList()
			local autoload = ConfigModule.GetAutoload()
			if autoload ~= "" and not isCrim then
				uiLog("autoload " .. tostring(autoload))
				local ok = ConfigModule.Autoload(S)
				if ok then
					refreshAllControls()
					setFooterStatus("Autoload · " .. autoload)
				end
			elseif autoload ~= "" and isCrim then
				uiLog("defer autoload on Criminality: " .. tostring(autoload))
				task.delay(2.5, function()
					if S.Unloaded then
						return
					end
					uiLog("autoload (delayed) " .. tostring(autoload))
					local ok = ConfigModule.Autoload(S)
					if ok then
						pcall(refreshAllControls)
						pcall(setFooterStatus, "Autoload · " .. autoload)
					end
				end)
			end
		end

		S._vgUiReady = true
		S._vgUiReadyAt = os.clock()
		uiLog("loader complete · uiReady=true")
		if typeof(S._onVgUiReady) == "function" then
			pcall(S._onVgUiReady)
		end

		menuOpen = false
		MenuRoot.Visible = true
		MenuRoot.GroupTransparency = 1
		MenuScale.Scale = 0.985
		uiLog("opening menu")
		if isCrim then
			-- Keep menuOpen=false until SetMenuOpen — otherwise SetMenuOpen no-ops and mouse never unlocks
			pcall(function()
				MenuRoot.GroupTransparency = 0
				MenuScale.Scale = 1
			end)
			uiLog("menu soft-visible (defer unlock)")
			task.delay(0.4, function()
				if S.Unloaded then
					return
				end
				pcall(SetMenuOpen, true)
				uiLog("menu SetMenuOpen done")
			end)
		else
			SetMenuOpen(true)
			uiLog("menu open done")
		end
	end)

	end
	setupMenuInput()

	Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		refreshLayout()
		ApplyLayout(previewVisible, false, true)
	end)
	end
	buildControlsAndTabs()
end

return UI
