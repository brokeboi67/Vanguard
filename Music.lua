-- Plik: workspace/Vanguard/Music.lua

local Music = {}

local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("RunService")

local AUDIO_SCORE = {
	["VBR MP3"] = 100,
	["MP3"] = 95,
	["Ogg Vorbis"] = 80,
	["Opus"] = 75,
	["Flac"] = 40,
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
		local lucene = query .. " AND mediatype:audio"
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

	local function assetFromDownload(url, cacheName)
		cacheName = safeFileName(cacheName)
		local relPath = CACHE_DIR .. "/" .. cacheName
		local getAsset, via = resolveCustomAssetFn()

		if typeof(writecustomasset) == "function" then
			logInfo("Pobieranie audio (writecustomasset):", url)
			local body, httpErr = httpGet(url, 30)
			if not body then
				return nil, "Nie pobrano MP3: " .. tostring(httpErr)
			end
			local ok, assetRef = pcall(writecustomasset, cacheName, body)
			if ok and assetRef and assetRef ~= "" then
				logInfo("writecustomasset OK:", cacheName, "(" .. #body .. " B)")
				return assetRef
			end
			logErr("writecustomasset fail:", assetRef)
		end

		if not getAsset then
			return nil, "Brak getcustomasset w executorze (Potassium: włącz filesystem)"
		end
		if typeof(writefile) ~= "function" then
			return nil, "Brak writefile — nie da się zapisać MP3"
		end

		ensureCacheDir()

		if typeof(isfile) == "function" and isfile(relPath) then
			local ok, assetRef = pcall(getAsset, relPath)
			if ok and assetRef and assetRef ~= "" then
				logInfo("Cache hit:", relPath, "via", via)
				return assetRef
			end
		end

		logInfo("Pobieranie audio:", url)
		local body, httpErr = httpGet(url, 30)
		if not body then
			return nil, "Nie pobrano MP3: " .. tostring(httpErr)
		end
		logInfo("Pobrano", #body, "B →", relPath)

		local writeOk, writeErr = pcall(writefile, relPath, body)
		if not writeOk then
			relPath = cacheName
			writeOk, writeErr = pcall(writefile, relPath, body)
		end
		if not writeOk then
			return nil, "writefile fail: " .. tostring(writeErr)
		end

		local ok, assetRef = pcall(getAsset, relPath)
		if ok and assetRef and assetRef ~= "" then
			logInfo("getcustomasset OK via", via, "→", tostring(assetRef):sub(1, 48))
			return assetRef
		end
		return nil, "getcustomasset fail: " .. tostring(assetRef)
	end

	local function disconnectProgress()
		if progressConn then
			progressConn:Disconnect()
			progressConn = nil
		end
	end

	local function stopInternal()
		disconnectProgress()
		if currentSound then
			pcall(function()
				currentSound:Stop()
				currentSound:Destroy()
			end)
			currentSound = nil
		end
		paused = false
		nowPlaying = nil
		notifyState()
	end

	local function pickAudioFile(files)
		local best, bestScore = nil, -1
		for _, f in ipairs(files or {}) do
			local name = tostring(f.name or "")
			local fmt = tostring(f.format or "")
			local size = tonumber(f.size) or 0
			if size >= 40000 and size <= 30000000 then
				local lower = name:lower()
				local skip = lower:find("sample") or lower:find("preview") or lower:find(".m3u") or lower:find(".xml")
				if not skip then
					local score = AUDIO_SCORE[fmt] or 0
					if fmt == "" and lower:find("%.mp3") then
						score = 90
					elseif lower:find("%.opus") then
						score = math.max(score, 75)
					elseif lower:find("%.ogg") then
						score = math.max(score, 80)
					end
					if score > 0 and score >= bestScore then
						bestScore = score
						best = f
					end
				end
			end
		end
		return best
	end

	local function resolveDownload(identifier)
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
		local file = pickAudioFile(meta.files)
		if not file then
			return nil, "Brak pliku audio (MP3/OGG) w tym uploadzie"
		end
		local dl = "https://archive.org/download/" .. id .. "/" .. urlEncode(file.name)
		return dl, file.name
	end

	function Music.GetState()
		local pos, dur = 0, 0
		if currentSound then
			pos = currentSound.TimePosition
			dur = currentSound.TimeLength
		end
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
		if currentSound then
			currentSound.Volume = S.MusicVolume
		end
		notifyState()
	end

	function Music.Stop()
		stopInternal()
	end

	function Music.TogglePause()
		if not currentSound then
			return
		end
		if paused then
			currentSound:Resume()
			paused = false
		else
			currentSound:Pause()
			paused = true
		end
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
		stopInternal()
		loading = true
		lastError = nil
		notifyState()

		task.spawn(function()
			logInfo("Play start:", item.identifier, item.title or "?")
			local dlUrl, fileNameOrErr = resolveDownload(item.identifier)
			if not dlUrl then
				loading = false
				lastError = fileNameOrErr
				logErr("Play metadata fail:", fileNameOrErr)
				if Music.onPlayError then
					pcall(Music.onPlayError, fileNameOrErr)
				end
				notifyState()
				return
			end

			local cacheKey = safeFileName(item.identifier .. "_" .. fileNameOrErr)
			local assetRef, aerr = assetFromDownload(dlUrl, cacheKey)
			if not assetRef then
				loading = false
				lastError = aerr
				logErr("Play asset fail:", aerr, "|", dlUrl)
				if Music.onPlayError then
					pcall(Music.onPlayError, aerr)
				end
				notifyState()
				return
			end

			local soundId = toSoundId(assetRef)
			if not soundId then
				loading = false
				lastError = "Nieprawidłowy asset ID"
				logErr("Invalid asset ref:", assetRef)
				if Music.onPlayError then
					pcall(Music.onPlayError, lastError)
				end
				notifyState()
				return
			end

			local sound = Instance.new("Sound")
			sound.Name = "VanguardMusic"
			sound.SoundId = soundId
			sound.Volume = S.MusicVolume or 0.65
			sound.Looped = S.MusicLoop == true
			sound.Parent = SoundService

			local playOk = pcall(function()
				SoundService:PlayLocalSound(sound)
			end)
			if not playOk then
				sound:Destroy()
				loading = false
				lastError = "PlayLocalSound failed"
				logErr("PlayLocalSound failed")
				if Music.onPlayError then
					pcall(Music.onPlayError, lastError)
				end
				notifyState()
				return
			end

			currentSound = sound
			lastError = nil
			nowPlaying = {
				identifier = item.identifier,
				title = item.title or item.identifier,
				creator = item.creator or "",
				file = fileNameOrErr,
			}
			loading = false
			paused = false
			logInfo("Play OK:", nowPlaying.title)

			sound.Ended:Connect(function()
				if currentSound == sound then
					stopInternal()
				end
			end)

			disconnectProgress()
			progressConn = RS.Heartbeat:Connect(function()
				if currentSound ~= sound or not Music.onProgress then
					return
				end
				local dur = sound.TimeLength
				if dur > 0 then
					pcall(Music.onProgress, sound.TimePosition, dur)
				end
			end)

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
