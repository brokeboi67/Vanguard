-- Plik: workspace/Vanguard/Features.lua

local Features = {}

function Features.Init(S, _ParentGUI, AntiBypassModule)
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")
	local Debris = game:GetService("Debris")

	local LP = Players.LocalPlayer
	local Cam = workspace.CurrentCamera
	local ACC = S.V

	local CG
	if AntiBypassModule and AntiBypassModule.getGuiRoot then
		CG = AntiBypassModule.getGuiRoot()
	end
	if not CG then
		CG = LP:WaitForChild("PlayerGui")
	end
	pcall(function() CG.VanguardHUD:Destroy() end)

	local hudName = (AntiBypassModule and AntiBypassModule.randomName and AntiBypassModule.randomName())
		or ("Ui" .. string.sub(game:GetService("HttpService"):GenerateGUID(false), 1, 10))
	local HudGui = Instance.new("ScreenGui")
	HudGui.Name = hudName
	HudGui.IgnoreGuiInset = true
	HudGui.ResetOnSpawn = false
	HudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	HudGui.DisplayOrder = 7
	if AntiBypassModule then
		AntiBypassModule.concealGui(HudGui)
	end
	if not HudGui.Parent then
		HudGui.Parent = CG
	end

	local Z = {
		cross = 10,
		hit = 15,
		wm = 12,
		kb = 12,
		stats = 12,
		kf = 13,
		spec = 20,
		specRow = 21,
		dmg = 20,
		dmgRow = 21,
		target = 22,
		targetRow = 23,
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

	local CrossRoot = tagZ(C("Frame", {
		Name = "CrosshairRoot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 40, 0, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = HudGui,
	}), Z.cross)

	local function makeCrossLine(name, size, pos, rot)
		local ln = tagZ(C("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = size,
			Rotation = rot or 0,
			BackgroundColor3 = ACC,
			BorderSizePixel = 0,
			Visible = false,
			Parent = CrossRoot,
		}), Z.cross + 1)
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ln })
		return ln
	end

	local CrossDot = makeCrossLine("CrossDot", UDim2.new(0, 5, 0, 5), UDim2.new(0.5, 0, 0.5, 0), 0)
	local CrossTop = makeCrossLine("CrossTop", UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 0.5, -7), 0)
	local CrossBottom = makeCrossLine("CrossBottom", UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 0.5, 7), 0)
	local CrossLeft = makeCrossLine("CrossLeft", UDim2.new(0, 8, 0, 2), UDim2.new(0.5, -7, 0.5, 0), 0)
	local CrossRight = makeCrossLine("CrossRight", UDim2.new(0, 8, 0, 2), UDim2.new(0.5, 7, 0.5, 0), 0)
	local CrossX1 = makeCrossLine("CrossX1", UDim2.new(0, 2, 0, 12), UDim2.new(0.5, 0, 0.5, 0), 45)
	local CrossX2 = makeCrossLine("CrossX2", UDim2.new(0, 2, 0, 12), UDim2.new(0.5, 0, 0.5, 0), -45)

	local CrossRing = tagZ(C("Frame", {
		Name = "CrossRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = CrossRoot,
	}), Z.cross + 1)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = CrossRing })
	C("UIStroke", {
		Name = "RingStroke",
		Color = ACC,
		Thickness = 1.5,
		Parent = CrossRing,
	})

	local crossParts = {
		CrossDot,
		CrossTop,
		CrossBottom,
		CrossLeft,
		CrossRight,
		CrossX1,
		CrossX2,
	}

	local function getCrossColor()
		local mode = S.CrosshairColorMode or "Accent"
		if mode == "White" then
			return Color3.fromRGB(255, 255, 255)
		end
		if mode == "Red" then
			return Color3.fromRGB(255, 85, 85)
		end
		if mode == "Green" then
			return Color3.fromRGB(80, 255, 150)
		end
		if mode == "Custom" then
			return S.CrosshairColor or ACC
		end
		return ACC
	end

	local function updCrosshair()
		if not S.Crosshair or S.MenuOpen then
			CrossRoot.Visible = false
			return
		end

		CrossRoot.Visible = true
		local sz = math.clamp(S.CrosshairSize or 5, 2, 14)
		local col = getCrossColor()
		local gap = math.max(2, math.floor(sz * 0.55))
		local arm = math.max(4, sz + 2)
		local thick = math.max(1, math.floor(sz * 0.35))

		for _, part in ipairs(crossParts) do
			part.BackgroundColor3 = col
			part.Visible = false
		end
		CrossRing.Visible = false
		local ringStroke = CrossRing:FindFirstChild("RingStroke")
		if ringStroke then
			ringStroke.Color = col
		end

		local style = S.CrosshairStyle or "Dot"
		if style == "Dot" then
			CrossDot.Size = UDim2.new(0, sz, 0, sz)
			CrossDot.Visible = true
		elseif style == "Cross" then
			CrossTop.Size = UDim2.new(0, thick, 0, arm)
			CrossTop.Position = UDim2.new(0.5, 0, 0.5, -(gap + arm * 0.5))
			CrossBottom.Size = UDim2.new(0, thick, 0, arm)
			CrossBottom.Position = UDim2.new(0.5, 0, 0.5, gap + arm * 0.5)
			CrossLeft.Size = UDim2.new(0, arm, 0, thick)
			CrossLeft.Position = UDim2.new(0.5, -(gap + arm * 0.5), 0.5, 0)
			CrossRight.Size = UDim2.new(0, arm, 0, thick)
			CrossRight.Position = UDim2.new(0.5, gap + arm * 0.5, 0.5, 0)
			CrossTop.Visible = true
			CrossBottom.Visible = true
			CrossLeft.Visible = true
			CrossRight.Visible = true
		elseif style == "X" then
			local len = arm + gap + 2
			CrossX1.Size = UDim2.new(0, thick, 0, len)
			CrossX2.Size = UDim2.new(0, thick, 0, len)
			CrossX1.Visible = true
			CrossX2.Visible = true
		elseif style == "Circle" then
			local d = sz * 3
			CrossRing.Size = UDim2.new(0, d, 0, d)
			CrossRing.Visible = true
			if ringStroke then
				ringStroke.Thickness = thick
			end
		elseif style == "DotCross" then
			CrossDot.Size = UDim2.new(0, math.max(3, sz - 1), 0, math.max(3, sz - 1))
			CrossDot.Visible = true
			CrossTop.Size = UDim2.new(0, thick, 0, arm)
			CrossTop.Position = UDim2.new(0.5, 0, 0.5, -(gap + arm * 0.5))
			CrossBottom.Size = UDim2.new(0, thick, 0, arm)
			CrossBottom.Position = UDim2.new(0.5, 0, 0.5, gap + arm * 0.5)
			CrossLeft.Size = UDim2.new(0, arm, 0, thick)
			CrossLeft.Position = UDim2.new(0.5, -(gap + arm * 0.5), 0.5, 0)
			CrossRight.Size = UDim2.new(0, arm, 0, thick)
			CrossRight.Position = UDim2.new(0.5, gap + arm * 0.5, 0.5, 0)
			CrossTop.Visible = true
			CrossBottom.Visible = true
			CrossLeft.Visible = true
			CrossRight.Visible = true
		end
	end

	local HitGroup = tagZ(C("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 26, 0, 26),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = HudGui,
	}), Z.hit)
	for i = 1, 4 do
		local ln = tagZ(C("Frame", {
			Size = UDim2.new(0, 10, 0, 3),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Rotation = (i - 1) * 90 + 45,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = HitGroup,
		}), Z.hit + 1)
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ln })
		C("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1, Transparency = 0.4, Parent = ln })
	end

	local HIT_SOUND_IDS = { 4868633804, 7147454322, 6026984224, 12222039, 9114481067 }
	local hitSoundIdx = 1
	local HitSound = C("Sound", {
		Name = "HitSound",
		SoundId = "rbxassetid://" .. HIT_SOUND_IDS[1],
		Volume = 0.45,
		Parent = CG,
	})
	task.spawn(function()
		for i, id in ipairs(HIT_SOUND_IDS) do
			HitSound.SoundId = "rbxassetid://" .. id
			local deadline = tick() + 2.5
			while not HitSound.IsLoaded and tick() < deadline do
				task.wait(0.08)
			end
			if HitSound.IsLoaded then
				hitSoundIdx = i
				break
			end
		end
	end)

	local session = { kills = 0, hits = 0, shots = 0, start = tick() }
	local wmShown = false
	local wmPulse = 0
	local fpsSmoothed = 60
	local fpsLast = tick()
	local fpsFrames = 0
	local statDisplay = { kills = 0, hits = 0, acc = 0 }

	local Watermark = tagZ(C("Frame", {
		Name = "Watermark",
		Size = UDim2.new(0, 220, 0, 48),
		Position = UDim2.new(0, 14, 0, 12),
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		Parent = HudGui,
	}), Z.wm)
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Watermark })
	local WmStroke = C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.62, Parent = Watermark })
	local WmAccent = tagZ(C("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Parent = Watermark,
	}), Z.wm + 1)
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = WmAccent })
	local WmShimmer = tagZ(C("Frame", {
		Size = UDim2.new(0, 56, 1, 0),
		Position = UDim2.new(-0.35, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Parent = WmAccent,
	}), Z.wm + 2)
	C("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = WmShimmer,
	})
	tagZ(C("Frame", {
		Name = "WmLogoBox",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 10, 0, 12),
		BackgroundColor3 = ACC,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = Watermark,
	}), Z.wm + 1)
	local wmLogoBox = Watermark:FindFirstChild("WmLogoBox")
	if wmLogoBox then
		C("UICorner", { CornerRadius = UDim.new(0, 7), Parent = wmLogoBox })
	end
	local WmLogo = tagZ(C("TextLabel", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 10, 0, 12),
		BackgroundTransparency = 1,
		Text = "V",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = Watermark,
	}), Z.wm + 2)
	tagZ(C("TextLabel", {
		Size = UDim2.new(1, -52, 0, 16),
		Position = UDim2.new(0, 46, 0, 10),
		BackgroundTransparency = 1,
		Text = "VANGUARD",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Watermark,
	}), Z.wm + 1)
	local WmSub = tagZ(C("TextLabel", {
		Size = UDim2.new(1, -52, 0, 12),
		Position = UDim2.new(0, 46, 0, 28),
		BackgroundTransparency = 1,
		Text = "v? · 60 FPS",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(150, 155, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Watermark,
	}), Z.wm + 1)

	local StatsPanel = tagZ(C("Frame", {
		Name = "SessionStats",
		Size = UDim2.new(0, 196, 0, 132),
		Position = UDim2.new(1, -210, 0, 12),
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		Parent = HudGui,
	}), Z.stats)
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = StatsPanel })
	local StatsStroke = C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.62, Parent = StatsPanel })
	tagZ(C("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Parent = StatsPanel,
	}), Z.stats + 1)
	tagZ(C("TextLabel", {
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Text = "SESSION",
		Font = Enum.Font.GothamBlack,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(235, 235, 242),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = StatsPanel,
	}), Z.stats + 1)
	tagZ(C("TextLabel", {
		Size = UDim2.new(1, -20, 0, 10),
		Position = UDim2.new(0, 12, 0, 24),
		BackgroundTransparency = 1,
		Text = "LIVE STATS",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		TextColor3 = Color3.fromRGB(120, 125, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = StatsPanel,
	}), Z.stats + 1)
	local StatsLines = {}
	local StatValues = {}
	for i, key in ipairs({ "Kills", "Hits", "Accuracy", "Time" }) do
		local rowY = 38 + (i - 1) * 22
		tagZ(C("TextLabel", {
			Size = UDim2.new(0.55, 0, 0, 14),
			Position = UDim2.new(0, 12, 0, rowY),
			BackgroundTransparency = 1,
			Text = key,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(145, 148, 162),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = StatsPanel,
		}), Z.stats + 1)
		local val = tagZ(C("TextLabel", {
			Size = UDim2.new(0.4, -12, 0, 14),
			Position = UDim2.new(0.6, 0, 0, rowY),
			BackgroundTransparency = 1,
			Text = "—",
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = ACC,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = StatsPanel,
		}), Z.stats + 1)
		StatsLines[key] = val
		StatValues[key] = val
	end
	local AccBarBg = tagZ(C("Frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 0, 104),
		BackgroundColor3 = Color3.fromRGB(38, 38, 48),
		BorderSizePixel = 0,
		Parent = StatsPanel,
	}), Z.stats + 1)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = AccBarBg })
	local AccBarFill = tagZ(C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Parent = AccBarBg,
	}), Z.stats + 2)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = AccBarFill })

	local KeybindPanel = tagZ(C("Frame", {
		Name = "KeybindList",
		Size = UDim2.new(0, 190, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
		Parent = HudGui,
	}), Z.kb)
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = KeybindPanel })
	C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.55, Parent = KeybindPanel })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = KeybindPanel,
	})
	C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindPanel })
	tagZ(C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Text = "KEYBINDS",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(150, 150, 162),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = KeybindPanel,
	}), Z.kb + 1)
	local KeybindBody = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = KeybindPanel,
	})
	C("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindBody })

	local KillFeedPanel = tagZ(C("Frame", {
		Name = "KillFeed",
		Size = UDim2.new(0, 240, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -254, 0, 108),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = HudGui,
	}), Z.kf)
	C("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = KillFeedPanel })
	local killEntries = {}

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
		Text = "Brak wykrytych obserwatorów",
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

	local DmgFolder = workspace:FindFirstChild("VG_DmgNums")
	if not DmgFolder then
		DmgFolder = Instance.new("Folder")
		DmgFolder.Name = "VG_DmgNums"
		DmgFolder.Parent = workspace
	end

	local TargetPanel = tagZ(C("Frame", {
		Name = "TargetInfo",
		Size = UDim2.new(0, 292, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Visible = false,
		Parent = HudGui,
	}), Z.target)
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = TargetPanel })
	local TargetStroke = C("UIStroke", { Color = ACC, Thickness = 1.5, Transparency = 0.28, Parent = TargetPanel })
	local TargetAccent = tagZ(C("Frame", {
		Name = "TargetAccent",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Parent = TargetPanel,
	}), Z.target + 1)
	C("UICorner", { CornerRadius = UDim.new(0, 12), Parent = TargetAccent })

	local TargetBody = C("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		Parent = TargetPanel,
	})
	C("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = TargetBody })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 12),
		Parent = TargetBody,
	})

	local TargetHeader = C("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = TargetBody,
	})
	local TargetAvWrap = tagZ(C("Frame", {
		Size = UDim2.new(0, 38, 0, 38),
		BackgroundColor3 = Color3.fromRGB(38, 38, 48),
		BorderSizePixel = 0,
		Parent = TargetHeader,
	}), Z.targetRow)
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = TargetAvWrap })
	C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.45, Parent = TargetAvWrap })
	local TargetAv = tagZ(C("ImageLabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.new(0, 2, 0, 2),
		BackgroundTransparency = 1,
		Image = "",
		Parent = TargetAvWrap,
	}), Z.targetRow + 1)
	C("UICorner", { CornerRadius = UDim.new(0, 7), Parent = TargetAv })

	local TargetName = tagZ(C("TextLabel", {
		Size = UDim2.new(1, -96, 0, 16),
		Position = UDim2.new(0, 48, 0, 4),
		BackgroundTransparency = 1,
		Text = "—",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = TargetHeader,
	}), Z.targetRow + 1)
	local TargetSub = tagZ(C("TextLabel", {
		Size = UDim2.new(1, -96, 0, 12),
		Position = UDim2.new(0, 48, 0, 22),
		BackgroundTransparency = 1,
		Text = "TARGET",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 145),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TargetHeader,
	}), Z.targetRow + 1)
	local TargetVisBadge = tagZ(C("TextLabel", {
		Size = UDim2.new(0, 52, 0, 20),
		Position = UDim2.new(1, -52, 0, 10),
		BackgroundColor3 = Color3.fromRGB(34, 70, 48),
		Text = "VISIBLE",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(120, 255, 170),
		Parent = TargetHeader,
	}), Z.targetRow + 1)
	C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = TargetVisBadge })

	local TargetHpRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = TargetBody,
	})
	tagZ(C("TextLabel", {
		Size = UDim2.new(0, 28, 1, 0),
		BackgroundTransparency = 1,
		Text = "HP",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(150, 150, 165),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TargetHpRow,
	}), Z.targetRow + 1)
	local TargetHpTrack = tagZ(C("Frame", {
		Size = UDim2.new(1, -96, 0, 8),
		Position = UDim2.new(0, 34, 0.5, -4),
		BackgroundColor3 = Color3.fromRGB(28, 28, 36),
		BorderSizePixel = 0,
		Parent = TargetHpRow,
	}), Z.targetRow + 1)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = TargetHpTrack })
	local TargetHpFill = tagZ(C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		Parent = TargetHpTrack,
	}), Z.targetRow + 2)
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = TargetHpFill })
	local TargetHpText = tagZ(C("TextLabel", {
		Size = UDim2.new(0, 54, 1, 0),
		Position = UDim2.new(1, -54, 0, 0),
		BackgroundTransparency = 1,
		Text = "100",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(230, 230, 238),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = TargetHpRow,
	}), Z.targetRow + 1)

	local TargetStats = C("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = TargetBody,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = TargetStats })
	local function makeTargetStat(label, order, xScale)
		tagZ(C("TextLabel", {
			Size = UDim2.new(0.33, -8, 0, 12),
			Position = UDim2.new(xScale, 8, 0, 6),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(110, 110, 125),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = TargetStats,
		}), Z.targetRow + 1)
		return tagZ(C("TextLabel", {
			Size = UDim2.new(0.33, -8, 0, 14),
			Position = UDim2.new(xScale, 8, 0, 18),
			BackgroundTransparency = 1,
			Text = "—",
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(235, 235, 242),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = TargetStats,
		}), Z.targetRow + 1)
	end
	local TargetDistLbl = makeTargetStat("DISTANCE", 1, 0)
	local TargetWpnLbl = makeTargetStat("WEAPON", 2, 0.33)
	local TargetPartLbl = makeTargetStat("BONE", 3, 0.66)

	local lastTargetUserId = nil

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

	local function getWeaponFromChar(char)
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				return item.Name
			end
		end
		return "—"
	end

	local function isCharVisibleFromCam(char, part)
		if not char or not part then
			return false
		end
		local origin = Cam.CFrame.Position
		local pos = part.Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
		local dir = pos - origin
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then
			return true
		end
		return hit.Instance:IsDescendantOf(char)
	end

	local function spawnDamageNumber(hum, dmg)
		if not S.DamageNumbers or not hum or not hum.Parent then
			return
		end
		local char = hum.Parent
		local adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		if not adornee then
			return
		end

		local host = Instance.new("Part")
		host.Name = "VG_DmgHost"
		host.Anchored = true
		host.CanCollide = false
		host.CanQuery = false
		host.CanTouch = false
		host.Transparency = 1
		host.Size = Vector3.new(0.2, 0.2, 0.2)
		host.CFrame = CFrame.new(adornee.Position + Vector3.new(math.random(-8, 8) / 10, 2.2, math.random(-8, 8) / 10))
		host.Parent = DmgFolder

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 120, 0, 44)
		bb.StudsOffset = Vector3.new(0, 0, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = host
		bb.Parent = host

		local isHead = dmg >= 50
		local col = isHead and Color3.fromRGB(255, 95, 95) or Color3.fromRGB(255, 255, 255)
		local glow = isHead and Color3.fromRGB(255, 60, 60) or ACC

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = glow
		stroke.Thickness = 1.5
		stroke.Transparency = 0.2
		stroke.Parent = card

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "-" .. tostring(math.floor(dmg + 0.5))
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextSize = isHead and 22 or 18
		lbl.TextColor3 = col
		lbl.TextStrokeTransparency = 0.55
		lbl.Parent = card

		if isHead then
			local tag = Instance.new("TextLabel")
			tag.Size = UDim2.new(1, 0, 0, 10)
			tag.Position = UDim2.new(0, 0, 1, -11)
			tag.BackgroundTransparency = 1
			tag.Text = "HEAD"
			tag.Font = Enum.Font.GothamBold
			tag.TextSize = 8
			tag.TextColor3 = Color3.fromRGB(255, 130, 130)
			tag.Parent = card
		end

		card.Size = UDim2.new(0.6, 0, 0.6, 0)
		Tween(card, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0),
		})

		local rise = 2.8
		local life = 0.85
		task.spawn(function()
			local t0 = tick()
			while host.Parent and tick() - t0 < life do
				local dt = task.wait(0.03)
				local a = (tick() - t0) / life
				host.CFrame = host.CFrame + Vector3.new(0, rise * dt, 0)
				card.BackgroundTransparency = 0.15 + a * 0.75
				lbl.TextTransparency = a * 0.95
				stroke.Transparency = 0.2 + a * 0.75
			end
			pcall(function() host:Destroy() end)
		end)
	end

	local targetInfoAt = 0
	local targetVisAt = 0
	local targetVisCached = true

	local function updTargetInfo()
		if not S.TargetInfo or S.MenuOpen then
			TargetPanel.Visible = false
			return
		end

		local now = tick()
		if now - targetInfoAt < 0.08 then
			return
		end
		targetInfoAt = now

		local tgt = S.GetAimTarget and S.GetAimTarget()
		if not tgt or not tgt.char or not tgt.part then
			TargetPanel.Visible = false
			lastTargetUserId = nil
			return
		end

		local char = tgt.char
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not hrp then
			TargetPanel.Visible = false
			return
		end

		TargetPanel.Visible = true
		local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		TargetHpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		TargetHpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 255, 130), hpRatio)
		TargetHpText.Text = string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))

		local dist = (Cam.CFrame.Position - hrp.Position).Magnitude
		TargetDistLbl.Text = math.floor(dist) .. "m"
		TargetWpnLbl.Text = getWeaponFromChar(char)
		TargetPartLbl.Text = string.upper(tgt.part.Name)

		local visible = targetVisCached
		if now - targetVisAt >= 0.15 then
			targetVisAt = now
			visible = isCharVisibleFromCam(char, tgt.part)
			targetVisCached = visible
		end
		if visible then
			TargetVisBadge.Text = "VISIBLE"
			TargetVisBadge.BackgroundColor3 = Color3.fromRGB(34, 70, 48)
			TargetVisBadge.TextColor3 = Color3.fromRGB(120, 255, 170)
		else
			TargetVisBadge.Text = "HIDDEN"
			TargetVisBadge.BackgroundColor3 = Color3.fromRGB(70, 34, 34)
			TargetVisBadge.TextColor3 = Color3.fromRGB(255, 140, 140)
		end

		local displayName = tgt.plr and (tgt.plr.DisplayName ~= tgt.plr.Name and tgt.plr.DisplayName or tgt.plr.Name) or char.Name
		local userName = tgt.plr and tgt.plr.Name or char.Name
		TargetName.Text = displayName
		TargetSub.Text = tgt.plr and ("@" .. userName) or "BOT / NPC"

		if tgt.plr and tgt.plr.UserId ~= lastTargetUserId then
			lastTargetUserId = tgt.plr.UserId
			loadAvatar(TargetAv, tgt.plr.UserId)
		elseif not tgt.plr then
			lastTargetUserId = nil
			TargetAv.Image = ""
		end

		TargetStroke.Color = visible and ACC or Color3.fromRGB(255, 100, 100)
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
			Text = "Obserwuje Ciebie",
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
	local HIT_WINDOW = 1.5

	local function playHitSound(force)
		if not force and not S.HitSound then
			return
		end
		HitSound.Volume = math.clamp(S.HitSoundVolume or 0.45, 0.05, 1)
		if not HitSound.IsLoaded then
			HitSound.SoundId = "rbxassetid://" .. HIT_SOUND_IDS[hitSoundIdx]
		end
		HitSound.TimePosition = 0
		local played = false
		pcall(function()
			HitSound:Play()
			played = HitSound.IsPlaying
		end)
		if played then
			return
		end
		for i, id in ipairs(HIT_SOUND_IDS) do
			if i ~= hitSoundIdx then
				HitSound.SoundId = "rbxassetid://" .. id
				local ok = pcall(function()
					HitSound:Play()
				end)
				if ok and HitSound.IsPlaying then
					hitSoundIdx = i
					break
				end
			end
		end
	end

	local function formatSessionTime()
		local sec = math.floor(tick() - session.start)
		local m = math.floor(sec / 60)
		local s = sec % 60
		return string.format("%02d:%02d", m, s)
	end

	local function bumpStatLabel(key, text)
		local lbl = StatsLines[key]
		if not lbl then
			return
		end
		lbl.Text = text
		lbl.TextSize = 13
		Tween(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 11 })
	end

	local function updSessionStats()
		if not S.SessionStats or S.MenuOpen then
			StatsPanel.Visible = false
			return
		end
		StatsPanel.Visible = true
		local acc = session.shots > 0 and math.floor(session.hits / session.shots * 100) or 0
		if statDisplay.kills ~= session.kills then
			statDisplay.kills = session.kills
			bumpStatLabel("Kills", tostring(session.kills))
		else
			StatsLines.Kills.Text = tostring(session.kills)
		end
		if statDisplay.hits ~= session.hits then
			statDisplay.hits = session.hits
			bumpStatLabel("Hits", tostring(session.hits))
		else
			StatsLines.Hits.Text = tostring(session.hits)
		end
		if statDisplay.acc ~= acc then
			statDisplay.acc = acc
			bumpStatLabel("Accuracy", acc .. "%")
		else
			StatsLines.Accuracy.Text = acc .. "%"
		end
		StatsLines.Time.Text = formatSessionTime()
		Tween(AccBarFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(math.clamp(acc / 100, 0, 1), 0, 1, 0),
		})
		local pulse = 0.58 + math.sin(tick() * 2.2) * 0.08
		StatsStroke.Transparency = pulse
	end

	local function addKillFeed(name)
		if not S.KillFeed or S.MenuOpen then
			return
		end
		KillFeedPanel.Visible = true
		local row = tagZ(C("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = PANEL_BG,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = KillFeedPanel,
		}), Z.kf + 1)
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = row })
		C("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.6, Parent = row })
		tagZ(C("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1,
			Text = "Eliminated  " .. name,
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(235, 235, 242),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		}), Z.kf + 2)
		row.Position = UDim2.new(0, 16, 0, 0)
		Tween(row, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		})
		table.insert(killEntries, 1, row)
		for i, entry in ipairs(killEntries) do
			entry.LayoutOrder = i
		end
		if #killEntries > 4 then
			local old = table.remove(killEntries)
			pcall(function() old:Destroy() end)
		end
		task.delay(4, function()
			if row.Parent then
				Tween(row, TweenInfo.new(0.2), { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0) })
				task.delay(0.22, function()
					pcall(function() row:Destroy() end)
					for i, entry in ipairs(killEntries) do
						if entry == row then
							table.remove(killEntries, i)
							break
						end
					end
					if #killEntries == 0 then
						KillFeedPanel.Visible = false
					end
				end)
			end
		end)
	end

	local function clearKeybindRows()
		for _, ch in ipairs(KeybindBody:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
	end

	local function addKeyRow(label, key, order)
		local row = tagZ(C("Frame", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = KeybindBody,
		}), Z.kb + 1)
		tagZ(C("TextLabel", {
			Size = UDim2.new(0.55, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(170, 170, 180),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}), Z.kb + 2)
		tagZ(C("TextLabel", {
			Size = UDim2.new(0.45, -4, 1, 0),
			Position = UDim2.new(0.55, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = key,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = ACC,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		}), Z.kb + 2)
	end

	local function updKeybindList()
		if not S.KeybindList or S.MenuOpen then
			KeybindPanel.Visible = false
			return
		end
		clearKeybindRows()
		local order = 1
		addKeyRow("Menu", "RightShift", order)
		order += 1
		if S.Trigger then
			local mode = S.TriggerMode == "Toggle" and "Toggle" or "Hold"
			addKeyRow("Trigger", (S.TriggerKey or "?") .. " · " .. mode, order)
			order += 1
		end
		if S.MasterRage and S.RageBot then
			local mode = S.RageMode == "Toggle" and "Toggle" or "Hold"
			addKeyRow("Ragebot", (S.RageKey or "?") .. " · " .. mode, order)
			order += 1
		end
		if S.Aimbot then
			local bind = S.AimKey or "MouseButton2"
			if bind == "MouseButton1" then bind = "M1"
			elseif bind == "MouseButton2" then bind = "M2"
			elseif bind == "MouseButton3" then bind = "M3" end
			addKeyRow("Aimbot", bind, order)
			order += 1
		end
		if S.Silent then
			local bind = S.SilentKey or "MouseButton1"
			if bind == "MouseButton1" then bind = "M1"
			elseif bind == "MouseButton2" then bind = "M2"
			elseif bind == "MouseButton3" then bind = "M3" end
			addKeyRow("Silent", bind, order)
			order += 1
		end
		if S.Invisibility then
			addKeyRow("Invis", (S.InvisKey or "X") .. " · Toggle", order)
			order += 1
		end
		if S.FriendClick then
			addKeyRow("Friend", "Ctrl+Click", order)
		end
		KeybindPanel.Visible = true
	end

	local function updWatermark()
		if not S.Watermark or S.MenuOpen then
			Watermark.Visible = false
			wmShown = false
			return
		end
		if not wmShown then
			wmShown = true
			Watermark.Position = UDim2.new(0, -240, 0, 12)
			Tween(Watermark, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 14, 0, 12),
			})
		end
		WmSub.Text = "v" .. (S.Version or "?") .. "  ·  " .. math.floor(fpsSmoothed + 0.5) .. " FPS"
		Watermark.Visible = true
	end

	local function flashHitmarker(dmg)
		hitHideToken = hitHideToken + 1
		local token = hitHideToken
		HitGroup.Visible = true
		HitGroup.Size = UDim2.new(0, 20, 0, 20)
		local col = dmg >= 50 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 255, 255)
		for _, ch in ipairs(HitGroup:GetChildren()) do
			if ch:IsA("Frame") then
				ch.BackgroundColor3 = col
			end
		end
		Tween(HitGroup, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 28, 0, 28),
		})
		task.delay(0.12, function()
			if token == hitHideToken then
				Tween(HitGroup, TweenInfo.new(0.1), { Size = UDim2.new(0, 22, 0, 22) })
			end
		end)
		task.delay(0.28, function()
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

	local function resolveTracerLine(targetChar, aimPos, isKill)
		local to = aimPos
		if typeof(to) ~= "Vector3" and targetChar and targetChar.Parent then
			local head = targetChar:FindFirstChild("Head")
			local hrp = targetChar:FindFirstChild("HumanoidRootPart")
			local part = head or hrp
			if part then
				to = part.Position
			end
		end
		if typeof(to) ~= "Vector3" and S.LastShotPos then
			local shotAt = tonumber(S.LastShotAt)
			if shotAt and tick() - shotAt <= 2.5 then
				to = S.LastShotPos
			end
		end

		local rayOrigin = S.LastShotRayOrigin
		local rayDir = S.LastShotRayDir
		local shotAt = tonumber(S.LastShotAt)
		if typeof(rayOrigin) ~= "Vector3" or not shotAt or tick() - shotAt > 0.75 then
			local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
			rayOrigin = ray.Origin
			rayDir = ray.Direction
		end
		if typeof(rayDir) == "Vector3" and rayDir.Magnitude > 0 then
			rayDir = rayDir.Unit
		else
			rayDir = nil
		end

		if typeof(to) ~= "Vector3" then
			local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1400, params)
			if hit then
				to = hit.Position
			else
				to = ray.Origin + ray.Direction * 280
			end
			if typeof(rayOrigin) ~= "Vector3" then
				rayOrigin = ray.Origin
			end
			if not rayDir then
				rayDir = ray.Direction.Unit
			end
		end

		if not rayDir then
			rayDir = (to - rayOrigin).Unit
		end

		local pierce = isKill and 14 or 8
		to = to + rayDir * pierce

		local from = rayOrigin + rayDir * 1.5
		local dist = (to - from).Magnitude
		if dist < 1 then
			return nil, nil
		end
		return from, to
	end

	local lastBulletTracerAt = 0

	local function spawnShotTracer(isKill, targetChar, aimPos)
		if isKill then
			if not S.KillShotTracers then
				return
			end
		elseif not S.ShotTracers then
			return
		end
		if not isKill and tick() - lastBulletTracerAt < 0.05 then
			return
		end
		if not isKill then
			lastBulletTracerAt = tick()
		end

		local from, to = resolveTracerLine(targetChar, aimPos, isKill)
		if not from or not to then
			return
		end
		local diff = to - from
		local dist = diff.Magnitude
		if dist < 0.5 then
			return
		end
		local mid = from + diff * 0.5
		local col = isKill and Color3.fromRGB(255, 55, 90) or (S.V or ACC)
		local width = isKill and 0.5 or 0.28
		local coreW = isKill and 0.22 or 0.12
		local life = isKill and 0.85 or 0.5

		local function makeSegment(w, color, transp, name)
			local seg = Instance.new("Part")
			seg.Name = name or "VG_ShotTrace"
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.Material = Enum.Material.Neon
			seg.Color = color
			seg.Size = Vector3.new(w, w, dist)
			seg.CFrame = CFrame.lookAt(mid, to)
			seg.Transparency = transp
			seg.Parent = workspace
			Debris:AddItem(seg, life + 0.2)
			pcall(function()
				Tween(seg, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
				})
			end)
			return seg
		end

		makeSegment(width, col, isKill and 0.1 or 0.15, "VG_ShotTrace")
		makeSegment(coreW, Color3.new(1, 1, 1), isKill and 0 or 0.05, "VG_ShotTraceCore")
		if isKill then
			local ring = Instance.new("Part")
			ring.Name = "VG_KillTrace"
			ring.Shape = Enum.PartType.Ball
			ring.Size = Vector3.new(2, 2, 2)
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.Material = Enum.Material.Neon
			ring.Color = col
			ring.Transparency = 0.1
			ring.CFrame = CFrame.new(to)
			ring.Parent = workspace
			Debris:AddItem(ring, 0.5)
			pcall(function()
				Tween(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(5, 5, 5),
					Transparency = 1,
				})
			end)
		end
	end

	function S.RequestShotTracer(isKill, targetChar, aimPos)
		pcall(spawnShotTracer, isKill == true, targetChar, aimPos)
	end

	local function registerHit(hum, dmg, plrName)
		local shotAt = tonumber(S.LastShotAt)
		local recent = shotAt and (tick() - shotAt) <= HIT_WINDOW
		if not recent then
			return
		end
		if S.LastShotHum and hum ~= S.LastShotHum then
			return
		end
		session.hits += 1
		if S.Hitmarker then
			flashHitmarker(dmg)
		end
		pcall(playHitSound, false)
		if S.DamageNumbers then
			pcall(spawnDamageNumber, hum, dmg)
		end
		if S.DamageLog then
			pcall(addDmgLog, plrName or "Target", dmg, false)
		end
		if S.ShotTracers and hum.Health > 0 then
			pcall(spawnShotTracer, false, hum.Parent, S.LastShotPos)
		end
	end

	function S.TestHitFeedback()
		flashHitmarker(42)
		playHitSound(true)
		if S.DamageLog then
			addDmgLog("Test", 42, false)
		end
	end

	local function shotMatchesKill(hum, victimChar)
		local shotAt = tonumber(S.LastShotAt)
		if not shotAt or tick() - shotAt > 2.5 then
			return false
		end
		if not S.LastShotChar and not S.LastShotHum then
			return false
		end
		if S.LastShotHum and hum and hum == S.LastShotHum then
			return true
		end
		if S.LastShotChar and victimChar and victimChar == S.LastShotChar then
			return true
		end
		return false
	end

	local function registerKill(plrName, victimChar, hum)
		if not shotMatchesKill(hum, victimChar) then
			return
		end
		session.kills += 1
		pcall(addKillFeed, plrName or "Target")
		if S.KillShotTracers then
			pcall(spawnShotTracer, true, victimChar, S.LastShotPos)
		end
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
			local trackHit = S.Hitmarker or S.HitSound or S.DamageLog or S.DamageNumbers or S.SessionStats or S.KillFeed
				or S.HitEffects or S.KillEffects
			if not trackHit then
				last = hp
				return
			end
			if hp < last then
				local dmg = last - hp
				registerHit(hum, dmg, plrName)
				if S.OnLocalHit then
					pcall(S.OnLocalHit, hum, dmg)
				end
			end
			if hp <= 0 and last > 0 then
				registerKill(plrName, hum.Parent, hum)
				if S.OnLocalKill then
					pcall(S.OnLocalKill, hum, plrName)
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
			local ray = Cam:ViewportPointToRay(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
			S.LastShotRayOrigin = ray.Origin
			S.LastShotRayDir = ray.Direction
			S.LastShotAt = tick()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1400, params)
			local aimPos = hit and hit.Position or nil
			local hum = rayHum()
			if hum then
				S.LastShotHum = hum
				if hum.Parent and hum.Parent:IsA("Model") then
					S.LastShotChar = hum.Parent
					if not aimPos then
						local head = hum.Parent:FindFirstChild("Head")
						local hrp = hum.Parent:FindFirstChild("HumanoidRootPart")
						local part = head or hrp
						if part then
							aimPos = part.Position
						end
					end
					if S.NotifyShot then
						pcall(S.NotifyShot, hum.Parent)
					end
				end
			end
			if aimPos then
				S.LastShotPos = aimPos
			end
		end
	end)

	local function getLocalSpectateSubjects()
		local subjects = {}
		local myChar = LP.Character
		if not myChar then
			return subjects
		end
		local hum = myChar:FindFirstChildOfClass("Humanoid")
		if hum then
			subjects[hum] = true
		end
		for _, inst in ipairs(myChar:GetDescendants()) do
			if inst:IsA("BasePart") then
				subjects[inst] = true
			end
		end
		return subjects
	end

	local function attributePointsToLocal(value)
		if value == nil then
			return false
		end
		if value == LP or value == LP.Character then
			return true
		end
		if typeof(value) == "number" and value == LP.UserId then
			return true
		end
		if typeof(value) == "string" then
			local lower = string.lower(value)
			if lower == string.lower(LP.Name) or lower == string.lower(LP.DisplayName) then
				return true
			end
			local num = tonumber(value)
			if num and num == LP.UserId then
				return true
			end
		end
		if typeof(value) == "Instance" and LP.Character and value:IsDescendantOf(LP.Character) then
			return true
		end
		return false
	end

	local function isSpectatingLocalPlayer(plr)
		if plr == LP then
			return false
		end

		local attrNames = {
			"SpectatingUserId",
			"SpectateTarget",
			"Spectating",
			"ObserveTarget",
			"CameraTarget",
			"WatchUserId",
			"TargetUserId",
			"SpectateUserId",
			"ViewTarget",
		}
		for _, attr in ipairs(attrNames) do
			if attributePointsToLocal(plr:GetAttribute(attr)) then
				return true
			end
		end

		for _, child in ipairs(plr:GetChildren()) do
			if child:IsA("ObjectValue") and attributePointsToLocal(child.Value) then
				return true
			end
			if child:IsA("IntValue") and child.Value == LP.UserId then
				return true
			end
			if child:IsA("StringValue") and attributePointsToLocal(child.Value) then
				return true
			end
		end

		if typeof(gethiddenproperty) == "function" then
			local ok, camera = pcall(gethiddenproperty, plr, "Camera")
			if ok and typeof(camera) == "Instance" and camera:IsA("Camera") then
				local subject = camera.CameraSubject
				if subject then
					local subjects = getLocalSpectateSubjects()
					if subjects[subject] then
						return true
					end
					if LP.Character and subject:IsDescendantOf(LP.Character) then
						return true
					end
				end
			end
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
			if isSpectatingLocalPlayer(plr) then
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

	local specAt = 0
	local lastShotTrack = 0
	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.Heartbeat:Connect(perfWrap("Features.HUD", function()
		updCrosshair()
		if not S.DamageLog or S.MenuOpen then
			if dmgVisible then
				setDmgPanelVisible(false)
			end
		end
		fpsFrames += 1
		local now = tick()
		if now - fpsLast >= 0.5 then
			fpsSmoothed = fpsSmoothed * 0.65 + (fpsFrames / (now - fpsLast)) * 0.35
			fpsFrames = 0
			fpsLast = now
		end
		if S.Watermark and not S.MenuOpen then
			wmPulse += 0.03
			local glow = 0.58 + math.sin(wmPulse) * 0.1
			WmStroke.Transparency = glow
			WmShimmer.Position = UDim2.new((wmPulse * 0.18) % 1.35 - 0.35, 0, 0, 0)
			WmLogo.TextColor3 = Color3.fromRGB(255, 255, 255):Lerp(ACC, 0.15 + math.sin(wmPulse * 1.4) * 0.15)
		end
		updWatermark()
		updKeybindList()
		updSessionStats()
		updTargetInfo()
		local shotAt = tonumber(S.LastShotAt) or 0
		if shotAt > 0 and shotAt > lastShotTrack then
			lastShotTrack = shotAt
			session.shots += 1
		end
	end))

	RS.Heartbeat:Connect(perfWrap("Features.Spectators", function()
		if tick() - specAt < 0.45 then
			return
		end
		specAt = tick()
		scanHumanoids()
		updSpectators()
	end))

	if _G.VANGUARD then
		_G.VANGUARD.registerGui(HudGui)
	end
end

return Features
