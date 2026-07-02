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
		url = "https://raw.githubusercontent.com/NotDSF/CSpy/main/CSpy.lua",
	},
	Hydroxide = {
		label = "Hydroxide",
		url = "https://raw.githubusercontent.com/Upbolt/Hydroxide/revision/oh-main/Init.lua",
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
	game:GetService("Lighting"),
	game:GetService("SoundService"),
}

local function assetIdFromString(str)
	if typeof(str) ~= "string" or str == "" then
		return nil
	end
	local id = str:match("rbxassetid://(%d+)") or str:match("^(%d+)$")
	if id then
		return tonumber(id)
	end
	return nil
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
	if typeof(game.HttpGet) ~= "function" then
		return false, "HttpGet niedostępny"
	end
	local ok, err = pcall(function()
		loadstring(game:HttpGet(entry.url))()
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, entry.label
end

function Menus.collectAssets()
	local seen = {}
	local list = {}

	local function add(inst)
		if not inst or seen[inst] then
			return
		end
		seen[inst] = true
		table.insert(list, inst)
	end

	local function scanString(str)
		local id = assetIdFromString(str)
		if id and not seen[id] then
			seen[id] = true
			table.insert(list, "rbxassetid://" .. id)
		end
	end

	for _, root in ipairs(SCAN_ROOTS) do
		if root then
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("Decal") or inst:IsA("Texture") then
					add(inst)
				elseif inst:IsA("Sound") and inst.SoundId ~= "" then
					add(inst)
				elseif inst:IsA("MeshPart") then
					add(inst)
				elseif inst:IsA("SpecialMesh") then
					add(inst)
				elseif inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then
					add(inst)
				elseif inst:IsA("SurfaceAppearance") then
					add(inst)
				elseif inst:IsA("Animation") and inst.AnimationId ~= "" then
					add(inst)
				elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
					if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
						scanString(inst.Image)
					end
					if inst:IsA("ViewportFrame") then
						add(inst)
					end
				elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
					add(inst)
				elseif inst:IsA("VideoFrame") and inst.Video ~= "" then
					add(inst)
				end
			end
		end
	end

	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		if plr.Character then
			for _, inst in ipairs(plr.Character:GetDescendants()) do
				if inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("MeshPart") or inst:IsA("SpecialMesh") then
					add(inst)
				elseif inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then
					add(inst)
				end
			end
		end
	end

	return list
end

function Menus.preloadAssets(onUpdate, shouldCancel)
	local ContentProvider = game:GetService("ContentProvider")
	local assets = Menus.collectAssets()
	local total = #assets
	if total == 0 then
		if onUpdate then
			onUpdate({ phase = "done", total = 0, loaded = 0, failed = 0, label = "Brak assetów" })
		end
		return { total = 0, loaded = 0, failed = 0 }
	end

	local loaded = 0
	local failed = 0
	local batchSize = 24

	if onUpdate then
		onUpdate({
			phase = "start",
			total = total,
			loaded = 0,
			failed = 0,
			label = "Skanowanie...",
		})
	end

	for i = 1, total, batchSize do
		if shouldCancel and shouldCancel() then
			break
		end
		local batch = {}
		for j = i, math.min(i + batchSize - 1, total) do
			table.insert(batch, assets[j])
		end
		local batchOk, batchErr = pcall(function()
			ContentProvider:PreloadAsync(batch, function(contentId)
				if onUpdate then
					onUpdate({
						phase = "item",
						contentId = contentId,
						total = total,
						loaded = loaded,
						failed = failed,
						label = tostring(contentId),
					})
				end
			end)
		end)
		if batchOk then
			loaded += #batch
		else
			failed += #batch
			if onUpdate then
				onUpdate({
					phase = "error",
					total = total,
					loaded = loaded,
					failed = failed,
					label = tostring(batchErr),
				})
			end
		end
		if onUpdate then
			onUpdate({
				phase = "progress",
				total = total,
				loaded = math.min(loaded, total),
				failed = failed,
				label = string.format("%d / %d", math.min(loaded, total), total),
			})
		end
		task.wait(0.03)
	end

	if onUpdate then
		onUpdate({
			phase = "done",
			total = total,
			loaded = loaded,
			failed = failed,
			label = string.format("Gotowe · %d assetów", total),
		})
	end

	return { total = total, loaded = loaded, failed = failed }
end

return Menus
