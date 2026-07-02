-- Plik: workspace/Vanguard/GameSupport.lua
-- Baza wsparcia gier — dodawaj placeId / gameId w ENTRIES poniżej.

local GameSupport = {}

--[[
	status:
	  "Supported"            — cheat działa
	  "Not Supported"        — znane problemy / nie działa
	  "Partially Supported"  — część funkcji działa
	  (brak wpisu)           — "No Data"

	Przykład:
	  [286090429] = { status = "Supported", note = "Arsenal — pełne wsparcie" },
	  [2788229376] = { status = "Partially Supported", note = "ESP OK, silent niestabilny" },
	  ["game:123456789"] = { status = "Not Supported", note = "Silny anty-cheat" },
]]
GameSupport.ENTRIES = {
	-- [292439477] = { status = "Partially Supported", note = "Phantom Forces" },
}

local STATUS_UI = {
	["Supported"] = {
		label = "SUPPORTED",
		color = Color3.fromRGB(80, 255, 150),
	},
	["Not Supported"] = {
		label = "NOT SUPPORTED",
		color = Color3.fromRGB(255, 85, 85),
	},
	["Partially Supported"] = {
		label = "PARTIALLY SUPPORTED",
		color = Color3.fromRGB(255, 195, 75),
	},
	["No Data"] = {
		label = "NO DATA",
		color = Color3.fromRGB(130, 130, 145),
	},
}

local function normalizeEntry(entry)
	if typeof(entry) == "string" then
		return { status = entry }
	end
	if typeof(entry) == "table" then
		return entry
	end
	return nil
end

function GameSupport.getStatus(placeId, gameId)
	local entry = GameSupport.ENTRIES[placeId]
	if not entry and gameId then
		entry = GameSupport.ENTRIES["game:" .. tostring(gameId)]
	end
	entry = normalizeEntry(entry)
	if not entry or not entry.status then
		return "No Data", nil
	end
	return entry.status, entry.note
end

function GameSupport.getStatusDisplay(status)
	local ui = STATUS_UI[status] or STATUS_UI["No Data"]
	return ui.label, ui.color
end

function GameSupport.getThumbnail(placeId, iconAssetId)
	if iconAssetId then
		return "rbxthumb://type=Asset&id=" .. tostring(iconAssetId) .. "&w=150&h=150"
	end
	return "rbxthumb://type=Place&id=" .. tostring(placeId) .. "&w=150&h=150"
end

function GameSupport.getGameInfo(placeId)
	placeId = placeId or game.PlaceId
	local name = "Unknown Game"
	local thumb = GameSupport.getThumbnail(placeId)

	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(placeId)
	end)
	if ok and typeof(info) == "table" then
		if info.Name and info.Name ~= "" then
			name = info.Name
		end
		if info.IconImageAssetId then
			thumb = GameSupport.getThumbnail(placeId, info.IconImageAssetId)
		end
	elseif game.Name and game.Name ~= "" then
		name = game.Name
	end

	return name, thumb
end

return GameSupport
