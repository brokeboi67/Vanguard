-- Plik: workspace/Vanguard/UIConfigMenus.lua

local UIConfigMenus = {}

function UIConfigMenus.build(env)
	local T4 = env.T4
	local TMenu = env.TMenu
	local C = env.C
	local ACC = env.ACC
	local S = env.S
	local ParentGUI = env.ParentGUI
	local ConfigModule = env.ConfigModule
	local MenusModule = env.MenusModule
	local MakeSection = env.MakeSection
	local MakeButton = env.MakeButton
	local MakeHint = env.MakeHint
	local MakeCard = env.MakeCard
	local showNotify = env.showNotify
	local setFooterStatus = env.setFooterStatus
	local refreshAllControls = env.refreshAllControls
	local SettingsAutoloadLbl = env.SettingsAutoloadLbl
	local TweenPlay = env.TweenPlay

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
		if not ConfigModule then
			return
		end
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
		if not ConfigModule then
			return
		end
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
		if not ConfigModule then
			return
		end
		local ok, msg = ConfigModule.Delete(getConfigName())
		if ok then
			showNotify("Usunięto: " .. msg)
			refreshConfigList()
		else
			showNotify(msg or "Błąd usuwania")
		end
	end)
	MakeButton(T4, "Ustaw autoload", 7, function()
		if not ConfigModule then
			return
		end
		local ok, msg = ConfigModule.SetAutoload(getConfigName())
		if ok then
			showNotify("Autoload: " .. getConfigName())
			refreshConfigList()
		else
			showNotify(msg or "Błąd autoload")
		end
	end)
	MakeButton(T4, "Wyłącz autoload", 8, function()
		if not ConfigModule then
			return
		end
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

	return {
		refreshConfigList = refreshConfigList,
	}
end

return UIConfigMenus
