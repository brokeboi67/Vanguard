-- Plik: workspace/Vanguard/Menus.lua

local Menus = {}

local SCRIPTS = {
	InfiniteYield = {
		label = "Infinite Yield",
		url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
	},
	Dex = {
		label = "Dex Explorer",
		url = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua",
	},
	SimpleSpy = {
		label = "SimpleSpy",
		url = "https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpySource.lua",
	},
	RemoteSpy = {
		label = "Remote Spy",
		url = "https://raw.githubusercontent.com/infyiff/backup/main/remotespy.lua",
	},
	CSpy = {
		label = "CSpy",
		url = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau",
	},
	Hydroxide = {
		label = "Hydroxide",
		loader = function()
			local owner = "Upbolt"
			local branch = "revision"
			local function httpGet(url)
				if typeof(game.HttpGetAsync) == "function" then
					return game:HttpGetAsync(url)
				elseif typeof(game.HttpGet) == "function" then
					return game:HttpGet(url)
				end
				error("HttpGet niedostępny")
			end
			local function webImport(file)
				local src = httpGet(
					("https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua"):format(owner, branch, file)
				)
				return loadstring(src, file .. ".lua")()
			end
			webImport("init")
			webImport("ui/main")
		end,
	},
	UnnamedESP = {
		label = "Unnamed ESP",
		url = "https://raw.githubusercontent.com/infyiff/backup/main/unnamedesp.lua",
	},
}

local SCAN_ROOTS = {
	workspace,
	game:GetService("ReplicatedStorage"),
	game:GetService("ReplicatedFirst"),
	game:GetService("StarterGui"),
	game:GetService("StarterPack"),
	game:GetService("StarterPlayer"),
	game:GetService("Lighting"),
	game:GetService("SoundService"),
	game:GetService("MaterialService"),
}

local STRING_PROPS = {
	"Texture",
	"TextureID",
	"MeshId",
	"SoundId",
	"AnimationId",
	"Image",
	"Video",
	"ColorMap",
	"MetalnessMap",
	"NormalMap",
	"RoughnessMap",
	"SkyboxBk",
	"SkyboxDn",
	"SkyboxFt",
	"SkyboxLf",
	"SkyboxRt",
	"SkyboxUp",
}

local DESC_PROPS = {
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",
	"Shirt",
	"Pants",
	"GraphicTShirt",
	"Face",
}

local function normalizeContentId(str)
	if typeof(str) ~= "string" or str == "" then
		return nil
	end
	if str:find("^rbxasset://fonts/") or str:find("^rbxasset://textures/") or str:find("^rbxasset://sounds/") then
		return nil
	end
	local num = str:match("rbxassetid://(%d+)")
		or str:match("rbxasset://(%d+)")
		or str:match("www%.roblox%.com/asset/%?id=(%d+)")
		or str:match("^(%d+)$")
	if num then
		return "rbxassetid://" .. num
	end
	if str:find("^rbxassetid://") then
		return str
	end
	return nil
end

local function addContentId(seen, list, str)
	local id = normalizeContentId(str)
	if id and not seen[id] then
		seen[id] = true
		table.insert(list, id)
	end
end

local function addNumericAsset(seen, list, assetId)
	if typeof(assetId) == "number" and assetId > 0 then
		addContentId(seen, list, "rbxassetid://" .. assetId)
	end
end

local function scanStringProperties(seen, list, inst)
	for _, prop in ipairs(STRING_PROPS) do
		local ok, val = pcall(function()
			return inst[prop]
		end)
		if ok and typeof(val) == "string" then
			addContentId(seen, list, val)
		end
	end
end

local function scanInstance(seen, list, inst)
	if not inst then
		return
	end

	scanStringProperties(seen, list, inst)

	if inst:IsA("Decal") or inst:IsA("Texture") then
		addContentId(seen, list, inst.Texture)
	elseif inst:IsA("Sound") then
		addContentId(seen, list, inst.SoundId)
	elseif inst:IsA("Animation") then
		addContentId(seen, list, inst.AnimationId)
	elseif inst:IsA("MeshPart") then
		addContentId(seen, list, inst.MeshId)
		addContentId(seen, list, inst.TextureID)
	elseif inst:IsA("SpecialMesh") or inst:IsA("FileMesh") or inst:IsA("BlockMesh") then
		addContentId(seen, list, inst.MeshId)
		if inst:IsA("SpecialMesh") then
			addContentId(seen, list, inst.TextureId)
		end
	elseif inst:IsA("Shirt") then
		addContentId(seen, list, inst.ShirtTemplate)
	elseif inst:IsA("Pants") then
		addContentId(seen, list, inst.PantsTemplate)
	elseif inst:IsA("ShirtGraphic") then
		addContentId(seen, list, inst.Graphic)
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		addContentId(seen, list, inst.Image)
	elseif inst:IsA("VideoFrame") then
		addContentId(seen, list, inst.Video)
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
		addContentId(seen, list, inst.Texture)
	elseif inst:IsA("Sky") then
		addContentId(seen, list, inst.SkyboxBk)
		addContentId(seen, list, inst.SkyboxDn)
		addContentId(seen, list, inst.SkyboxFt)
		addContentId(seen, list, inst.SkyboxLf)
		addContentId(seen, list, inst.SkyboxRt)
		addContentId(seen, list, inst.SkyboxUp)
	elseif inst:IsA("StringValue") then
		addContentId(seen, list, inst.Value)
	end
end

local function scanTree(seen, list, root)
	if not root then
		return
	end
	for _, inst in ipairs(root:GetDescendants()) do
		scanInstance(seen, list, inst)
	end
	scanInstance(seen, list, root)
end

local function scanHumanoidDescription(seen, list, desc)
	if not desc then
		return
	end
	for _, prop in ipairs(DESC_PROPS) do
		local ok, val = pcall(function()
			return desc[prop]
		end)
		if ok then
			addNumericAsset(seen, list, val)
		end
	end
	local okAcc, accessories = pcall(function()
		return desc:GetAccessories(false)
	end)
	if okAcc and typeof(accessories) == "table" then
		for _, accessory in ipairs(accessories) do
			if typeof(accessory) == "number" then
				addNumericAsset(seen, list, accessory)
			elseif typeof(accessory) == "table" and accessory.AssetId then
				addNumericAsset(seen, list, accessory.AssetId)
			end
		end
	end
end

local function scanCharacter(seen, list, character)
	if not character then
		return
	end
	scanTree(seen, list, character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok then
			scanHumanoidDescription(seen, list, desc)
		end
		for _, acc in ipairs(hum:GetAccessories()) do
			scanTree(seen, list, acc)
		end
	end
end

function Menus.getScriptList()
	local order = {
		"InfiniteYield",
		"Dex",
		"SimpleSpy",
		"RemoteSpy",
		"CSpy",
		"Hydroxide",
		"UnnamedESP",
	}
	local list = {}
	for _, key in ipairs(order) do
		local data = SCRIPTS[key]
		if data then
			table.insert(list, {
				key = key,
				label = data.label,
				url = data.url,
			})
		end
	end
	return list
end

function Menus.loadScript(key)
	local entry = SCRIPTS[key]
	if not entry then
		return false, "Nieznany skrypt"
	end

	if entry.loader then
		local ok, err = pcall(entry.loader)
		if not ok then
			return false, tostring(err)
		end
		return true, entry.label
	end

	if not entry.url then
		return false, "Brak URL skryptu"
	end

	local function httpGet(url)
		if typeof(game.HttpGetAsync) == "function" then
			return game:HttpGetAsync(url)
		elseif typeof(game.HttpGet) == "function" then
			return game:HttpGet(url)
		end
		error("HttpGet niedostępny")
	end

	local ok, err = pcall(function()
		loadstring(httpGet(entry.url))()
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, entry.label
end

function Menus.collectAssets()
	local seen = {}
	local list = {}

	for _, root in ipairs(SCAN_ROOTS) do
		if root then
			pcall(function()
				scanTree(seen, list, root)
			end)
		end
	end

	local StarterPlayer = game:GetService("StarterPlayer")
	if StarterPlayer.StarterCharacter then
		scanCharacter(seen, list, StarterPlayer.StarterCharacter)
	end

	local Players = game:GetService("Players")
	for _, plr in ipairs(Players:GetPlayers()) do
		scanCharacter(seen, list, plr.Character)
		if plr:FindFirstChildOfClass("Backpack") then
			scanTree(seen, list, plr.Backpack)
		end
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(plr.UserId)
		end)
		if ok then
			scanHumanoidDescription(seen, list, desc)
		end
	end

	return list
end

local function assetFetchStatus(contentId)
	local ContentProvider = game:GetService("ContentProvider")
	local ok, status = pcall(function()
		return ContentProvider:GetAssetFetchStatus(contentId)
	end)
	if not ok then
		return nil
	end
	return status
end

local function isAssetLoaded(contentId)
	local status = assetFetchStatus(contentId)
	if status == nil then
		return false
	end
	return status == Enum.AssetFetchStatus.Success
end

local function filterPending(contentIds)
	local pending = {}
	local skipped = 0
	for _, contentId in ipairs(contentIds) do
		if isAssetLoaded(contentId) then
			skipped += 1
		else
			table.insert(pending, contentId)
		end
	end
	return pending, skipped
end

local function tryPreload(contentId)
	local ContentProvider = game:GetService("ContentProvider")
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ contentId })
	end)
	if not ok then
		return false
	end
	task.wait(0.02)
	return isAssetLoaded(contentId)
end

function Menus.preloadAssets(onUpdate, shouldCancel)
	local ContentProvider = game:GetService("ContentProvider")

	if onUpdate then
		onUpdate({
			phase = "scan",
			label = "Skanowanie gry...",
			total = 0,
			processed = 0,
			loaded = 0,
			failed = 0,
		})
	end

	local allAssets = Menus.collectAssets()
	local pending, skipped = filterPending(allAssets)
	local total = #pending
	local loaded = 0
	local failed = 0
	local processed = 0
	local batchSize = 8

	if onUpdate then
		onUpdate({
			phase = "start",
			total = total,
			scanned = #allAssets,
			skipped = skipped,
			processed = 0,
			loaded = 0,
			failed = 0,
			label = string.format("%d do załadowania · %d już OK", total, skipped),
		})
	end

	if total == 0 then
		if onUpdate then
			onUpdate({
				phase = "done",
				total = 0,
				scanned = #allAssets,
				skipped = skipped,
				processed = 0,
				loaded = 0,
				failed = 0,
				label = skipped > 0 and ("Wszystko załadowane · " .. skipped .. " assetów") or "Brak assetów",
			})
		end
		return { total = 0, scanned = #allAssets, skipped = skipped, loaded = 0, failed = 0 }
	end

	for i = 1, total, batchSize do
		if shouldCancel and shouldCancel() then
			break
		end

		local batch = {}
		for j = i, math.min(i + batchSize - 1, total) do
			table.insert(batch, pending[j])
		end

		pcall(function()
			ContentProvider:PreloadAsync(batch, function(contentId)
				if onUpdate then
					onUpdate({
						phase = "item",
						contentId = contentId,
						total = total,
						processed = processed,
						loaded = loaded,
						failed = failed,
						label = tostring(contentId):gsub("rbxassetid://", "#"),
					})
				end
			end)
		end)

		task.wait(0.08)

		for _, contentId in ipairs(batch) do
			if shouldCancel and shouldCancel() then
				break
			end

			if isAssetLoaded(contentId) then
				loaded += 1
			elseif tryPreload(contentId) then
				loaded += 1
			else
				failed += 1
			end
			processed += 1

			if onUpdate then
				onUpdate({
					phase = "progress",
					total = total,
					processed = processed,
					loaded = loaded,
					failed = failed,
					label = string.format("%d / %d · OK %d · błędy %d", processed, total, loaded, failed),
				})
			end
		end
	end

	local cancelled = shouldCancel and shouldCancel()
	if onUpdate then
		onUpdate({
			phase = "done",
			total = total,
			scanned = #allAssets,
			skipped = skipped,
			processed = processed,
			loaded = loaded,
			failed = failed,
			label = cancelled
				and string.format("Anulowano · %d / %d", processed, total)
				or (failed > 0
					and string.format("Gotowe · %d OK · %d błędów", loaded, failed)
					or string.format("Gotowe · %d assetów", loaded)),
		})
	end

	return {
		total = total,
		scanned = #allAssets,
		skipped = skipped,
		processed = processed,
		loaded = loaded,
		failed = failed,
		cancelled = cancelled,
	}
end

return Menus
