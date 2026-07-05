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
	{ identifier = "hnm-1982", title = "Human Nature (Multitracks)", creator = "Michael Jackson", downloads = 12000 },
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
	local resuming = false
	local softPaused = false
	local endedConn = nil
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

	local function queryWords(query)
		local words = {}
		for w in tostring(query or ""):lower():gmatch("[%w']+") do
			if #w >= 2 then
				table.insert(words, w)
			end
		end
		return words
	end

	local function buildSearchUrls(query)
		local clean = tostring(query or ""):gsub('"', ""):gsub("^%s+", ""):gsub("%s+$", "")
		local terms = {}
		local seen = {}

		local function add(term)
			if term == "" or seen[term] then
				return
			end
			seen[term] = true
			table.insert(terms, term)
		end

		if clean:find(":") or clean:find('"') then
			add(clean)
		else
			local words = {}
			for w in clean:gmatch("%S+") do
				table.insert(words, w)
			end

			if #words >= 4 then
				local artist = words[#words - 1] .. " " .. words[#words]
				local songParts = {}
				for i = 1, #words - 2 do
					table.insert(songParts, words[i])
				end
				local song = table.concat(songParts, " ")
				add('title:"' .. song .. '" AND creator:"' .. artist .. '"')
				add('title:"' .. song .. '" AND "' .. artist .. '"')
			elseif #words == 3 then
				local artist = words[2] .. " " .. words[3]
				add('title:"' .. words[1] .. '" AND creator:"' .. artist .. '"')
				add('title:"' .. words[1] .. '" AND "' .. artist .. '"')
			elseif #words == 2 then
				add('title:"' .. words[1] .. '" AND creator:"' .. words[2] .. '"')
				add('creator:"' .. words[2] .. '" AND title:"' .. words[1] .. '"')
			end

			add('(title:"' .. clean .. '" OR creator:"' .. clean .. '" OR "' .. clean .. '")')
			add('creator:"' .. clean .. '"')
		end

		local urls = {}
		for _, term in ipairs(terms) do
			local lucene = term .. " AND mediatype:audio"
			table.insert(urls, "https://archive.org/advancedsearch.php?q="
				.. urlEncode(lucene)
				.. "&fl[]=identifier,title,creator,downloads"
				.. "&sort[]=downloads+desc"
				.. "&rows=48&page=1&output=json")
		end
		return urls
	end

	local function filterSearchResults(query, results)
		local words = queryWords(query)
		if #words < 2 or #results == 0 then
			return results
		end
		local minMatch = math.max(2, math.ceil(#words * 0.45))
		local filtered = {}
		for _, item in ipairs(results) do
			local hay = ((item.title or "") .. " " .. (item.creator or "")):lower()
			local matched = 0
			for _, w in ipairs(words) do
				if hay:find(w, 1, true) then
					matched += 1
				end
			end
			if matched >= minMatch then
				table.insert(filtered, item)
			end
		end
		if #filtered >= 2 then
			return filtered
		end
		return results
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

	local function rankSearchResults(query, results)
		local q = query:lower()
		local words = {}
		for w in q:gmatch("[%w]+") do
			if #w >= 2 then
				table.insert(words, w)
			end
		end

		local function relevance(item)
			local title = (item.title or ""):lower()
			local creator = (item.creator or ""):lower()
			local hay = title .. " " .. creator
			local s = 0

			if title == q then
				s += 250
			end
			if title:find(q, 1, true) then
				s += 180
			end
			if hay:find(q, 1, true) then
				s += 120
			end

			local matched = 0
			for _, w in ipairs(words) do
				if hay:find(w, 1, true) then
					matched += 1
				end
			end
			if #words > 0 then
				s += (matched / #words) * 100
			end
			if matched == #words and #words >= 2 then
				s += 60
			end

			if title:find("podcast") or title:find("radio") or title:find("program")
				or title:find("mix") or title:find("voice of america") or title:find("voa")
				or title:find("crap from") or title:find("kmart") or title:find("tape%-a%-thon") then
				s -= 80
			end
			if title:find("lyrics") or title:find("multitrack") or title:find("cover") then
				if title:find("multitrack") then
					s -= 90
				else
					s += 10
				end
			end

			s += math.min((item.downloads or 0) / 2000, 15)
			return s
		end

		for _, item in ipairs(results) do
			item._rel = relevance(item)
		end
		table.sort(results, function(a, b)
			if a._rel ~= b._rel then
				return a._rel > b._rel
			end
			return (a.downloads or 0) > (b.downloads or 0)
		end)
		for _, item in ipairs(results) do
			item._rel = nil
		end
		return results
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

	local AUDIUS_API = "https://discoveryprovider.audius.co"

	local function normalizeAudiusTrack(track)
		local user = track.user
		local creator = "Audius"
		if user then
			creator = tostring(user.name or user.handle or creator)
		end
		return {
			identifier = "audius:" .. tostring(track.id or "?"),
			audiusId = track.id,
			title = tostring(track.title or track.id or "?"),
			creator = creator,
			downloads = tonumber(track.play_count) or 0,
			source = "audius",
			streamUrl = track.stream and track.stream.url,
		}
	end

	local function searchAudius(query)
		local url = AUDIUS_API .. "/v1/tracks/search?query=" .. urlEncode(query) .. "&app_name=Vanguard"
		logInfo("Audius GET", url)
		local body, httpErr = httpGet(url)
		if not body then
			return nil, httpErr or "Audius nie odpowiada"
		end
		local data, parseErr = decodeJson(body)
		if not data or not data.data then
			return nil, parseErr or "Błąd odpowiedzi Audius"
		end
		local results = {}
		for _, track in ipairs(data.data) do
			if track.is_streamable ~= false and track.stream and track.stream.url then
				table.insert(results, normalizeAudiusTrack(track))
			end
		end
		return results
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
		if endedConn then
			endedConn:Disconnect()
			endedConn = nil
		end
	end

	local function stopInternal()
		disconnectProgress()
		destroyAllMusicSounds()
		currentSound = nil
		paused = false
		softPaused = false
		nowPlaying = nil
		loading = false
		resuming = false
		playClockStart = 0
		playPosOffset = 0
		pausePosSnapshot = 0
		pausedSession = nil
		cachedDuration = 0
		notifyState()
	end

	local function attachProgress(sound)
		disconnectProgress()
		endedConn = sound.Ended:Connect(function()
			if currentSound ~= sound or paused or S.MusicLoop == true then
				return
			end
			playGen += 1
			stopInternal()
		end)
		progressConn = RS.Heartbeat:Connect(function()
			if currentSound ~= sound or paused or loading or resuming then
				return
			end
			local pos, dur = getPlaybackPosition()
			if Music.onProgress and dur > 0 then
				pcall(Music.onProgress, pos, dur)
			end
			if S.MusicLoop == true or dur <= 0 then
				return
			end
			local tp = sound.TimePosition
			if tp > 0.5 and tp >= dur - 0.35 then
				playGen += 1
				stopInternal()
				return
			end
			if tp <= 0.05 and playClockStart > 0 then
				local clockPos = playPosOffset + (os.clock() - playClockStart)
				if clockPos >= dur - 0.35 and clockPos >= dur * 0.88 then
					playGen += 1
					stopInternal()
				end
			end
		end)
	end

	local function soundIdFromSession(session)
		local soundId = session.soundId
		if session.cachePath and typeof(isfile) == "function" and isfile(session.cachePath) then
			local getAsset, via = resolveCustomAssetFn()
			if getAsset then
				local ok, assetRef = pcall(getAsset, session.cachePath)
				if ok and assetRef and assetRef ~= "" then
					local sid = toSoundId(assetRef)
					if sid then
						logInfo("Resume z cache via", via)
						return sid
					end
				end
			end
		end
		return soundId
	end

	local function resumePausedSession()
		if resuming then
			return
		end
		if not pausedSession or not pausedSession.soundId then
			paused = false
			softPaused = false
			notifyState()
			return
		end

		resuming = true
		loading = true
		notifyState()

		local ok, err = pcall(function()
			local session = pausedSession
			local soundId = soundIdFromSession(session)
			if not soundId then
				error("Brak SoundId do wznowienia")
			end

			local sound = Instance.new("Sound")
			sound.Name = "VanguardMusic"
			sound.SoundId = soundId
			sound.Volume = S.MusicVolume or 0.65
			sound.Looped = S.MusicLoop == true
			sound.Parent = SoundService

			if not waitForSoundLoad(sound, 12) then
				killSound(sound)
				error("Nie udało się wznowić odtwarzania")
			end

			local pos = math.min(session.position or 0, math.max(0, sound.TimeLength - 0.1))
			pcall(function()
				sound.TimePosition = pos
			end)

			if not startPlayback(sound) then
				killSound(sound)
				error("Resume play fail")
			end

			task.wait(0.15)
			if pos > 0.05 then
				pcall(function()
					sound.TimePosition = pos
				end)
			end

			currentSound = sound
			paused = false
			softPaused = false
			pausedSession = nil
			lastError = nil
			playPosOffset = pos
			pausePosSnapshot = pos
			playClockStart = os.clock()
			cachedDuration = sound.TimeLength

			attachProgress(sound)
			logInfo("Resume OK @", string.format("%.1fs", pos))
		end)

		loading = false
		resuming = false
		if not ok then
			lastError = tostring(err)
			logErr("Resume fail:", err)
		end
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
			loading = loading or resuming,
			playing = currentSound ~= nil and not paused,
			paused = paused,
			title = nowPlaying and nowPlaying.title or "",
			artist = nowPlaying and nowPlaying.creator or "",
			identifier = nowPlaying and nowPlaying.identifier or "",
			position = pos,
			duration = dur,
			volume = S.MusicVolume or 0.65,
			error = lastError,
			hasTrack = nowPlaying ~= nil or (paused and pausedSession ~= nil),
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
		return loading or resuming
	end

	function Music.SetLoop(on)
		S.MusicLoop = on == true
		if currentSound then
			currentSound.Looped = S.MusicLoop
		end
		notifyState()
	end

	function Music.TogglePause()
		if os.clock() - lastToggleAt < 0.35 then
			return
		end
		lastToggleAt = os.clock()

		if loading or resuming then
			return
		end

		if paused then
			if currentSound and softPaused then
				paused = false
				softPaused = false
				currentSound.Volume = S.MusicVolume or 0.65
				playPosOffset = pausePosSnapshot
				playClockStart = os.clock()
				pcall(function()
					if currentSound.TimePosition < pausePosSnapshot - 0.5 or currentSound.TimePosition < 0.05 then
						currentSound.TimePosition = pausePosSnapshot
					end
				end)
				if not currentSound.IsPlaying then
					startPlayback(currentSound)
					task.defer(function()
						if currentSound and not paused then
							pcall(function()
								currentSound.TimePosition = pausePosSnapshot
							end)
						end
					end)
				end
				pausedSession = nil
				lastError = nil
				logInfo("Resume soft @", string.format("%.1fs", pausePosSnapshot))
				notifyState()
				return
			end
			task.spawn(resumePausedSession)
			return
		end

		if not currentSound then
			return
		end

		local pos, dur = getPlaybackPosition()
		pausePosSnapshot = pos
		pausedSession = {
			soundId = currentSound.SoundId,
			position = pos,
			duration = dur > 0 and dur or cachedDuration,
			cachePath = nowPlaying and nowPlaying.cachePath,
			identifier = nowPlaying and nowPlaying.identifier,
		}
		paused = true
		softPaused = true
		playClockStart = 0
		currentSound.Volume = 0
		logInfo("Pause soft @", string.format("%.1fs", pos))
		notifyState()
	end

	local function applySuccessfulPlay(sound, soundId, cachePath, item, fileLabel, myGen)
		currentSound = sound
		lastError = nil
		nowPlaying = {
			identifier = item.identifier,
			title = item.title or item.identifier,
			creator = item.creator or "",
			file = fileLabel,
			soundId = soundId,
			cachePath = cachePath,
			source = item.source,
		}
		loading = false
		paused = false
		softPaused = false
		pausedSession = nil
		playPosOffset = 0
		pausePosSnapshot = 0
		playClockStart = os.clock()
		cachedDuration = sound.TimeLength
		logInfo("Play OK:", nowPlaying.title, "→", fileLabel)
		attachProgress(sound)
		notifyState()
		task.defer(notifyState)
	end

	local function tryPlayAsset(assetRef, cachePath, item, fileLabel, myGen, stale)
		local soundId = toSoundId(assetRef)
		if not soundId then
			return false, "Nieprawidłowy asset ID"
		end
		local sound = Instance.new("Sound")
		sound.Name = "VanguardMusic"
		sound.SoundId = soundId
		sound.Volume = S.MusicVolume or 0.65
		sound.Looped = S.MusicLoop == true
		sound.Parent = SoundService
		if waitForSoundLoad(sound, 12, myGen) and not stale() then
			if startPlayback(sound) and not stale() then
				applySuccessfulPlay(sound, soundId, cachePath, item, fileLabel, myGen)
				return true
			end
		end
		killSound(sound)
		return false, "Roblox odrzucił format: " .. fileLabel
	end

	function Music.GetSource()
		local src = tostring(S.MusicSource or "audius"):lower()
		if src ~= "archive" then
			return "audius"
		end
		return "archive"
	end

	function Music.SetSource(src)
		src = tostring(src or ""):lower()
		S.MusicSource = src == "archive" and "archive" or "audius"
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
				local source = Music.GetSource()
				logInfo("Search source:", source)

				if source == "audius" then
					local results, audErr = searchAudius(query)
					if not results then
						finish({}, audErr or "Audius niedostępny")
						return
					end
					for _, preset in ipairs(filterPresets(query)) do
						preset.source = "archive"
						table.insert(results, 1, preset)
					end
					rankSearchResults(query, results)
					results = filterSearchResults(query, results)
					finish(results, #results == 0 and "Brak wyników na Audius" or nil)
					return
				end

				local urls = buildSearchUrls(query)
				local results = {}
				local seen = {}
				local httpErr = nil

				for i, url in ipairs(urls) do
					logInfo("GET", i .. "/" .. #urls, url)
					local body, err = httpGet(url)
					if body then
						local data = decodeJson(body)
						if data and data.response then
							for _, doc in ipairs(data.response.docs or {}) do
								local item = normalizeDoc(doc)
								if item.identifier and not seen[item.identifier] then
									seen[item.identifier] = true
									table.insert(results, item)
								end
							end
						end
					else
						httpErr = err
					end
					if i == 1 and #results >= 8 then
						break
					end
				end

				for _, preset in ipairs(filterPresets(query)) do
					if not seen[preset.identifier] then
						seen[preset.identifier] = true
						table.insert(results, 1, preset)
					end
				end

				if #results == 0 then
					local presets = filterPresets(query)
					finish(presets, #presets == 0 and ("Brak połączenia z Archive — " .. tostring(httpErr or "HttpGet")) or ("Offline — " .. tostring(httpErr or "HttpGet")))
					return
				end

				rankSearchResults(query, results)
				results = filterSearchResults(query, results)

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
		softPaused = false
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

			if item.source == "audius" and item.streamUrl then
				local cacheKey = safeFileName("audius_" .. tostring(item.audiusId or item.identifier) .. ".mp3")
				local assetRef, cachePath, aerr = assetFromDownload(item.streamUrl, cacheKey, false)
				if stale() then
					return
				end
				if assetRef then
					local okPlay, playErr = tryPlayAsset(assetRef, cachePath, item, cacheKey, myGen, stale)
					if okPlay then
						return
					end
					if cachePath then
						deleteCache(cachePath)
					end
					loading = false
					lastError = playErr
					if Music.onPlayError then
						pcall(Music.onPlayError, playErr)
					end
					notifyState()
					return
				end
				loading = false
				lastError = aerr or "Nie pobrano z Audius"
				if Music.onPlayError then
					pcall(Music.onPlayError, lastError)
				end
				notifyState()
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
									soundId = soundId,
									cachePath = cachePath,
								}
								loading = false
								paused = false
								softPaused = false
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
