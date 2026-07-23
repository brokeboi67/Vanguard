--[[
  CrimFullDump.lua — dig interesting corners of Criminality (not just skins)

  Run in-game (after menu / Storage loaded). Writes:

    VG_FullDump/
      00_summary.txt
      01_services_roots.txt
      02_storage_overview.txt
      03_itemstats.txt          ← Guns / Melees / Throwables / Misc
      04_values.txt             ← ReplicatedStorage.Values
      05_events_remotes.txt
      06_newmodules.txt         ← NewModules tree + require peek
      07_display_wep.txt
      08_skinvariants.txt
      09_pbrtextures.txt
      10_guis.txt
      11_filter_workspace.txt
      12_gc_skins.json / .txt
      13_gc_weapon_stats.txt    ← FireRate / Recoil / Damage tables
      14_gc_interesting.txt     ← odd tables (Dealer, Economy, …)
      15_gc_cases.json / .txt    ← CaseContents pools + Odds sample
      16_sounds_anims_sample.txt
      17_charstats_sample.txt

  Also: VG_CrimSkinIds.json + .txt at workspace root (skin merge).
]]

local HttpService = game:GetService("HttpService")
local RepSt = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local OUT = "VG_FullDump"
local stamp = os.date("%Y-%m-%d %H:%M:%S")
local LP = Players.LocalPlayer

local function ensureFolder(path)
	if typeof(makefolder) == "function" then
		pcall(makefolder, path)
	end
end

local function write(path, text)
	if typeof(writefile) ~= "function" then
		warn("[VG:full] no writefile", path)
		print(text:sub(1, 500))
		return false
	end
	local ok, err = pcall(writefile, path, text)
	if not ok then
		warn("[VG:full] write fail", path, err)
		return false
	end
	return true
end

local function safeFull(inst)
	if not inst then
		return "<nil>"
	end
	local ok, s = pcall(function()
		return inst:GetFullName()
	end)
	return ok and s or tostring(inst)
end

local function childSummary(inst, maxKids)
	maxKids = maxKids or 60
	if not inst then
		return "<nil>"
	end
	local parts, kids = {}, inst:GetChildren()
	for i, ch in ipairs(kids) do
		if i > maxKids then
			parts[#parts + 1] = string.format("... +%d", #kids - maxKids)
			break
		end
		parts[#parts + 1] = string.format("%s:%s(%d)", ch.Name, ch.ClassName, #ch:GetChildren())
	end
	return table.concat(parts, ", ")
end

local function tree(root, maxDepth, maxPer, prefix, depth, out, budget)
	out = out or {}
	budget = budget or { n = 0, max = 3500 }
	depth = depth or 0
	prefix = prefix or ""
	if not root or budget.n >= budget.max then
		return out
	end
	budget.n += 1
	out[#out + 1] = string.format("%s%s [%s] kids=%d", prefix, root.Name, root.ClassName, #root:GetChildren())
	if depth >= (maxDepth or 3) then
		return out
	end
	local kids = root:GetChildren()
	local lim = maxPer or 50
	for i, ch in ipairs(kids) do
		if i > lim then
			out[#out + 1] = prefix .. "  ... +" .. (#kids - lim)
			break
		end
		tree(ch, maxDepth, maxPer, prefix .. "  ", depth + 1, out, budget)
		if depth == 0 and i % 20 == 0 then
			task.wait()
		end
	end
	return out
end

local function dumpValueish(inst, lines, prefix)
	prefix = prefix or ""
	if not inst then
		return
	end
	local cls = inst.ClassName
	if cls == "BoolValue" or cls == "NumberValue" or cls == "IntValue" or cls == "StringValue" then
		lines[#lines + 1] = string.format("%s%s [%s] = %s", prefix, inst.Name, cls, tostring(inst.Value))
	elseif cls == "ObjectValue" then
		lines[#lines + 1] = string.format("%s%s [ObjectValue] = %s", prefix, inst.Name, safeFull(inst.Value))
	elseif cls == "DoubleConstrainedValue" or cls == "IntConstrainedValue" then
		pcall(function()
			lines[#lines + 1] = string.format(
				"%s%s [%s] = %s (min=%s max=%s)",
				prefix,
				inst.Name,
				cls,
				tostring(inst.Value),
				tostring(inst.MinValue),
				tostring(inst.MaxValue)
			)
		end)
	elseif cls == "Folder" or cls == "Configuration" then
		lines[#lines + 1] = string.format("%s%s [%s]", prefix, inst.Name, cls)
		for _, ch in ipairs(inst:GetChildren()) do
			dumpValueish(ch, lines, prefix .. "  ")
		end
	else
		lines[#lines + 1] = string.format("%s%s [%s]", prefix, inst.Name, cls)
	end
end

local function interestingName(n)
	n = string.lower(tostring(n or ""))
	local keys = {
		"skin", "cosmetic", "case", "dealer", "economy", "money", "cash", "credit",
		"recoil", "spread", "damage", "firerate", "ammo", "bullet", "weapon", "gun",
		"melee", "stamina", "sprint", "ragdoll", "inventory", "safe", "crate",
		"airdrop", "rebel", "staff", "admin", "anticheat", "adonis", "ban",
		"teleport", "elevator", "lockpick", "door", "smoke", "flash", "heli",
		"allowance", "atm", "shop", "store", "unbox", "trade", "buff",
	}
	for _, k in ipairs(keys) do
		if string.find(n, k, 1, true) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------
ensureFolder(OUT)
print("[VG:full] start", stamp)

local summary = {
	"VG Full Dump  " .. stamp,
	"PlaceId=" .. tostring(game.PlaceId),
	"GameId=" .. tostring(game.GameId),
	"Executor=" .. tostring(identifyexecutor and identifyexecutor() or "?"),
	"Player=" .. tostring(LP and LP.Name),
	"",
}

-- 01 roots
do
	local lines = { "=== Service roots ===", "" }
	local function add(label, inst)
		lines[#lines + 1] = label .. " = " .. safeFull(inst)
		if inst then
			lines[#lines + 1] = "  kids: " .. childSummary(inst, 40)
		end
		lines[#lines + 1] = ""
	end
	add("ReplicatedStorage", RepSt)
	add("ReplicatedFirst", RepFirst)
	add("Lighting", Lighting)
	add("StarterGui", StarterGui)
	add("Workspace.Filter", workspace:FindFirstChild("Filter"))
	add("Workspace.Characters", workspace:FindFirstChild("Characters"))
	write(OUT .. "/01_services_roots.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 02 Storage overview
do
	local storage = RepSt:FindFirstChild("Storage")
	local lines = {
		"=== ReplicatedStorage.Storage ===",
		"path=" .. safeFull(storage),
		"",
	}
	if storage then
		lines[#lines + 1] = "TOP: " .. childSummary(storage, 80)
		lines[#lines + 1] = ""
		for _, ch in ipairs(storage:GetChildren()) do
			lines[#lines + 1] = string.format(
				"%s [%s] kids=%d | %s",
				ch.Name,
				ch.ClassName,
				#ch:GetChildren(),
				childSummary(ch, 8)
			)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "--- tree depth 2 ---"
		for _, l in ipairs(tree(storage, 2, 40)) do
			lines[#lines + 1] = l
		end
		summary[#summary + 1] = "Storage kids=" .. #storage:GetChildren()
	end
	write(OUT .. "/02_storage_overview.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 03 ItemStats (goldmine for gun list + caps)
do
	local lines = { "=== ItemStats ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local stats = storage and storage:FindFirstChild("ItemStats")
	lines[#lines + 1] = "path=" .. safeFull(stats)
	if stats then
		for _, cat in ipairs(stats:GetChildren()) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format("## %s (%d)", cat.Name, #cat:GetChildren())
			local names = {}
			for _, item in ipairs(cat:GetChildren()) do
				names[#names + 1] = item.Name
				local caps = {}
				for _, v in ipairs(item:GetChildren()) do
					if v:IsA("ValueBase") then
						caps[#caps + 1] = v.Name .. "=" .. tostring(v.Value)
					elseif interestingName(v.Name) then
						caps[#caps + 1] = v.Name .. ":" .. v.ClassName
					end
				end
				if #caps > 0 then
					lines[#lines + 1] = "  " .. item.Name .. " → " .. table.concat(caps, ", ")
				end
			end
			table.sort(names)
			lines[#lines + 1] = "  NAMES: " .. table.concat(names, ", ")
			task.wait()
		end
		summary[#summary + 1] = "ItemStats cats=" .. #stats:GetChildren()
	end
	write(OUT .. "/03_itemstats.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 04 Values
do
	local lines = { "=== ReplicatedStorage.Values ===", "" }
	local values = RepSt:FindFirstChild("Values")
	lines[#lines + 1] = "path=" .. safeFull(values)
	if values then
		for _, ch in ipairs(values:GetChildren()) do
			dumpValueish(ch, lines, "")
		end
		summary[#summary + 1] = "Values kids=" .. #values:GetChildren()
	end
	write(OUT .. "/04_values.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 05 Events / remotes
do
	local lines = { "=== Remotes / Bindables (interesting names) ===", "" }
	local function scan(root, label)
		if not root then
			return
		end
		lines[#lines + 1] = "-- " .. label
		local n = 0
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
				if interestingName(d.Name) or interestingName(d.Parent and d.Parent.Name) then
					n += 1
					lines[#lines + 1] = string.format("  %s [%s]", d:GetFullName(), d.ClassName)
				end
			end
		end
		-- also list ALL under Events / Events2
		if root.Name == "Events" or root.Name == "Events2" then
			lines[#lines + 1] = "  (full listing)"
			for _, ch in ipairs(root:GetChildren()) do
				lines[#lines + 1] = string.format("  * %s [%s]", ch.Name, ch.ClassName)
			end
		end
		lines[#lines + 1] = "  matched=" .. n
		lines[#lines + 1] = ""
	end
	scan(RepSt:FindFirstChild("Events"), "Events")
	scan(RepSt:FindFirstChild("Events2"), "Events2")
	scan(RepSt, "ReplicatedStorage (filtered)")
	write(OUT .. "/05_events_remotes.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 06 NewModules peek
do
	local lines = { "=== NewModules (interesting + require peek) ===", "" }
	local nm = RepSt:FindFirstChild("NewModules")
	lines[#lines + 1] = "path=" .. safeFull(nm)
	if nm then
		for _, l in ipairs(tree(nm, 4, 40, "", 0, {}, { n = 0, max = 2500 })) do
			lines[#lines + 1] = l
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "--- require ModuleScripts with interesting names ---"
		local tried = 0
		for _, d in ipairs(nm:GetDescendants()) do
			if d:IsA("ModuleScript") and interestingName(d.Name) and tried < 40 then
				tried += 1
				lines[#lines + 1] = d:GetFullName()
				local rok, res = pcall(require, d)
				if rok and typeof(res) == "table" then
					local keys = {}
					local i = 0
					for k, v in pairs(res) do
						i += 1
						if i <= 40 then
							keys[#keys + 1] = string.format("%s=%s", tostring(k), typeof(v))
						end
					end
					lines[#lines + 1] = "  keys(" .. i .. "): " .. table.concat(keys, ", ")
				else
					lines[#lines + 1] = "  require: " .. tostring(res)
				end
				task.wait()
			end
		end
		summary[#summary + 1] = "NewModules require peeks=" .. tried
	end
	write(OUT .. "/06_newmodules.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 07 DisplayWepModels
do
	local lines = { "=== DisplayWepModels ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local folder = storage and storage:FindFirstChild("DisplayWepModels")
	lines[#lines + 1] = "path=" .. safeFull(folder)
	if folder then
		local names = {}
		for _, ch in ipairs(folder:GetChildren()) do
			names[#names + 1] = ch.Name .. ":" .. ch.ClassName
		end
		table.sort(names)
		lines[#lines + 1] = "count=" .. #names
		lines[#lines + 1] = table.concat(names, "\n")
		summary[#summary + 1] = "DisplayWep=" .. #names
	end
	write(OUT .. "/07_display_wep.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 08 SkinVariants
do
	local lines = { "=== SkinVariants ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local folder = storage and storage:FindFirstChild("SkinVariants")
	lines[#lines + 1] = "path=" .. safeFull(folder)
	if folder then
		for _, cat in ipairs(folder:GetChildren()) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## " .. cat.Name .. " (" .. #cat:GetChildren() .. ")"
			for _, ch in ipairs(cat:GetChildren()) do
				local meshN, saN = 0, 0
				for _, d in ipairs(ch:GetDescendants()) do
					if d:IsA("MeshPart") then
						meshN += 1
					elseif d:IsA("SurfaceAppearance") then
						saN += 1
					end
				end
				lines[#lines + 1] = string.format("  %s [%s] mesh=%d sa=%d", ch.Name, ch.ClassName, meshN, saN)
			end
		end
	end
	write(OUT .. "/08_skinvariants.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 09 PBRTextures names
do
	local lines = { "=== PBRTextures (names only) ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local folder = storage and storage:FindFirstChild("PBRTextures")
	lines[#lines + 1] = "path=" .. safeFull(folder)
	if folder then
		local names = {}
		for _, ch in ipairs(folder:GetChildren()) do
			names[#names + 1] = ch.Name
		end
		table.sort(names)
		lines[#lines + 1] = "count=" .. #names
		lines[#lines + 1] = table.concat(names, "\n")
		summary[#summary + 1] = "PBRTextures=" .. #names
	end
	write(OUT .. "/09_pbrtextures.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 10 GUIs interesting
do
	local lines = { "=== Storage.GUIs (interesting) ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local guis = storage and storage:FindFirstChild("GUIs")
	lines[#lines + 1] = "path=" .. safeFull(guis)
	if guis then
		for _, ch in ipairs(guis:GetChildren()) do
			if interestingName(ch.Name) then
				lines[#lines + 1] = string.format("%s [%s] kids=%d", ch.Name, ch.ClassName, #ch:GetChildren())
			end
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "ALL GUI names:"
		local names = {}
		for _, ch in ipairs(guis:GetChildren()) do
			names[#names + 1] = ch.Name
		end
		table.sort(names)
		lines[#lines + 1] = table.concat(names, ", ")
		summary[#summary + 1] = "GUIs=" .. #names
	end
	write(OUT .. "/10_guis.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 11 Filter / workspace hotspots
do
	local lines = { "=== Workspace Filter / hotspots ===", "" }
	local filter = workspace:FindFirstChild("Filter")
	lines[#lines + 1] = "Filter=" .. safeFull(filter)
	if filter then
		lines[#lines + 1] = "kids: " .. childSummary(filter, 80)
		for _, name in ipairs({
			"SpawnedTools",
			"SpawnedPiles",
			"SpawnedBread",
			"Vehicles",
			"Dealers",
			"Safes",
			"Ignore",
			"Nodes",
		}) do
			local f = filter:FindFirstChild(name)
			lines[#lines + 1] = string.format("  %s = %s kids=%s", name, tostring(f ~= nil), f and #f:GetChildren() or "-")
		end
	end
	-- map folders often used by Crim
	for _, name in ipairs({ "Characters", "Map", "Bush", "Trees", "Rain", "Ignored" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			lines[#lines + 1] = name .. " kids=" .. #f:GetChildren()
		end
	end
	write(OUT .. "/11_filter_workspace.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 12 + 13 + 14 getgc
do
	local skinMap = {}
	local meshMap = {}
	local skinRows = {}
	local weaponStats = {}
	local interesting = {}
	local scanned = 0

	local STAT_KEYS = {
		"Damage", "damage", "FireRate", "Firerate", "RPM", "Recoil", "recoil",
		"Spread", "spread", "AimSpread", "HipSpread", "Ammo", "MagSize", "Magazine",
		"ReloadTime", "EquipTime", "Range", "Penetration", "HeadshotMultiplier",
		"WalkSpeed", "SprintSpeed", "Stamina",
	}

	-- Crim proxy tables (PhysicModule etc.) throw on missing keys via __index
	local function safeGet(t, k)
		local ok, val = pcall(function()
			if typeof(rawget) == "function" then
				local r = rawget(t, k)
				if r ~= nil then
					return r
				end
			end
			return t[k]
		end)
		if ok then
			return val
		end
		return nil
	end

	local function hasAny(t, keys)
		for _, k in ipairs(keys) do
			local val = safeGet(t, k)
			if val ~= nil and (typeof(val) == "number" or typeof(val) == "boolean") then
				return true
			end
		end
		return false
	end

	if typeof(getgc) == "function" then
		print("[VG:full] getgc…")
		local ok, gc = pcall(getgc, true)
		if ok and typeof(gc) == "table" then
			for _, v in ipairs(gc) do
				scanned += 1
				if scanned % 500 == 0 then
					task.wait()
				end
				if typeof(v) ~= "table" then
					continue
				end

				-- skins (+ MeshVariant official SkinVariants link)
				local ok2, tex, name, disp, rarity, skinClass, meshVar = pcall(function()
					return v.TextureID, v.ItemName, v.DisplayName, v.Rarity, v.SkinClass, v.MeshVariant
				end)
				if ok2 and typeof(tex) == "number" and tex > 1000
					and typeof(name) == "string" and name ~= ""
					and typeof(disp) == "string" and disp ~= ""
				then
					skinMap[name] = skinMap[name] or {}
					if not skinMap[name][disp] then
						skinMap[name][disp] = tex
						skinRows[#skinRows + 1] = {
							item = name,
							display = disp,
							tex = tex,
							rarity = rarity,
							class = skinClass,
							mesh = typeof(meshVar) == "string" and meshVar or nil,
						}
					elseif typeof(meshVar) == "string" and meshVar ~= "" then
						for _, r in ipairs(skinRows) do
							if r.item == name and r.display == disp and not r.mesh then
								r.mesh = meshVar
								break
							end
						end
					end
					if typeof(meshVar) == "string" and meshVar ~= "" then
						meshMap[name] = meshMap[name] or {}
						meshMap[name][disp] = meshVar
					end
				elseif ok2 and typeof(name) == "string" and name ~= ""
					and typeof(disp) == "string" and disp ~= ""
					and typeof(meshVar) == "string" and meshVar ~= ""
				then
					meshMap[name] = meshMap[name] or {}
					meshMap[name][disp] = meshVar
				end

				-- weapon / movement stat tables (rawget/pcall — avoid PhysicModule __index throws)
				if hasAny(v, STAT_KEYS) and #weaponStats < 400 then
					local bits = {}
					local label = safeGet(v, "Name") or safeGet(v, "WeaponName") or safeGet(v, "GunName")
						or safeGet(v, "ItemName") or safeGet(v, "Id") or "?"
					bits[#bits + 1] = "label=" .. tostring(label)
					for _, k in ipairs(STAT_KEYS) do
						local val = safeGet(v, k)
						if val ~= nil then
							bits[#bits + 1] = k .. "=" .. tostring(val)
						end
					end
					if #bits > 2 then
						weaponStats[#weaponStats + 1] = table.concat(bits, " | ")
					end
				end

				-- interesting keyword tables
				if #interesting < 300 then
					local hit = false
					local sample = {}
					local nkeys = 0
					local okPairs = pcall(function()
						for k, val in pairs(v) do
							nkeys += 1
							if nkeys > 60 then
								break
							end
							local ks = tostring(k)
							if interestingName(ks) or (typeof(val) == "string" and interestingName(val)) then
								hit = true
							end
							if nkeys <= 12 then
								sample[#sample + 1] = ks .. ":" .. typeof(val)
							end
						end
					end)
					if okPairs and hit and nkeys >= 3 then
						interesting[#interesting + 1] = "keys(" .. nkeys .. ") " .. table.concat(sample, ", ")
					end
				end
			end
		end
	end

	table.sort(skinRows, function(a, b)
		if a.item == b.item then
			return a.display < b.display
		end
		return a.item < b.item
	end)

	local skinTxt = {
		"-- skin TextureID dump " .. stamp,
		"-- format: ItemName | DisplayName | TextureID | rarity= | class= | mesh=",
		"",
	}
	for _, r in ipairs(skinRows) do
		skinTxt[#skinTxt + 1] = string.format(
			"%s | %s | %d | rarity=%s | class=%s | mesh=%s",
			r.item,
			r.display,
			r.tex,
			tostring(r.rarity or "?"),
			tostring(r.class or "?"),
			tostring(r.mesh or "")
		)
	end
	write(OUT .. "/12_gc_skins.txt", table.concat(skinTxt, "\n") .. "\n")
	local jok, json = pcall(function()
		return HttpService:JSONEncode(skinMap)
	end)
	if jok then
		write(OUT .. "/12_gc_skins.json", json)
		write("VG_CrimSkinIds.json", json)
		write("VG_CrimSkinIds.txt", table.concat(skinTxt, "\n") .. "\n")
	end
	local mok, mjson = pcall(function()
		return HttpService:JSONEncode(meshMap)
	end)
	if mok then
		write(OUT .. "/12_gc_skin_meshes.json", mjson)
		write("VG_CrimSkinMeshes.json", mjson)
	end
	local meshLines = { "-- MeshVariant map " .. stamp, "-- ItemName | DisplayName | MeshVariant", "" }
	local meshN = 0
	local meshRows = {}
	for gun, skins in pairs(meshMap) do
		for disp, mesh in pairs(skins) do
			meshN += 1
			meshRows[#meshRows + 1] = string.format("%s | %s | %s", gun, disp, mesh)
		end
	end
	table.sort(meshRows)
	for _, row in ipairs(meshRows) do
		meshLines[#meshLines + 1] = row
	end
	write(OUT .. "/12_gc_skin_meshes.txt", table.concat(meshLines, "\n") .. "\n")

	write(OUT .. "/13_gc_weapon_stats.txt", table.concat({
		"=== getgc weapon/movement-like tables ===",
		"count=" .. #weaponStats,
		"",
		table.concat(weaponStats, "\n"),
	}, "\n") .. "\n")

	write(OUT .. "/14_gc_interesting.txt", table.concat({
		"=== getgc interesting keyword tables (heuristic) ===",
		"count=" .. #interesting,
		"",
		table.concat(interesting, "\n"),
	}, "\n") .. "\n")

	local gunN = 0
	for _ in pairs(skinMap) do
		gunN += 1
	end
	summary[#summary + 1] = "getgc scanned=" .. scanned
	summary[#summary + 1] = "skins=" .. #skinRows .. " guns=" .. gunN
	summary[#summary + 1] = "meshVariants=" .. meshN
	summary[#summary + 1] = "statTables=" .. #weaponStats
	summary[#summary + 1] = "interestingGC=" .. #interesting
	print("[VG:full] skins", #skinRows, "meshes", meshN, "stats", #weaponStats)

	-- dedicated case dump (CaseContents / Odds)
	local caseMap = {}
	local caseTxt = { "-- CaseContents dump " .. stamp, "-- Name | Display | type | skins/limiteds/exotics", "" }
	local caseN = 0
	if typeof(getgc) == "function" then
		local okc, gcc = pcall(getgc, true)
		if okc and typeof(gcc) == "table" then
			local n = 0
			for _, v in ipairs(gcc) do
				n += 1
				if n % 500 == 0 then
					task.wait()
				end
				if typeof(v) ~= "table" then
					continue
				end
				local ok2, contents, name, display, casetype, layout, enabled = pcall(function()
					return v.CaseContents, v.Name, v.DisplayName, v.Casetype, v.LayoutOrder, v.Enabled
				end)
				if not ok2 or typeof(contents) ~= "table" or typeof(name) ~= "string" or name == "" then
					continue
				end
				local function samplePool(pool, limit)
					local samples = {}
					if typeof(pool) ~= "table" then
						return samples, 0
					end
					local count = 0
					local function take(item)
						if #samples >= (limit or 3) then
							return
						end
						if typeof(item) ~= "table" then
							return
						end
						local ok3, gun, disp, rar, odds, tex = pcall(function()
							return item.ItemName, item.DisplayName, item.Rarity, item.Odds, item.TextureID
						end)
						if ok3 and (gun or disp) then
							samples[#samples + 1] = {
								item = gun,
								display = disp,
								rarity = rar,
								odds = odds,
								tex = tex,
							}
						end
					end
					if #pool > 0 then
						count = #pool
						for _, item in ipairs(pool) do
							take(item)
						end
					else
						for _, val in pairs(pool) do
							if typeof(val) == "table" then
								local has = false
								pcall(function()
									has = val.ItemName ~= nil or val.TextureID ~= nil
								end)
								if has then
									count += 1
									take(val)
								else
									for _, nested in pairs(val) do
										if typeof(nested) == "table" then
											count += 1
											take(nested)
										end
									end
								end
							end
						end
					end
					return samples, count
				end
				local skinsS, skinsC = samplePool(contents.skins, 3)
				local limS, limC = samplePool(contents.limiteds, 3)
				local exoS, exoC = samplePool(contents.exotics, 3)
				caseN += 1
				caseMap[name] = {
					id = name,
					name = name,
					display = display,
					type = casetype,
					layout = layout,
					enabled = enabled,
					counts = { skins = skinsC, limiteds = limC, exotics = exoC },
					sample = { skins = skinsS, limiteds = limS, exotics = exoS },
				}
				caseTxt[#caseTxt + 1] = string.format(
					"%s | %s | type=%s | skins=%d limiteds=%d exotics=%d",
					name,
					tostring(display),
					tostring(casetype),
					skinsC,
					limC,
					exoC
				)
			end
		end
	end
	write(OUT .. "/15_gc_cases.txt", table.concat(caseTxt, "\n") .. "\n")
	local cok, cjson = pcall(function()
		return HttpService:JSONEncode(caseMap)
	end)
	if cok then
		write(OUT .. "/15_gc_cases.json", cjson)
		write("VG_CrimCases.json", cjson)
	end
	summary[#summary + 1] = "cases=" .. caseN
	print("[VG:full] cases", caseN)
end

task.wait()

-- 16 sounds / anims sample
do
	local lines = { "=== Sounds / Animations sample under Storage ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	if storage then
		local snd, anim = {}, {}
		for _, d in ipairs(storage:GetDescendants()) do
			if d:IsA("Sound") and #snd < 80 and interestingName(d.Name) then
				snd[#snd + 1] = d:GetFullName() .. " id=" .. tostring(d.SoundId)
			elseif d:IsA("Animation") and #anim < 80 and interestingName(d.Name) then
				anim[#anim + 1] = d:GetFullName() .. " id=" .. tostring(d.AnimationId)
			end
		end
		lines[#lines + 1] = "## Sounds"
		lines[#lines + 1] = table.concat(snd, "\n")
		lines[#lines + 1] = ""
		lines[#lines + 1] = "## Animations"
		lines[#lines + 1] = table.concat(anim, "\n")
	end
	write(OUT .. "/16_sounds_anims_sample.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 17 CharStats sample
do
	local lines = { "=== CharStats sample ===", "" }
	local cs = RepSt:FindFirstChild("CharStats")
	lines[#lines + 1] = "path=" .. safeFull(cs)
	if cs then
		lines[#lines + 1] = "players tracked=" .. #cs:GetChildren()
		local shown = 0
		for _, plrFolder in ipairs(cs:GetChildren()) do
			if shown >= 3 then
				break
			end
			shown += 1
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## " .. plrFolder.Name
			for _, ch in ipairs(plrFolder:GetChildren()) do
				dumpValueish(ch, lines, "  ")
			end
		end
	end
	write(OUT .. "/17_charstats_sample.txt", table.concat(lines, "\n") .. "\n")
end

summary[#summary + 1] = ""
summary[#summary + 1] = "Done → " .. OUT .. "/"
summary[#summary + 1] = "Open 00_summary + 03_itemstats + 05_events + 06_newmodules + 13/14/15_gc_*"
write(OUT .. "/00_summary.txt", table.concat(summary, "\n") .. "\n")
print("[VG:full] DONE")
print(table.concat(summary, "\n"))
