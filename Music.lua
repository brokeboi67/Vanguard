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

function Music.Init(S, I18nModule)
	local I18n = I18nModule
	local function L(key, ...)
		if I18n and I18n.t then
			return I18n.t(key, ...)
		end
		return tostring(key)
	end
	local currentSound = nil
	local progressConn = nil
	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end
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
	local queue = {}
	local queueIndex = 0
	local trackEnding = false
	local activePlaySeek = 0
	local pendingPauseAfterPlay = false
	local transferRestorePending = false
	local lastSoundTimePos = 0
	local TRANSFER_MUSIC_PATH = "Vanguard/transfer_music.json"
	local GLOBAL_MUSIC_PATH = "Vanguard/music_persist.json"

	local function canPersistTransfer()
		return typeof(writefile) == "function"
			and typeof(readfile) == "function"
			and typeof(isfile) == "function"
	end

	local function musicPersistEnabled()
		return S.MusicGlobalPersist == true or S.TransferScript == true
	end

	local function musicPersistIsGlobal()
		return S.MusicGlobalPersist == true
	end

	local function ensureVanguardFolder()
		if typeof(makefolder) == "function" then
			pcall(makefolder, "Vanguard")
		end
	end

	local function decodeMusicFile(path)
		if not canPersistTransfer() or not isfile(path) then
			return nil
		end
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		if not ok or typeof(data) ~= "table" then
			return nil, "corrupt"
		end
		return data
	end

	local function writeMusicFile(path, snap)
		ensureVanguardFolder()
		local ok = pcall(function()
			writefile(path, HttpService:JSONEncode(snap))
		end)
		return ok == true
	end

	local function cloneQueueItem(item)
		if not item then
			return nil
		end
		return {
			identifier = item.identifier,
			title = item.title,
			creator = item.creator,
			source = item.source,
			localPath = item.localPath,
			streamUrl = item.streamUrl,
			audiusId = item.audiusId,
			videoId = item.videoId,
			downloads = item.downloads,
		}
	end

	local function findQueueIndexForItem(item)
		if not item or #queue == 0 then
			return 0
		end
		local id = item.identifier
		if id then
			for i, q in ipairs(queue) do
				if q.identifier == id then
					return i
				end
			end
		end
		local title = (item.title or ""):lower():gsub("%s+", " ")
		if title == "" then
			return 0
		end
		for i, q in ipairs(queue) do
			local qt = (q.title or ""):lower():gsub("%s+", " ")
			if qt == title then
				return i
			end
			if #title >= 4 and (qt:find(title, 1, true) or title:find(qt, 1, true)) then
				return i
			end
		end
		return 0
	end

	local function resolveCurrentQueueIndex()
		if nowPlaying and nowPlaying.queueSlot and nowPlaying.queueSlot > 0 then
			return nowPlaying.queueSlot
		end
		if queueIndex > 0 and queueIndex <= #queue then
			return queueIndex
		end
		if nowPlaying then
			return findQueueIndexForItem(nowPlaying)
		end
		return 0
	end

	local function logInfo(...)
		print("[Vanguard Music]", ...)
	end

	local function logErr(...)
		warn("[Vanguard Music]", ...)
	end

	Music.onProgress = nil
	Music.onStateChanged = nil
	Music.onPlayError = nil
	local stateListeners = {}

	function Music.AddStateListener(fn)
		if typeof(fn) == "function" then
			table.insert(stateListeners, fn)
		end
	end

	local function notifyState()
		local state = Music.GetState()
		if Music.onStateChanged then
			pcall(Music.onStateChanged, state)
		end
		for _, fn in ipairs(stateListeners) do
			pcall(fn, state)
		end
	end

	local function urlEncode(str)
		return HttpService:UrlEncode(str)
	end

	local function httpGet(url, timeoutSec, extraHeaders)
		timeoutSec = timeoutSec or HTTP_TIMEOUT
		local box = { done = false, body = nil, err = nil, via = nil }

		task.spawn(function()
			local headers = {
				["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
				["Accept"] = "application/json,text/plain,*/*",
			}
			if typeof(extraHeaders) == "table" then
				for key, value in pairs(extraHeaders) do
					headers[key] = value
				end
			end

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
			return nil, "Timeout (" .. timeoutSec .. "s)"
		end
		if box.body then
			logInfo("HTTP OK via", box.via, "(" .. #box.body .. " B)")
			return box.body
		end
		logErr("HTTP fail:", box.err or "brak body", "|", url)
		return nil, box.err or "Brak odpowiedzi HTTP"
	end

	local function httpPost(url, jsonBody, timeoutSec)
		timeoutSec = timeoutSec or HTTP_TIMEOUT
		local box = { done = false, body = nil, err = nil, via = nil }

		task.spawn(function()
			local headers = {
				["User-Agent"] = "Mozilla/5.0 (compatible; Vanguard/2.31)",
				["Content-Type"] = "application/json",
				["Accept"] = "application/json,text/plain,*/*",
			}

			local req = request or (syn and syn.request) or (http and http.request)
			if req then
				local ok, res = pcall(function()
					return req({
						Url = url,
						Method = "POST",
						Headers = headers,
						Body = jsonBody,
					})
				end)
				if ok and res then
					local code = tonumber(res.StatusCode) or 0
					if res.Body and res.Body ~= "" and code >= 200 and code < 300 then
						box.body = res.Body
						box.via = "request POST"
						box.done = true
						return
					end
					if not box.err then
						box.err = "request POST HTTP " .. tostring(code)
					end
				elseif not box.err then
					box.err = "request POST: " .. tostring(res)
				end
			end

			if HttpService.RequestAsync then
				local ok, res = pcall(function()
					return HttpService:RequestAsync({
						Url = url,
						Method = "POST",
						Headers = headers,
						Body = jsonBody,
					})
				end)
				if ok and res then
					if res.Success and res.Body and res.Body ~= "" then
						box.body = res.Body
						box.via = "RequestAsync POST"
						box.done = true
						return
					end
					if not box.err then
						box.err = "RequestAsync POST status " .. tostring(res.StatusCode)
					end
				elseif not box.err then
					box.err = "RequestAsync POST: " .. tostring(res)
				end
			end

			box.done = true
		end)

		local deadline = os.clock() + timeoutSec
		while not box.done and os.clock() < deadline do
			task.wait(0.05)
		end
		if not box.done then
			return nil, "Timeout POST (" .. timeoutSec .. "s)"
		end
		if box.body then
			logInfo("HTTP POST OK via", box.via, "(" .. #box.body .. " B)")
			return box.body
		end
		return nil, box.err or "Brak odpowiedzi POST"
	end

	local function decodeJson(body)
		if not body or body == "" then
			return nil
		end
		local trimmed = body:match("^%s*(.-)%s*$")
		if trimmed:sub(1, 1) == "<" then
			logErr("Odpowiedź HTML zamiast JSON:", trimmed:sub(1, 160))
			return nil, "Serwer zwrócił HTML zamiast JSON"
		end
		if trimmed:find("shutdown", 1, true) or trimmed:find("error code", 1, true) then
			return nil, "Serwis proxy niedostępny"
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
			if title:find("lyrics") or title:find("multitrack") then
				s -= 120
			elseif title:find("cover") or title:find("remix") or title:find("edit")
				or title:find("mashup") or title:find("bootleg") or title:find("karaoke")
				or title:find("8d audio") or title:find("slowed") or title:find("sped up")
				or title:find("reaction") or title:find("tutorial") or title:find("lesson") then
				s -= 70
			end

			if item.source == "audius" then
				s += 180
			elseif item.source == "youtube" then
				s -= 40
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

	local AUDIUS_NODES = {
		"https://discoveryprovider.audius.co",
		"https://audius-discovery-3.altego.net",
		"https://audius-discovery-7.cultur3stake.com",
	}
	local AUDIUS_API = AUDIUS_NODES[1]

	local function audiusGet(path, timeoutSec)
		timeoutSec = timeoutSec or HTTP_TIMEOUT
		local lastErr = nil
		for _, base in ipairs(AUDIUS_NODES) do
			local url = base .. path
			local body, err = httpGet(url, timeoutSec)
			if body then
				AUDIUS_API = base
				return body
			end
			lastErr = err
		end
		return nil, lastErr or "Audius nie odpowiada"
	end

	local function refreshAudiusStream(trackId)
		if not trackId then
			return nil
		end
		local body = audiusGet("/v1/tracks/" .. tostring(trackId) .. "?app_name=Vanguard", 10)
		if not body then
			return nil
		end
		local data = decodeJson(body)
		if data and data.data and data.data.stream and data.data.stream.url then
			return data.data.stream.url
		end
		return nil
	end

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
		local path = "/v1/tracks/search?query=" .. urlEncode(query) .. "&app_name=Vanguard"
		logInfo("Audius GET", query)
		local body, httpErr = audiusGet(path)
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

	local function walkYoutubeTree(node, results, seen, limit)
		if not node or #results >= limit then
			return
		end
		if typeof(node) ~= "table" then
			return
		end

		local vid = node.videoId
		if typeof(vid) == "string" and #vid == 11 and not seen[vid] and node.title then
			local title = nil
			if typeof(node.title) == "table" then
				if node.title.simpleText then
					title = node.title.simpleText
				elseif node.title.runs and node.title.runs[1] then
					title = node.title.runs[1].text
				end
			end
			if title and title ~= "" then
				local creator = "YouTube"
				if node.ownerText and node.ownerText.runs and node.ownerText.runs[1] then
					creator = node.ownerText.runs[1].text
				elseif node.longBylineText and node.longBylineText.runs and node.longBylineText.runs[1] then
					creator = node.longBylineText.runs[1].text
				end
				local views = 0
				if node.viewCountText and node.viewCountText.simpleText then
					views = tonumber(node.viewCountText.simpleText:gsub("[^%d]", "")) or 0
				end
				seen[vid] = true
				table.insert(results, {
					identifier = "yt:" .. vid,
					videoId = vid,
					title = title,
					creator = creator,
					downloads = views,
					source = "youtube",
				})
			end
		end

		for _, v in pairs(node) do
			walkYoutubeTree(v, results, seen, limit)
			if #results >= limit then
				return
			end
		end
	end

	local function searchYoutube(query)
		local payload = HttpService:JSONEncode({
			context = {
				client = {
					clientName = "WEB",
					clientVersion = "2.20250201.01.00",
				},
			},
			query = query,
		})
		logInfo("YouTube search:", query)
		local body, httpErr = httpPost(
			"https://www.youtube.com/youtubei/v1/search?prettyPrint=false",
			payload,
			15
		)
		if not body then
			return nil, httpErr or "YouTube nie odpowiada"
		end
		local data, parseErr = decodeJson(body)
		if not data then
			return nil, parseErr or "Błąd odpowiedzi YouTube"
		end
		local results = {}
		local seen = {}
		walkYoutubeTree(data, results, seen, 24)
		return results
	end

	local function cleanTitleForSearch(title)
		title = tostring(title or "")
		title = title:gsub("%b()", " "):gsub("%b[]", " ")
		title = title:gsub("Official 4K Video", "", 1)
		title = title:gsub("Official Video", "", 1)
		title = title:gsub("Official Audio", "", 1)
		title = title:gsub("HD", "", 1)
		return title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	end

	local function extractSongFromYoutube(item)
		local raw = cleanTitleForSearch(item.title or "")
		local creator = tostring(item.creator or ""):gsub(" %- Topic$", ""):gsub(" %- topic$", "")
		local song = raw
		local artist = creator

		local a, t = raw:match("^(.-)%s+-%s+(.+)$")
		if a and t and #t >= 2 then
			artist = a:gsub("^%s+", ""):gsub("%s+$", "")
			song = t:gsub("^%s+", ""):gsub("%s+$", "")
		end

		if artist ~= "" and artist ~= "YouTube" then
			local al = artist:lower()
			local sl = song:lower()
			if sl:sub(1, #al) == al then
				song = song:sub(#artist + 1):gsub("^[%s%-]+", ""):gsub("%s+", " ")
			end
		end

		song = song:gsub("^%s+", ""):gsub("%s+$", "")
		if artist == "YouTube" then
			artist = ""
		end
		return song, artist
	end

	local function scoreAudiusFallback(song, artist, track)
		local title = (track.title or ""):lower()
		local creator = (track.creator or ""):lower()
		local hay = title .. " " .. creator
		local s = 0
		local sw = song:lower()
		local aw = artist:lower()

		if sw ~= "" and title:find(sw, 1, true) then
			s += 100
		elseif sw ~= "" then
			for w in sw:gmatch("%S+") do
				if #w >= 2 and hay:find(w, 1, true) then
					s += 25
				end
			end
		end
		if aw ~= "" and hay:find(aw, 1, true) then
			s += 60
		end
		s += math.min((track.downloads or 0) / 1000, 20)
		return s
	end

	local function findAudiusCandidates(item, limit)
		limit = limit or 12
		local rawTitle = tostring(item.title or "")
		local song, artist = extractSongFromYoutube(item)
		local queries = {}
		local seenQ = {}

		local function addQ(q)
			q = tostring(q or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if q ~= "" and not seenQ[q:lower()] then
				seenQ[q:lower()] = true
				table.insert(queries, q)
			end
		end

		addQ(rawTitle)
		addQ(rawTitle:gsub("%b[]", " "):gsub("%b()", " "):gsub("%s+", " "))
		if song ~= "" and artist ~= "" then
			addQ(song .. " " .. artist)
			addQ(artist .. " " .. song)
		end
		if song ~= "" then
			addQ(song)
			addQ(song:gsub("[?%.!,]", " "))
		end
		if artist ~= "" then
			addQ(artist)
			local firstWords = song:match("^(%S+%s+%S+)") or song:match("^(%S+)")
			if firstWords and firstWords ~= "" then
				addQ(artist .. " " .. firstWords)
			end
		end

		local seen = {}
		local ranked = {}
		local function ingest(results)
			if not results then
				return
			end
			for _, r in ipairs(results) do
				if r.streamUrl and r.identifier and not seen[r.identifier] then
					seen[r.identifier] = true
					r._fb = scoreAudiusFallback(song, artist, r)
					if r._fb >= 20 then
						table.insert(ranked, r)
					end
				end
			end
		end

		for _, q in ipairs(queries) do
			ingest(searchAudius(q))
		end

		if #ranked < 3 and artist ~= "" then
			logInfo("Audius rozszerzone:", artist)
			ingest(searchAudius(artist))
		end

		table.sort(ranked, function(a, b)
			if a._fb ~= b._fb then
				return a._fb > b._fb
			end
			return (a.downloads or 0) > (b.downloads or 0)
		end)

		local out = {}
		for i, r in ipairs(ranked) do
			r._fb = nil
			table.insert(out, r)
			if i >= limit then
				break
			end
		end
		return out, song, artist
	end

	local function findAudiusForYoutube(item)
		local candidates = findAudiusCandidates(item, 1)
		return candidates[1]
	end

	local function pickYoutubeAudioUrl(data)
		if not data or not data.streamingData then
			return nil
		end
		local sd = data.streamingData
		local bestUrl, bestBr = nil, 0

		local function consider(list)
			if typeof(list) ~= "table" then
				return
			end
			for _, fmt in ipairs(list) do
				if typeof(fmt) == "table" and fmt.url and fmt.mimeType then
					local mime = tostring(fmt.mimeType):lower()
					if mime:find("audio/") and not mime:find("video") then
						local br = tonumber(fmt.bitrate) or tonumber(fmt.averageBitrate) or 0
						if br >= bestBr then
							bestBr = br
							bestUrl = fmt.url
						end
					end
				end
			end
		end

		consider(sd.adaptiveFormats)
		consider(sd.formats)
		return bestUrl
	end

	local function tryInnertubeStream(videoId)
		local payload = HttpService:JSONEncode({
			context = {
				client = {
					clientName = "WEB",
					clientVersion = "2.20250201.01.00",
					hl = "en",
					gl = "US",
				},
			},
			videoId = videoId,
		})
		local body = httpPost(
			"https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
			payload,
			8
		)
		if not body then
			return nil
		end
		local data = decodeJson(body)
		return pickYoutubeAudioUrl(data)
	end

	local function resolveYoutubeStream(videoId)
		videoId = tostring(videoId or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if #videoId ~= 11 then
			return nil, "Nieprawidłowe videoId"
		end
		local url = tryInnertubeStream(videoId)
		if url then
			logInfo("YouTube stream OK:", videoId)
			return url
		end
		return nil, "YouTube zablokowany w Roblox"
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
		if lower:find("%.m4a") or lower:find("%.mp4") then
			if body:sub(5, 8) == "ftyp" then
				return true
			end
			local b1, b2, b3 = body:byte(1, 3)
			if b1 == 0x49 and b2 == 0x44 and b3 == 0x33 then
				return true
			end
			if b1 == 0xFF and b2 and b2 >= 0xE0 then
				return true
			end
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

	local LOCAL_DIR = CACHE_DIR .. "/local"
	local LOCAL_EXTS = { mp3 = true, ogg = true, wav = true, flac = true, m4a = true }

	local function ensureLocalDir()
		ensureCacheDir()
		if typeof(makefolder) ~= "function" then
			return
		end
		if typeof(isfolder) == "function" and isfolder(LOCAL_DIR) then
			return
		end
		pcall(makefolder, LOCAL_DIR)
	end

	local function normalizeWinPath(path)
		return tostring(path or ""):gsub("/", "\\")
	end

	local function joinWinPath(a, b)
		a = normalizeWinPath(a):gsub("\\+$", "")
		b = normalizeWinPath(b):gsub("^\\+", "")
		if a == "" then
			return b
		end
		if b == "" then
			return a
		end
		return a .. "\\" .. b
	end

	local function safeGetEnv(key)
		if type(os) == "table" and typeof(os.getenv) == "function" then
			local ok, val = pcall(os.getenv, key)
			if ok and type(val) == "string" and val ~= "" then
				return val
			end
		end
		return ""
	end

	local function inferLocalAppData()
		local fromEnv = normalizeWinPath(safeGetEnv("LOCALAPPDATA"))
		if fromEnv ~= "" then
			return fromEnv
		end
		local user = safeGetEnv("USERNAME")
		if user ~= "" then
			return joinWinPath(joinWinPath("C:\\Users", user), "AppData\\Local")
		end
		return ""
	end

	local function isWinAbsPath(path)
		path = normalizeWinPath(path)
		return path:match("^%a:[\\/]") ~= nil
	end

	local function isExecutorWorkspaceRelPath(path)
		path = normalizeWinPath(path)
		if path == "" or isWinAbsPath(path) then
			return false
		end
		if path:lower():find("\\workspace\\", 1, true) or path:lower():match("\\workspace$") then
			return true
		end
		local head = path:match("^([^\\]+)\\")
		if not head then
			return false
		end
		local known = {
			potassium = true,
			krnl = true,
			fluxus = true,
			synapse = true,
			["script-ware"] = true,
			scriptware = true,
			valyse = true,
			celery = true,
			solara = true,
			wave = true,
			codex = true,
			jjsploit = true,
			electron = true,
			ronix = true,
			matcha = true,
			opiumware = true,
			hydrogen = true,
			xeno = true,
			vega = true,
			comet = true,
		}
		return known[head:lower()] == true
	end

	local function expandEnvVarTokens(path)
		path = normalizeWinPath(path)
		if path == "" then
			return path
		end
		local localApp = inferLocalAppData()
		if localApp ~= "" then
			local lower = path:lower()
			local token = "%%localappdata%%"
			local idx = lower:find(token, 1, true)
			if idx then
				return path:sub(1, idx - 1) .. localApp .. path:sub(idx + #token)
			end
		end
		return path
	end

	local function resolveAbsoluteWindowsPath(path)
		path = normalizeWinPath(expandEnvVarTokens(path))
		if path == "" then
			return path
		end
		if isWinAbsPath(path) then
			return path
		end
		if isExecutorWorkspaceRelPath(path) then
			local localApp = inferLocalAppData()
			if localApp ~= "" then
				return joinWinPath(localApp, path)
			end
		end
		return path
	end

	local function resolveExecutorWorkspace()
		local ok, result = pcall(function()
			if typeof(getsynapsepath) == "function" then
				local synOk, base = pcall(getsynapsepath)
				if synOk and type(base) == "string" and base ~= "" then
					return joinWinPath(normalizeWinPath(base), "workspace")
				end
			end
			if typeof(getexecutorpath) == "function" then
				local exOk, base = pcall(getexecutorpath)
				if exOk and type(base) == "string" and base ~= "" then
					local p = normalizeWinPath(base)
					if not p:lower():find("workspace", 1, true) then
						p = joinWinPath(p, "workspace")
					end
					return p
				end
			end
			if typeof(getgenv) == "function" then
				local gOk, g = pcall(getgenv)
				if gOk and type(g) == "table" and type(g.WORKSPACE_PATH) == "string" and g.WORKSPACE_PATH ~= "" then
					return normalizeWinPath(g.WORKSPACE_PATH)
				end
			end
			local execName = ""
			if typeof(identifyexecutor) == "function" then
				local idOk, name = pcall(identifyexecutor)
				if idOk and type(name) == "string" then
					execName = name:lower()
				end
			end
			local localApp = safeGetEnv("LOCALAPPDATA")
			local appData = safeGetEnv("APPDATA")
			local candidates = {
				{ "synapse x", joinWinPath(localApp, "Synapse\\workspace") },
				{ "synapse", joinWinPath(localApp, "Synapse\\workspace") },
				{ "script-ware", joinWinPath(localApp, "Script-Ware\\workspace") },
				{ "scriptware", joinWinPath(localApp, "Script-Ware\\workspace") },
				{ "krnl", joinWinPath(localApp, "Krnl\\workspace") },
				{ "fluxus", joinWinPath(localApp, "Fluxus\\workspace") },
				{ "valyse", joinWinPath(localApp, "Valyse\\workspace") },
				{ "celery", joinWinPath(localApp, "Celery\\workspace") },
				{ "solara", joinWinPath(localApp, "Solara\\workspace") },
				{ "wave", joinWinPath(localApp, "Wave\\workspace") },
				{ "codex", joinWinPath(localApp, "Codex\\workspace") },
				{ "potassium", joinWinPath(localApp, "Potassium\\workspace") },
				{ "jjsploit", joinWinPath(localApp, "JJSploit\\workspace") },
				{ "electron", joinWinPath(localApp, "Electron\\workspace") },
				{ "ronix", joinWinPath(localApp, "Ronix\\workspace") },
				{ "matcha", joinWinPath(localApp, "matcha\\workspace") },
				{ "opiumware", joinWinPath(localApp, "Opiumware\\workspace") },
				{ "hydrogen", joinWinPath(localApp, "Hydrogen\\workspace") },
				{ "xeno", joinWinPath(localApp, "Xeno\\workspace") },
				{ "vega", joinWinPath(localApp, "Vega X\\workspace") },
				{ "swift", joinWinPath(appData, "Swift\\workspace") },
				{ "comet", joinWinPath(localApp, "Comet\\workspace") },
				{ "arceus", joinWinPath(localApp, "Arceus X\\workspace") },
			}
			for _, entry in ipairs(candidates) do
				if execName:find(entry[1], 1, true) then
					return entry[2]
				end
			end
			if localApp ~= "" then
				return joinWinPath(localApp, "workspace")
			end
			return nil
		end)
		if ok then
			return result
		end
		return nil
	end

	local POTASSIUM_CACHE_ENV = "%localappdata%\\Potassium\\workspace\\VanguardMusic"
	local POTASSIUM_LOCAL_ENV = "%localappdata%\\Potassium\\workspace\\VanguardMusic\\local"

	local function isPotassiumExecutor()
		if typeof(identifyexecutor) == "function" then
			local ok, name = pcall(identifyexecutor)
			if ok and type(name) == "string" and name:lower():find("potassium", 1, true) then
				return true
			end
		end
		if typeof(getexecutorpath) == "function" then
			local ok, base = pcall(getexecutorpath)
			if ok and type(base) == "string" and base:lower():find("potassium", 1, true) then
				return true
			end
		end
		local root = resolveExecutorWorkspace()
		if type(root) == "string" and root:lower():find("potassium", 1, true) then
			return true
		end
		return false
	end

	local function toEnvVarPath(absPath)
		absPath = normalizeWinPath(absPath)
		if absPath == "" then
			return absPath
		end
		if absPath:lower():find("%%localappdata%%", 1, true) then
			return absPath
		end
		local localApp = inferLocalAppData()
		if localApp ~= "" and isWinAbsPath(absPath) then
			local absLower = absPath:lower()
			local appLower = localApp:lower()
			if #appLower > 0 and absLower:sub(1, #appLower) == appLower then
				local rest = absPath:sub(#localApp + 1):gsub("^\\+", "")
				return "%localappdata%\\" .. rest
			end
		end
		if isExecutorWorkspaceRelPath(absPath) then
			return "%localappdata%\\" .. absPath
		end
		if not isWinAbsPath(absPath) and absPath:find("\\", 1, true) then
			local localAppRel = inferLocalAppData()
			if localAppRel ~= "" then
				local expanded = joinWinPath(localAppRel, absPath)
				local absLower = expanded:lower()
				local appLower = localAppRel:lower()
				if absLower:sub(1, #appLower) == appLower then
					local rest = expanded:sub(#localAppRel + 1):gsub("^\\+", "")
					return "%localappdata%\\" .. rest
				end
			end
		end
		return absPath
	end

	local function relPathToEnvPath(relPath)
		relPath = tostring(relPath or ""):gsub("/", "\\"):gsub("^\\+", ""):gsub("\\+$", "")
		if relPath == "" then
			return relPath
		end
		local root = resolveExecutorWorkspace()
		if root then
			local abs = joinWinPath(root, relPath)
			local env = toEnvVarPath(abs)
			if env:lower():find("%%localappdata%%", 1, true) then
				return env
			end
		end
		if isExecutorWorkspaceRelPath(relPath) then
			return "%localappdata%\\" .. relPath
		end
		return relPath
	end

	local function localDirToWindowsPath()
		local root = resolveExecutorWorkspace()
		if not root then
			return nil
		end
		return joinWinPath(root, LOCAL_DIR:gsub("/", "\\"))
	end

	local function tryShellCommand(cmd)
		if typeof(execute) == "function" then
			local ok, result = pcall(execute, cmd)
			if ok and result ~= false then
				return true
			end
		end
		if typeof(exec) == "function" then
			local ok, result = pcall(exec, cmd)
			if ok and result ~= false then
				return true
			end
		end
		if typeof(os) == "table" and typeof(os.execute) == "function" then
			local ok, result = pcall(os.execute, cmd)
			if ok and result ~= false then
				return true
			end
		end
		return false
	end

	local function tryOpenWindowsFolder(absPath)
		absPath = resolveAbsoluteWindowsPath(absPath)
		if absPath == "" then
			return false
		end
		absPath = absPath:gsub("\\+$", "")
		local quoted = '"' .. absPath:gsub('"', "") .. '"'
		local commands = {
			"explorer " .. quoted,
			"cmd /c start \"\" /D " .. quoted .. " explorer " .. quoted,
			"cmd /c start explorer " .. quoted,
		}
		for _, cmd in ipairs(commands) do
			if tryShellCommand(cmd) then
				return true
			end
		end
		local syn = (syn or (getgenv and getgenv().syn)) or nil
		if syn and typeof(syn.open_file) == "function" then
			local ok = pcall(syn.open_file, absPath)
			if ok then
				return true
			end
		end
		return false
	end

	local function localTitleFromName(name)
		local base = tostring(name or ""):match("([^/\\]+)$") or tostring(name or "")
		return base:gsub("%.[%w]+$", "")
	end

	local function resolveLocalFilePath(rawName)
		rawName = tostring(rawName or ""):gsub("\\", "/"):gsub("^%./", "")
		local rel = LOCAL_DIR
		if rawName == rel or rawName:sub(1, #rel + 1) == rel .. "/" then
			return rawName
		end
		if typeof(isfile) == "function" and isfile(rawName) then
			return rawName
		end
		local base = rawName:match("([^/]+)$") or rawName
		local joined = rel .. "/" .. base
		return joined
	end

	local function normalizePlayItem(item)
		if not item or not item.identifier then
			return item
		end
		local id = tostring(item.identifier)
		if id:sub(1, 6) ~= "local:" then
			return item
		end
		item.source = "local"
		if not item.localPath or item.localPath == "" then
			item.localPath = resolveLocalFilePath(id:sub(7))
		end
		return item
	end

	local function searchLocalFiles(query)
		ensureLocalDir()
		if typeof(listfiles) ~= "function" or typeof(isfolder) ~= "function" then
			return {}, "Brak listfiles — wrzuć pliki do folderu VanguardMusic/local"
		end
		if not isfolder(LOCAL_DIR) then
			return {}, "Folder VanguardMusic/local nie istnieje"
		end
		local q = tostring(query or ""):lower()
		local results = {}
		for _, name in ipairs(listfiles(LOCAL_DIR)) do
			local filePath = resolveLocalFilePath(name)
			local lower = filePath:lower()
			local ext = lower:match("%.([%w]+)$")
			if ext and LOCAL_EXTS[ext] then
				local title = localTitleFromName(filePath)
				local hay = (lower .. " " .. title:lower())
				if q == "" or hay:find(q, 1, true) then
					table.insert(results, {
						source = "local",
						identifier = "local:" .. filePath,
						localPath = filePath,
						title = title,
						creator = "Local",
					})
				end
			end
		end
		table.sort(results, function(a, b)
			return (a.title or ""):lower() < (b.title or ""):lower()
		end)
		local err = nil
		if #results == 0 then
			if q == "" then
				err = "Brak plików w VanguardMusic/local — dodaj .mp3 / .ogg / .wav"
			else
				err = "Brak lokalnych plików dla: " .. query
			end
		end
		return results, err
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

	local function assetFromDownload(url, cacheName, skipCache, dlHeaders, timeoutSec)
		timeoutSec = timeoutSec or 45
		cacheName = safeFileName(cacheName)
		local relPath = CACHE_DIR .. "/" .. cacheName
		local getAsset, via = resolveCustomAssetFn()
		local fetchHeaders = dlHeaders
		if not fetchHeaders and tostring(url):find("googlevideo%.com") then
			fetchHeaders = {
				["Referer"] = "https://www.youtube.com/",
				["Origin"] = "https://www.youtube.com",
			}
		end

		if typeof(writecustomasset) == "function" then
			logInfo("Pobieranie audio (writecustomasset):", url:sub(1, 80))
			local body, httpErr = httpGet(url, timeoutSec, fetchHeaders)
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

		logInfo("Pobieranie audio:", url:sub(1, 80))
		local body, httpErr = httpGet(url, timeoutSec, fetchHeaders)
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
			if paused then
				return pausePosSnapshot, cachedDuration
			end
			if cachedDuration > 0 and playClockStart > 0 then
				local estimatedPos = math.min(playPosOffset + (os.clock() - playClockStart), cachedDuration)
				return estimatedPos, cachedDuration
			end
			return playPosOffset > 0 and playPosOffset or 0, cachedDuration
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

	local function captureTransferSnapshot()
		if not musicPersistEnabled() then
			return nil
		end
		local qOut = {}
		for _, it in ipairs(queue) do
			local copy = cloneQueueItem(it)
			if copy and copy.identifier then
				normalizePlayItem(copy)
				table.insert(qOut, copy)
			end
		end
		local pos, _dur = getPlaybackPosition()
		if paused and pausePosSnapshot > 0 then
			pos = pausePosSnapshot
		elseif paused and pausedSession and pausedSession.position then
			pos = pausedSession.position
		end
		local currentItem = nil
		local isActive = false
		if nowPlaying and nowPlaying.identifier then
			isActive = true
			currentItem = cloneQueueItem(nowPlaying)
			for _, it in ipairs(queue) do
				if it.identifier == currentItem.identifier then
					currentItem = cloneQueueItem(it)
					break
				end
			end
		elseif pausedSession and pausedSession.identifier then
			-- Paused mid-track — resume later
			isActive = true
			currentItem = {
				identifier = pausedSession.identifier,
				title = nowPlaying and nowPlaying.title or pausedSession.identifier,
				creator = nowPlaying and nowPlaying.creator or "",
				cachePath = pausedSession.cachePath,
			}
		end
		-- Do NOT fall back to queue[queueIndex] when idle — that re-started finished tracks after join
		if currentItem then
			normalizePlayItem(currentItem)
		end
		if #qOut == 0 and not currentItem then
			return nil
		end
		return {
			v = 1,
			mode = musicPersistIsGlobal() and "global" or "transfer",
			gameId = game.GameId,
			ts = os.time(),
			volume = S.MusicVolume or 0.65,
			loop = S.MusicLoop == true,
			autoQueue = S.MusicAutoQueue ~= false,
			showWidget = S.ShowMusicWidget ~= false,
			widgetPos = {
				xScale = tonumber(S.MusicWidgetPosXScale) or 0,
				xOffset = tonumber(S.MusicWidgetPosXOffset) or 18,
				yScale = tonumber(S.MusicWidgetPosYScale) or 1,
				yOffset = tonumber(S.MusicWidgetPosYOffset) or -90,
			},
			queue = qOut,
			queueIndex = queueIndex,
			current = currentItem and {
				item = currentItem,
				position = pos,
				paused = paused,
				active = isActive,
			} or nil,
		}
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

	local playFromQueue = nil

	local function handleTrackEnded()
		if trackEnding then
			return
		end
		if S.MusicLoop == true then
			return
		end
		trackEnding = true

		local curIdx = resolveCurrentQueueIndex()
		local nextIdx = nil
		if S.MusicAutoQueue ~= false and #queue > 0 then
			if curIdx > 0 and curIdx < #queue then
				nextIdx = curIdx + 1
			end
		end

		if nextIdx then
			queueIndex = nextIdx
			local nextItem = queue[nextIdx]
			logInfo("Auto-next:", nextIdx, "/", #queue, nextItem and nextItem.title or "?")
			trackEnding = false
			task.defer(function()
				if nextItem and playFromQueue then
					playFromQueue(nextItem, { keepQueue = true, queueIndex = nextIdx })
				else
					logErr("Auto-next fail — brak playFromQueue")
				end
			end)
			return
		end

		playGen += 1
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
		trackEnding = false
		notifyState()
		-- Persist idle state (queue kept, no auto-resume current) so next game doesn't restart
		if musicPersistEnabled() then
			task.defer(Music.SaveTransferState)
		end
	end

	local function attachProgress(sound)
		disconnectProgress()
		lastSoundTimePos = sound.TimePosition
		endedConn = sound.Ended:Connect(function()
			if currentSound ~= sound or paused or resuming or S.MusicLoop == true then
				return
			end
			handleTrackEnded()
		end)
		progressConn = RS.Heartbeat:Connect(perfWrap("Music.Progress", function()
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
			if tp + 2 < lastSoundTimePos and lastSoundTimePos > 3 and playPosOffset > 3 then
				local restorePos = math.max(playPosOffset, pausePosSnapshot)
				pcall(function()
					sound.TimePosition = restorePos
				end)
				-- If it fails to restore (e.g. engine broke the sound buffer), tp will remain low on next heartbeat
				-- However, if it's completely stuck at 0, we can detect it here if we want, but CharacterAdded handles the recreation.
				playPosOffset = restorePos
				playClockStart = os.clock()
				lastSoundTimePos = restorePos
				return
			end
			lastSoundTimePos = tp
			if tp > 0.5 and tp >= dur - 0.35 then
				handleTrackEnded()
				return
			end
			if tp <= 0.05 and playClockStart > 0 then
				local clockPos = playPosOffset + (os.clock() - playClockStart)
				if clockPos >= dur - 0.35 and clockPos >= dur * 0.88 then
					handleTrackEnded()
				end
			end
		end))
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
		local qIdx = resolveCurrentQueueIndex()
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
			queueIndex = qIdx,
			queueCount = #queue,
			hasNext = #queue > 0 and (qIdx <= 0 or qIdx < #queue),
			hasPrev = qIdx > 1,
		}
	end

	local MUSIC_VOL_MAX = 3

	function Music.SetVolume(v)
		S.MusicVolume = math.clamp(v, 0, MUSIC_VOL_MAX)
		if currentSound then
			currentSound.Volume = S.MusicVolume
		end
		notifyState()
	end

	function Music.GetVolumeMax()
		return MUSIC_VOL_MAX
	end

	function Music.Stop()
		playGen += 1
		queue = {}
		queueIndex = 0
		stopInternal()
		if musicPersistEnabled() then
			task.defer(function()
				-- Fully idle — wipe resume snapshots so next game stays silent
				if musicPersistIsGlobal() then
					Music.ClearGlobalPersist()
				end
				Music.ClearTransferState()
			end)
		end
	end

	function Music.GetQueue()
		local out = {}
		for _, item in ipairs(queue) do
			table.insert(out, cloneQueueItem(item))
		end
		return out, queueIndex
	end

	function Music.AddToQueue(item)
		local copy = cloneQueueItem(item)
		if not copy or not copy.identifier then
			return false, "Brak utworu"
		end
		for _, q in ipairs(queue) do
			if q.identifier == copy.identifier then
				notifyState()
				return false, "Już w kolejce"
			end
		end
		table.insert(queue, copy)
		logInfo("Dodano do kolejki:", copy.title)
		notifyState()
		return true
	end

	function Music.RemoveFromQueue(index)
		index = math.floor(tonumber(index) or 0)
		if index < 1 or index > #queue then
			return false
		end
		local wasCurrent = index == queueIndex
		table.remove(queue, index)
		if queueIndex > index then
			queueIndex -= 1
		elseif wasCurrent then
			queueIndex = 0
		elseif queueIndex > #queue then
			queueIndex = #queue
		end
		notifyState()
		return true
	end

	function Music.PlayQueue(items, startIdx)
		local built = {}
		for _, it in ipairs(items or {}) do
			local copy = cloneQueueItem(it)
			if copy and copy.identifier then
				table.insert(built, copy)
			end
		end
		if #built == 0 then
			return false, "Pusta kolejka"
		end
		queue = built
		queueIndex = math.clamp(math.floor(tonumber(startIdx) or 1), 1, #built)
		Music.Play(queue[queueIndex], { keepQueue = true })
		return true
	end

	function Music.PlayNext()
		if loading or resuming or #queue == 0 then
			return false
		end
		local curIdx = resolveCurrentQueueIndex()
		local nextIdx = curIdx > 0 and curIdx + 1 or 1
		if nextIdx > #queue then
			return false
		end
		queueIndex = nextIdx
		Music.Play(queue[queueIndex], { keepQueue = true, queueIndex = queueIndex })
		return true
	end

	function Music.PlayPrevious()
		if loading or resuming then
			return false
		end
		if queueIndex > 1 then
			queueIndex -= 1
			Music.Play(queue[queueIndex], { keepQueue = true })
			return true
		end
		if currentSound and currentSound.Parent then
			local pos = getPlaybackPosition()
			if pos > 3 then
				pcall(function()
					currentSound.TimePosition = 0
				end)
				playPosOffset = 0
				pausePosSnapshot = 0
				playClockStart = os.clock()
				notifyState()
				return true
			end
		end
		return false
	end

	function Music.ClearQueue()
		queue = {}
		queueIndex = 0
		notifyState()
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

	function Music.Seek(seconds)
		if resuming then
			return false
		end
		if loading then
			activePlaySeek = seconds
			if Music.onProgress and cachedDuration > 0 then
				pcall(Music.onProgress, seconds, cachedDuration)
			end
			notifyState()
			return true
		end
		seconds = math.max(0, tonumber(seconds) or 0)
		if currentSound and currentSound.Parent then
			local dur = currentSound.TimeLength
			if dur <= 0 then
				dur = cachedDuration
			end
			if dur > 0 then
				seconds = math.min(seconds, math.max(0, dur - 0.05))
			end
			pcall(function()
				currentSound.TimePosition = seconds
			end)
			playPosOffset = seconds
			playClockStart = os.clock()
			pausePosSnapshot = seconds
			if Music.onProgress then
				pcall(Music.onProgress, seconds, dur > 0 and dur or cachedDuration)
			end
			notifyState()
			return true
		end
		if paused then
			local dur = (pausedSession and pausedSession.duration) or cachedDuration
			if dur > 0 then
				seconds = math.min(seconds, dur)
			end
			pausePosSnapshot = seconds
			if pausedSession then
				pausedSession.position = seconds
			end
			if Music.onProgress then
				pcall(Music.onProgress, seconds, dur)
			end
			notifyState()
			return true
		end
		return false
	end

	function Music.TogglePause()
		if os.clock() - lastToggleAt < 0.35 then
			return
		end
		lastToggleAt = os.clock()

		if resuming then
			return
		end
		if loading then
			pendingPauseAfterPlay = not pendingPauseAfterPlay
			notifyState()
			return
		end

		if paused then
			if currentSound and currentSound.Parent then
				paused = false
				local resumePos = pausePosSnapshot

				if softPaused then
					currentSound.Volume = S.MusicVolume or 0.65
					softPaused = false
				else
					pcall(function()
						currentSound:Resume()
					end)
					if not currentSound.IsPlaying then
						pcall(function()
							currentSound.TimePosition = resumePos
						end)
						startPlayback(currentSound)
					end
					currentSound.Volume = S.MusicVolume or 0.65
				end

				playPosOffset = resumePos
				playClockStart = os.clock()
				pausedSession = nil
				lastError = nil
				logInfo("Resume @", string.format("%.1fs", resumePos))
				notifyState()
				return
			end
			task.spawn(resumePausedSession)
			return
		end

		if not currentSound or not currentSound.Parent then
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

		local usedNative = false
		pcall(function()
			currentSound:Pause()
			usedNative = not currentSound.IsPlaying
		end)

		paused = true
		playClockStart = 0
		if usedNative then
			softPaused = false
			logInfo("Pause native @", string.format("%.1fs", pos))
		else
			softPaused = true
			currentSound.Volume = 0
			logInfo("Pause soft @", string.format("%.1fs", pos))
		end
		notifyState()
		if musicPersistEnabled() then
			task.defer(Music.SaveTransferState)
		end
	end

	local function applySuccessfulPlay(sound, soundId, cachePath, item, fileLabel, myGen, seekPos)
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
			localPath = item.localPath,
			queueSlot = queueIndex > 0 and queueIndex or nil,
		}
		loading = false
		paused = false
		softPaused = false
		pausedSession = nil
		pausePosSnapshot = 0
		cachedDuration = sound.TimeLength
		local startAt = tonumber(seekPos) or 0
		if startAt > 0.05 then
			pcall(function()
				local dur = sound.TimeLength
				if dur > 0 then
					startAt = math.clamp(startAt, 0, math.max(0, dur - 0.05))
				end
				sound.TimePosition = startAt
			end)
			playPosOffset = sound.TimePosition
		else
			playPosOffset = 0
		end
		playClockStart = os.clock()
		logInfo("Play OK:", nowPlaying.title, "→", fileLabel, startAt > 0.05 and ("@" .. string.format("%.1fs", startAt)) or "")
		attachProgress(sound)
		notifyState()
		task.defer(notifyState)
		if pendingPauseAfterPlay then
			pendingPauseAfterPlay = false
			activePlaySeek = 0
			task.defer(function()
				for _ = 1, 30 do
					if currentSound and currentSound.Parent and not loading and not resuming then
						Music.TogglePause()
						break
					end
					task.wait(0.05)
				end
			end)
		else
			activePlaySeek = 0
		end
		if transferRestorePending then
			transferRestorePending = false
			Music.ClearTransferState()
		end
	end

	local function tryPlayAsset(assetRef, cachePath, item, fileLabel, myGen, stale, seekPos, loadTimeout)
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
		if waitForSoundLoad(sound, loadTimeout or 12, myGen) and not stale() then
			if startPlayback(sound) and not stale() then
				applySuccessfulPlay(sound, soundId, cachePath, item, fileLabel, myGen, seekPos)
				return true
			end
		end
		killSound(sound)
		return false, "Roblox odrzucił format: " .. fileLabel
	end

	local function readLocalFileBody(filePath)
		if typeof(readfile) ~= "function" then
			return nil, "Brak readfile w executorze"
		end
		local ok, body = pcall(readfile, filePath)
		if not ok or type(body) ~= "string" or #body < 100 then
			return nil, "Nie można odczytać pliku (ścieżka lub uprawnienia)"
		end
		return body
	end

	local function resolveLocalAssetRef(filePath)
		filePath = tostring(filePath or "")
		if filePath == "" then
			return nil, nil, "Brak ścieżki pliku"
		end
		if typeof(isfile) == "function" and not isfile(filePath) then
			local alt = resolveLocalFilePath(filePath)
			if alt ~= filePath and isfile(alt) then
				filePath = alt
			else
				return nil, nil, "Plik nie istnieje: " .. filePath
			end
		end

		local getAsset, via = resolveCustomAssetFn()
		if getAsset then
			local ok, assetRef = pcall(getAsset, filePath)
			if ok and assetRef and assetRef ~= "" then
				logInfo("Local asset OK via", via, "→", filePath)
				return assetRef, filePath, nil
			end
			logErr("getcustomasset fail dla:", filePath, tostring(assetRef))
		end

		local body, readErr = readLocalFileBody(filePath)
		if not body then
			return nil, nil, readErr
		end
		local valid, validErr = validateAudioBody(body, filePath)
		if not valid then
			return nil, nil, validErr or "Nieprawidłowy plik audio"
		end

		local ext = filePath:lower():match("%.([%w]+)$") or "mp3"
		local safeBase = safeFileName(localTitleFromName(filePath) .. "." .. ext)

		if typeof(writecustomasset) == "function" then
			local ok, assetRef = pcall(writecustomasset, safeBase, body)
			if ok and assetRef and assetRef ~= "" then
				logInfo("Local via writecustomasset:", safeBase)
				return assetRef, filePath, nil
			end
			logErr("writecustomasset fail:", safeBase, tostring(assetRef))
		end

		if getAsset and typeof(writefile) == "function" then
			ensureCacheDir()
			local cacheRel = CACHE_DIR .. "/local_" .. safeBase
			local writeOk, writeErr = pcall(writefile, cacheRel, body)
			if writeOk then
				local ok, assetRef = pcall(getAsset, cacheRel)
				if ok and assetRef and assetRef ~= "" then
					logInfo("Local via cache copy:", cacheRel)
					return assetRef, cacheRel, nil
				end
				logErr("Cache copy asset fail:", cacheRel, tostring(assetRef))
			else
				logErr("Cache copy write fail:", writeErr)
			end
		end

		return nil, nil, "Executor nie zarejestrował pliku — spróbuj OGG zamiast MP3"
	end

	local function downloadAudiusCandidate(cand, timeoutSec, skipCache)
		local streamUrl = cand.streamUrl
		if cand.audiusId then
			local fresh = refreshAudiusStream(cand.audiusId)
			if fresh then
				streamUrl = fresh
			end
		end
		local cacheKey = safeFileName("audius_" .. tostring(cand.audiusId or cand.identifier) .. ".mp3")
		local assetRef, cachePath, aerr = assetFromDownload(streamUrl, cacheKey, skipCache, nil, timeoutSec)
		return assetRef, cachePath, aerr
	end

	local function playAudiusCandidates(candidates, myGen, stale, logPrefix)
		if not candidates or #candidates == 0 then
			return false
		end
		logPrefix = logPrefix or "Audius"
		local batchSize = 3
		local idx = 1
		while idx <= #candidates do
			if stale() then
				return false
			end
			local batchEnd = math.min(idx + batchSize - 1, #candidates)
			local winner = nil
			local claimed = false
			local expected = batchEnd - idx + 1
			local finished = 0
			local batchTimeout = idx == 1 and 26 or 20

			for bi = idx, batchEnd do
				local cand = candidates[bi]
				local perTimeout = (idx == 1 and bi == idx) and 28 or 18
				task.spawn(function()
					logInfo(logPrefix, "próba", bi .. "/" .. #candidates .. ":", cand.title)
					local assetRef, cachePath, aerr = downloadAudiusCandidate(cand, perTimeout, bi > 1)
					finished += 1
					if assetRef and not claimed and not stale() then
						claimed = true
						winner = {
							cand = cand,
							assetRef = assetRef,
							cachePath = cachePath,
							cacheKey = safeFileName("audius_" .. tostring(cand.audiusId or cand.identifier) .. ".mp3"),
						}
					elseif not assetRef then
						logErr("Audius pobieranie fail:", aerr)
					end
				end)
			end

			local deadline = os.clock() + batchTimeout
			while finished < expected and not winner and os.clock() < deadline do
				task.wait(0.08)
			end

			if winner then
				local okPlay, playErr = tryPlayAsset(
					winner.assetRef,
					winner.cachePath,
					winner.cand,
					winner.cacheKey,
					myGen,
					stale,
					activePlaySeek
				)
				if okPlay then
					return true
				end
				if winner.cachePath then
					deleteCache(winner.cachePath)
				end
				logErr("Audius próba fail:", playErr)
			end

			idx = batchEnd + 1
		end
		return false
	end

	function Music.GetSource()
		local src = tostring(S.MusicSource or "audius"):lower()
		if src == "archive" then
			return "archive"
		end
		if src == "audius" then
			return "audius"
		end
		if src == "youtube" then
			return "youtube"
		end
		if src == "local" then
			return "local"
		end
		return "auto"
	end

	function Music.SetSource(src)
		src = tostring(src or ""):lower()
		if src == "archive" or src == "audius" or src == "youtube" or src == "local" then
			S.MusicSource = src
		else
			S.MusicSource = "auto"
		end
		notifyState()
	end

	function Music.GetLocalDir()
		return LOCAL_DIR
	end

	function Music.GetLocalDirAbsolute()
		ensureLocalDir()
		local ok, path = pcall(localDirToWindowsPath)
		if ok and type(path) == "string" and path ~= "" then
			return resolveAbsoluteWindowsPath(path)
		end
		local user = safeGetEnv("USERNAME")
		local execName = ""
		if typeof(identifyexecutor) == "function" then
			local idOk, n = pcall(identifyexecutor)
			if idOk and type(n) == "string" then
				execName = n:lower()
			end
		end
		if user ~= "" and execName:find("potassium", 1, true) then
			return joinWinPath(
				joinWinPath(joinWinPath("C:\\Users", user), "AppData\\Local"),
				"Potassium\\workspace\\" .. LOCAL_DIR:gsub("/", "\\")
			)
		end
		return nil
	end

	function Music.GetLocalDirEnvPath()
		if isPotassiumExecutor() then
			return POTASSIUM_LOCAL_ENV
		end
		local abs = Music.GetLocalDirAbsolute()
		if abs and abs ~= "" then
			local env = toEnvVarPath(abs)
			if env:lower():find("%%localappdata%%", 1, true) then
				return env
			end
		end
		local envFallback = relPathToEnvPath(LOCAL_DIR)
		if envFallback:lower():find("%%localappdata%%", 1, true) then
			return envFallback
		end
		return POTASSIUM_LOCAL_ENV
	end

	function Music.EnsureLocalDir()
		ensureLocalDir()
	end

	function Music.OpenLocalFolder()
		ensureLocalDir()
		local abs = Music.GetLocalDirAbsolute()
		local clip = Music.GetLocalDirEnvPath()
		local opened = abs and tryOpenWindowsFolder(abs) or false
		return opened, clip, abs
	end

	function Music.CopyLocalDirPath()
		local clip = Music.GetLocalDirEnvPath()
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, clip)
		elseif typeof(toclipboard) == "function" then
			pcall(toclipboard, clip)
		end
		return clip
	end

	local function cacheDirToWindowsPath()
		local root = resolveExecutorWorkspace()
		if not root then
			return nil
		end
		return joinWinPath(root, CACHE_DIR:gsub("/", "\\"))
	end

	local function cacheEntryBaseName(entry)
		return tostring(entry or ""):gsub("\\", "/"):match("([^/]+)$") or tostring(entry or "")
	end

	local function isLocalCacheSubfolder(entry)
		local base = cacheEntryBaseName(entry):lower()
		if base == "local" then
			return typeof(isfolder) == "function" and isfolder(entry)
		end
		return false
	end

	local function isDownloadCacheFile(entry)
		if not entry or entry == "" then
			return false
		end
		if isLocalCacheSubfolder(entry) then
			return false
		end
		if typeof(isfolder) == "function" and isfolder(entry) then
			return false
		end
		if typeof(isfile) == "function" then
			return isfile(entry)
		end
		local base = cacheEntryBaseName(entry)
		return base ~= "" and base:lower() ~= "local"
	end

	local function fileSizeBytes(relPath)
		if typeof(getfilesize) == "function" then
			local ok, n = pcall(getfilesize, relPath)
			if ok and type(n) == "number" and n >= 0 then
				return n
			end
		end
		local root = resolveExecutorWorkspace()
		if root then
			local abs = joinWinPath(root, tostring(relPath):gsub("/", "\\"))
			if type(io) == "table" and typeof(io.open) == "function" then
				local ok, sz = pcall(function()
					local f = io.open(abs, "rb")
					if not f then
						return nil
					end
					local size = f:seek("end")
					f:close()
					return size
				end)
				if ok and type(sz) == "number" and sz >= 0 then
					return sz
				end
			end
		end
		return nil
	end

	local function formatCacheBytes(bytes)
		bytes = tonumber(bytes) or 0
		if bytes < 1024 then
			return bytes .. " B"
		end
		if bytes < 1024 * 1024 then
			return string.format("%.1f KB", bytes / 1024)
		end
		if bytes < 1024 * 1024 * 1024 then
			return string.format("%.1f MB", bytes / (1024 * 1024))
		end
		return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
	end

	local function listDownloadCacheFiles()
		if typeof(listfiles) ~= "function" or typeof(isfolder) ~= "function" then
			return nil, "Brak listfiles"
		end
		ensureCacheDir()
		if not isfolder(CACHE_DIR) then
			return {}, nil
		end
		local out = {}
		for _, entry in ipairs(listfiles(CACHE_DIR)) do
			if isDownloadCacheFile(entry) then
				table.insert(out, entry)
			end
		end
		return out, nil
	end

	function Music.GetCacheDir()
		return CACHE_DIR
	end

	function Music.GetCacheDirAbsolute()
		ensureCacheDir()
		local ok, path = pcall(cacheDirToWindowsPath)
		if ok and type(path) == "string" and path ~= "" then
			return resolveAbsoluteWindowsPath(path)
		end
		return nil
	end

	function Music.GetCacheDirEnvPath()
		if isPotassiumExecutor() then
			return POTASSIUM_CACHE_ENV
		end
		local abs = Music.GetCacheDirAbsolute()
		if abs and abs ~= "" then
			local env = toEnvVarPath(abs)
			if env:lower():find("%%localappdata%%", 1, true) then
				return env
			end
		end
		local envFallback = relPathToEnvPath(CACHE_DIR)
		if envFallback:lower():find("%%localappdata%%", 1, true) then
			return envFallback
		end
		return POTASSIUM_CACHE_ENV
	end

	function Music.GetCacheStats()
		local files, err = listDownloadCacheFiles()
		local envPath = Music.GetCacheDirEnvPath()
		if not files then
			return {
				fileCount = 0,
				totalBytes = 0,
				sizeKnown = false,
				path = envPath,
				localPath = Music.GetLocalDirEnvPath(),
				error = err,
			}
		end
		local totalBytes = 0
		local sizeKnown = true
		for _, path in ipairs(files) do
			local sz = fileSizeBytes(path)
			if sz then
				totalBytes += sz
			else
				sizeKnown = false
			end
		end
		return {
			fileCount = #files,
			totalBytes = totalBytes,
			sizeKnown = sizeKnown,
			path = envPath,
			localPath = Music.GetLocalDirEnvPath(),
			error = nil,
		}
	end

	function Music.ClearDownloadCache()
		local files, err = listDownloadCacheFiles()
		if not files then
			return false, 0, 0, err or "Brak listfiles"
		end
		local deleted = 0
		local bytesFreed = 0
		for _, path in ipairs(files) do
			if isDownloadCacheFile(path) then
				local sz = fileSizeBytes(path) or 0
				deleteCache(path)
				if typeof(isfile) == "function" and not isfile(path) then
					deleted += 1
					bytesFreed += sz
				elseif typeof(isfile) ~= "function" then
					deleted += 1
					bytesFreed += sz
				end
			end
		end
		logInfo("Cache wyczyszczony:", deleted, "plików,", formatCacheBytes(bytesFreed))
		return true, deleted, bytesFreed, nil
	end

	function Music.FormatCacheBytes(bytes)
		return formatCacheBytes(bytes)
	end

	function Music.Search(query, callback)
		query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local source = Music.GetSource()
		if query == "" and source ~= "local" then
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

				if source == "auto" then
					local box = { aud = nil, yt = nil, done = 0 }
					task.spawn(function()
						box.aud = searchAudius(query)
						box.done += 1
					end)
					task.spawn(function()
						box.yt = searchYoutube(query)
						box.done += 1
					end)
					local deadline = os.clock() + 18
					while box.done < 2 and os.clock() < deadline do
						task.wait(0.05)
					end

					local results = {}
					local seen = {}
					for _, r in ipairs(box.aud or {}) do
						if r.identifier and not seen[r.identifier] then
							seen[r.identifier] = true
							table.insert(results, r)
						end
					end
					for _, r in ipairs(box.yt or {}) do
						if r.identifier and not seen[r.identifier] then
							seen[r.identifier] = true
							table.insert(results, r)
						end
					end

					if #results == 0 then
						finish({}, "Brak wyników — sprawdź HttpGet")
						return
					end
					rankSearchResults(query, results)
					local aud, yt = {}, {}
					for _, r in ipairs(results) do
						if r.source == "youtube" then
							if #yt < 6 then
								table.insert(yt, r)
							end
						else
							table.insert(aud, r)
						end
					end
					results = aud
					for _, r in ipairs(yt) do
						table.insert(results, r)
					end
					results = filterSearchResults(query, results)
					finish(results, nil)
					return
				end

				if source == "audius" then
					local results, audErr = searchAudius(query)
					if not results then
						finish({}, audErr or "Audius niedostępny")
						return
					end
					rankSearchResults(query, results)
					results = filterSearchResults(query, results)
					finish(results, #results == 0 and "Brak wyników na Audius" or nil)
					return
				end

				if source == "youtube" then
					local results, ytErr = searchYoutube(query)
					if not results then
						finish({}, ytErr or "YouTube niedostępny")
						return
					end
					rankSearchResults(query, results)
					results = filterSearchResults(query, results)
					finish(results, #results == 0 and "Brak wyników na YouTube" or nil)
					return
				end

				if source == "local" then
					local results, locErr = searchLocalFiles(query)
					finish(results, locErr)
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

	function Music.Play(item, opts)
		opts = opts or {}
		activePlaySeek = tonumber(opts.startPosition) or 0
		pendingPauseAfterPlay = opts.resumePaused == true
		item = cloneQueueItem(item)
		if not item or not item.identifier then
			activePlaySeek = 0
			pendingPauseAfterPlay = false
			return false, "Brak utworu"
		end
		normalizePlayItem(item)
		if opts.queueIndex then
			queueIndex = math.clamp(math.floor(opts.queueIndex), 1, math.max(1, #queue))
		else
			local idx = findQueueIndexForItem(item)
			if idx > 0 then
				queueIndex = idx
			elseif not opts.keepQueue then
				queueIndex = 0
			end
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

			if item.source == "youtube" and item.videoId then
				local candidates, song, artist = findAudiusCandidates(item, 12)
				logInfo("YT → Audius:", song, "|", artist, "| kandydatów:", #candidates)

				if playAudiusCandidates(candidates, myGen, stale, "YT→Audius") then
					return
				end

				loading = false
				lastError = L("music_no_audius", song ~= "" and song or item.title or "?")
				logErr("Play fail YT — utwór nie jest na Audius")
				if Music.onPlayError then
					pcall(Music.onPlayError, lastError)
				end
				notifyState()
				return
			end

			if item.source == "audius" and item.streamUrl then
				if playAudiusCandidates({ item }, myGen, stale, "Audius") then
					return
				end
				loading = false
				lastError = L("music_audius_fail")
				if Music.onPlayError then
					pcall(Music.onPlayError, lastError)
				end
				notifyState()
				return
			end

			if item.source == "local" and item.localPath and item.localPath ~= "" then
				local getAsset = select(1, resolveCustomAssetFn())
				if not getAsset and typeof(writecustomasset) ~= "function" then
					loading = false
					lastError = "Brak getcustomasset — włącz filesystem w executorze"
					if Music.onPlayError then
						pcall(Music.onPlayError, lastError)
					end
					notifyState()
					return
				end
				local assetRef, cachePath, aerr = resolveLocalAssetRef(item.localPath)
				if stale() then
					return
				end
				if assetRef then
					local okPlay, playErr = tryPlayAsset(
						assetRef,
						cachePath or item.localPath,
						item,
						item.title or item.localPath,
						myGen,
						stale,
						activePlaySeek,
						20
					)
					if okPlay then
						return
					end
					lastError = playErr
						or "Roblox odrzucił ten plik (często VBR MP3) — przekonwertuj na OGG"
				else
					lastError = aerr or "Nie odtworzono pliku lokalnego"
				end
				loading = false
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
								applySuccessfulPlay(sound, soundId, cachePath, item, cand.name, myGen, activePlaySeek)
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
			activePlaySeek = 0
			pendingPauseAfterPlay = false
			transferRestorePending = false
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

	function Music.SaveTransferState()
		if not musicPersistEnabled() or not canPersistTransfer() then
			return false
		end
		local snap = captureTransferSnapshot()
		if not snap then
			return false
		end
		local ok = false
		-- Global: dedicated file (no GameId gate on restore). Transfer: teleport file.
		if musicPersistIsGlobal() then
			snap.mode = "global"
			ok = writeMusicFile(GLOBAL_MUSIC_PATH, snap) or ok
		end
		if S.TransferScript == true then
			snap.mode = "transfer"
			ok = writeMusicFile(TRANSFER_MUSIC_PATH, snap) or ok
		elseif not musicPersistIsGlobal() then
			snap.mode = "transfer"
			ok = writeMusicFile(TRANSFER_MUSIC_PATH, snap) or ok
		end
		return ok
	end

	function Music.ClearTransferState()
		-- Only clear transfer teleport snapshot — never wipe global persist here
		if canPersistTransfer() and isfile(TRANSFER_MUSIC_PATH) then
			pcall(delfile, TRANSFER_MUSIC_PATH)
		end
	end

	function Music.ClearGlobalPersist()
		if canPersistTransfer() and isfile(GLOBAL_MUSIC_PATH) then
			pcall(delfile, GLOBAL_MUSIC_PATH)
		end
	end

	local function readTransferData()
		-- Prefer global persist when toggle is on (works across games / fresh execute)
		if musicPersistIsGlobal() then
			local data, err = decodeMusicFile(GLOBAL_MUSIC_PATH)
			if data then
				local maxAge = 7 * 24 * 3600
				if os.time() - (tonumber(data.ts) or 0) > maxAge then
					return nil, "expired"
				end
				return data
			end
			if err == "corrupt" then
				return nil, "corrupt"
			end
			-- Fallback: old transfer_music.json saved before split (ignore GameId)
			local legacy = decodeMusicFile(TRANSFER_MUSIC_PATH)
			if legacy then
				local maxAge = 7 * 24 * 3600
				if os.time() - (tonumber(legacy.ts) or 0) <= maxAge then
					return legacy
				end
			end
			return nil
		end

		local data, err = decodeMusicFile(TRANSFER_MUSIC_PATH)
		if not data then
			return nil, err
		end
		if data.gameId ~= game.GameId then
			return nil, "game"
		end
		if os.time() - (tonumber(data.ts) or 0) > 900 then
			return nil, "expired"
		end
		return data
	end

	local function applyTransferPrefs(data)
		if not data then
			return false
		end
		local applied = false
		local vol = tonumber(data.volume)
		if vol then
			Music.SetVolume(vol)
			applied = true
		end
		if data.loop ~= nil then
			S.MusicLoop = data.loop == true
			if currentSound then
				currentSound.Looped = S.MusicLoop
			end
			applied = true
		end
		if data.autoQueue ~= nil then
			S.MusicAutoQueue = data.autoQueue ~= false
			applied = true
		end
		if data.showWidget ~= nil then
			S.ShowMusicWidget = data.showWidget ~= false
			applied = true
		end
		if typeof(data.widgetPos) == "table" then
			local wp = data.widgetPos
			S.MusicWidgetPosXScale = tonumber(wp.xScale) or 0
			S.MusicWidgetPosXOffset = tonumber(wp.xOffset) or 18
			S.MusicWidgetPosYScale = tonumber(wp.yScale) or 1
			S.MusicWidgetPosYOffset = tonumber(wp.yOffset) or -90
			applied = true
		end
		return applied
	end

	function Music.ApplyTransferVolume()
		local data = readTransferData()
		if not data then
			return false
		end
		local vol = tonumber(data.volume)
		if vol then
			Music.SetVolume(vol)
			return true
		end
		return false
	end

	function Music.ApplyTransferSettings()
		return applyTransferPrefs(readTransferData())
	end

	function Music.RestoreFromTransfer()
		local data, reason = readTransferData()
		if not data then
			if reason == "corrupt" or reason == "expired" then
				if musicPersistIsGlobal() then
					Music.ClearGlobalPersist()
				else
					Music.ClearTransferState()
				end
			end
			logInfo("Persist restore skipped:", tostring(reason or "none"))
			return false
		end

		applyTransferPrefs(data)

		queue = {}
		for _, it in ipairs(data.queue or {}) do
			local copy = cloneQueueItem(it)
			if copy and copy.identifier then
				normalizePlayItem(copy)
				table.insert(queue, copy)
			end
		end
		queueIndex = math.clamp(math.floor(tonumber(data.queueIndex) or 0), 0, #queue)

		local cur = data.current
		transferRestorePending = true
		local isGlobal = musicPersistIsGlobal() or data.mode == "global"

		if cur and typeof(cur.item) == "table" and cur.item.identifier then
			local item = cloneQueueItem(cur.item)
			normalizePlayItem(item)
			local idx = findQueueIndexForItem(item)
			if idx > 0 then
				queueIndex = idx
			end
			local pos = tonumber(cur.position) or 0
			local wasPaused = cur.paused == true
			-- Only auto-resume when we were actually playing/paused — not after track finished
			local shouldResume = cur.active == true or (cur.active == nil and (wasPaused or pos > 1.5))
			if cur.active == false then
				shouldResume = false
			end
			if not shouldResume then
				logInfo(isGlobal and "Global restore: queue only (track was idle)" or "Transfer restore: queue only (track was idle)")
				transferRestorePending = false
				if not isGlobal then
					Music.ClearTransferState()
				else
					task.defer(Music.SaveTransferState)
				end
				notifyState()
				return true
			end
			logInfo(
				isGlobal and "Global restore:" or "Transfer restore:",
				item.title or item.identifier,
				string.format("@ %.1fs", pos),
				wasPaused and "(paused)" or ""
			)
			task.defer(function()
				Music.Play(item, {
					keepQueue = true,
					queueIndex = queueIndex > 0 and queueIndex or nil,
					startPosition = pos,
					resumePaused = wasPaused,
				})
				-- Keep global file; only clear teleport transfer snapshot
				if not isGlobal then
					Music.ClearTransferState()
				else
					task.defer(Music.SaveTransferState)
				end
			end)
			return true
		end

		if #queue > 0 then
			transferRestorePending = false
			if not isGlobal then
				Music.ClearTransferState()
			end
			notifyState()
			logInfo(isGlobal and "Global restore: queue only" or "Transfer restore: queue only", #queue)
			return true
		end
		transferRestorePending = false
		if not isGlobal then
			Music.ClearTransferState()
		end
		return false
	end

	local transferHeartbeatConn = nil
	local transferHeartbeatAt = 0
	transferHeartbeatConn = RS.Heartbeat:Connect(perfWrap("Music.Transfer", function()
		if not musicPersistEnabled() then
			return
		end
		if os.clock() - transferHeartbeatAt < 3 then
			return
		end
		transferHeartbeatAt = os.clock()
		if #queue > 0 or nowPlaying or pausedSession or (paused and currentSound) then
			Music.SaveTransferState()
		end
	end))

	local TeleportService = game:GetService("TeleportService")
	local tpConn = nil
	pcall(function()
		tpConn = TeleportService.LocalPlayerLeaving:Connect(function()
			if musicPersistEnabled() then
				Music.SaveTransferState()
			end
		end)
	end)

	playFromQueue = Music.Play

	local Players = game:GetService("Players")
	local LP = Players.LocalPlayer
	local charConn = nil
	if LP then
		charConn = LP.CharacterAdded:Connect(function()
			task.defer(function()
				task.wait(1.0)
				if not nowPlaying or loading or resuming then
					return
				end
				if paused and pausedSession then
					return
				end
				local targetPos = playPosOffset
				if playClockStart > 0 and not paused and cachedDuration > 0 then
					targetPos = math.min(playPosOffset + (os.clock() - playClockStart), cachedDuration)
				end
				if targetPos < 1 then
					return
				end
				if currentSound and currentSound.Parent then
					local tp = currentSound.TimePosition
					if tp + 2 < targetPos then
						pcall(function()
							local dur = currentSound.TimeLength
							if dur > 0 then
								targetPos = math.clamp(targetPos, 0, math.max(0, dur - 0.05))
							end
							currentSound.TimePosition = targetPos
						end)
						task.wait(0.15)
						if currentSound and currentSound.TimePosition < targetPos - 2 then
							logInfo("Respawn — sound broken (TimePosition locked), recreating @", string.format("%.1fs", targetPos))
							Music.Play(nowPlaying, {
								keepQueue = true,
								queueIndex = queueIndex > 0 and queueIndex or nil,
								startPosition = targetPos,
								resumePaused = paused
							})
							return
						end
						playPosOffset = targetPos
						playClockStart = os.clock()
						lastSoundTimePos = targetPos
						logInfo("Respawn seek restore @", string.format("%.1fs", targetPos))
					end
					return
				end
				for _retryAttempt = 1, 6 do
					task.wait(0.3)
					if loading or resuming then
						return
					end
					if currentSound and currentSound.Parent then
						local tp = currentSound.TimePosition
						if tp + 2 < targetPos then
							pcall(function()
								local dur = currentSound.TimeLength
								if dur > 0 then
									targetPos = math.clamp(targetPos, 0, math.max(0, dur - 0.05))
								end
								currentSound.TimePosition = targetPos
							end)
							task.wait(0.15)
							if currentSound and currentSound.TimePosition < targetPos - 2 then
								logInfo("Respawn delayed — sound broken, recreating @", string.format("%.1fs", targetPos))
								Music.Play(nowPlaying, {
									keepQueue = true,
									queueIndex = queueIndex > 0 and queueIndex or nil,
									startPosition = targetPos,
									resumePaused = paused
								})
								return
							end
							playPosOffset = targetPos
							playClockStart = os.clock()
							lastSoundTimePos = targetPos
							logInfo("Respawn delayed restore @", string.format("%.1fs", targetPos))
						end
						return
					end
				end
				if nowPlaying and nowPlaying.identifier and not loading and not resuming then
					logInfo("Respawn — sound lost, restarting @", string.format("%.1fs", targetPos))
					Music.Play(nowPlaying, {
						keepQueue = true,
						queueIndex = queueIndex > 0 and queueIndex or nil,
						startPosition = targetPos,
						resumePaused = paused
					})
				end
			end)
		end)
	end

	if _G.VANGUARD then
		_G.VANGUARD.registerCleanup(function()
			if musicPersistEnabled() then
				pcall(Music.SaveTransferState)
			end
			if transferHeartbeatConn then
				transferHeartbeatConn:Disconnect()
				transferHeartbeatConn = nil
			end
			if tpConn then
				tpConn:Disconnect()
				tpConn = nil
			end
			if charConn then
				charConn:Disconnect()
				charConn = nil
			end
		end)
		_G.VANGUARD.registerCleanup(function()
			Music.Stop()
		end)
	end
end

return Music
