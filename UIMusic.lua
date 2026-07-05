-- Plik: workspace/Vanguard/UIMusic.lua

local UIMusic = {}

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%d:%02d", m, s)
end

function UIMusic.build(env)
	local page = env.TMusic
	local S = env.S
	local C = env.C
	local ACC = env.ACC
	local Music = env.Music
	local MakeCard = env.MakeCard
	local MakeSlider = env.MakeSlider
	local MakeTog = env.MakeTog
	local showNotify = env.showNotify
	local setFooterStatus = env.setFooterStatus
	local TweenPlay = env.TweenPlay

	local tabCol = env.tabCol or ACC

	local NowTitle
	local NowArtist
	local NowStatus
	local ProgressFill
	local ProgressTrack
	local TimeCur
	local TimeDur
	local PlayPauseBtn
	local PlayIcon
	local PauseIcon
	local ResultsHost
	local SearchBox
	local SearchStatus

	local function refreshNowPlaying(state)
		state = state or (Music and Music.GetState and Music.GetState()) or {}
		if NowTitle then
			if state.loading then
				NowTitle.Text = "Ładowanie..."
				NowArtist.Text = state.title ~= "" and state.title or "Archive.org"
				NowStatus.Text = "Pobieranie audio..."
			elseif state.playing or state.paused then
				NowTitle.Text = state.title ~= "" and state.title or "—"
				NowArtist.Text = state.artist ~= "" and state.artist or "Internet Archive"
				NowStatus.Text = state.paused and "Pauza" or "Odtwarzanie · tylko Ty słyszysz"
			else
				NowTitle.Text = "Nic nie gra"
				NowArtist.Text = "Szukaj hitów na Archive.org"
				NowStatus.Text = state.error or "Wpisz np. Modjo Lady, Stereo Love"
			end
		end
		if PlayIcon and PauseIcon then
			local showPause = state.playing and not state.paused
			PlayIcon.Visible = not showPause
			PauseIcon.Visible = showPause
		end
		if TimeCur then
			TimeCur.Text = fmtTime(state.position)
		end
		if TimeDur then
			TimeDur.Text = fmtTime(state.duration)
		end
		if ProgressFill and state.duration and state.duration > 0 then
			local p = math.clamp(state.position / state.duration, 0, 1)
			ProgressFill.Size = UDim2.new(p, 0, 1, 0)
		elseif ProgressFill then
			ProgressFill.Size = UDim2.new(0, 0, 1, 0)
		end
	end

	local function clearResults()
		if not ResultsHost then
			return
		end
		for _, ch in ipairs(ResultsHost:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
	end

	local function addResultRow(item, order)
		local initial = string.sub(item.title or "?", 1, 1):upper()
		local Row = C("TextButton", {
			Size = UDim2.new(1, -4, 0, 52),
			BackgroundColor3 = Color3.fromRGB(18, 18, 22),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 6,
			Parent = ResultsHost,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Row })

		local Art = C("Frame", {
			Size = UDim2.new(0, 40, 0, 40),
			Position = UDim2.new(0, 8, 0.5, -20),
			BackgroundColor3 = tabCol,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Art })
		C("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = initial,
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(12, 12, 16),
			ZIndex = 8,
			Parent = Art,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -120, 0, 16),
			Position = UDim2.new(0, 56, 0, 10),
			BackgroundTransparency = 1,
			Text = item.title or "?",
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(230, 230, 238),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -120, 0, 14),
			Position = UDim2.new(0, 56, 0, 28),
			BackgroundTransparency = 1,
			Text = item.creator or "Unknown",
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(120, 120, 135),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 48, 1, 0),
			Position = UDim2.new(1, -56, 0, 0),
			BackgroundTransparency = 1,
			Text = "▶",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = tabCol,
			ZIndex = 7,
			Parent = Row,
		})

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) })
		end)
		Row.MouseButton1Click:Connect(function()
			if not Music then
				return
			end
			showNotify("Ładowanie: " .. (item.title or "?"))
			Music.Play(item)
			setFooterStatus("Music · " .. (item.title or "?"))
		end)
	end

	local function runSearch(query)
		if not Music then
			return
		end
		query = query or (SearchBox and SearchBox.Text) or ""
		if SearchStatus then
			SearchStatus.Text = "Szukam na Archive.org..."
		end
		clearResults()
		Music.Search(query, function(results, err)
			clearResults()
			if err and #results == 0 then
				if SearchStatus then
					SearchStatus.Text = err
				end
				showNotify(err)
				return
			end
			if SearchStatus then
				SearchStatus.Text = #results .. " wyników · archive.org"
			end
			for i, item in ipairs(results) do
				addResultRow(item, i)
			end
		end)
	end

	-- // Now Playing
	local NPlay = MakeCard(page, "NOW PLAYING", "Internet Archive · słyszysz tylko Ty (PlayLocalSound).", 1)

	local TopRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = NPlay,
	})

	local ArtBig = C("Frame", {
		Size = UDim2.new(0, 56, 0, 56),
		BackgroundColor3 = tabCol,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = TopRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ArtBig })

	local InfoCol = C("Frame", {
		Size = UDim2.new(1, -68, 0, 56),
		Position = UDim2.new(0, 68, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = TopRow,
	})

	NowTitle = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Nic nie gra",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(240, 240, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = InfoCol,
	})
	NowArtist = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Szukaj hitów na Archive.org",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(130, 130, 145),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = InfoCol,
	})
	NowStatus = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "Wpisz np. Modjo Lady, Stereo Love",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(95, 95, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = InfoCol,
	})

	local CtrlRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		ZIndex = 6,
		Parent = NPlay,
	})

	PlayPauseBtn = C("TextButton", {
		Size = UDim2.new(0, 36, 0, 36),
		BackgroundColor3 = tabCol,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = CtrlRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayPauseBtn })
	PlayIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(12, 12, 16),
		ZIndex = 8,
		Parent = PlayPauseBtn,
	})
	PauseIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "❚❚",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(12, 12, 16),
		Visible = false,
		ZIndex = 8,
		Parent = PlayPauseBtn,
	})

	local StopBtn = C("TextButton", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 44, 0, 0),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		Text = "■",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = CtrlRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = StopBtn })

	PlayPauseBtn.MouseButton1Click:Connect(function()
		if Music then
			Music.TogglePause()
		end
	end)
	StopBtn.MouseButton1Click:Connect(function()
		if Music then
			Music.Stop()
			showNotify("Muzyka zatrzymana")
		end
	end)

	local ProgressRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		ZIndex = 6,
		Parent = NPlay,
	})

	TimeCur = C("TextLabel", {
		Size = UDim2.new(0, 36, 1, 0),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(130, 130, 145),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = ProgressRow,
	})

	ProgressTrack = C("Frame", {
		Size = UDim2.new(1, -88, 0, 4),
		Position = UDim2.new(0, 40, 0.5, -2),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = ProgressRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack })
	ProgressFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = tabCol,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressFill })

	TimeDur = C("TextLabel", {
		Size = UDim2.new(0, 36, 1, 0),
		Position = UDim2.new(1, -36, 0, 0),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(130, 130, 145),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
		Parent = ProgressRow,
	})

	MakeSlider(NPlay, "Volume", "MusicVolume", 0, 1, 7, {
		step = 0.01,
		fmt = function(v)
			return math.floor(v * 100) .. "%"
		end,
		onChange = function(v)
			if Music then
				Music.SetVolume(v)
			end
		end,
	})
	MakeTog(NPlay, "Loop Track", "MusicLoop", 8, { flat = true })

	-- // Search
	local SCard = MakeCard(page, "SEARCH", "Hitów może nie być — Archive to uploady użytkowników.", 2)

	local SearchRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = SCard,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = SearchRow })
	C("UIStroke", { Color = Color3.fromRGB(38, 38, 48), Thickness = 1, Parent = SearchRow })

	SearchBox = C("TextBox", {
		Size = UDim2.new(1, -88, 1, -8),
		Position = UDim2.new(0, 12, 0, 4),
		BackgroundTransparency = 1,
		Text = S.MusicLastQuery or "",
		PlaceholderText = "Modjo Lady, Stereo Love, SVM!R NDA...",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(230, 230, 235),
		PlaceholderColor3 = Color3.fromRGB(80, 80, 95),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = SearchRow,
	})

	local SearchBtn = C("TextButton", {
		Size = UDim2.new(0, 64, 0, 28),
		Position = UDim2.new(1, -72, 0.5, -14),
		BackgroundColor3 = tabCol,
		Text = "Szukaj",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(12, 12, 16),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = SearchRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SearchBtn })

	local ChipsWrap = C("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = SCard,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ChipsWrap,
	})

	local chips = {
		{ "Lady", "Modjo Lady Hear Me Tonight" },
		{ "Stereo Love", "Stereo Love Edward Maya" },
		{ "NDA", "SVM!R NDA" },
		{ "Phonk", "phonk mix" },
	}
	for i, c in ipairs(chips) do
		local Chip = C("TextButton", {
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(24, 24, 30),
			Text = "  " .. c[1] .. "  ",
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = Color3.fromRGB(180, 180, 195),
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 7,
			Parent = ChipsWrap,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Chip })
		local q = c[2]
		Chip.MouseButton1Click:Connect(function()
			if SearchBox then
				SearchBox.Text = q
			end
			runSearch(q)
		end)
	end

	SearchBtn.MouseButton1Click:Connect(function()
		runSearch(SearchBox and SearchBox.Text)
	end)
	SearchBox.FocusLost:Connect(function(enter)
		if enter then
			runSearch(SearchBox.Text)
		end
	end)

	-- // Results
	local RCard = MakeCard(page, "RESULTS", nil, 3)
	SearchStatus = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "Wpisz frazę i kliknij Szukaj",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(100, 100, 115),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = RCard,
	})

	ResultsHost = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = RCard,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ResultsHost,
	})

	if Music then
		Music.onStateChanged = refreshNowPlaying
		Music.onProgress = function(pos, dur)
			if TimeCur then
				TimeCur.Text = fmtTime(pos)
			end
			if TimeDur then
				TimeDur.Text = fmtTime(dur)
			end
			if ProgressFill and dur > 0 then
				ProgressFill.Size = UDim2.new(math.clamp(pos / dur, 0, 1), 0, 1, 0)
			end
		end
		Music.onPlayError = function(msg)
			showNotify(tostring(msg))
			refreshNowPlaying(Music.GetState())
		end
	end

	refreshNowPlaying()
end

return UIMusic
