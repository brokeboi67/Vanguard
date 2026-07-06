-- Plik: workspace/Vanguard/UIMusic.lua

local UIMusic = {}

local langRefs = {}

local SPOTIFY = Color3.fromRGB(29, 185, 84)
local BG = Color3.fromRGB(10, 10, 12)
local BG2 = Color3.fromRGB(16, 16, 20)
local BG3 = Color3.fromRGB(22, 22, 28)
local SURFACE = Color3.fromRGB(14, 14, 16)
local ELEV = Color3.fromRGB(22, 22, 28)
local HOVER = Color3.fromRGB(36, 36, 44)
local DIVIDER = Color3.fromRGB(34, 34, 42)
local TXT = Color3.fromRGB(245, 245, 248)
local MUT = Color3.fromRGB(120, 120, 132)

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
	local SourceLocalBtn
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
				Size = UDim2.new(1, -2, 0, 34),
				BackgroundColor3 = active and Color3.fromRGB(24, 40, 30) or HOVER,
				BackgroundTransparency = active and 0 or 1,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 8,
				Parent = QueueHost,
			})
			C("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Row })
			local PlayHit = C("TextButton", {
				Size = UDim2.new(1, -28, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 9,
				Parent = Row,
			})
			C("TextLabel", {
				Size = UDim2.new(0, 20, 1, 0),
				Position = UDim2.new(0, 4, 0, 0),
				BackgroundTransparency = 1,
				Text = active and "♪" or tostring(i),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = active and SPOTIFY or MUT,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 9,
				Parent = Row,
			})
			C("TextLabel", {
				Size = UDim2.new(1, -52, 0, 16),
				Position = UDim2.new(0, 26, 0, 6),
				BackgroundTransparency = 1,
				Text = item.title or "?",
				Font = active and Enum.Font.GothamSemibold or Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = active and TXT or Color3.fromRGB(200, 200, 210),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 9,
				Parent = Row,
			})
			Row.MouseEnter:Connect(function()
				if not active then
					TweenPlay(Row, TweenInfo.new(0.08), { BackgroundTransparency = 0, BackgroundColor3 = HOVER })
				end
			end)
			Row.MouseLeave:Connect(function()
				if not active then
					TweenPlay(Row, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
				end
			end)
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
				elseif src == "local" then
					srcLabel = "Local"
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
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = SURFACE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = ResultsHost,
		})

		C("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			BackgroundColor3 = DIVIDER,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = Row,
		})

		local PlayHit = C("TextButton", {
			Size = UDim2.new(1, -44, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(0, 28, 1, 0),
			Position = UDim2.new(0, 4, 0, 0),
			BackgroundTransparency = 1,
			Text = tostring(order),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = MUT,
			ZIndex = 9,
			Parent = Row,
		})

		local Art = C("Frame", {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, 34, 0.5, -18),
			BackgroundColor3 = ELEV,
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
			Size = UDim2.new(1, -130, 0, 16),
			Position = UDim2.new(0, 78, 0, 8),
			BackgroundTransparency = 1,
			Text = item.title or "?",
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextColor3 = TXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = Row,
		})

		C("TextLabel", {
			Size = UDim2.new(1, -130, 0, 14),
			Position = UDim2.new(0, 78, 0, 24),
			BackgroundTransparency = 1,
			Text = (item.creator or "Unknown")
				.. (item.source == "audius" and (" · " .. L("music_playable"))
					or (item.source == "youtube" and (" · " .. L("music_yt_hint"))
						or (item.source == "local" and (" · " .. L("music_local_hint")) or ""))),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = MUT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
			Parent = Row,
		})

		local AddBtn = C("TextButton", {
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(1, -36, 0.5, -14),
			BackgroundTransparency = 1,
			Text = "+",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = MUT,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = Row,
		})
		AddBtn.MouseEnter:Connect(function()
			AddBtn.TextColor3 = SPOTIFY
		end)
		AddBtn.MouseLeave:Connect(function()
			AddBtn.TextColor3 = MUT
		end)
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
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundTransparency = 0, BackgroundColor3 = HOVER })
			AddBtn.TextColor3 = SPOTIFY
		end)
		Row.MouseLeave:Connect(function()
			TweenPlay(Row, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
			AddBtn.TextColor3 = MUT
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

	local function styleSourceBtn(btn, active)
		if not btn then
			return
		end
		if active then
			btn.BackgroundColor3 = SPOTIFY
			btn.BackgroundTransparency = 0
			btn.TextColor3 = Color3.fromRGB(8, 8, 10)
		else
			btn.BackgroundTransparency = 1
			btn.TextColor3 = MUT
		end
	end

	local function refreshSourceButtons()
		local src = Music and Music.GetSource and Music.GetSource() or "auto"
		styleSourceBtn(SourceAutoBtn, src == "auto")
		styleSourceBtn(SourceYoutubeBtn, src == "youtube")
		styleSourceBtn(SourceAudiusBtn, src == "audius")
		styleSourceBtn(SourceArchiveBtn, src == "archive")
		styleSourceBtn(SourceLocalBtn, src == "local")
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
			["local"] = L("music_src_local"),
		}
		setSearchStatus(L("music_status_source", labels[src] or labels.auto))
		updateBodyLayout()
		if src == "local" then
			if LocalHelpLbl then
				local path = (Music and Music.GetLocalDir and Music.GetLocalDir()) or "VanguardMusic/local"
				LocalHelpLbl.Text = L("music_local_help", path)
			end
			task.defer(function()
				runSearch(SearchBox and SearchBox.Text or "")
			end)
		end
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

	local QueueEmptyLbl
	local QueueSection

	local function makeSourceBtn(parent, text, order)
		local B = C("TextButton", {
			Size = UDim2.new(0.2, -2, 1, -4),
			BackgroundColor3 = ELEV,
			Text = text,
			Font = Enum.Font.GothamSemibold,
			TextSize = 10,
			TextColor3 = MUT,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 8,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = B })
		return B
	end

	local PLAYER_H = 118
	local HEADER_H = 82
	local LOCAL_BAR_H = 36
	local LocalHelpLbl
	local Body
	local LocalBar

	local function makeCompactTog(parent, label, key, order, opts)
		opts = opts or {}
		local Btn = C("TextButton", {
			Size = UDim2.new(0, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = BG3,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 11,
			Parent = parent,
		})
		C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Btn })
		C("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = Btn,
		})
		local Title = C("TextLabel", {
			Size = UDim2.new(0, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = MUT,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 12,
			Parent = Btn,
		})
		local function paint()
			local on = S[key] == true
			Btn.BackgroundColor3 = on and Color3.fromRGB(24, 40, 30) or BG3
			Title.TextColor3 = on and SPOTIFY or MUT
		end
		Btn.MouseButton1Click:Connect(function()
			S[key] = not S[key]
			paint()
			if opts.onChange then
				pcall(opts.onChange, S[key])
			end
		end)
		paint()
		return Btn
	end

	local function updateBodyLayout()
		if not Body then
			return
		end
		local isLocal = Music and Music.GetSource and Music.GetSource() == "local"
		if LocalBar then
			LocalBar.Visible = isLocal == true
		end
		local barExtra = isLocal and (LOCAL_BAR_H + 4) or 0
		Body.Size = UDim2.new(1, -8, 1, -(HEADER_H + PLAYER_H + 6 + barExtra))
		Body.Position = UDim2.new(0, 4, 0, HEADER_H + 2 + barExtra)
	end

	local function openLocalFolder()
		if Music and Music.EnsureLocalDir then
			Music.EnsureLocalDir()
		end
		local path = (Music and Music.GetLocalDir and Music.GetLocalDir()) or "VanguardMusic/local"
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, path)
			showNotify(L("music_local_copied", path), { type = "info", duration = 6 })
		elseif typeof(toclipboard) == "function" then
			pcall(toclipboard, path)
			showNotify(L("music_local_copied", path), { type = "info", duration = 6 })
		else
			showNotify(L("music_local_path", path), { type = "info", duration = 8 })
		end
	end

	local Shell = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = page,
	})

	local Header = C("Frame", {
		Size = UDim2.new(1, -8, 0, HEADER_H),
		Position = UDim2.new(0, 4, 0, 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Shell,
	})

	local SearchShell = C("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = ELEV,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = Header,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SearchShell })

	SearchBox = C("TextBox", {
		Size = UDim2.new(1, -108, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Text = S.MusicLastQuery or "",
		PlaceholderText = L("music_search_ph"),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = TXT,
		PlaceholderColor3 = MUT,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = SearchShell,
	})

	local SearchBtn = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 30),
		Position = UDim2.new(1, -80, 0.5, -15),
		BackgroundColor3 = SPOTIFY,
		Text = L("music_search_btn"),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = SearchShell,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SearchBtn })

	local SegBar = C("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 46),
		BackgroundColor3 = ELEV,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = Header,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SegBar })
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = SegBar,
	})
	C("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		Parent = SegBar,
	})

	SourceAudiusBtn = makeSourceBtn(SegBar, "Audius", 1)
	SourceAutoBtn = makeSourceBtn(SegBar, "Auto", 2)
	SourceYoutubeBtn = makeSourceBtn(SegBar, "YouTube", 3)
	SourceArchiveBtn = makeSourceBtn(SegBar, "Archive", 4)
	SourceLocalBtn = makeSourceBtn(SegBar, "♪ Local", 5)

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
	SourceLocalBtn.MouseButton1Click:Connect(function()
		setSource("local")
	end)
	refreshSourceButtons()

	local BodyFrame = C("Frame", {
		Size = UDim2.new(1, -8, 1, -(HEADER_H + PLAYER_H + 6)),
		Position = UDim2.new(0, 4, 0, HEADER_H + 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Shell,
	})
	Body = BodyFrame

	LocalBar = C("Frame", {
		Size = UDim2.new(1, -8, 0, LOCAL_BAR_H),
		Position = UDim2.new(0, 4, 0, HEADER_H + 2),
		BackgroundColor3 = ELEV,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = Shell,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = LocalBar })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 8),
		Parent = LocalBar,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 18, 0, 18),
		BackgroundTransparency = 1,
		Text = "♪",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = SPOTIFY,
		ZIndex = 7,
		Parent = LocalBar,
	})

	LocalHelpLbl = C("TextLabel", {
		Size = UDim2.new(1, -196, 1, 0),
		Position = UDim2.new(0, 22, 0, 0),
		BackgroundTransparency = 1,
		Text = L("music_local_help", (Music and Music.GetLocalDir and Music.GetLocalDir()) or "VanguardMusic/local"),
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		ZIndex = 7,
		Parent = LocalBar,
	})

	local OpenLocalBtn = C("TextButton", {
		Size = UDim2.new(0, 88, 0, 24),
		Position = UDim2.new(1, -176, 0.5, -12),
		BackgroundColor3 = SPOTIFY,
		Text = L("music_local_open"),
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = LocalBar,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = OpenLocalBtn })
	OpenLocalBtn.MouseButton1Click:Connect(openLocalFolder)

	local RefreshLocalBtn = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 24),
		Position = UDim2.new(1, -80, 0.5, -12),
		BackgroundColor3 = BG3,
		Text = L("music_local_refresh"),
		Font = Enum.Font.GothamSemibold,
		TextSize = 9,
		TextColor3 = TXT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = LocalBar,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = RefreshLocalBtn })
	RefreshLocalBtn.MouseButton1Click:Connect(function()
		runSearch(SearchBox and SearchBox.Text or "")
	end)

	local ResultsPane = C("Frame", {
		Size = UDim2.new(0.63, -8, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Body,
	})

	C("TextLabel", {
		Size = UDim2.new(0, 28, 0, 16),
		BackgroundTransparency = 1,
		Text = "#",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
		Parent = ResultsPane,
	})
	C("TextLabel", {
		Size = UDim2.new(0, 120, 0, 16),
		Position = UDim2.new(0, 34, 0, 0),
		BackgroundTransparency = 1,
		Text = "Title",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = ResultsPane,
	})

	SearchStatus = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = L("music_status_auto"),
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = ResultsPane,
	})

	local ResultsScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.new(0, 0, 0, 32),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = ResultsPane,
	})

	ResultsHost = C("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = ResultsScroll,
	})
	C("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ResultsHost,
	})

	QueueSection = C("Frame", {
		Size = UDim2.new(0.37, -4, 1, 0),
		Position = UDim2.new(0.63, 12, 0, 0),
		BackgroundColor3 = ELEV,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = Body,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = QueueSection })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 8),
		Parent = QueueSection,
	})

	local QueueLabel = C("TextLabel", {
		Size = UDim2.new(1, -56, 0, 16),
		BackgroundTransparency = 1,
		Text = L("music_queue_label"),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = QueueSection,
	})

	local ClearQueueBtn = C("TextButton", {
		Size = UDim2.new(0, 52, 0, 16),
		Position = UDim2.new(1, -52, 0, 0),
		BackgroundTransparency = 1,
		Text = L("music_clear_queue"),
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		ZIndex = 9,
		Parent = QueueSection,
	})
	ClearQueueBtn.MouseButton1Click:Connect(function()
		if Music and Music.ClearQueue then
			Music.ClearQueue()
			showNotify(L("music_queue_cleared"), { type = "info" })
		end
	end)

	QueueEmptyLbl = C("TextLabel", {
		Size = UDim2.new(1, -8, 0, 40),
		Position = UDim2.new(0, 0, 0.5, -20),
		BackgroundTransparency = 1,
		Text = L("music_queue_empty"),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 8,
		Parent = QueueSection,
	})

	local QueueScroll = C("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -26),
		Position = UDim2.new(0, 0, 0, 22),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = QueueSection,
	})

	QueueHost = C("Frame", {
		Size = UDim2.new(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = QueueScroll,
	})
	C("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = QueueHost })

	local origRefreshQueue = refreshQueue
	refreshQueue = function(state)
		origRefreshQueue(state)
		local count = state and state.queueCount or 0
		if QueueEmptyLbl then
			QueueEmptyLbl.Visible = count == 0
		end
		if QueueScroll then
			QueueScroll.Visible = count > 0
		end
	end

	local PlayerDock = C("Frame", {
		Size = UDim2.new(1, 0, 0, PLAYER_H),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = Shell,
	})
	C("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = DIVIDER,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = PlayerDock,
	})

	local ProgressTrack = C("Frame", {
		Size = UDim2.new(1, -24, 0, 3),
		Position = UDim2.new(0, 12, 0, 8),
		BackgroundColor3 = BG3,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = PlayerDock,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack })
	ProgressFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressFill })

	TimeCur = C("TextLabel", {
		Size = UDim2.new(0, 36, 0, 12),
		Position = UDim2.new(0, 12, 0, 14),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		Parent = PlayerDock,
	})
	TimeDur = C("TextLabel", {
		Size = UDim2.new(0, 36, 0, 12),
		Position = UDim2.new(1, -48, 0, 14),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 10,
		Parent = PlayerDock,
	})

	local PlayerRow = C("Frame", {
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.new(0, 8, 0, 28),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = PlayerDock,
	})

	ArtFrame = C("Frame", {
		Size = UDim2.new(0, 48, 0, 48),
		BackgroundColor3 = BG3,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = PlayerRow,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ArtFrame })
	C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "♪",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = SPOTIFY,
		ZIndex = 11,
		Parent = ArtFrame,
	})

	local InfoCol = C("Frame", {
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = UDim2.new(0, 58, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = PlayerRow,
	})
	NowTitle = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = L("music_pick_track"),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
		Parent = InfoCol,
	})
	NowArtist = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = L("music_only_you"),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
		Parent = InfoCol,
	})

	local CtrlCol = C("Frame", {
		Size = UDim2.new(0, 120, 1, 0),
		Position = UDim2.new(0.5, -60, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = PlayerRow,
	})
	local PrevBtn = C("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 0, 0.5, -14),
		BackgroundTransparency = 1,
		Text = "⏮",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = TXT,
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = CtrlCol,
	})
	local PlayPauseBtn = C("TextButton", {
		Size = UDim2.new(0, 38, 0, 38),
		Position = UDim2.new(0.5, -19, 0.5, -19),
		BackgroundColor3 = TXT,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = CtrlCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayPauseBtn })
	PlayIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		ZIndex = 12,
		Parent = PlayPauseBtn,
	})
	PauseIcon = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "❚❚",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		Visible = false,
		ZIndex = 12,
		Parent = PlayPauseBtn,
	})
	local NextBtn = C("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -28, 0.5, -14),
		BackgroundTransparency = 1,
		Text = "⏭",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = TXT,
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = CtrlCol,
	})

	local StopBtn = C("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -28, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "■",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = MUT,
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = PlayerRow,
	})

	local SettingsRow = C("Frame", {
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 1, -6),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = PlayerDock,
	})

	local VolLbl = C("TextLabel", {
		Size = UDim2.new(0, 24, 0, 14),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = L("music_vol"),
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		Parent = SettingsRow,
	})

	local VolPctLbl = C("TextLabel", {
		Size = UDim2.new(0, 32, 0, 14),
		Position = UDim2.new(0, 196, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = math.floor((S.MusicVolume or 0.65) * 100) .. "%",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = SPOTIFY,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		Parent = SettingsRow,
	})

	local VolTrack = C("TextButton", {
		Size = UDim2.new(0, 136, 0, 6),
		Position = UDim2.new(0, 28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = BG3,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = SettingsRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = VolTrack })
	local VolFill = C("Frame", {
		Size = UDim2.new(S.MusicVolume or 0.65, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = VolTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = VolFill })
	local VolKnob = C("Frame", {
		Size = UDim2.new(0, 10, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(S.MusicVolume or 0.65, 0, 0.5, 0),
		BackgroundColor3 = TXT,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = VolTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = VolKnob })

	local volDragging = false
	local UIS = game:GetService("UserInputService")

	local function setVolumeFromX(x)
		local rel = math.clamp((x - VolTrack.AbsolutePosition.X) / math.max(VolTrack.AbsoluteSize.X, 1), 0, 1)
		S.MusicVolume = rel
		VolFill.Size = UDim2.new(rel, 0, 1, 0)
		VolKnob.Position = UDim2.new(rel, 0, 0.5, 0)
		VolPctLbl.Text = math.floor(rel * 100) .. "%"
		if Music and Music.SetVolume then
			Music.SetVolume(rel)
		end
	end

	VolTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			volDragging = true
			setVolumeFromX(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if volDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setVolumeFromX(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			volDragging = false
		end
	end)

	local TogRow = C("Frame", {
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = SettingsRow,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = TogRow,
	})

	makeCompactTog(TogRow, "Loop", "MusicLoop", 1, {
		onChange = function(on)
			if Music and Music.SetLoop then
				Music.SetLoop(on)
			end
		end,
	})
	makeCompactTog(TogRow, L("music_auto_next_short"), "MusicAutoQueue", 2)
	makeCompactTog(TogRow, L("music_mini_short"), "ShowMusicWidget", 3, {
		onChange = function()
			if UIMusic._refreshWidget then
				UIMusic._refreshWidget(Music and Music.GetState and Music.GetState() or {})
			end
		end,
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
		if QueueEmptyLbl then
			I18n.registerText(QueueEmptyLbl, "music_queue_empty")
		end
		I18n.registerText(OpenLocalBtn, "music_local_open")
		I18n.registerText(RefreshLocalBtn, "music_local_refresh")
	end

	langRefs.I18n = I18n
	langRefs.Music = Music
	langRefs.setSource = setSource
	langRefs.refreshNowPlaying = refreshNowPlaying
	langRefs.updateBodyLayout = updateBodyLayout
	langRefs.LocalHelpLbl = LocalHelpLbl

	updateBodyLayout()
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
	if r.updateBodyLayout then
		r.updateBodyLayout()
	end
	if r.LocalHelpLbl and r.I18n and r.Music then
		local path = (r.Music.GetLocalDir and r.Music.GetLocalDir()) or "VanguardMusic/local"
		r.LocalHelpLbl.Text = r.I18n.t("music_local_help", path)
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
