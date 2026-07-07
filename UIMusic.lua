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

local MusicIcons = {}

-- Lucide icons (lucideblox) — ImageLabel assets render reliably on executors
-- where rotated Frame chevrons and font glyphs do not.
local ICON_ASSETS = {
	play = "rbxassetid://7743871480",
	pause = "rbxassetid://7734021897",
	skipBack = "rbxassetid://7734058404",
	skipForward = "rbxassetid://7734058495",
	stop = "rbxassetid://7743872181",
	repeat1 = "rbxassetid://7734051342",
	repeatAll = "rbxassetid://7734051454",
}

function MusicIcons.holder(parent, C, name)
	local z = (parent.ZIndex or 1) + 2
	return C("Frame", {
		Name = name or "Icon",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
end

function MusicIcons._image(C, holder, assetKey, color, inset)
	inset = inset or 3
	local z = (holder.ZIndex or 1) + 1
	return C("ImageLabel", {
		Name = assetKey,
		Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2)),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = ICON_ASSETS[assetKey],
		ImageColor3 = color or TXT,
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z,
		Parent = holder,
	})
end

function MusicIcons.setColor(holder, color)
	if not holder then
		return
	end
	for _, ch in ipairs(holder:GetDescendants()) do
		if ch:IsA("ImageLabel") then
			ch.ImageColor3 = color
		end
	end
end

function MusicIcons.setFade(holder, alpha)
	if not holder then
		return
	end
	for _, ch in ipairs(holder:GetDescendants()) do
		if ch:IsA("ImageLabel") then
			ch.ImageTransparency = alpha
		end
	end
end

function MusicIcons.play(holder, C, color)
	MusicIcons._image(C, holder, "play", color, 8)
end

function MusicIcons.pause(holder, C, color)
	MusicIcons._image(C, holder, "pause", color, 7)
end

function MusicIcons.skipBack(holder, C, color)
	MusicIcons._image(C, holder, "skipBack", color, 5)
end

function MusicIcons.skipForward(holder, C, color)
	MusicIcons._image(C, holder, "skipForward", color, 5)
end

function MusicIcons.stop(holder, C, color, size)
	color = color or MUT
	size = size or 10
	local inset = math.max(2, math.floor((24 - size) / 2))
	MusicIcons._image(C, holder, "stop", color, inset)
end

function MusicIcons.setLoopIcon(holder, C, loopOne, color)
	if not holder then
		return
	end
	for _, ch in ipairs(holder:GetChildren()) do
		if ch:IsA("ImageLabel") then
			ch:Destroy()
		end
	end
	MusicIcons._image(C, holder, loopOne and "repeat1" or "repeatAll", color or SPOTIFY, 0)
end

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
	local playerDuration = 0
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
		if state.duration and state.duration > 0 then
			playerDuration = state.duration
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
	local updateBodyLayout
	local openLocalFolder
	local setSource

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
	local LOCAL_PANEL_GAP = 4
	local LOCAL_BAR_H = 36
	local POTASSIUM_CACHE_ENV = "%localappdata%\\Potassium\\workspace\\VanguardMusic"
	local POTASSIUM_LOCAL_ENV = "%localappdata%\\Potassium\\workspace\\VanguardMusic\\local"
	local MUSIC_VOL_MAX = 3
	local LocalPathLbl
	local LocalTipLbl
	local CacheStatsLbl
	local ClearCacheBtn
	local cacheConfirmUntil = 0
	local Body
	local HeaderFrame
	local LocalPanel
	local OpenLocalBtn
	local RefreshLocalBtn

	local function cachePathLabel()
		local ok, path = pcall(function()
			if Music and Music.GetCacheDirEnvPath then
				local envPath = Music.GetCacheDirEnvPath()
				if envPath and envPath ~= "" then
					return envPath
				end
			end
			if Music and Music.GetCacheDir then
				return Music.GetCacheDir()
			end
			return POTASSIUM_CACHE_ENV
		end)
		if ok and type(path) == "string" and path ~= "" then
			return path
		end
		return POTASSIUM_CACHE_ENV
	end

	local function formatCacheCompactText(stats)
		stats = stats or {}
		local count = stats.fileCount or 0
		if stats.error then
			return L("music_cache_unavail")
		end
		if count == 0 then
			return L("music_cache_empty")
		end
		if stats.sizeKnown and Music and Music.FormatCacheBytes then
			return L("music_cache_compact", count, Music.FormatCacheBytes(stats.totalBytes or 0))
		end
		return L("music_cache_compact_nosize", count)
	end

	local function formatCacheStatsText(stats)
		stats = stats or {}
		local path = stats.path or cachePathLabel()
		local count = stats.fileCount or 0
		if stats.error then
			return L("music_cache_unavail")
		end
		if count == 0 then
			return L("music_cache_empty")
		end
		if stats.sizeKnown and Music and Music.FormatCacheBytes then
			return L("music_cache_stats", path, count, Music.FormatCacheBytes(stats.totalBytes or 0))
		end
		return L("music_cache_stats_nosize", path, count)
	end

	local function refreshCachePanelLabels()
		if not CacheStatsLbl then
			return
		end
		local stats = (Music and Music.GetCacheStats) and Music.GetCacheStats() or {}
		CacheStatsLbl.Text = formatCacheCompactText(stats)
		if ClearCacheBtn then
			local disabled = stats.error ~= nil or (stats.fileCount or 0) == 0
			ClearCacheBtn.AutoButtonColor = false
			ClearCacheBtn.Active = not disabled
			ClearCacheBtn.TextTransparency = disabled and 0.45 or 0
			if cacheConfirmUntil <= os.clock() then
				ClearCacheBtn.Text = L("music_cache_clear")
				ClearCacheBtn.BackgroundColor3 = BG3
				ClearCacheBtn.TextColor3 = MUT
			end
		end
	end

	local function clearDownloadCache()
		if not Music or not Music.GetCacheStats or not Music.ClearDownloadCache then
			showNotify(L("music_cache_unavail"), { type = "warn" })
			return
		end
		local stats = Music.GetCacheStats()
		if stats.error then
			showNotify(L("music_cache_unavail"), { type = "warn" })
			return
		end
		if (stats.fileCount or 0) == 0 then
			showNotify(L("music_cache_empty"), { type = "info" })
			return
		end
		if cacheConfirmUntil <= os.clock() then
			cacheConfirmUntil = os.clock() + 5
			if ClearCacheBtn then
				ClearCacheBtn.Text = L("music_cache_confirm")
				ClearCacheBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
				ClearCacheBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
			end
			return
		end
		cacheConfirmUntil = 0
		local ok, deleted, bytesFreed, err = Music.ClearDownloadCache()
		if not ok then
			showNotify(tostring(err or L("music_cache_unavail")), { type = "error" })
			refreshCachePanelLabels()
			return
		end
		local sizeText = Music.FormatCacheBytes and Music.FormatCacheBytes(bytesFreed or 0) or tostring(bytesFreed or 0)
		if deleted == 0 then
			showNotify(L("music_cache_empty"), { type = "info" })
		else
			showNotify(L("music_cache_cleared", deleted, sizeText), { type = "success", duration = 6 })
		end
		refreshCachePanelLabels()
	end

	local function localPathLabel()
		local ok, path = pcall(function()
			if Music and Music.GetLocalDirEnvPath then
				local envPath = Music.GetLocalDirEnvPath()
				if envPath and envPath ~= "" then
					return envPath
				end
			end
			if Music and Music.GetLocalDir then
				return Music.GetLocalDir()
			end
			return POTASSIUM_LOCAL_ENV
		end)
		if ok and type(path) == "string" and path ~= "" then
			return path
		end
		return POTASSIUM_LOCAL_ENV
	end

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

	local function copyLocalPath()
		local path = localPathLabel()
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, path)
		elseif typeof(toclipboard) == "function" then
			pcall(toclipboard, path)
		end
		showNotify(L("music_local_copied", path), { type = "info", duration = 8 })
	end

	local function updateLocalPanelLabels()
		local path = localPathLabel()
		if LocalPathLbl then
			LocalPathLbl.Text = path
		end
		if LocalTipLbl then
			LocalTipLbl.Text = L("music_local_tip")
		end
	end

	local localAutoRefreshed = false

	local function refreshLocalFiles(manual)
		updateLocalPanelLabels()
		if Music and Music.EnsureLocalDir then
			pcall(Music.EnsureLocalDir)
		end
		if not manual then
			if localAutoRefreshed then
				return
			end
			localAutoRefreshed = true
		end
		runSearch(SearchBox and SearchBox.Text or "")
	end

	setSource = function(src)
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
		if updateBodyLayout then
			updateBodyLayout()
		end
		if src == "local" then
			updateLocalPanelLabels()
			if not localAutoRefreshed then
				task.defer(function()
					refreshLocalFiles(false)
				end)
			end
		end
	end

	updateBodyLayout = function()
		if not Body or not HeaderFrame then
			return
		end
		local isLocal = Music and Music.GetSource and Music.GetSource() == "local"
		if LocalPanel then
			LocalPanel.Visible = isLocal == true
		end
		local headerH = HEADER_H + (isLocal and (LOCAL_PANEL_GAP + LOCAL_BAR_H) or 0)
		if HeaderFrame then
			HeaderFrame.Size = UDim2.new(1, -8, 0, headerH)
		end
		Body.Size = UDim2.new(1, -8, 1, -(headerH + PLAYER_H + 8))
		Body.Position = UDim2.new(0, 4, 0, headerH + 4)
	end

	openLocalFolder = function()
		if Music and Music.OpenLocalFolder then
			local opened, clip = Music.OpenLocalFolder()
			if opened then
				showNotify(L("music_local_opened", clip), { type = "success", duration = 7 })
			else
				showNotify(L("music_local_copied", clip), { type = "info", duration = 8 })
			end
			return
		end
		showNotify(L("music_local_path", POTASSIUM_LOCAL_ENV), { type = "warn" })
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
	HeaderFrame = Header

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

	LocalPanel = C("Frame", {
		Name = "LocalPanel",
		Size = UDim2.new(1, 0, 0, LOCAL_BAR_H),
		Position = UDim2.new(0, 0, 0, HEADER_H + LOCAL_PANEL_GAP),
		BackgroundColor3 = BG3,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9,
		Parent = Header,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = LocalPanel })

	LocalTipLbl = C("TextLabel", {
		Size = UDim2.new(0, 150, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = L("music_local_tip"),
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
		Parent = LocalPanel,
	})

	LocalPathLbl = C("TextLabel", {
		Size = UDim2.new(1, -268, 1, 0),
		Position = UDim2.new(0, 162, 0, 0),
		BackgroundTransparency = 1,
		Text = localPathLabel(),
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(165, 165, 178),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
		Parent = LocalPanel,
	})

	local LocalBtnCol = C("Frame", {
		Size = UDim2.new(0, 196, 1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = LocalPanel,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = LocalBtnCol,
	})

	local CopyPathBtn = C("TextButton", {
		Size = UDim2.new(0, 52, 0, 24),
		BackgroundColor3 = BG2,
		Text = L("music_local_copy"),
		Font = Enum.Font.GothamSemibold,
		TextSize = 9,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 10,
		Parent = LocalBtnCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = CopyPathBtn })
	CopyPathBtn.MouseButton1Click:Connect(function()
		copyLocalPath()
	end)

	OpenLocalBtn = C("TextButton", {
		Size = UDim2.new(0, 58, 0, 24),
		BackgroundColor3 = SPOTIFY,
		Text = L("music_local_open"),
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Color3.fromRGB(8, 8, 10),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = 10,
		Parent = LocalBtnCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = OpenLocalBtn })
	OpenLocalBtn.MouseButton1Click:Connect(function()
		openLocalFolder()
	end)

	RefreshLocalBtn = C("TextButton", {
		Size = UDim2.new(0, 68, 0, 24),
		BackgroundColor3 = BG2,
		Text = L("music_local_refresh"),
		Font = Enum.Font.GothamSemibold,
		TextSize = 9,
		TextColor3 = TXT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 10,
		Parent = LocalBtnCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = RefreshLocalBtn })
	RefreshLocalBtn.MouseButton1Click:Connect(function()
		refreshLocalFiles(true)
	end)

	local BodyFrame = C("Frame", {
		Size = UDim2.new(1, -8, 1, -(HEADER_H + PLAYER_H + 6)),
		Position = UDim2.new(0, 4, 0, HEADER_H + 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = Shell,
	})
	Body = BodyFrame

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
		Position = UDim2.new(0, 0, 0, 20),
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
		Size = UDim2.new(1, 0, 1, -38),
		Position = UDim2.new(0, 0, 0, 36),
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

	local ProgressHit = C("TextButton", {
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.new(0, 12, 0, 5),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = PlayerDock,
	})
	local ProgressTrack = C("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0.5, -1),
		BackgroundColor3 = BG3,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = ProgressHit,
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
		Text = "",
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = CtrlCol,
	})
	MusicIcons.skipBack(MusicIcons.holder(PrevBtn, C), C, Color3.fromRGB(220, 220, 228))
	local PlayPauseBtn = C("TextButton", {
		Size = UDim2.new(0, 38, 0, 38),
		Position = UDim2.new(0.5, -19, 0.5, -19),
		BackgroundColor3 = SPOTIFY,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = CtrlCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayPauseBtn })
	local playColor = Color3.fromRGB(255, 255, 255)
	PlayIcon = MusicIcons.holder(PlayPauseBtn, C, "PlayIcon")
	MusicIcons.play(PlayIcon, C, playColor)
	PauseIcon = MusicIcons.holder(PlayPauseBtn, C, "PauseIcon")
	MusicIcons.pause(PauseIcon, C, playColor)
	PauseIcon.Visible = false
	local NextBtn = C("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -28, 0.5, -14),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = CtrlCol,
	})
	MusicIcons.skipForward(MusicIcons.holder(NextBtn, C), C, Color3.fromRGB(220, 220, 228))

	local StopBtn = C("TextButton", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -28, 0.5, -12),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 11,
		Parent = PlayerRow,
	})
	MusicIcons.stop(MusicIcons.holder(StopBtn, C), C, MUT, 7)

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

	local function musicVolPct(v)
		return math.floor((v or S.MusicVolume or 0.65) * 100) .. "%"
	end

	local function musicVolRel(v)
		return math.clamp((v or S.MusicVolume or 0.65) / MUSIC_VOL_MAX, 0, 1)
	end

	local initVolRel = musicVolRel()

	local VolPctLbl = C("TextLabel", {
		Size = UDim2.new(0, 36, 0, 14),
		Position = UDim2.new(0, 196, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = musicVolPct(),
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
		Size = UDim2.new(initVolRel, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = VolTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = VolFill })
	local VolKnob = C("Frame", {
		Size = UDim2.new(0, 10, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(initVolRel, 0, 0.5, 0),
		BackgroundColor3 = TXT,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = VolTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = VolKnob })

	local CacheRow = C("Frame", {
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0, 238, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = SettingsRow,
	})
	C("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = CacheRow,
	})

	CacheStatsLbl = C("TextLabel", {
		Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = formatCacheCompactText(Music and Music.GetCacheStats and Music.GetCacheStats() or {}),
		Font = Enum.Font.Gotham,
		TextSize = 8,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		ZIndex = 11,
		Parent = CacheRow,
	})

	ClearCacheBtn = C("TextButton", {
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BG3,
		Text = L("music_cache_clear"),
		Font = Enum.Font.GothamSemibold,
		TextSize = 8,
		TextColor3 = MUT,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ZIndex = 11,
		Parent = CacheRow,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ClearCacheBtn })
	C("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = ClearCacheBtn,
	})
	ClearCacheBtn.MouseButton1Click:Connect(function()
		clearDownloadCache()
	end)

	local volDragging = false
	local UIS = game:GetService("UserInputService")

	local function setVolumeFromX(x)
		local rel = math.clamp((x - VolTrack.AbsolutePosition.X) / math.max(VolTrack.AbsoluteSize.X, 1), 0, 1)
		local val = rel * MUSIC_VOL_MAX
		S.MusicVolume = val
		VolFill.Size = UDim2.new(rel, 0, 1, 0)
		VolKnob.Position = UDim2.new(rel, 0, 0.5, 0)
		VolPctLbl.Text = musicVolPct(val)
		if Music and Music.SetVolume then
			Music.SetVolume(val)
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

	local seekDragging = false
	local function seekFromInput(x)
		if playerDuration <= 0 or not Music or not Music.Seek then
			return
		end
		if ProgressTrack.AbsoluteSize.X < 1 then
			return
		end
		local rel = math.clamp((x - ProgressTrack.AbsolutePosition.X) / ProgressTrack.AbsoluteSize.X, 0, 1)
		if ProgressFill then
			ProgressFill.Size = UDim2.new(rel, 0, 1, 0)
		end
		Music.Seek(rel * playerDuration)
	end
	ProgressHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			seekDragging = true
			seekFromInput(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if seekDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			seekFromInput(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			seekDragging = false
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

	local function syncVolumeUI(state)
		state = state or {}
		local v = state.volume
		if v == nil then
			return
		end
		local rel = musicVolRel(v)
		VolFill.Size = UDim2.new(rel, 0, 1, 0)
		VolKnob.Position = UDim2.new(rel, 0, 0.5, 0)
		VolPctLbl.Text = musicVolPct(v)
	end

	if Music then
		Music.onStateChanged = function(state)
			refreshNowPlaying(state)
			syncVolumeUI(state)
		end
		Music.onProgress = function(pos, dur)
			playerDuration = dur or 0
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
		if ClearCacheBtn then
			I18n.registerText(ClearCacheBtn, "music_cache_clear")
		end
		if LocalTipLbl then
			I18n.registerText(LocalTipLbl, "music_local_tip")
		end
		if CopyPathBtn then
			I18n.registerText(CopyPathBtn, "music_local_copy")
		end
	end

	langRefs.I18n = I18n
	langRefs.Music = Music
	langRefs.setSource = setSource
	langRefs.refreshNowPlaying = refreshNowPlaying
	langRefs.updateBodyLayout = updateBodyLayout
	langRefs.LocalPathLbl = LocalPathLbl
	langRefs.LocalTipLbl = LocalTipLbl
	langRefs.updateLocalPanelLabels = updateLocalPanelLabels
	langRefs.refreshCachePanelLabels = refreshCachePanelLabels

	updateBodyLayout()
	refreshNowPlaying()
	refreshCachePanelLabels()

	function UIMusic.onMenuOpen()
		task.defer(function()
			refreshCachePanelLabels()
		end)
		if Music and Music.GetSource and Music.GetSource() == "local" then
			task.defer(function()
				refreshLocalFiles(false)
			end)
		end
	end
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
	if r.updateLocalPanelLabels then
		r.updateLocalPanelLabels()
	end
	if r.refreshCachePanelLabels then
		r.refreshCachePanelLabels()
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
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")

	local SPOTIFY = Color3.fromRGB(29, 185, 84)
	local BG = Color3.fromRGB(14, 14, 18)
	local BG2 = Color3.fromRGB(22, 22, 28)
	local TXT = Color3.fromRGB(245, 245, 248)
	local MUT = Color3.fromRGB(130, 130, 142)
	local ART_PALETTE = {
		Color3.fromRGB(29, 185, 84),
		Color3.fromRGB(30, 130, 220),
		Color3.fromRGB(180, 90, 255),
		Color3.fromRGB(255, 120, 80),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(80, 200, 180),
	}

	local function fmtTime(sec)
		sec = math.max(0, math.floor(sec or 0))
		return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
	end

	local function artAccent(title)
		local h = 0
		for i = 1, #(title or "") do
			h = (h + string.byte(title, i) * (i + 3)) % 997
		end
		return ART_PALETTE[(h % #ART_PALETTE) + 1]
	end

	local transportBtnMeta = {}

	local function makeTransportBtn(parent, iconKind, x, w, color)
		color = color or Color3.fromRGB(220, 220, 228)
		local Btn = C("TextButton", {
			Size = UDim2.new(0, w, 0, w),
			Position = UDim2.new(0, x, 0.5, -math.floor(w / 2)),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 86,
			Parent = parent,
		})
		local iconGroup = MusicIcons.holder(Btn, C)
		if iconKind == "back" then
			MusicIcons.skipBack(iconGroup, C, color)
		else
			MusicIcons.skipForward(iconGroup, C, color)
		end
		local Scale = C("UIScale", { Scale = 1, Parent = Btn })
		local meta = { enabled = true, iconGroup = iconGroup, color = color }
		transportBtnMeta[Btn] = meta
		Btn.MouseEnter:Connect(function()
			if not meta.enabled then
				return
			end
			TweenPlay(Scale, TweenInfo.new(0.12), { Scale = 1.08 })
			MusicIcons.setColor(iconGroup, SPOTIFY)
		end)
		Btn.MouseLeave:Connect(function()
			TweenPlay(Scale, TweenInfo.new(0.12), { Scale = 1 })
			MusicIcons.setColor(iconGroup, meta.enabled and color or Color3.fromRGB(120, 120, 132))
		end)
		return Btn, Scale
	end

	local widgetVisible = false
	local pulseConn = nil
	local activeTweens = {}
	local widgetDuration = 0

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

	local WIDGET_W = 440
	local WIDGET_H = 74

	local function posFromSettings()
		return UDim2.new(
			tonumber(S.MusicWidgetPosXScale) or 0,
			tonumber(S.MusicWidgetPosXOffset) or 18,
			tonumber(S.MusicWidgetPosYScale) or 1,
			tonumber(S.MusicWidgetPosYOffset) or -90
		)
	end

	local function savePosToSettings(pos)
		S.MusicWidgetPosXScale = pos.X.Scale
		S.MusicWidgetPosXOffset = pos.X.Offset
		S.MusicWidgetPosYScale = pos.Y.Scale
		S.MusicWidgetPosYOffset = pos.Y.Offset
	end

	local function viewportSize()
		local vpW = ParentGUI and ParentGUI.AbsoluteSize.X or 0
		local vpH = ParentGUI and ParentGUI.AbsoluteSize.Y or 0
		if vpW < 1 or vpH < 1 then
			local cam = workspace.CurrentCamera
			if cam then
				vpW = cam.ViewportSize.X
				vpH = cam.ViewportSize.Y
			else
				vpW, vpH = 1920, 1080
			end
		end
		return vpW, vpH
	end

	local function clampWidgetPos(pos)
		local vpW, vpH = viewportSize()
		local absX = vpW * pos.X.Scale + pos.X.Offset
		local absY = vpH * pos.Y.Scale + pos.Y.Offset
		absX = math.clamp(absX, 0, math.max(0, vpW - WIDGET_W))
		absY = math.clamp(absY, WIDGET_H, vpH)
		return UDim2.new(
			pos.X.Scale,
			absX - vpW * pos.X.Scale,
			pos.Y.Scale,
			absY - vpH * pos.Y.Scale
		)
	end

	local function applyWidgetPosition(pos)
		local clamped = clampWidgetPos(pos)
		Root.Position = clamped
		savePosToSettings(clamped)
		return clamped
	end

	local Root = C("Frame", {
		Name = "VanguardMusicWidget",
		Size = UDim2.new(0, WIDGET_W, 0, WIDGET_H),
		Position = clampWidgetPos(posFromSettings()),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 80,
		Parent = ParentGUI,
	})
	savePosToSettings(Root.Position)

	local Shell = C("Frame", {
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 81,
		Parent = Root,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 16), Parent = Shell })
	C("UIStroke", {
		Color = Color3.fromRGB(48, 48, 58),
		Thickness = 1,
		Transparency = 0.45,
		Parent = Shell,
	})

	local Glow = C("Frame", {
		Size = UDim2.new(1, 12, 1, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = SPOTIFY,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		ZIndex = 80,
		Parent = Shell,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 20), Parent = Glow })

	local MainRow = C("Frame", {
		Size = UDim2.new(1, -12, 0, 54),
		Position = UDim2.new(0, 6, 0, 6),
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = Shell,
	})

	local DragZone = C("TextButton", {
		Size = UDim2.new(1, -138, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 82,
		Parent = MainRow,
	})

	local ArtWrap = C("Frame", {
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 2, 0.5, -21),
		BackgroundTransparency = 1,
		ZIndex = 83,
		Parent = DragZone,
	})
	local ArtScale = C("UIScale", { Scale = 1, Parent = ArtWrap })
	local ArtRing = C("Frame", {
		Size = UDim2.new(1, 5, 1, 5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = SPOTIFY,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 83,
		Parent = ArtWrap,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ArtRing })
	local Art = C("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BG2,
		BorderSizePixel = 0,
		ZIndex = 84,
		Parent = ArtWrap,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = Art })
	local ArtGrad = C("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 48)),
			ColorSequenceKeypoint.new(1, SPOTIFY),
		}),
		Rotation = 135,
		Parent = Art,
	})
	local ArtLetter = C("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "♪",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = TXT,
		ZIndex = 85,
		Parent = Art,
	})

	local InfoCol = C("Frame", {
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.new(0, 50, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 83,
		Parent = DragZone,
	})
	local TitleLbl = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundTransparency = 1,
		Text = "—",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 84,
		Parent = InfoCol,
	})
	local MetaLbl = C("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "Vanguard Music",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 84,
		Parent = InfoCol,
	})

	local CtrlCol = C("Frame", {
		Size = UDim2.new(0, 128, 1, 0),
		Position = UDim2.new(1, -128, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 85,
		Parent = MainRow,
	})
	local PrevBtn, _ = makeTransportBtn(CtrlCol, "back", 0, 28)
	local PlayBtn = C("TextButton", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 34, 0.5, -18),
		BackgroundColor3 = SPOTIFY,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 86,
		Parent = CtrlCol,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = PlayBtn })
	local PlayBtnScale = C("UIScale", { Scale = 1, Parent = PlayBtn })
	local widgetPlayColor = Color3.fromRGB(255, 255, 255)
	local PlayIcon = MusicIcons.holder(PlayBtn, C, "PlayIcon")
	MusicIcons.play(PlayIcon, C, widgetPlayColor)
	local PauseIcon = MusicIcons.holder(PlayBtn, C, "PauseIcon")
	MusicIcons.pause(PauseIcon, C, widgetPlayColor)
	PauseIcon.Visible = false
	local NextBtn, _ = makeTransportBtn(CtrlCol, "forward", 80, 28)

	local ProgressHit = C("TextButton", {
		Size = UDim2.new(1, -16, 0, 10),
		Position = UDim2.new(0, 8, 1, -12),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 90,
		Parent = Shell,
	})
	local ProgressTrack = C("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0.5, -1),
		BackgroundColor3 = Color3.fromRGB(36, 36, 44),
		BorderSizePixel = 0,
		ZIndex = 91,
		Parent = ProgressHit,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack })
	local ProgressFill = C("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = SPOTIFY,
		BorderSizePixel = 0,
		ZIndex = 92,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressFill })
	local ProgressKnob = C("Frame", {
		Size = UDim2.new(0, 7, 0, 7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = TXT,
		BorderSizePixel = 0,
		ZIndex = 93,
		Parent = ProgressTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ProgressKnob })

	local LoopBadge = C("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(1, 2, 1, 2),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 86,
		Parent = ArtWrap,
	})
	MusicIcons.setLoopIcon(LoopBadge, C, true, SPOTIFY)

	local function formatMeta(state, pos, dur)
		local artist = state.artist ~= "" and state.artist or "Audius"
		if state.paused then
			return artist .. " · " .. L("music_pause")
		end
		if state.loading then
			return L("music_downloading")
		end
		local volPct = math.floor((state.volume or 0.65) * 100)
		local timePart = (dur and dur > 0) and (fmtTime(pos or 0) .. " / " .. fmtTime(dur)) or "0:00"
		return artist .. " · " .. timePart .. " · " .. volPct .. "%"
	end

	local function setTransportEnabled(btn, enabled)
		local meta = transportBtnMeta[btn]
		if not meta then
			return
		end
		meta.enabled = enabled == true
		btn.Active = meta.enabled
		MusicIcons.setFade(meta.iconGroup, meta.enabled and 0 or 0.55)
	end

	local function setProgressRatio(ratio)
		ratio = math.clamp(ratio or 0, 0, 1)
		ProgressFill.Size = UDim2.new(ratio, 0, 1, 0)
		ProgressKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
		ProgressKnob.Visible = ratio > 0.01 and ratio < 0.99
	end

	local function seekFromInput(x)
		if widgetDuration <= 0 or not Music or not Music.Seek then
			return
		end
		if ProgressTrack.AbsoluteSize.X < 1 then
			return
		end
		local rel = math.clamp((x - ProgressTrack.AbsolutePosition.X) / ProgressTrack.AbsoluteSize.X, 0, 1)
		setProgressRatio(rel)
		Music.Seek(rel * widgetDuration)
	end

	local draggingSeek = false
	ProgressHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSeek = true
			seekFromInput(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if draggingSeek and input.UserInputType == Enum.UserInputType.MouseMovement then
			seekFromInput(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSeek = false
		end
	end)

	local draggingWidget = false
	local dragStartMouse
	local dragStartPos
	DragZone.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingWidget = true
			dragStartMouse = input.Position
			dragStartPos = Root.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if draggingWidget and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStartMouse
			Root.Position = UDim2.new(
				dragStartPos.X.Scale,
				dragStartPos.X.Offset + delta.X,
				dragStartPos.Y.Scale,
				dragStartPos.Y.Offset + delta.Y
			)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if draggingWidget then
				applyWidgetPosition(Root.Position)
			end
			draggingWidget = false
		end
	end)

	local function setPulse(on, accent)
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
		if not on then
			ArtRing.BackgroundTransparency = 0.82
			ArtScale.Scale = 1
			Glow.BackgroundColor3 = accent or SPOTIFY
			return
		end
		Glow.BackgroundColor3 = accent or SPOTIFY
		local t0 = os.clock()
		pulseConn = RS.Heartbeat:Connect(function()
			local wave = (math.sin((os.clock() - t0) * 3.2) + 1) * 0.5
			ArtRing.BackgroundTransparency = 0.45 + wave * 0.35
			ArtScale.Scale = 1 + wave * 0.035
			Glow.BackgroundTransparency = 0.9 + wave * 0.06
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
			Shell.Position = UDim2.new(0, 0, 0, 16)
			Shell.BackgroundTransparency = 1
			tween(Shell, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 0.04,
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
			Position = UDim2.new(0, 0, 0, 20),
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
		MetaLbl.Text = formatMeta(state, state.position, state.duration)

		local accent = artAccent(state.title)
		ArtGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, BG2),
			ColorSequenceKeypoint.new(1, accent),
		})
		ArtRing.BackgroundColor3 = accent
		local initial = string.sub(state.title or "?", 1, 1):upper()
		ArtLetter.Text = initial ~= "" and initial or "♪"

		local showPause = (state.playing and not state.paused) or state.loading
		PlayIcon.Visible = not showPause
		PauseIcon.Visible = showPause

		setTransportEnabled(PrevBtn, state.hasPrev == true)
		setTransportEnabled(NextBtn, state.hasNext == true)
		LoopBadge.Visible = S.MusicLoop == true

		if state.duration and state.duration > 0 then
			widgetDuration = state.duration
			setProgressRatio(state.position / state.duration)
		else
			widgetDuration = 0
			setProgressRatio(0)
		end

		setPulse(state.playing and not state.paused and not state.loading, accent)
	end

	UIMusic._refreshWidget = refreshWidget
	UIMusic._applyWidgetPosition = applyWidgetPosition

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

	if Music then
		Music.AddStateListener(refreshWidget)
		local prevProgress = Music.onProgress
		Music.onProgress = function(pos, dur)
			if prevProgress then
				prevProgress(pos, dur)
			end
			if dur and dur > 0 then
				widgetDuration = dur
				if not draggingSeek then
					setProgressRatio(pos / dur)
				end
				if Music.GetState then
					MetaLbl.Text = formatMeta(Music.GetState(), pos, dur)
				end
			end
			if Music.GetState then
				local st = Music.GetState()
				local showPause = (st.playing and not st.paused) or st.loading
				PlayIcon.Visible = not showPause
				PauseIcon.Visible = showPause
				setTransportEnabled(PrevBtn, st.hasPrev == true)
				setTransportEnabled(NextBtn, st.hasNext == true)
			end
		end
	end

	refreshWidget(Music and Music.GetState and Music.GetState() or {})
end

return UIMusic
