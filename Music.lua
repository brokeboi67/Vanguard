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

function Music.Init(S)
	local currentSound = nil
	local progressConn = nil
	local loading = false
	local paused = false
	local nowPlaying = nil
	local lastError = nil

	Music.onProgress = nil
	Music.onStateChanged = nil
	Music.onPlayError = nil

	local function notifyState()
		if Music.onStateChanged then
			pcall(Music.onStateChanged, Music.GetState())
		end
	end

	local function httpGet(url)
		local req = request or (syn and syn.request) or (http and http.request)
		if req then
			local ok, res = pcall(function()
				return req({
					Url = url,
					Method = "GET",
					Headers = { ["User-Agent"] = "Vanguard/1.0" },
				})
			end)
			if ok and res and res.Body then
				return res.Body
			end
		end
		return game:HttpGet(url, true)
	end

	local function urlEncode(str)
		return HttpService:UrlEncode(str)
	end

	local function decodeJson(body)
		if not body or body == "" then
			return nil
		end
		local ok, data = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if ok then
			return data
		end
		return nil
	end

	local function assetFromUrl(url)
		if getcustomasset then
			local ok, id = pcall(getcustomasset, url)
			if ok and id then
				return id
			end
		end
		if typeof(getsynasset) == "function" then
			local ok, id = pcall(getsynasset, url)
			if ok and id then
				return id
			end
		end
		return nil, "Executor nie wspiera getcustomasset — wymagane do streamu z Archive"
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
		local body = httpGet("https://archive.org/metadata/" .. urlEncode(identifier))
		local meta = decodeJson(body)
		if not meta or not meta.files then
			return nil, "Brak metadanych Archive"
		end
		local file = pickAudioFile(meta.files)
		if not file then
			return nil, "Brak pliku audio (MP3/OGG) w tym uploadzie"
		end
		local dl = "https://archive.org/download/" .. identifier .. "/" .. urlEncode(file.name)
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
			local q = urlEncode(query .. " AND mediatype:audio")
			local url = "https://archive.org/advancedsearch.php?q="
				.. q
				.. "&fl[]=identifier,title,creator,downloads,description"
				.. "&sort[]=downloads desc&rows=24&page=1&output=json"

			local ok, err = pcall(function()
				local body = httpGet(url)
				local data = decodeJson(body)
				if not data or not data.response then
					if callback then
						callback({}, "Błąd odpowiedzi Archive")
					end
					return
				end
				local docs = data.response.docs or {}
				local results = {}
				for _, doc in ipairs(docs) do
					local title = doc.title
					if typeof(title) == "table" then
						title = title[1]
					end
					local creator = doc.creator
					if typeof(creator) == "table" then
						creator = table.concat(creator, ", ")
					end
					table.insert(results, {
						identifier = doc.identifier,
						title = tostring(title or doc.identifier or "?"),
						creator = tostring(creator or "Unknown"),
						downloads = tonumber(doc.downloads) or 0,
					})
				end
				if callback then
					callback(results, #results == 0 and "Brak wyników — spróbuj innej frazy" or nil)
				end
			end)
			if not ok and callback then
				callback({}, tostring(err))
			end
		end)
	end

	function Music.Play(item)
		if not item or not item.identifier then
			return false, "Brak utworu"
		end
		stopInternal()
		loading = true
		notifyState()

		task.spawn(function()
			local dlUrl, fileNameOrErr = resolveDownload(item.identifier)
			if not dlUrl then
				loading = false
				lastError = fileNameOrErr
				if Music.onPlayError then
					pcall(Music.onPlayError, fileNameOrErr)
				end
				notifyState()
				return
			end

			local assetId, aerr = assetFromUrl(dlUrl)
			if not assetId then
				loading = false
				lastError = aerr
				if Music.onPlayError then
					pcall(Music.onPlayError, aerr)
				end
				notifyState()
				return
			end

			local sound = Instance.new("Sound")
			sound.Name = "VanguardMusic"
			sound.SoundId = "rbxassetid://" .. tostring(assetId)
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
