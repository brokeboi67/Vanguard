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
	-- Criminality — lobby (4588604953) AND Casual (8343259840) matched via GameId
	["game:1494262959"] = { status = "Supported", note = "Criminality — bypass aktywny" },
	[4588604953]  = { status = "Supported", note = "Criminality — bypass aktywny" },
	[8343259840]  = { status = "Supported", note = "Criminality: Casual — bypass aktywny" },
	-- Rivals (PlaceId 17625359962, Universe 6035872082)
	[17625359962] = { status = "Partially Supported", note = "Rivals — ESP/Aim OK, transfer w toku" },
	["game:6035872082"] = { status = "Partially Supported", note = "Rivals — ESP/Aim OK, transfer w toku" },
	[120851538706364] = { status = "Partially Supported", note = "Murder Duels — tylko legit" },
	[106502313058092] = { status = "Supported", note = "Aura Edit Arena" },
	[109397169461300] = { status = "Partially Supported", note = "SNIPER DUELS" },
	[103911874761600] = { status = "Supported", note = "Murderer VS Sniper DUELS" },
	[12355337193] = { status = "Supported", note = "Murderers VS Sheriffs DUELS" },
	[72258920367796] = { status = "Supported", note = "Recoil" },
	[87018676608089] = { status = "Partially Supported", note = "Pistol Arena" },
	[128326169270358] = { status = "Supported", note = "[FPS] One Shot Arena" },
	[70611375906033] = { status = "Supported", note = "FFA HEADSHOT" },
	[93466613073564] = { status = "Not Supported", note = "[FPS]Scoped [Season]" },
	[89772838187511] = { status = "Partially Supported", note = "CHAMBERED" },
	[72387437800091] = { status = "Partially Supported", note = "DUELS" },
	[131693791362588] = { status = "Supported", note = "[FPS] Sniper Wars" },
	[83055872352243] = { status = "Partially Supported", note = "HEAT" },
	[84556640895285] = { status = "Supported", note = "Deagle Arena" },
	[131964389958213] = { status = "Supported", note = "[UPD] RELOADED GUNS" },
	[124842176624983] = { status = "Not Supported", note = "OVERKILL" },
	[140582629911298] = { status = "Supported", note = "[FPS] Deathshot" },
	[286090429] = { status = "Supported", note = "Arsenal" },
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

function GameSupport.getThumbnail(iconAssetId, gameId)
	if iconAssetId then
		return "rbxthumb://type=Asset&id=" .. tostring(iconAssetId) .. "&w=150&h=150"
	end
	if gameId and gameId > 0 then
		return "rbxthumb://type=GameThumbnail&id=" .. tostring(gameId) .. "&w=150&h=150"
	end
	return ""
end

function GameSupport.getGameInfo(placeId, gameId)
	placeId = placeId or game.PlaceId
	gameId = gameId or game.GameId
	local name = "Unknown Game"
	local thumb = GameSupport.getThumbnail(nil, gameId)

	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(placeId)
	end)
	if ok and typeof(info) == "table" then
		if info.Name and info.Name ~= "" then
			name = info.Name
		end
		if info.IconImageAssetId then
			thumb = GameSupport.getThumbnail(info.IconImageAssetId, gameId)
		end
	elseif game.Name and game.Name ~= "" then
		name = game.Name
	end

	return name, thumb
end

return GameSupport
