-- Plik: workspace/Vanguard/Session.lua

local Session = {}

function Session.rejoin(markLeave)
	if markLeave then
		pcall(markLeave)
	end
	local TS = game:GetService("TeleportService")
	local LP = game:GetService("Players").LocalPlayer
	if not LP then
		return false, "Brak gracza"
	end
	local ok, err = pcall(function()
		TS:Teleport(game.PlaceId, LP)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Session.serverHop(markLeave)
	if markLeave then
		pcall(markLeave)
	end
	local TS = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local LP = game:GetService("Players").LocalPlayer
	if not LP then
		return false, "Brak gracza"
	end
	if typeof(game.HttpGet) ~= "function" then
		return false, "HttpGet niedostępny"
	end

	local placeId = game.PlaceId
	local cursor = ""
	local hopId = nil

	for _ = 1, 5 do
		local url = string.format(
			"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
			placeId,
			cursor ~= "" and ("&cursor=" .. cursor) or ""
		)
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if not ok or not body then
			return false, "Nie udało się pobrać listy serwerów"
		end

		local decodeOk, data = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not decodeOk or typeof(data) ~= "table" or typeof(data.data) ~= "table" then
			return false, "Błąd odpowiedzi API"
		end

		for _, server in ipairs(data.data) do
			if typeof(server) == "table"
				and server.id
				and server.id ~= game.JobId
				and (server.playing or 0) < (server.maxPlayers or 0)
			then
				hopId = server.id
				break
			end
		end

		if hopId then
			break
		end
		cursor = data.nextPageCursor
		if not cursor or cursor == "" then
			break
		end
	end

	if not hopId then
		return false, "Brak wolnego serwera"
	end

	local hopOk, hopErr = pcall(function()
		TS:TeleportToPlaceInstance(placeId, hopId, LP)
	end)
	if not hopOk then
		return false, tostring(hopErr)
	end
	return true
end

return Session
