-- UISkinVault.lua — CS-style Criminality skin inventory vault

local UISkinVault = {}

local SKIN_ACCENT = Color3.fromRGB(70, 140, 255)
local RARITY = {
	Color3.fromRGB(235, 75, 75),
	Color3.fromRGB(211, 44, 230),
	Color3.fromRGB(136, 71, 255),
	Color3.fromRGB(75, 105, 255),
	Color3.fromRGB(176, 195, 217),
}
local MELEE_NAMES = {
	Bayonet = true, Katana = true, Rambo = true, Chainsaw = true,
	Crowbar = true, Club = true, Wrench = true, Knife = true,
	Bat = true, Machete = true, Axe = true, Bowie = true,
	Karambit = true, Kukri = true, Cleaver = true, Tactical = true,
	Shiv = true, Pipe = true, Hammer = true,
}

local function skinHashColor(name)
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 2147483647
	end
	return RARITY[(h % #RARITY) + 1]
end

local function isMeleeWeapon(name)
	if MELEE_NAMES[name] then
		return true
	end
	local lower = string.lower(name or "")
	return string.find(lower, "knife", 1, true)
		or string.find(lower, "blade", 1, true)
		or string.find(lower, "sword", 1, true)
end

local function contentToImage(val)
	if val == nil then
		return ""
	end
	local s = tostring(val)
	if s == "" or s == "nil" or string.find(s, "ContentId", 1, true) then
		return ""
	end
	local id = string.match(s, "(%d%d%d+)")
	if id then
		return "rbxassetid://" .. id
	end
	if string.find(s, "rbxasset", 1, true) then
		return s
	end
	return ""
end

-- Frame icons (no unicode — Gotham shows tofu □ for ▾/★/◆ on many executors)
local function iconChevron(parent, C, open, z, color)
	local holder = C("Frame", {
		Name = "Chevron",
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(1, -18, 0.5, -6),
		BackgroundTransparency = 1,
		ZIndex = z or 9,
		Parent = parent,
	})
	if open then
		-- down: wide bar + shorter bar under it
		C("Frame", {
			Size = UDim2.new(0, 10, 0, 2),
			Position = UDim2.new(0.5, -5, 0, 3),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 9,
			Parent = holder,
		})
		C("Frame", {
			Size = UDim2.new(0, 6, 0, 2),
			Position = UDim2.new(0.5, -3, 0, 7),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 9,
			Parent = holder,
		})
	else
		-- right: two stacked bars growing left→right look like >
		C("Frame", {
			Size = UDim2.new(0, 2, 0, 8),
			Position = UDim2.new(0, 3, 0.5, -4),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 9,
			Parent = holder,
		})
		C("Frame", {
			Size = UDim2.new(0, 2, 0, 5),
			Position = UDim2.new(0, 6, 0.5, -2.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 9,
			Parent = holder,
		})
		C("Frame", {
			Size = UDim2.new(0, 2, 0, 2),
			Position = UDim2.new(0, 9, 0.5, -1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 9,
			Parent = holder,
		})
	end
	return holder
end

local function iconDot(parent, C, pos, size, color, z)
	local d = C("Frame", {
		Name = "Dot",
		Size = UDim2.new(0, size, 0, size),
		Position = pos,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 9,
		Parent = parent,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
	return d
end

local function iconCloseX(parent, C, z, color)
	local holder = C("Frame", {
		Name = "CloseIcon",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = z or 11,
		Parent = parent,
	})
	-- two bars crossing via Rotation (works in Studio + most executors)
	local a = C("Frame", {
		Size = UDim2.new(0, 10, 0, 2),
		Position = UDim2.new(0.5, -5, 0.5, -1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = z or 11,
		Parent = holder,
	})
	local b = C("Frame", {
		Size = UDim2.new(0, 10, 0, 2),
		Position = UDim2.new(0.5, -5, 0.5, -1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = -45,
		ZIndex = z or 11,
		Parent = holder,
	})
	return holder, a, b
end

local function iconDiamond(parent, C, color, z)
	local holder = C("Frame", {
		Name = "Diamond",
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0.5, -18, 0.5, -10),
		BackgroundTransparency = 1,
		ZIndex = z or 9,
		Parent = parent,
	})
	local core = C("Frame", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(0.5, -11, 0.5, -11),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = z or 9,
		Parent = holder,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 3), Parent = core })
	return holder
end

local function cmapImage(saName, precomputed)
	if precomputed and precomputed ~= "" then
		return contentToImage(precomputed)
	end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Storage")
	folder = folder and folder:FindFirstChild("CosmeticsStuff")
	folder = folder and folder:FindFirstChild("RepPBR")
	local sa = folder and folder:FindFirstChild(saName)
	if not sa then
		return ""
	end
	local ok, val = pcall(function()
		return sa.ColorMap
	end)
	if ok then
		return contentToImage(val)
	end
	return ""
end

function UISkinVault.build(opts)
	local C = opts.C
	local S = opts.S
	local CSkins = opts.CSkins
	local ConfigModule = opts.ConfigModule
	local MakeTog = opts.MakeTog
	local MakeButton = opts.MakeButton
	local MakeHint = opts.MakeHint
	local showNotify = opts.showNotify

	local persistToken = 0
	local function persistSkins()
		-- debounce disk writes — picking skins was blocking on SaveGlobals + config
		persistToken = persistToken + 1
		local token = persistToken
		task.delay(0.45, function()
			if token ~= persistToken then
				return
			end
			if S._crimSkinPersist then
				pcall(S._crimSkinPersist)
			end
			if ConfigModule and ConfigModule.SaveGlobals then
				pcall(ConfigModule.SaveGlobals, S)
			end
			pcall(function()
				local name = ConfigModule and ConfigModule.GetAutoload and ConfigModule.GetAutoload()
				if name and name ~= "" and ConfigModule.Save then
					ConfigModule.Save(name, S)
				end
			end)
		end)
	end

	MakeTog(CSkins, "Enable Skin Changer", "CrimSkinChanger", 1, { flat = true })

	local Vault = C("Frame", {
		Name = "SkinVault",
		Size = UDim2.new(1, 0, 0, 560),
		BackgroundColor3 = Color3.fromRGB(12, 14, 20),
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = CSkins,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Vault })
	C("UIStroke", { Color = Color3.fromRGB(32, 40, 58), Thickness = 1, Transparency = 0.25, Parent = Vault })

	local Header = C("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(16, 18, 26),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = Vault,
	})

	local BtnSelect = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 24),
		Position = UDim2.new(0, 12, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "Select",
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 210, 230),
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = Header,
	})
	local BtnClear = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 24),
		Position = UDim2.new(0, 84, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "Clear",
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(160, 170, 190),
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = Header,
	})
	C("TextLabel", {
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0.5, -100, 0, 0),
		BackgroundTransparency = 1,
		Text = "Inventory",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(235, 240, 250),
		ZIndex = 7,
		Parent = Header,
	})
	local StatusLbl = C("TextLabel", {
		Size = UDim2.new(0, 220, 0, 18),
		Position = UDim2.new(1, -232, 0.5, -9),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(140, 150, 170),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = Header,
	})

	local FilterRow = C("Frame", {
		Size = UDim2.new(1, -16, 0, 56),
		Position = UDim2.new(0, 8, 0, 48),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Vault,
	})

	local SearchBox = C("TextBox", {
		Size = UDim2.new(0, 200, 0, 32),
		Position = UDim2.new(0, 0, 0, 18),
		BackgroundColor3 = Color3.fromRGB(22, 24, 34),
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "Name",
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(230, 230, 240),
		PlaceholderColor3 = Color3.fromRGB(100, 105, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = FilterRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SearchBox })
	C("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = SearchBox })
	C("TextLabel", {
		Size = UDim2.new(0, 100, 0, 14),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "Skin search",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(120, 130, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = FilterRow,
	})

	local ClassWrap = C("Frame", {
		Size = UDim2.new(1, -216, 0, 32),
		Position = UDim2.new(0, 216, 0, 18),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = FilterRow,
	})
	C("TextLabel", {
		Size = UDim2.new(0, 80, 0, 14),
		Position = UDim2.new(0, 216, 0, 0),
		BackgroundTransparency = 1,
		Text = "Skin class",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(120, 130, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = FilterRow,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = ClassWrap,
	})

	local classFilter = "all"
	local classDefs = {
		{ key = "all", label = "All", color = Color3.fromRGB(180, 190, 210) },
		{ key = 1, label = "Covert", color = RARITY[1] },
		{ key = 2, label = "Classified", color = RARITY[2] },
		{ key = 3, label = "Restricted", color = RARITY[3] },
		{ key = 4, label = "Mil-Spec", color = RARITY[4] },
		{ key = 5, label = "Industrial", color = RARITY[5] },
	}
	local classBtns = {}

	local Body = C("Frame", {
		Size = UDim2.new(1, -16, 1, -118),
		Position = UDim2.new(0, 8, 0, 110),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Vault,
	})

	local TypeSide = C("ScrollingFrame", {
		Size = UDim2.new(0, 168, 1, 0),
		BackgroundColor3 = Color3.fromRGB(16, 18, 26),
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 7,
		Parent = Body,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = TypeSide })
	C("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = TypeSide,
	})
	C("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = TypeSide,
	})
	C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Type",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(150, 160, 180),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		ZIndex = 8,
		Parent = TypeSide,
	})

	local GridScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, -176, 1, 0),
		Position = UDim2.new(0, 176, 0, 0),
		BackgroundColor3 = Color3.fromRGB(14, 16, 22),
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(55, 65, 90),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 7,
		Parent = Body,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = GridScroll })
	C("UIGridLayout", {
		CellSize = UDim2.new(0, 148, 0, 168),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 0,
		Parent = GridScroll,
	})
	C("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = GridScroll,
	})

	local skinUi = {
		weapon = S.CrimSkinUiWeapon or "Mare",
		filter = "",
		expanded = { Melee = true, Firearms = true },
	}

	local refreshWeaponSidebar
	local refreshSkinGrid

	local function makeWeaponBtn(parent, gun, order, active)
		local saved = S._crimSkinSaved and S._crimSkinSaved(gun)
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = active and Color3.fromRGB(28, 36, 55) or Color3.fromRGB(20, 22, 30),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = B })
		if active then
			C("UIStroke", { Color = SKIN_ACCENT, Thickness = 1, Transparency = 0.35, Parent = B })
		end
		local labelPad = 8
		if isMeleeWeapon(gun) then
			iconDot(B, C, UDim2.new(0, 7, 0.5, -3), 6, Color3.fromRGB(255, 180, 70), 9)
			labelPad = 18
		end
		C("TextLabel", {
			Size = UDim2.new(1, -(labelPad + 4), 1, 0),
			Position = UDim2.new(0, labelPad, 0, 0),
			BackgroundTransparency = 1,
			Text = gun .. (saved and "  ·" or ""),
			Font = Enum.Font.GothamSemibold,
			TextSize = 10,
			TextColor3 = active and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(150, 155, 170),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = B,
		})
		B.MouseButton1Click:Connect(function()
			skinUi.weapon = gun
			S.CrimSkinUiWeapon = gun
			refreshWeaponSidebar()
			refreshSkinGrid()
		end)
		return B
	end

	local function makeCatHeader(parent, title, key, order)
		local open = skinUi.expanded[key] ~= false
		local B = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Color3.fromRGB(22, 24, 34),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = B })
		C("TextLabel", {
			Size = UDim2.new(1, -28, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			BackgroundTransparency = 1,
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(210, 215, 230),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
			Parent = B,
		})
		iconChevron(B, C, open, 9, Color3.fromRGB(140, 150, 170))
		B.MouseButton1Click:Connect(function()
			skinUi.expanded[key] = not open
			refreshWeaponSidebar()
		end)
		return B
	end

	refreshWeaponSidebar = function()
		for _, ch in ipairs(TypeSide:GetChildren()) do
			if ch:IsA("TextButton") or (ch:IsA("TextLabel") and ch.Text ~= "Type") then
				ch:Destroy()
			end
		end
		local weapons = {}
		if S._crimSkinListWeapons then
			local ok, list = pcall(S._crimSkinListWeapons)
			if ok and typeof(list) == "table" then
				weapons = list
			end
		end
		local q = string.lower(skinUi.filter or "")
		local melee, guns = {}, {}
		for _, gun in ipairs(weapons) do
			if q == "" or string.find(string.lower(gun), q, 1, true) then
				if isMeleeWeapon(gun) then
					melee[#melee + 1] = gun
				else
					guns[#guns + 1] = gun
				end
			end
		end
		local order = 1
		makeCatHeader(TypeSide, "Melee", "Melee", order)
		order = order + 1
		if skinUi.expanded.Melee ~= false then
			for _, gun in ipairs(melee) do
				makeWeaponBtn(TypeSide, gun, order, gun == skinUi.weapon)
				order = order + 1
			end
		end
		makeCatHeader(TypeSide, "Firearms", "Firearms", order)
		order = order + 1
		if skinUi.expanded.Firearms ~= false then
			for _, gun in ipairs(guns) do
				makeWeaponBtn(TypeSide, gun, order, gun == skinUi.weapon)
				order = order + 1
			end
		end
	end

	local function makeSkinCard(parent, gun, row, order, selected)
		local lab = row.label or row.full
		local accent = skinHashColor(lab)
		local rarityIdx = 1
		for i, c in ipairs(RARITY) do
			if c == accent then
				rarityIdx = i
				break
			end
		end
		if classFilter ~= "all" and classFilter ~= rarityIdx then
			return false
		end

		local Card = C("TextButton", {
			BackgroundColor3 = Color3.fromRGB(20, 22, 30),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Card })
		C("UIStroke", {
			Color = selected and SKIN_ACCENT or accent,
			Thickness = selected and 2 or 1,
			Transparency = selected and 0.15 or 0.45,
			Parent = Card,
		})

		local Halo = C("Frame", {
			Size = UDim2.new(0, 90, 0, 90),
			Position = UDim2.new(0.5, -45, 0, 28),
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = Card,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Halo })

		local img = cmapImage(row.full, row.preview)
		if img ~= "" then
			local preview = C("ImageLabel", {
				Size = UDim2.new(1, -16, 0, 96),
				Position = UDim2.new(0, 8, 0, 22),
				BackgroundTransparency = 1,
				Image = "",
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 9,
				Parent = Card,
			})
			-- defer image set so grid paints first; retry once if Content still resolving
			task.defer(function()
				if not preview.Parent then
					return
				end
				preview.Image = img
				if preview.IsLoaded == false then
					task.delay(0.35, function()
						if preview.Parent and (not preview.IsLoaded or preview.Image == "") then
							preview.Image = cmapImage(row.full, row.preview)
						end
					end)
				end
			end)
		else
			local ph = C("Frame", {
				Size = UDim2.new(1, -16, 0, 96),
				Position = UDim2.new(0, 8, 0, 22),
				BackgroundTransparency = 1,
				ZIndex = 9,
				Parent = Card,
			})
			iconDiamond(ph, C, accent, 9)
		end

		C("TextLabel", {
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.new(0, 6, 0, 4),
			BackgroundTransparency = 1,
			Text = lab,
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(235, 238, 245),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 10,
			Parent = Card,
		})
		C("TextLabel", {
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.new(0, 6, 1, -22),
			BackgroundTransparency = 1,
			Text = gun,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 10,
			Parent = Card,
		})

		if selected then
			local X = C("TextButton", {
				Size = UDim2.new(0, 22, 0, 22),
				Position = UDim2.new(1, -26, 0, 4),
				BackgroundColor3 = Color3.fromRGB(40, 42, 52),
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 11,
				Parent = Card,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = X })
			iconCloseX(X, C, 12, Color3.fromRGB(190, 190, 200))
			X.MouseButton1Click:Connect(function()
				if S._crimSkinClear then
					local ok, msg = S._crimSkinClear(gun)
					if showNotify then
						showNotify(tostring(msg or (ok and "cleared" or "fail")))
					end
				end
				persistSkins()
				refreshWeaponSidebar()
				refreshSkinGrid()
			end)
		end

		Card.MouseButton1Click:Connect(function()
			if S._crimSkinPick then
				local ok2, msg = S._crimSkinPick(gun, row.full)
				if showNotify then
					showNotify(tostring(msg or (ok2 and "applied" or "fail")))
				end
			end
			persistSkins()
			refreshWeaponSidebar()
			refreshSkinGrid()
		end)
		return true
	end

	refreshSkinGrid = function()
		for _, ch in ipairs(GridScroll:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
		local gun = skinUi.weapon
		local rows = {}
		if S._crimSkinListSkins and gun then
			local ok, list = pcall(S._crimSkinListSkins, gun)
			if ok and typeof(list) == "table" then
				rows = list
			end
		end
		local q = string.lower(skinUi.filter or "")
		local saved = S._crimSkinSaved and S._crimSkinSaved(gun)
		local order = 0
		local shown = 0

		local AddCard = C("TextButton", {
			BackgroundColor3 = Color3.fromRGB(18, 22, 32),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = 0,
			ZIndex = 8,
			Parent = GridScroll,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = AddCard })
		C("UIStroke", { Color = Color3.fromRGB(50, 60, 85), Thickness = 1, Transparency = 0.3, Parent = AddCard })
		local plusLbl = C("TextLabel", {
			Size = UDim2.new(0, 44, 0, 44),
			Position = UDim2.new(0.5, -22, 0.5, -36),
			BackgroundColor3 = Color3.fromRGB(28, 34, 50),
			Text = "+",
			Font = Enum.Font.GothamBold,
			TextSize = 26,
			TextColor3 = SKIN_ACCENT,
			ZIndex = 9,
			Parent = AddCard,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = plusLbl })
		C("TextLabel", {
			Size = UDim2.new(1, -12, 0, 18),
			Position = UDim2.new(0, 6, 1, -36),
			BackgroundTransparency = 1,
			Text = "Refresh list",
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(170, 180, 200),
			ZIndex = 9,
			Parent = AddCard,
		})
		AddCard.MouseButton1Click:Connect(function()
			refreshWeaponSidebar()
			refreshSkinGrid()
			if showNotify then
				showNotify("Skin list refreshed")
			end
		end)

		for _, row in ipairs(rows) do
			local lab = row.label or row.full
			if q == "" or string.find(string.lower(lab), q, 1, true) or string.find(string.lower(gun or ""), q, 1, true) then
				order = order + 1
				if makeSkinCard(GridScroll, gun, row, order, saved == row.full) then
					shown = shown + 1
				end
			end
		end

		if shown == 0 then
			StatusLbl.Text = gun and "No skins" or "Pick a weapon"
		else
			local savedLab = nil
			if saved then
				local us = string.find(saved, "_", 1, true)
				savedLab = us and string.sub(saved, us + 1) or saved
			end
			StatusLbl.Text = string.format("%s · %d%s", gun or "?", shown, savedLab and (" · " .. savedLab) or "")
		end
	end

	for i, def in ipairs(classDefs) do
		local B = C("TextButton", {
			Size = UDim2.new(0, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(22, 24, 34),
			Text = "  " .. def.label .. "  ",
			Font = Enum.Font.GothamSemibold,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(200, 205, 220),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 8,
			Parent = ClassWrap,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = B })
		local stroke = C("UIStroke", { Color = def.color, Thickness = 1.5, Transparency = 0.35, Parent = B })
		classBtns[def.key] = { btn = B, stroke = stroke, color = def.color }
		B.MouseButton1Click:Connect(function()
			classFilter = def.key
			for k, info in pairs(classBtns) do
				info.stroke.Transparency = (k == classFilter) and 0.05 or 0.45
				info.btn.BackgroundColor3 = (k == classFilter) and Color3.fromRGB(30, 36, 52) or Color3.fromRGB(22, 24, 34)
			end
			refreshSkinGrid()
		end)
	end
	if classBtns.all then
		classBtns.all.stroke.Transparency = 0.05
		classBtns.all.btn.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
	end

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		skinUi.filter = SearchBox.Text or ""
		refreshWeaponSidebar()
		refreshSkinGrid()
	end)

	BtnSelect.MouseButton1Click:Connect(function()
		refreshWeaponSidebar()
		refreshSkinGrid()
		if showNotify then
			showNotify("Selected: " .. tostring(skinUi.weapon))
		end
	end)
	BtnClear.MouseButton1Click:Connect(function()
		if S._crimSkinClear then
			local ok, msg = S._crimSkinClear(skinUi.weapon)
			if showNotify then
				showNotify(tostring(msg or (ok and "cleared" or "fail")))
			end
		end
		persistSkins()
		refreshWeaponSidebar()
		refreshSkinGrid()
	end)

	MakeButton(CSkins, nil, 3, function()
		if S._crimSkinDump then
			local ok, msg = S._crimSkinDump()
			if showNotify then
				showNotify(tostring(msg or (ok and "dumped" or "fail")))
			end
		end
	end, "btn_crim_skin_dump")
	MakeHint(CSkins, "hint_crim_skinchanger_vault", 4)

	task.defer(function()
		task.wait(0.15)
		refreshWeaponSidebar()
		refreshSkinGrid()
	end)
	_G.__VG_RefreshSkinUi = function()
		refreshWeaponSidebar()
		refreshSkinGrid()
	end
end

return UISkinVault
