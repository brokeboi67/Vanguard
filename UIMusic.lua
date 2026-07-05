-- Plik: workspace/Vanguard/UIMusic.lua

local UIMusic = {}

local langRefs = {}

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
	local I18n = env.I18n
	local L = function(key, ...)
		if I18n and I18n.t then
			return I18n.t(key, ...)
		end
		return tostring(key)
	end
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
	local QueueHost
	local lastSearchResults = {}
	local SourceAutoBtn
	local SourceYoutubeBtn
	local SourceAudiusBtn
	local SourceArchiveBtn
	local ArtFrame
	local searchToken = 0

	local function setSearchStatus(text)
		if SearchStatus then
			SearchStatus.Text = text
		end
	end

	local function clearQueueRows()
		if not QueueHost then
			return
		end
		for _, ch in ipairs(QueueHost:GetChildren()) do
			if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
	end

	local function refreshQueue(state)
		if not QueueHost then
			return
		end
		clearQueueRows()
		local items, idx = {}, 0
		if Music and Music.GetQueue then
			items, idx = Music.GetQueue()
		end
		if #items == 0 then
			return
		end
		for i, item in ipairs(items) do
			local active = i == idx
			local Row = C("Frame", {
				Size = UDim2.new(1, -4, 0, 28),
				BackgroundColor3 = active and Color3.fromRGB(24, 40, 30) or BG2,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 8,
				Parent = QueueHost,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Row })
			local PlayHit = C("TextButton", {
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 9,
				Parent = Row,
			})
			C("TextLabel", {
				Size = UDim2.new(0, 18, 1, 0),
				Position = UDim2.new(0, 6, 0, 0),
				BackgroundTransparency = 1,
				Text = active and "♪" or tostring(i),
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				TextColor3 = active and SPOTIFY or MUT,
				ZIndex = 9,
				Parent = Row,
			})
			C("TextLabel", {
				Size = UDim2.new(1, -56, 1, 0),
				Position = UDim2.new(0, 26, 0, 0),
				BackgroundTransparency = 1,
				Text = item.title or "?",
				Font = active and Enum.Font.GothamSemibold or Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = active and TXT or MUT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 9,
				Parent = Row,
			})
			PlayHit.MouseButton1Click:Connect(function()
				if Music and Music.Play then
					Music.Play(items[i], { keepQueue = true })
					setFooterStatus("♪ " .. (item.title or "?"))
				end
			end)
			local RemoveBtn = C("TextButton", {
				Size = UDim2.new(0, 22, 1, 0),
				Position = UDim2.new(1, -24, 0, 0),
				BackgroundTransparency = 1,
				Text = "×",
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = MUT,
				AutoButtonColor = false,
				ZIndex = 10,
				Parent = Row,
			})
			RemoveBtn.MouseButton1Click:Connect(function()
				if Music and Music.RemoveFromQueue then
					Music.RemoveFromQueue(i)
				end
			end)
		end
	end

	local function refreshNowPlaying(state)
		state = state or (Music and Music.GetState and Music.GetState()) or {}
		if NowTitle then
			if state.playing or state.paused or state.hasTrack then
				NowTitle.Text = state.title ~= "" and state.title or "—"
				NowArtist.Text = state.paused and L("music_pause")
					or (state.artist ~= "" and state.artist or "Audius")
			elseif state.loading then
				NowTitle.Text = state.title ~= "" and state.title or L("music_loading")
				NowArtist.Text = L("music_downloading")
			else
				NowTitle.Text = L("music_pick_track")
				local src = Music and Music.GetSource and Music.GetSource() or "auto"
				local srcLabel = "Auto"
				if src == "archive" then
					srcLabel = "Archive.org"
				elseif src == "audius" then
					srcLabel = "Audius"
				elseif src == "youtube" then
					srcLabel = "YouTube"
				end
				NowArtist.Text = state.error or (srcLabel .. " · " .. L("music_only_you"))
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
		refreshQueue(state)
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
		local Row = C("Frame", {
			Size = UDim2.new(1, -8, 0, 48),
			BackgroundColor3 = BG2,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = ResultsHost,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })

		local PlayHit = C("TextButton", {
			Size = UDim2.new(1, -36, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = Row,
		})

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
			Text = (item.creator or "Unknown")
				.. (item.source == "audius" and (" · " .. L("music_playable"))
					or (item.source == "youtube" and (" · " .. L("music_yt_hint")) or "")),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = MUT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 22, 1, 0),
			Position = UDim2.new(1, -52, 0, 0),
			BackgroundTransparency = 1,
			Text = "▶",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = SPOTIFY,
			TextTransparency = 0.35,
			ZIndex = 9,
			Parent = Row,
		})

		local AddBtn = C("TextButton", {
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(1, -30, 0.5, -13),
			BackgroundColor3 = BG3,
			Text = "+",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = SPOTIFY,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = AddBtn })
		AddBtn.MouseButton1Click:Connect(function()
			if not Music or not Music.AddToQueue then
				return
			end
			local ok, err = Music.AddToQueue(item)
			if ok then
				showNotify(L("music_added_queue"), { type = "success" })
			else
				showNotify(tostring(err or L("music_already_queue")), { type = "warn" })
			end
		end)

		Row.MouseEnter:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundColor3 = BG3 })
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundColor3 = BG2 })
		end)
		PlayHit.MouseButton1Click:Connect(function()
			if not Music then
				return
			end
			if Music.IsBusy and Music.IsBusy() then
				return
			end
			Music.Play(item)
			setFooterStatus("♪ " .. (item.title or "?"))
		end)
	end

	local function refreshSourceButtons()
		local src = Music and Music.GetSource and Music.GetSource() or "auto"
		if SourceAutoBtn then
			SourceAutoBtn.BackgroundColor3 = src == "auto" and SPOTIFY or BG2
			SourceAutoBtn.TextColor3 = src == "auto" and Color3.fromRGB(8, 8, 10) or MUT
		end
		if SourceYoutubeBtn then
			SourceYoutubeBtn.BackgroundColor3 = src == "youtube" and SPOTIFY or BG2
			SourceYoutubeBtn.TextColor3 = src == "youtube" and Color3.fromRGB(8, 8, 10) or MUT
		end
		if SourceAudiusBtn then
			SourceAudiusBtn.BackgroundColor3 = src == "audius" and SPOTIFY or BG2
			SourceAudiusBtn.TextColor3 = src == "audius" and Color3.fromRGB(8, 8, 10) or MUT
		end
		if SourceArchiveBtn then
			SourceArchiveBtn.BackgroundColor3 = src == "archive" and SPOTIFY or BG2
			SourceArchiveBtn.TextColor3 = src == "archive" and Color3.fromRGB(8, 8, 10) or MUT
		end
	end

	local searchPending = false

	local function setSource(src)
		if Music and Music.SetSource then
			Music.SetSource(src)
		end
		refreshSourceButtons()
		local labels = {
			auto = L("music_src_auto"),
			audius = L("music_src_audius"),
			youtube = L("music_src_youtube"),
			archive = L("music_src_archive"),
		}
		setSearchStatus(L("music_status_source", labels[src] or labels.auto))
	end

	local function runSearch(query)
		if not Music then
			warn("[Vanguard Music] Music module nil — UI bez backendu")
			setSearchStatus(L("music_no_module"))
			return
		end
		query = query or (SearchBox and SearchBox.Text) or ""
		searchToken += 1
		local token = searchToken
		searchPending = true
		setSearchStatus(L("music_searching"))
		clearResults()

		task.delay(15, function()
			if token ~= searchToken then
				return
			end
			if searchPending then
				setSearchStatus(L("music_search_timeout"))
				warn("[Vanguard Music] UI timeout — callback wyszukiwania nie wrócił w 15s")
			end
		end)

		Music.Search(query, function(results, err)
			searchPending = false
			if token ~= searchToken then
				return
			end
			clearResults()
			if err and #results == 0 then
				setSearchStatus(err)
				showNotify(err, { type = "error" })
				return
			end
			setSearchStatus(L("music_results", #results, err and (" · " .. err) or ""))
			lastSearchResults = results
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
		PlaceholderText = L("music_search_ph"),
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
		Text = L("music_search_btn"),
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
		{ "Human Nature", "human nature michael jackson" },
		{ "MJ", "Michael Jackson" },
		{ "Stereo Love", "Stereo Love Edward Maya" },
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
		Text = L("music_status_auto"),
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = Root,
	})

	local SourceRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 6,
		Parent = Root,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = SourceRow,
	})

	SourceAudiusBtn = C("TextButton", {
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BG2,
		Text = "  Audius  ",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 7,
		Parent = SourceRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SourceAudiusBtn })

	SourceAutoBtn = C("TextButton", {
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BG2,
		Text = "  Auto  ",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = 7,
		Parent = SourceRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SourceAutoBtn })

	SourceYoutubeBtn = C("TextButton", {
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BG2,
		Text = "  YouTube  ",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 7,
		Parent = SourceRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SourceYoutubeBtn })

	SourceArchiveBtn = C("TextButton", {
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BG2,
		Text = "  Archive  ",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		ZIndex = 7,
		Parent = SourceRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SourceArchiveBtn })

	SourceAutoBtn.MouseButton1Click:Connect(function()
		setSource("auto")
	end)
	SourceYoutubeBtn.MouseButton1Click:Connect(function()
		setSource("youtube")
	end)
	SourceAudiusBtn.MouseButton1Click:Connect(function()
		setSource("audius")
	end)
	SourceArchiveBtn.MouseButton1Click:Connect(function()
		setSource("archive")
	end)
	refreshSourceButtons()

	local ResultsScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = BG,
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(50, 50, 58),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = 5,
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
		LayoutOrder = 6,
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
		Size = UDim2.new(1, -148, 0, 44),
		Position = UDim2.new(0, 52, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = PlayerTop,
	})

	NowTitle = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = L("music_pick_track"),
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
		Text = "Archive.org · " .. L("music_only_you"),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
		Parent = InfoCol,
	})

	local CtrlCol = C("Frame", {
		Size = UDim2.new(0, 88, 0, 44),
		Position = UDim2.new(1, -88, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = PlayerTop,
	})

	local PrevBtn = C("TextButton", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(0, 0, 0.5, -11),
		BackgroundTransparency = 1,
		Text = "⏮",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = MUT,
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = CtrlCol,
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

	local NextBtn = C("TextButton", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -22, 0.5, -11),
		BackgroundTransparency = 1,
		Text = "⏭",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = MUT,
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = CtrlCol,
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
	PrevBtn.MouseButton1Click:Connect(function()
		if Music and Music.PlayPrevious then
			Music.PlayPrevious()
		end
	end)
	NextBtn.MouseButton1Click:Connect(function()
		if Music and Music.PlayNext then
			Music.PlayNext()
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

	local QueueSection = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
		ZIndex = 7,
		Parent = Player,
	})
	C("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = QueueSection })

	local QueueLabel = C("TextLabel", {
		Size = UDim2.new(1, -60, 0, 14),
		BackgroundTransparency = 1,
		Text = L("music_queue_label"),
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 8,
		Parent = QueueSection,
	})

	local ClearQueueBtn = C("TextButton", {
		Size = UDim2.new(0, 52, 0, 14),
		Position = UDim2.new(1, -52, 0, 0),
		BackgroundTransparency = 1,
		Text = L("music_clear_queue"),
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		TextColor3 = MUT,
		AutoButtonColor = false,
		LayoutOrder = 1,
		ZIndex = 9,
		Parent = QueueSection,
	})
	ClearQueueBtn.MouseButton1Click:Connect(function()
		if Music and Music.ClearQueue then
			Music.ClearQueue()
			showNotify(L("music_queue_cleared"), { type = "info" })
		end
	end)

	local QueueScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.5,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(50, 50, 58),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = 7,
		Parent = QueueSection,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = QueueScroll })
	C("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = QueueScroll })

	QueueHost = C("Frame", {
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = QueueScroll,
	})
	C("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = QueueHost })

	local origRefreshQueue = refreshQueue
	refreshQueue = function(state)
		origRefreshQueue(state)
		local count = state and state.queueCount or 0
		if QueueSection then
			QueueSection.Visible = count > 0
		end
	end

	local OptRow = C("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
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
	MakeTog(OptRow, "Loop", "MusicLoop", 2, {
		flat = true,
		onChange = function(on)
			if Music and Music.SetLoop then
				Music.SetLoop(on)
			end
		end,
	})
	MakeTog(OptRow, L("music_auto_next"), "MusicAutoQueue", 3, {
		flat = true,
	})
	MakeTog(OptRow, L("music_mini_player"), "ShowMusicWidget", 4, {
		flat = true,
		onChange = function(on)
			if UIMusic._refreshWidget then
				UIMusic._refreshWidget(Music and Music.GetState and Music.GetState() or {})
			end
		end,
	})

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
			if PlayIcon and PauseIcon and Music.GetState then
				local st = Music.GetState()
				local showPause = st.playing and not st.paused
				PlayIcon.Visible = not showPause
				PauseIcon.Visible = showPause
			end
		end
		Music.onPlayError = function(msg)
			showNotify(tostring(msg), { type = "error" })
			refreshNowPlaying(Music.GetState())
		end
	end

	if I18n and I18n.registerText then
		I18n.registerText(SearchBox, "music_search_ph", nil, "PlaceholderText")
		I18n.registerText(SearchBtn, "music_search_btn")
		I18n.registerText(QueueLabel, "music_queue_label")
		I18n.registerText(ClearQueueBtn, "music_clear_queue")
	end

	langRefs.I18n = I18n
	langRefs.Music = Music
	langRefs.setSource = setSource
	langRefs.refreshNowPlaying = refreshNowPlaying

	refreshNowPlaying()
end

function UIMusic.refreshLang()
	local r = langRefs
	if not r.I18n then
		return
	end
	if r.Music and r.setSource then
		r.setSource(r.Music.GetSource and r.Music.GetSource() or "auto")
	end
	if r.refreshNowPlaying then
		r.refreshNowPlaying(r.Music and r.Music.GetState and r.Music.GetState() or {})
	end
	if UIMusic._refreshWidget and r.Music then
		UIMusic._refreshWidget(r.Music.GetState and r.Music.GetState() or {})
	end
end

function UIMusic.buildWidget(env)
	local S = env.S
	local C = env.C
	local Music = env.Music
	local I18n = env.I18n
	local L = function(key, ...)
		if I18n and I18n.t then
			return I18n.t(key, ...)
		end
		return tostring(key)
	end
	local ParentGUI = env.ParentGUI
	local TweenPlay = env.TweenPlay
	local TS = game:GetService("TweenService")
	local RS = game:GetService("RunService")

	local SPOTIFY = Color3.fromRGB(29, 185, 84)
	local BG = Color3.fromRGB(18, 18, 22)
	local BG2 = Color3.fromRGB(28, 28, 34)
	local TXT = Color3.fromRGB(245, 245, 248)
	local MUT = Color3.fromRGB(130, 130, 142)

	local function fmtTime(sec)
		sec = math.max(0, math.floor(sec or 0))
		return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
	end

	local widgetVisible = false
	local pulseConn = nil
	local activeTweens = {}

	local function cancelTweens()
		for _, tw in ipairs(activeTweens) do
			pcall(function()
				tw:Cancel()
			end)
		end
		table.clear(activeTweens)
	end

	local function tween(obj, info, props)
		local tw = TweenPlay(obj, info, props)
		table.insert(activeTweens, tw)
		return tw
	end

	local Root = C("Frame", {
		Name = "VanguardMusicWidget",
		Size = UDim2.new(0, 340, 0, 72),
		Position = UDim2.new(0, 18, 1, -88),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 80,
		Parent = ParentGUI,
	})

	local Shell = C("Frame", {
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ZIndex = 81,
		Parent = Root,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Shell })
	C("UIStroke", {
		Color = Color3.fromRGB(42, 42, 50),
		Thickness = 1,
		Transparency = 0.35,
		Parent = Shell,
	})

	local Glow = C("Frame", {
		Size = UDim2.new(1, 10, 1, 10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = SPOTIFY,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		ZIndex = 80,
		Parent = Shell,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 18), Parent = Glow })

	local ArtWrap = C("Frame", {
		Size = UDim2.new(0, 48, 0, 48),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = Shell,
	})
	local ArtScale = C("UIScale", { Scale = 1, Parent = ArtWrap })

	local ArtRing = C("Frame", {
		Size = UDim2.new(1, 6, 1, 6),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = SPOTIFY,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 82,
		Parent = ArtWrap,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ArtRing })

	local Art = C("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BG2,
		BorderSizePixel = 0,
		ZIndex = 83,
		Parent = ArtWrap,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Art })

	local ArtLetter = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "♪",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = SPOTIFY,
		ZIndex = 84,
		Parent = Art,
	})

	local InfoCol = C("Frame", {
		Size = UDim2.new(1, -168, 0, 48),
		Position = UDim2.new(0, 68, 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = Shell,
	})

	local TitleLbl = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "—",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 83,
		Parent = InfoCol,
	})

	local ArtistLbl = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Vanguard Music",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 83,
		Parent = InfoCol,
	})

	local ProgressTrack = C("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 1, -6),
		BackgroundColor3 = Color3.fromRGB(38, 38, 44),
		BorderSizePixel = 0,
		ZIndex = 83,
		Parent = InfoCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack })

	local ProgressFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 84,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressFill })

	local TimeLbl = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 83,
		Parent = InfoCol,
	})

	local PlayBtn = C("TextButton", {
		Size = UDim2.new(0, 38, 0, 38),
		Position = UDim2.new(1, -52, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = SPOTIFY,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 83,
		Parent = Shell,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayBtn })
	local PlayBtnScale = C("UIScale", { Scale = 1, Parent = PlayBtn })

	local PlayIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		ZIndex = 84,
		Parent = PlayBtn,
	})
	local PauseIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "❚❚",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		Visible = false,
		ZIndex = 84,
		Parent = PlayBtn,
	})

	local function setPulse(on)
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
		if not on then
			ArtRing.BackgroundTransparency = 0.85
			ArtScale.Scale = 1
			return
		end
		local t0 = os.clock()
		pulseConn = RS.Heartbeat:Connect(function()
			local wave = (math.sin((os.clock() - t0) * 3.2) + 1) * 0.5
			ArtRing.BackgroundTransparency = 0.55 + wave * 0.35
			ArtScale.Scale = 1 + wave * 0.04
		end)
	end

	local function showWidget(animateIn)
		if widgetVisible or S.ShowMusicWidget == false then
			return
		end
		widgetVisible = true
		Root.Visible = true
		if animateIn then
			cancelTweens()
			Shell.Position = UDim2.new(0, 0, 0, 14)
			Shell.BackgroundTransparency = 1
			tween(Shell, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 0.06,
			})
		end
	end

	local function hideWidget()
		if not widgetVisible then
			return
		end
		widgetVisible = false
		setPulse(false)
		cancelTweens()
		local tw = tween(Shell, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0, 18),
			BackgroundTransparency = 1,
		})
		tw.Completed:Connect(function()
			if not widgetVisible then
				Root.Visible = false
				Shell.Position = UDim2.new(0, 0, 0, 0)
			end
		end)
	end

	local function refreshWidget(state)
		state = state or (Music and Music.GetState and Music.GetState()) or {}
		local shouldShow = S.ShowMusicWidget ~= false
			and (state.hasTrack or state.loading or state.paused)

		if not shouldShow then
			hideWidget()
			return
		end

		local wasHidden = not widgetVisible
		showWidget(wasHidden)

		TitleLbl.Text = state.title ~= "" and state.title or (state.loading and L("music_loading") or "—")
		ArtistLbl.Text = state.paused and L("music_pause")
			or (state.loading and L("music_downloading")
				or (state.artist ~= "" and state.artist or "Audius"))

		local initial = string.sub(state.title or "?", 1, 1):upper()
		ArtLetter.Text = initial ~= "" and initial or "♪"

		local showPause = (state.playing and not state.paused) or state.loading
		PlayIcon.Visible = not showPause
		PauseIcon.Visible = showPause

		if state.duration and state.duration > 0 then
			ProgressFill.Size = UDim2.new(math.clamp(state.position / state.duration, 0, 1), 0, 1, 0)
			TimeLbl.Text = fmtTime(state.position) .. " / " .. fmtTime(state.duration)
		else
			ProgressFill.Size = UDim2.new(0, 0, 1, 0)
			TimeLbl.Text = state.loading and "..." or "0:00"
		end

		setPulse(state.playing and not state.paused and not state.loading)
	end

	UIMusic._refreshWidget = refreshWidget

	PlayBtn.MouseEnter:Connect(function()
		tween(PlayBtnScale, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1.08 })
	end)
	PlayBtn.MouseLeave:Connect(function()
		tween(PlayBtnScale, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
	end)
	PlayBtn.MouseButton1Click:Connect(function()
		tween(PlayBtnScale, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.92 })
		task.delay(0.08, function()
			tween(PlayBtnScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end)
		if Music and not (Music.IsBusy and Music.IsBusy()) then
			Music.TogglePause()
		end
	end)

	if Music then
		Music.AddStateListener(refreshWidget)
		local prevProgress = Music.onProgress
		Music.onProgress = function(pos, dur)
			if prevProgress then
				prevProgress(pos, dur)
			end
			if dur and dur > 0 then
				ProgressFill.Size = UDim2.new(math.clamp(pos / dur, 0, 1), 0, 1, 0)
				TimeLbl.Text = fmtTime(pos) .. " / " .. fmtTime(dur)
			end
			if Music.GetState then
				local st = Music.GetState()
				local showPause = st.playing and not st.paused
				PlayIcon.Visible = not showPause
				PauseIcon.Visible = showPause
			end
		end
	end

	refreshWidget(Music and Music.GetState and Music.GetState() or {})
end

return UIMusic
