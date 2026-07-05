-- Plik: workspace/Vanguard/Music.lua

local Music = {}

local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("RunService")

local AUDIO_SCORE = {
	["Ogg Vorbis"] = 150,
	["Opus"] = 130,
	["MP3"] = 100,
	["VBR MP3"] = 35,
	["Flac"] = 20,
}

local PRESETS = {
	{ identifier = "stereo-love", title = "Stereo Love", creator = "Edward Maya", downloads = 22591 },
	{ identifier = "ModjoLadyHearMeTonight", title = "Lady (Hear Me Tonight)", creator = "Modjo", downloads = 33449 },
	{ identifier = "DanceTheMainstreamMash2010-2011", title = "Dance MainStream Mash 2010-2011", creator = "Ryan Janjuha", downloads = 7978 },
}

function Music.Init(S)
	local currentSound = nil
	local progressConn = nil
	local loading = false
	local paused = false
	local nowPlaying = nil
	local lastError = nil
	local playGen = 0
	local playClockStart = 0
	local playPosOffset = 0
	local pausePosSnapshot = 0
	local lastToggleAt = 0
	local pausedSession = nil
	local cachedDuration = 0
	local HTTP_TIMEOUT = 12

	local function logInfo(...)
		print("[Vanguard Music]", ...)
	end

	local function logErr(...)
		warn("[Vanguard Music]", ...)
	end

	Music.onProgress = nil
	Music.onStateChanged = nil
	Music.onPlayError = nil

	local function notifyState()
		if Music.onStateChanged then
			pcall(Music.onStateChanged, Music.GetState())
		end
	end

	local function urlEncode(str)
		return HttpService:UrlEncode(str)
	end

	local function httpGet(url, timeoutSec)
		timeoutSec = timeoutSec or HTTP_TIMEOUT
		local box = { done = false, body = nil, err = nil, via = nil }

		task.spawn(function()
			local headers = {
				["User-Agent"] = "Mozilla/5.0 (compatible; Vanguard/2.27.1)",
				["Accept"] = "application/json,text/plain,*/*",
			}

			local req = request or (syn and syn.request) or (http and http.request)
			if req then
				local ok, res = pcall(function()
					return req({
						Url = url,
						Method = "GET",
						Headers = headers,
					})
				end)
				if ok and res then
					local code = tonumber(res.StatusCode) or 0
					if res.Body and res.Body ~= "" and code >= 200 and code < 300 then
						box.body = res.Body
						box.via = "request"
						box.done = true
						return
					end
					if not box.err then
						box.err = "request HTTP " .. tostring(code)
					end
				elseif not box.err then
					box.err = "request: " .. tostring(res)
				end
			end

			if typeof(game.HttpGetAsync) == "function" then
				local ok, body = pcall(game.HttpGetAsync, game, url)
				if ok and body and body ~= "" then
					box.body = body
					box.via = "HttpGetAsync"
					box.done = true
					return
				end
				if not box.err then
					box.err = "HttpGetAsync: " .. tostring(body)
				end
			end

			if HttpService.RequestAsync then
				local ok, res = pcall(function()
					return HttpService:RequestAsync({
						Url = url,
						Method = "GET",
						Headers = headers,
					})
				end)
				if ok and res then
					if res.Success and res.Body and res.Body ~= "" then
						box.body = res.Body
						box.via = "RequestAsync"
						box.done = true
						return
					end
					if not box.err then
						box.err = "RequestAsync status " .. tostring(res.StatusCode)
					end
				elseif not box.err then
					box.err = "RequestAsync: " .. tostring(res)
				end
			end

			local ok, body = pcall(game.HttpGet, game, url, true)
			if ok and body and body ~= "" then
				box.body = body
				box.via = "HttpGet"
				box.done = true
				return
			end
			if not box.err then
				box.err = "HttpGet: " .. tostring(body)
			end
			box.done = true
		end)

		local deadline = os.clock() + timeoutSec
		while not box.done and os.clock() < deadline do
			task.wait(0.05)
		end
		if not box.done then
			logErr("HTTP timeout (" .. timeoutSec .. "s):", url)
			return nil, "Timeout — Archive nie odpowiada (" .. timeoutSec .. "s)"
		end
		if box.body then
			logInfo("HTTP OK via", box.via, "(" .. #box.body .. " B)")
			return box.body
		end
		logErr("HTTP fail:", box.err or "brak body", "|", url)
		return nil, box.err or "Brak odpowiedzi HTTP"
	end

	local function decodeJson(body)
		if not body or body == "" then
			return nil
		end
		local trimmed = body:match("^%s*(.-)%s*$")
		if trimmed:sub(1, 1) == "<" then
			logErr("Odpowiedź HTML zamiast JSON:", trimmed:sub(1, 160))
			return nil, "Archive zwrócił HTML zamiast JSON — sprawdź HttpGet w executorze"
		end
		local ok, data = pcall(function()
			return HttpService:JSONDecode(trimmed)
		end)
		if ok then
			return data
		end
		logErr("JSON decode fail:", trimmed:sub(1, 160))
		return nil, "Nieprawidłowa odpowiedź Archive (JSON)"
	end

	local function buildSearchUrl(query)
		local term = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if term:find("%s") and not term:find(":") and not term:find('"') then
			local clean = term:gsub('"', "")
			term = '(creator:"' .. clean .. '" OR title:"' .. clean .. '" OR "' .. clean .. '")'
		end
		local lucene = term .. " AND mediatype:audio"
		return "https://archive.org/advancedsearch.php?q="
			.. urlEncode(lucene)
			.. "&fl[]=identifier,title,creator,downloads"
			.. "&sort[]=downloads+desc"
			.. "&rows=24&page=1&output=json"
	end

	local function normalizeDoc(doc)
		local title = doc.title
		if typeof(title) == "table" then
			title = title[1]
		end
		local creator = doc.creator
		if typeof(creator) == "table" then
			creator = table.concat(creator, ", ")
		end
		return {
			identifier = doc.identifier,
			title = tostring(title or doc.identifier or "?"),
			creator = tostring(creator or "Unknown"),
			downloads = tonumber(doc.downloads) or 0,
		}
	end

	local function filterPresets(query)
		local q = query:lower()
		local words = {}
		for word in q:gmatch("[%w%p]+") do
			if #word >= 2 then
				table.insert(words, word)
			end
		end
		local out = {}
		for _, preset in ipairs(PRESETS) do
			local hay = (preset.title .. " " .. preset.creator):lower()
			local match = q ~= "" and hay:find(q, 1, true)
			if not match and #words > 0 then
				match = true
				for _, w in ipairs(words) do
					if not hay:find(w, 1, true) then
						match = false
						break
					end
				end
			end
			if match then
				table.insert(out, preset)
			end
		end
		return out
	end

	local function validateAudioBody(body, fileName)
		if not body or #body < 1000 then
			return false, "plik za mały (" .. tostring(body and #body or 0) .. " B)"
		end
		if body:sub(1, 1) == "<" then
			return false, "pobrano HTML zamiast audio"
		end
		local lower = tostring(fileName or ""):lower()
		if lower:find("%.ogg") or lower:find("%.opus") then
			return body:sub(1, 4) == "OggS", "nieprawidłowy OGG"
		end
		if lower:find("%.mp3") then
			local b1, b2, b3 = body:byte(1, 3)
			if b1 == 0x49 and b2 == 0x44 and b3 == 0x33 then
				return true
			end
			if b1 == 0xFF and b2 and b2 >= 0xE0 then
				return true
			end
			for i = 1, math.min(#body - 1, 4096) do
				local a, b = body:byte(i, i + 1)
				if a == 0xFF and b and b >= 0xE0 then
					return true
				end
			end
			return false, "nieprawidłowy MP3"
		end
		return true
	end

	local function deleteCache(relPath)
		if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(relPath) then
			pcall(delfile, relPath)
			logInfo("Usunięto cache:", relPath)
		end
	end

	local CACHE_DIR = "VanguardMusic"

	local function safeFileName(name)
		return tostring(name or "track.mp3"):gsub("[^%w%.%-_]", "_")
	end

	local function resolveCustomAssetFn()
		if typeof(getcustomasset) == "function" then
			return getcustomasset, "getcustomasset"
		end
		if typeof(getsynasset) == "function" then
			return getsynasset, "getsynasset"
		end
		local g = (getgenv and getgenv()) or _G
		if typeof(g.getcustomasset) == "function" then
			return g.getcustomasset, "getcustomasset(genv)"
		end
		return nil
	end

	local function ensureCacheDir()
		if typeof(makefolder) ~= "function" then
			return
		end
		if typeof(isfolder) == "function" and isfolder(CACHE_DIR) then
			return
		end
		pcall(makefolder, CACHE_DIR)
	end

	local function toSoundId(assetRef)
		if typeof(assetRef) ~= "string" or assetRef == "" then
			return nil
		end
		if assetRef:find("^rbxasset") then
			return assetRef
		end
		return "rbxassetid://" .. assetRef
	end

	local function assetFromDownload(url, cacheName, skipCache)
		cacheName = safeFileName(cacheName)
		local relPath = CACHE_DIR .. "/" .. cacheName
		local getAsset, via = resolveCustomAssetFn()

		if typeof(writecustomasset) == "function" then
			logInfo("Pobieranie audio (writecustomasset):", url)
			local body, httpErr = httpGet(url, 30)
			if not body then
				return nil, nil, "Nie pobrano audio: " .. tostring(httpErr)
			end
			local valid, validErr = validateAudioBody(body, cacheName)
			if not valid then
				return nil, nil, validErr
			end
			local ok, assetRef = pcall(writecustomasset, cacheName, body)
			if ok and assetRef and assetRef ~= "" then
				logInfo("writecustomasset OK:", cacheName, "(" .. #body .. " B)")
				return assetRef, relPath
			end
			logErr("writecustomasset fail:", assetRef)
		end

		if not getAsset then
			return nil, nil, "Brak getcustomasset w executorze (Potassium: włącz filesystem)"
		end
		if typeof(writefile) ~= "function" then
			return nil, nil, "Brak writefile — nie da się zapisać audio"
		end

		ensureCacheDir()

		if not skipCache and typeof(isfile) == "function" and isfile(relPath) then
			local ok, assetRef = pcall(getAsset, relPath)
			if ok and assetRef and assetRef ~= "" then
				logInfo("Cache hit:", relPath, "via", via)
				return assetRef, relPath
			end
		end

		logInfo("Pobieranie audio:", url)
		local body, httpErr = httpGet(url, 30)
		if not body then
			return nil, nil, "Nie pobrano audio: " .. tostring(httpErr)
		end
		local valid, validErr = validateAudioBody(body, cacheName)
		if not valid then
			logErr("Walidacja audio fail:", validErr)
			return nil, nil, validErr
		end
		logInfo("Pobrano", #body, "B →", relPath)

		local writeOk, writeErr = pcall(writefile, relPath, body)
		if not writeOk then
			relPath = cacheName
			writeOk, writeErr = pcall(writefile, relPath, body)
		end
		if not writeOk then
			return nil, nil, "writefile fail: " .. tostring(writeErr)
		end

		local ok, assetRef = pcall(getAsset, relPath)
		if ok and assetRef and assetRef ~= "" then
			logInfo("getcustomasset OK via", via, "→", tostring(assetRef):sub(1, 48))
			return assetRef, relPath
		end
		return nil, relPath, "getcustomasset fail: " .. tostring(assetRef)
	end

	local function destroyAllMusicSounds()
		local function kill(inst)
			if inst:IsA("Sound") and inst.Name == "VanguardMusic" then
				pcall(function()
					inst:Stop()
					inst.Playing = false
					inst:Destroy()
				end)
			end
		end
		for _, ch in ipairs(SoundService:GetChildren()) do
			kill(ch)
		end
		local lp = game:GetService("Players").LocalPlayer
		if lp then
			for _, d in ipairs(lp:GetDescendants()) do
				kill(d)
			end
		end
	end

	local function getPlaybackPosition()
		if not currentSound then
			if paused and pausedSession then
				return pausePosSnapshot, pausedSession.duration or cachedDuration
			end
			return 0, cachedDuration
		end
		local dur = currentSound.TimeLength
		if dur > 0 then
			cachedDuration = dur
		end
		if dur <= 0 then
			return 0, cachedDuration
		end
		local pos = currentSound.TimePosition
		if paused then
			return pausePosSnapshot, dur
		end
		if pos > 0.05 then
			playPosOffset = pos
			playClockStart = os.clock()
			return pos, dur
		end
		if playClockStart > 0 then
			pos = math.min(playPosOffset + (os.clock() - playClockStart), dur)
			return pos, dur
		end
		return pos, dur
	end

	local function attachProgress(sound)
		disconnectProgress()
		progressConn = RS.Heartbeat:Connect(function()
			if currentSound ~= sound then
				return
			end
			local pos, dur = getPlaybackPosition()
			if Music.onProgress and dur > 0 then
				pcall(Music.onProgress, pos, dur)
			end
			if not paused and dur > 0 and pos >= dur - 0.35 and S.MusicLoop ~= true then
				playGen += 1
				stopInternal()
			end
		end)
	end

	local function resumePausedSession()
		if not pausedSession or not pausedSession.soundId then
			paused = false
			notifyState()
			return
		end

		loading = true
		notifyState()

		local session = pausedSession
		local sound = Instance.new("Sound")
		sound.Name = "VanguardMusic"
		sound.SoundId = session.soundId
		sound.Volume = S.MusicVolume or 0.65
		sound.Looped = S.MusicLoop == true
		sound.Parent = SoundService

		if not waitForSoundLoad(sound, 12) then
			loading = false
			lastError = "Nie udało się wznowić odtwarzania"
			logErr("Resume load fail")
			notifyState()
			return
		end

		local pos = math.min(session.position or 0, math.max(0, sound.TimeLength - 0.1))
		pcall(function()
			sound.TimePosition = pos
		end)

		if not startPlayback(sound) then
			killSound(sound)
			loading = false
			lastError = "Resume play fail"
			logErr("Resume play fail")
			notifyState()
			return
		end

		task.wait(0.2)
		if pos > 0.05 then
			pcall(function()
				sound.TimePosition = pos
			end)
		end

		currentSound = sound
		paused = false
		pausedSession = nil
		loading = false
		lastError = nil
		playPosOffset = pos
		pausePosSnapshot = pos
		playClockStart = os.clock()
		cachedDuration = sound.TimeLength

		attachProgress(sound)
		notifyState()
		logInfo("Resume OK @", string.format("%.1fs", pos))
	end

	local function startPlayback(sound)
		local ok = pcall(function()
			sound:Play()
		end)
		if ok then
			return true
		end
		return pcall(function()
			SoundService:PlayLocalSound(sound)
		end)
	end

	local function killSound(sound)
		if not sound then
			return
		end
		pcall(function()
			sound:Stop()
			sound:Destroy()
		end)
	end

	local function waitForSoundLoad(sound, timeoutSec, gen)
		timeoutSec = timeoutSec or 12
		local deadline = os.clock() + timeoutSec
		while os.clock() < deadline do
			if gen and gen ~= playGen then
				return false
			end
			if not sound.Parent then
				return false
			end
			if sound.IsLoaded and sound.TimeLength > 0 then
				return true
			end
			task.wait(0.1)
		end
		return sound.Parent ~= nil and sound.IsLoaded == true and sound.TimeLength > 0
	end

	local function disconnectProgress()
		if progressConn then
			progressConn:Disconnect()
			progressConn = nil
		end
	end

	local function stopInternal()
		disconnectProgress()
		destroyAllMusicSounds()
		currentSound = nil
		paused = false
		nowPlaying = nil
		loading = false
		playClockStart = 0
		playPosOffset = 0
		pausePosSnapshot = 0
		pausedSession = nil
		cachedDuration = 0
		notifyState()
	end

	local function scoreAudioFile(f)
		local name = tostring(f.name or "")
		local fmt = tostring(f.format or "")
		local lower = name:lower()
		local score = AUDIO_SCORE[fmt] or 0
		if lower:find("%.ogg") then
			score = math.max(score, 150)
		elseif lower:find("%.opus") then
			score = math.max(score, 130)
		elseif lower:find("%.mp3") then
			if fmt == "VBR MP3" then
				score = math.max(score, 35)
			else
				score = math.max(score, 90)
			end
		end
		return score
	end

	local function listAudioFiles(files, titleHint)
		local list = {}
		local hint = titleHint and tostring(titleHint):lower() or ""
		for _, f in ipairs(files or {}) do
			local name = tostring(f.name or "")
			local fmt = tostring(f.format or "")
			local size = tonumber(f.size) or 0
			if size >= 40000 and size <= 30000000 then
				local lower = name:lower()
				local skip = lower:find("sample")
					or lower:find("preview")
					or lower:find(".m3u")
					or lower:find(".xml")
					or lower:find(".png")
					or lower:find(".jpg")
					or lower:find(".sqlite")
					or lower:find(".torrent")
					or lower:find(".afpk")
					or lower:find("_spectrogram")
					or lower:find("_meta%.")
				if not skip then
					local score = scoreAudioFile(f)
					if score > 0 then
						if hint ~= "" then
							for word in hint:lower():gmatch("[%w]+") do
								if #word >= 3 and lower:find(word, 1, true) then
									score += 15
									break
								end
							end
						end
						table.insert(list, {
							name = name,
							format = fmt,
							score = score,
						})
					end
				end
			end
		end
		table.sort(list, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.name < b.name
		end)

		local hasOgg = false
		for _, f in ipairs(list) do
			if f.name:lower():find("%.ogg") then
				hasOgg = true
				break
			end
		end
		if hasOgg then
			local filtered = {}
			for _, f in ipairs(list) do
				local lower = f.name:lower()
				if not (lower:find("%.mp3") and f.format == "VBR MP3") then
					table.insert(filtered, f)
				end
			end
			if #filtered > 0 then
				list = filtered
			end
		end

		return list
	end

	local function resolveDownloadList(identifier, titleHint)
		local id = tostring(identifier or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if id == "" then
			return nil, "Brak identyfikatora Archive"
		end
		local body = httpGet("https://archive.org/metadata/" .. id)
		if not body then
			return nil, "Brak połączenia z Archive (HttpGet)"
		end
		local meta, parseErr = decodeJson(body)
		if not meta then
			return nil, parseErr or "Brak metadanych Archive"
		end
		if not meta.files then
			return nil, "Brak plików w tym uploadzie"
		end
		local hint = titleHint or (meta.metadata and meta.metadata.title) or ""
		local files = listAudioFiles(meta.files, hint)
		if #files == 0 then
			return nil, "Brak pliku audio (OGG/MP3) w tym uploadzie"
		end
		local out = {}
		for _, f in ipairs(files) do
			table.insert(out, {
				url = "https://archive.org/download/" .. id .. "/" .. urlEncode(f.name),
				name = f.name,
				format = f.format,
			})
		end
		return out
	end

	function Music.GetState()
		local pos, dur = getPlaybackPosition()
		return {
			loading = loading,
			playing = currentSound ~= nil and not paused,
			paused = paused,
			title = nowPlaying and nowPlaying.title or "",
			artist = nowPlaying and nowPlaying.creator or "",
			identifier = nowPlaying and nowPlaying.identifier or "",
			position = pos,
			duration = dur,
			volume = S.MusicVolume or 0.65,
			error = lastError,
		}
	end

	function Music.SetVolume(v)
		S.MusicVolume = math.clamp(v, 0, 1)
		if currentSound and not paused then
			currentSound.Volume = S.MusicVolume
		end
		notifyState()
	end

	function Music.Stop()
		playGen += 1
		stopInternal()
	end

	function Music.IsBusy()
		return loading
	end

	function Music.SetLoop(on)
		S.MusicLoop = on == true
		if currentSound then
			currentSound.Looped = S.MusicLoop
		end
		notifyState()
	end

	function Music.TogglePause()
		if os.clock() - lastToggleAt < 0.3 then
			return
		end
		lastToggleAt = os.clock()

		if paused then
			task.spawn(resumePausedSession)
			return
		end

		if not currentSound then
			return
		end

		pausePosSnapshot = getPlaybackPosition()
		local _, dur = getPlaybackPosition()
		pausedSession = {
			soundId = currentSound.SoundId,
			position = pausePosSnapshot,
			duration = dur > 0 and dur or cachedDuration,
		}
		paused = true
		playClockStart = 0
		killSound(currentSound)
		currentSound = nil
		logInfo("Pause @", string.format("%.1fs", pausePosSnapshot))
		notifyState()
	end

	function Music.Search(query, callback)
		query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if query == "" then
			if callback then
				callback({}, "Puste zapytanie")
			end
			return
		end
		S.MusicLastQuery = query

		task.spawn(function()
			local t0 = os.clock()
			logInfo("Search start:", query)

			local function finish(results, err)
				local ms = math.floor((os.clock() - t0) * 1000)
				if err then
					logErr("Search done (" .. ms .. "ms):", err, "| wyników:", #results)
				else
					logInfo("Search done (" .. ms .. "ms):", #results, "wyników")
				end
				if callback then
					local cbOk, cbErr = pcall(callback, results, err)
					if not cbOk then
						logErr("Search callback error:", cbErr)
					end
				end
			end

			local ok, err = pcall(function()
				local url = buildSearchUrl(query)
				logInfo("GET", url)
				local body, httpErr = httpGet(url)
				if not body then
					local presets = filterPresets(query)
					finish(presets, #presets == 0 and ("Brak połączenia z Archive — " .. tostring(httpErr or "HttpGet")) or ("Offline — " .. tostring(httpErr or "HttpGet")))
					return
				end

				local data, parseErr = decodeJson(body)
				if not data or not data.response then
					local presets = filterPresets(query)
					local msg = parseErr or "Błąd odpowiedzi Archive"
					finish(presets, #presets == 0 and msg or (msg .. " — znane hity"))
					return
				end

				local results = {}
				local seen = {}
				for _, doc in ipairs(data.response.docs or {}) do
					local item = normalizeDoc(doc)
					if item.identifier and not seen[item.identifier] then
						seen[item.identifier] = true
						table.insert(results, item)
					end
				end

				if #results == 0 then
					for _, preset in ipairs(filterPresets(query)) do
						if not seen[preset.identifier] then
							table.insert(results, preset)
						end
					end
				end

				finish(results, #results == 0 and "Brak wyników — spróbuj innej frazy" or nil)
			end)
			if not ok then
				logErr("Search crash:", err)
				local presets = filterPresets(query)
				finish(presets, #presets == 0 and tostring(err) or tostring(err))
			end
		end)
	end

	function Music.Play(item)
		if not item or not item.identifier then
			return false, "Brak utworu"
		end
		playGen += 1
		local myGen = playGen
		disconnectProgress()
		destroyAllMusicSounds()
		currentSound = nil
		paused = false
		pausedSession = nil
		nowPlaying = {
			identifier = item.identifier,
			title = item.title or item.identifier,
			creator = item.creator or "",
		}
		loading = true
		lastError = nil
		notifyState()

		task.spawn(function()
			local function stale()
				return myGen ~= playGen
			end

			logInfo("Play start:", item.identifier, item.title or "?")
			if stale() then
				return
			end

			local candidates, listErr = resolveDownloadList(item.identifier, item.title)
			if stale() then
				return
			end
			if not candidates then
				loading = false
				lastError = listErr
				logErr("Play metadata fail:", listErr)
				if Music.onPlayError then
					pcall(Music.onPlayError, listErr)
				end
				notifyState()
				return
			end

			local lastFail = nil
			for i, cand in ipairs(candidates) do
				if stale() then
					return
				end
				logInfo("Próba", i .. "/" .. #candidates .. ":", cand.name, "(" .. cand.format .. ")")
				local cacheKey = safeFileName(item.identifier .. "_" .. cand.name)
				local assetRef, cachePath, aerr = assetFromDownload(cand.url, cacheKey, i > 1)
				if stale() then
					return
				end

				if assetRef then
					local soundId = toSoundId(assetRef)
					if soundId then
						local sound = Instance.new("Sound")
						sound.Name = "VanguardMusic"
						sound.SoundId = soundId
						sound.Volume = S.MusicVolume or 0.65
						sound.Looped = S.MusicLoop == true
						sound.Parent = SoundService

						if waitForSoundLoad(sound, 12, myGen) and not stale() then
							local playOk = startPlayback(sound)
							if playOk and not stale() then
								currentSound = sound
								lastError = nil
								nowPlaying = {
									identifier = item.identifier,
									title = item.title or item.identifier,
									creator = item.creator or "",
									file = cand.name,
								}
								loading = false
								paused = false
								pausedSession = nil
								playPosOffset = 0
								pausePosSnapshot = 0
								playClockStart = os.clock()
								cachedDuration = sound.TimeLength
								logInfo("Play OK:", nowPlaying.title, "→", cand.name)

								attachProgress(sound)

								notifyState()
								task.defer(notifyState)
								return
							end
						end

						lastFail = "Roblox odrzucił format: " .. cand.name
						logErr("Sound load fail:", cand.name, soundId)
						killSound(sound)
					else
						lastFail = "Nieprawidłowy asset ID"
						logErr("Invalid asset ref:", assetRef)
					end
				else
					lastFail = aerr
					logErr("Asset fail:", aerr)
				end
				if cachePath then
					deleteCache(cachePath)
				end
			end

			if stale() then
				return
			end
			loading = false
			lastError = lastFail
				or "Ten upload nie ma OGG — Roblox odrzuca większość VBR MP3 z Archive"
			logErr("Play failed po wszystkich formatach:", lastError)
			if Music.onPlayError then
				pcall(Music.onPlayError, lastError)
			end
			notifyState()
		end)

		return true
	end

	if _G.VANGUARD then
		_G.VANGUARD.registerCleanup(function()
			Music.Stop()
		end)
	end
end

return Music
