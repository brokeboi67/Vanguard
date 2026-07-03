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

local function addContentId(ctx, str)
	local id = normalizeContentId(str)
	if id and not ctx.seenIds[id] then
		ctx.seenIds[id] = true
		table.insert(ctx.ids, id)
	end
end

local function addNumericAsset(ctx, assetId)
	if typeof(assetId) == "number" and assetId > 0 then
		addContentId(ctx, "rbxassetid://" .. assetId)
	end
end

local function trackPreloadInstance(ctx, inst)
	if not inst or ctx.seenInst[inst] then
		return
	end
	if inst:IsA("LuaSourceContainer") then
		return
	end
	local preloadable = inst:IsA("Decal")
		or inst:IsA("Texture")
		or inst:IsA("Sound")
		or inst:IsA("Animation")
		or inst:IsA("MeshPart")
		or inst:IsA("SpecialMesh")
		or inst:IsA("FileMesh")
		or inst:IsA("Shirt")
		or inst:IsA("Pants")
		or inst:IsA("ShirtGraphic")
		or inst:IsA("ImageLabel")
		or inst:IsA("ImageButton")
		or inst:IsA("VideoFrame")
		or inst:IsA("ParticleEmitter")
		or inst:IsA("Beam")
		or inst:IsA("Trail")
		or inst:IsA("SurfaceAppearance")
		or inst:IsA("Sky")
	if preloadable then
		ctx.seenInst[inst] = true
		table.insert(ctx.instances, inst)
	end
end

local function scanStringProperties(ctx, inst)
	for _, prop in ipairs(STRING_PROPS) do
		local ok, val = pcall(function()
			return inst[prop]
		end)
		if ok and typeof(val) == "string" then
			addContentId(ctx, val)
		end
	end
end

local function scanInstance(ctx, inst)
	if not inst then
		return
	end

	trackPreloadInstance(ctx, inst)
	scanStringProperties(ctx, inst)

	if inst:IsA("Decal") or inst:IsA("Texture") then
		addContentId(ctx, inst.Texture)
	elseif inst:IsA("Sound") then
		addContentId(ctx, inst.SoundId)
	elseif inst:IsA("Animation") then
		addContentId(ctx, inst.AnimationId)
	elseif inst:IsA("MeshPart") then
		addContentId(ctx, inst.MeshId)
		addContentId(ctx, inst.TextureID)
	elseif inst:IsA("SpecialMesh") or inst:IsA("FileMesh") or inst:IsA("BlockMesh") then
		addContentId(ctx, inst.MeshId)
		if inst:IsA("SpecialMesh") then
			addContentId(ctx, inst.TextureId)
		end
	elseif inst:IsA("Shirt") then
		addContentId(ctx, inst.ShirtTemplate)
	elseif inst:IsA("Pants") then
		addContentId(ctx, inst.PantsTemplate)
	elseif inst:IsA("ShirtGraphic") then
		addContentId(ctx, inst.Graphic)
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		addContentId(ctx, inst.Image)
	elseif inst:IsA("VideoFrame") then
		addContentId(ctx, inst.Video)
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
		addContentId(ctx, inst.Texture)
	elseif inst:IsA("Sky") then
		addContentId(ctx, inst.SkyboxBk)
		addContentId(ctx, inst.SkyboxDn)
		addContentId(ctx, inst.SkyboxFt)
		addContentId(ctx, inst.SkyboxLf)
		addContentId(ctx, inst.SkyboxRt)
		addContentId(ctx, inst.SkyboxUp)
	elseif inst:IsA("StringValue") then
		addContentId(ctx, inst.Value)
	end
end

local function scanTree(ctx, root)
	if not root then
		return
	end
	local ok, descendants = pcall(function()
		return root:GetDescendants()
	end)
	if ok and typeof(descendants) == "table" then
		for _, inst in ipairs(descendants) do
			scanInstance(ctx, inst)
		end
	end
	scanInstance(ctx, root)
end

local function scanHumanoidDescription(ctx, desc)
	if not desc then
		return
	end
	for _, prop in ipairs(DESC_PROPS) do
		local ok, val = pcall(function()
			return desc[prop]
		end)
		if ok then
			addNumericAsset(ctx, val)
		end
	end
	local okAcc, accessories = pcall(function()
		return desc:GetAccessories(false)
	end)
	if okAcc and typeof(accessories) == "table" then
		for _, accessory in ipairs(accessories) do
			if typeof(accessory) == "number" then
				addNumericAsset(ctx, accessory)
			elseif typeof(accessory) == "table" and accessory.AssetId then
				addNumericAsset(ctx, accessory.AssetId)
			end
		end
	end
end

local function scanCharacter(ctx, character)
	if not character then
		return
	end
	scanTree(ctx, character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok then
			scanHumanoidDescription(ctx, desc)
		end
		local okAcc, accessories = pcall(function()
			return hum:GetAccessories()
		end)
		if okAcc and typeof(accessories) == "table" then
			for _, acc in ipairs(accessories) do
				scanTree(ctx, acc)
			end
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
	local ctx = {
		seenIds = {},
		ids = {},
		seenInst = {},
		instances = {},
	}

	for _, root in ipairs(SCAN_ROOTS) do
		if root then
			pcall(function()
				scanTree(ctx, root)
			end)
		end
	end

	pcall(function()
		local StarterPlayer = game:GetService("StarterPlayer")
		local starterChar = StarterPlayer:FindFirstChild("StarterCharacter")
		if starterChar and starterChar:IsA("Model") then
			scanCharacter(ctx, starterChar)
		end
		local okDesc, starterDesc = pcall(function()
			return StarterPlayer.StarterHumanoidDescription
		end)
		if okDesc and starterDesc then
			scanHumanoidDescription(ctx, starterDesc)
		end
	end)

	local Players = game:GetService("Players")
	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(function()
			scanCharacter(ctx, plr.Character)
			local backpack = plr:FindFirstChildOfClass("Backpack")
			if backpack then
				scanTree(ctx, backpack)
			end
			local ok, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(plr.UserId)
			end)
			if ok then
				scanHumanoidDescription(ctx, desc)
			end
		end)
	end

	return ctx.ids, ctx.instances
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

local function isContentIdLoaded(contentId)
	local status = assetFetchStatus(contentId)
	return status == Enum.AssetFetchStatus.Success
end

local function filterPendingIds(contentIds)
	local pending = {}
	local skipped = 0
	for _, contentId in ipairs(contentIds) do
		if isContentIdLoaded(contentId) then
			skipped += 1
		else
			table.insert(pending, contentId)
		end
	end
	return pending, skipped
end

local function preloadEntry(entry)
	local ContentProvider = game:GetService("ContentProvider")
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ entry })
	end)
	if not ok then
		return false
	end
	task.wait(0.035)
	if typeof(entry) == "string" then
		local status = assetFetchStatus(entry)
		if status == nil or status == Enum.AssetFetchStatus.None then
			return true
		end
		return status == Enum.AssetFetchStatus.Success
	end
	return true
end

local function buildWorkQueue(ids, instances)
	local pendingIds, skipped = filterPendingIds(ids)
	local queue = {}
	for _, inst in ipairs(instances) do
		if inst and inst.Parent then
			table.insert(queue, inst)
		end
	end
	for _, contentId in ipairs(pendingIds) do
		table.insert(queue, contentId)
	end
	return queue, skipped, #pendingIds + #instances
end

function Menus.preloadAssets(onUpdate, shouldCancel)
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

	local ids, instances = {}, {}
	local scanOk, scanErr = pcall(function()
		ids, instances = Menus.collectAssets()
	end)
	if not scanOk then
		if onUpdate then
			onUpdate({
				phase = "done",
				total = 0,
				processed = 0,
				loaded = 0,
				failed = 0,
				label = "Błąd skanowania: " .. tostring(scanErr),
			})
		end
		return { total = 0, loaded = 0, failed = 0, error = tostring(scanErr) }
	end

	if onUpdate then
		onUpdate({
			phase = "scan",
			label = "Preload mapy i RS...",
			total = 0,
			processed = 0,
			loaded = 0,
			failed = 0,
		})
	end

	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync({
			workspace,
			game:GetService("ReplicatedStorage"),
		})
	end)

	local queue, skipped, scanned = buildWorkQueue(ids, instances)
	local total = #queue
	local loaded = 0
	local failed = 0
	local processed = 0

	if onUpdate then
		onUpdate({
			phase = "start",
			total = total,
			scanned = scanned,
			skipped = skipped,
			processed = 0,
			loaded = 0,
			failed = 0,
			label = string.format("%d elementów · %d już OK", total, skipped),
		})
	end

	if total == 0 then
		if onUpdate then
			onUpdate({
				phase = "done",
				total = 0,
				scanned = scanned,
				skipped = skipped,
				processed = 0,
				loaded = 0,
				failed = 0,
				label = skipped > 0 and ("Mapa OK · " .. skipped .. " assetów") or "Brak assetów do preloadu",
			})
		end
		return { total = 0, scanned = scanned, skipped = skipped, loaded = 0, failed = 0 }
	end

	for index, entry in ipairs(queue) do
		if shouldCancel and shouldCancel() then
			break
		end

		local label
		if typeof(entry) == "string" then
			label = entry:gsub("rbxassetid://", "#")
		else
			label = entry.ClassName
		end

		if preloadEntry(entry) then
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
				label = string.format("%d / %d · %s", processed, total, label),
			})
		end

		if index % 6 == 0 then
			task.wait(0.02)
		end
	end

	local cancelled = shouldCancel and shouldCancel()
	if onUpdate then
		onUpdate({
			phase = "done",
			total = total,
			scanned = scanned,
			skipped = skipped,
			processed = processed,
			loaded = loaded,
			failed = failed,
			label = cancelled
				and string.format("Anulowano · %d / %d", processed, total)
				or (failed > 0
					and string.format("Gotowe · %d OK · %d błędów", loaded, failed)
					or string.format("Gotowe · %d załadowanych", loaded)),
		})
	end

	return {
		total = total,
		scanned = scanned,
		skipped = skipped,
		processed = processed,
		loaded = loaded,
		failed = failed,
		cancelled = cancelled,
	}
end

return Menus
