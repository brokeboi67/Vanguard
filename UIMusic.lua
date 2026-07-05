-- Plik: workspace/Vanguard/UIMusic.lua

local UIMusic = {}

local SPOTIFY = Color3.fromRGB(29, 185, 84)
local BG = Color3.fromRGB(12, 12, 14)
local BG2 = Color3.fromRGB(18, 18, 22)
local BG3 = Color3.fromRGB(24, 24, 28)
local TXT = Color3.fromRGB(235, 235, 240)
local MUT = Color3.fromRGB(115, 115, 128)

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
	local Music = env.Music
	local MakeSlider = env.MakeSlider
	local MakeTog = env.MakeTog
	local showNotify = env.showNotify
	local setFooterStatus = env.setFooterStatus
	local TweenPlay = env.TweenPlay

	local NowTitle
	local NowArtist
	local ProgressFill
	local TimeCur
	local TimeDur
	local PlayIcon
	local PauseIcon
	local ResultsHost
	local SearchBox
	local SearchStatus
	local ArtFrame

	local function refreshNowPlaying(state)
		state = state or (Music and Music.GetState and Music.GetState()) or {}
		if NowTitle then
			if state.loading then
				NowTitle.Text = state.title ~= "" and state.title or "Ładowanie..."
				NowArtist.Text = "Pobieranie z Archive..."
			elseif state.playing or state.paused then
				NowTitle.Text = state.title ~= "" and state.title or "—"
				NowArtist.Text = state.artist ~= "" and state.artist or "Internet Archive"
			else
				NowTitle.Text = "Wybierz utwór"
				NowArtist.Text = state.error or "Archive.org · tylko Ty słyszysz"
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
		if ProgressFill then
			if state.duration and state.duration > 0 then
				ProgressFill.Size = UDim2.new(math.clamp(state.position / state.duration, 0, 1), 0, 1, 0)
			else
				ProgressFill.Size = UDim2.new(0, 0, 1, 0)
			end
		end
	end

	local function clearResults()
		if not ResultsHost then
			return
		end
		for _, ch in ipairs(ResultsHost:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
	end

	local function addResultRow(item, order)
		local initial = string.sub(item.title or "?", 1, 1):upper()
		local Row = C("TextButton", {
			Size = UDim2.new(1, -8, 0, 48),
			BackgroundColor3 = BG2,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = ResultsHost,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })

		local Art = C("Frame", {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, 6, 0.5, -18),
			BackgroundColor3 = BG3,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Art })
		C("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = initial,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = SPOTIFY,
			ZIndex = 10,
			Parent = Art,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -96, 0, 16),
			Position = UDim2.new(0, 50, 0, 9),
			BackgroundTransparency = 1,
			Text = item.title or "?",
			Font = Enum.Font.GothamSemibold,
			TextSize = 11,
			TextColor3 = TXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -96, 0, 14),
			Position = UDim2.new(0, 50, 0, 26),
			BackgroundTransparency = 1,
			Text = item.creator or "Unknown",
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = MUT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 28, 1, 0),
			Position = UDim2.new(1, -34, 0, 0),
			BackgroundTransparency = 1,
			Text = "▶",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = SPOTIFY,
			TextTransparency = 0.35,
			ZIndex = 9,
			Parent = Row,
		})

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundColor3 = BG3 })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundColor3 = BG2 })
		end)
		Row.MouseButton1Click:Connect(function()
			if not Music then
				return
			end
			Music.Play(item)
			setFooterStatus("♪ " .. (item.title or "?"))
		end)
	end

	local function runSearch(query)
		if not Music then
			return
		end
		query = query or (SearchBox and SearchBox.Text) or ""
		if SearchStatus then
			SearchStatus.Text = "Szukam..."
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
				SearchStatus.Text = #results .. " wyników" .. (err and (" · " .. err) or "")
			end
			for i, item in ipairs(results) do
				addResultRow(item, i)
			end
		end)
	end

	local Root = C("Frame", {
		Size = UDim2.new(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 5,
		Parent = page,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Root })
	C("UIStroke", { Color = Color3.fromRGB(32, 32, 38), Thickness = 1, Parent = Root })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = Root,
	})
	C("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Root })

	-- Search
	local SearchRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = BG2,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = Root,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = SearchRow })

	SearchBox = C("TextBox", {
		Size = UDim2.new(1, -76, 1, -8),
		Position = UDim2.new(0, 12, 0, 4),
		BackgroundTransparency = 1,
		Text = S.MusicLastQuery or "",
		PlaceholderText = "Szukaj na Archive.org...",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = TXT,
		PlaceholderColor3 = MUT,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = SearchRow,
	})

	local SearchBtn = C("TextButton", {
		Size = UDim2.new(0, 56, 0, 26),
		Position = UDim2.new(1, -64, 0.5, -13),
		BackgroundColor3 = SPOTIFY,
		Text = "Szukaj",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = SearchRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SearchBtn })

	local ChipsWrap = C("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = Root,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ChipsWrap,
	})

	local chips = {
		{ "Lady", "Modjo Lady" },
		{ "Stereo Love", "Stereo Love Edward Maya" },
		{ "Phonk", "phonk mix" },
	}
	for i, c in ipairs(chips) do
		local Chip = C("TextButton", {
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = BG2,
			Text = "  " .. c[1] .. "  ",
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = MUT,
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

	SearchStatus = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Text = "Wpisz frazę lub wybierz tag",
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = Root,
	})

	local ResultsScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = BG,
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(50, 50, 58),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = Root,
	})
	C("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = ResultsScroll })

	ResultsHost = C("Frame", {
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = ResultsScroll,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ResultsHost,
	})

	-- Player bar
	local Player = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BG2,
		BorderSizePixel = 0,
		LayoutOrder = 5,
		ZIndex = 6,
		Parent = Root,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Player })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = Player,
	})
	C("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Player })

	local PlayerTop = C("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 7,
		Parent = Player,
	})

	ArtFrame = C("Frame", {
		Size = UDim2.new(0, 44, 0, 44),
		BackgroundColor3 = BG3,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = PlayerTop,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ArtFrame })
	C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "♪",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = SPOTIFY,
		ZIndex = 9,
		Parent = ArtFrame,
	})

	local InfoCol = C("Frame", {
		Size = UDim2.new(1, -108, 0, 44),
		Position = UDim2.new(0, 52, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = PlayerTop,
	})

	NowTitle = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "Wybierz utwór",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
		Parent = InfoCol,
	})
	NowArtist = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Archive.org · tylko Ty słyszysz",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
		Parent = InfoCol,
	})

	local CtrlCol = C("Frame", {
		Size = UDim2.new(0, 48, 0, 44),
		Position = UDim2.new(1, -48, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = PlayerTop,
	})

	local PlayPauseBtn = C("TextButton", {
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0.5, -16, 0.5, -16),
		BackgroundColor3 = SPOTIFY,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = CtrlCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayPauseBtn })
	PlayIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		ZIndex = 10,
		Parent = PlayPauseBtn,
	})
	PauseIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "❚❚",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		Visible = false,
		ZIndex = 10,
		Parent = PlayPauseBtn,
	})

	local StopBtn = C("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -24, 1, -24),
		BackgroundTransparency = 1,
		Text = "■",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = MUT,
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = PlayerTop,
	})

	PlayPauseBtn.MouseButton1Click:Connect(function()
		if Music then
			Music.TogglePause()
		end
	end)
	StopBtn.MouseButton1Click:Connect(function()
		if Music then
			Music.Stop()
		end
	end)

	local ProgressRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		ZIndex = 7,
		Parent = Player,
	})

	TimeCur = C("TextLabel", {
		Size = UDim2.new(0, 32, 1, 0),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = ProgressRow,
	})

	local ProgressTrack = C("Frame", {
		Size = UDim2.new(1, -72, 0, 3),
		Position = UDim2.new(0, 36, 0.5, -1),
		BackgroundColor3 = BG3,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = ProgressRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack })
	ProgressFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressFill })

	TimeDur = C("TextLabel", {
		Size = UDim2.new(0, 32, 1, 0),
		Position = UDim2.new(1, -32, 0, 0),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = ProgressRow,
	})

	local OptRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 7,
		Parent = Player,
	})
	C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = OptRow })

	MakeSlider(OptRow, "Volume", "MusicVolume", 0, 1, 1, {
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
	MakeTog(OptRow, "Loop", "MusicLoop", 2, { flat = true })

	SearchBtn.MouseButton1Click:Connect(function()
		runSearch(SearchBox and SearchBox.Text)
	end)
	SearchBox.FocusLost:Connect(function(enter)
		if enter then
			runSearch(SearchBox.Text)
		end
	end)

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
