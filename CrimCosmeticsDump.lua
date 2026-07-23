--[[
  CrimCosmeticsDump.lua — full cosmetics / skin corner digger for Criminality

  1) Inject in-game (Potassium / Syn etc.)
  2) Wait until you are past menu (Storage loaded)
  3) Execute this script
  4) Files land in executor workspace:

       VG_CosmeticsDump/
         00_summary.txt
         01_storage_tree.txt
         02_cosmetics_stuff.txt
         03_reppbr_names.txt
         04_casepbrs_names.txt
         05_events.txt
         06_gc_skins.json
         07_gc_skins.txt
         08_gc_other_cosmetics.txt
         09_modules.txt
         10_viewmodels.txt

  Safe-ish: batched getgc, task.wait, no hooks that kick.
]]

local HttpService = game:GetService("HttpService")
local RepSt = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")

local OUT = "VG_CosmeticsDump"
local stamp = os.date("%Y-%m-%d %H:%M:%S")

local function ensureFolder(path)
	if typeof(makefolder) == "function" then
		pcall(makefolder, path)
	end
end

local function write(path, text)
	if typeof(writefile) ~= "function" then
		warn("[VG:dump] writefile missing — print only")
		print(text)
		return false
	end
	local ok, err = pcall(writefile, path, text)
	if not ok then
		warn("[VG:dump] write fail", path, err)
		return false
	end
	return true
end

local function append(path, text)
	if typeof(appendfile) == "function" then
		pcall(appendfile, path, text)
		return
	end
	local prev = ""
	if typeof(isfile) == "function" and isfile(path) and typeof(readfile) == "function" then
		local ok, s = pcall(readfile, path)
		if ok and typeof(s) == "string" then
			prev = s
		end
	end
	write(path, prev .. text)
end

local function safeName(inst)
	if not inst then
		return "<nil>"
	end
	local ok, full = pcall(function()
		return inst:GetFullName()
	end)
	return ok and full or tostring(inst)
end

local function childSummary(inst, maxKids)
	maxKids = maxKids or 40
	if not inst then
		return "<nil>"
	end
	local parts = {}
	local kids = inst:GetChildren()
	for i, ch in ipairs(kids) do
		if i > maxKids then
			parts[#parts + 1] = string.format("... +%d more", #kids - maxKids)
			break
		end
		parts[#parts + 1] = string.format("%s:%s(%d)", ch.Name, ch.ClassName, #ch:GetChildren())
	end
	return table.concat(parts, ", ")
end

local function treeLines(root, maxDepth, maxPerLevel, prefix, depth, out, budget)
	out = out or {}
	budget = budget or { n = 0, max = 4000 }
	depth = depth or 0
	prefix = prefix or ""
	if not root or budget.n >= budget.max then
		return out
	end
	budget.n += 1
	out[#out + 1] = string.format("%s%s [%s] kids=%d", prefix, root.Name, root.ClassName, #root:GetChildren())
	if depth >= (maxDepth or 4) then
		return out
	end
	local kids = root:GetChildren()
	local lim = maxPerLevel or 80
	for i, ch in ipairs(kids) do
		if i > lim then
			out[#out + 1] = prefix .. "  ... +" .. (#kids - lim) .. " more"
			break
		end
		treeLines(ch, maxDepth, maxPerLevel, prefix .. "  ", depth + 1, out, budget)
		if depth <= 1 and i % 25 == 0 then
			task.wait()
		end
	end
	return out
end

local function listSurfaceAppearances(folder, label)
	local lines = { "=== " .. label .. " ===", "path=" .. safeName(folder) }
	if not folder then
		lines[#lines + 1] = "NOT FOUND"
		return table.concat(lines, "\n")
	end
	local byGun = {}
	local total = 0
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("SurfaceAppearance") then
			total += 1
			local us = string.find(ch.Name, "_", 1, true)
			local gun = us and string.sub(ch.Name, 1, us - 1) or "?"
			local skin = us and string.sub(ch.Name, us + 1) or ch.Name
			byGun[gun] = byGun[gun] or {}
			byGun[gun][#byGun[gun] + 1] = skin
		end
	end
	lines[#lines + 1] = "SurfaceAppearance count=" .. total
	local guns = {}
	for g in pairs(byGun) do
		guns[#guns + 1] = g
	end
	table.sort(guns)
	for _, g in ipairs(guns) do
		local skins = byGun[g]
		table.sort(skins)
		lines[#lines + 1] = string.format("%s (%d): %s", g, #skins, table.concat(skins, ", "))
		if #lines % 40 == 0 then
			task.wait()
		end
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------
-- START
--------------------------------------------------------------------------

ensureFolder(OUT)
print("[VG:dump] start", stamp)

local summary = {
	"VG Cosmetics Dump  " .. stamp,
	"PlaceId=" .. tostring(game.PlaceId),
	"GameId=" .. tostring(game.GameId),
	"Executor=" .. tostring(identifyexecutor and identifyexecutor() or "?"),
	"",
}

-- 01 Storage tree
do
	local storage = RepSt:FindFirstChild("Storage")
	local lines = {
		"=== ReplicatedStorage.Storage ===",
		"exists=" .. tostring(storage ~= nil),
		"path=" .. safeName(storage),
		"",
	}
	if storage then
		lines[#lines + 1] = "children: " .. childSummary(storage, 120)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "--- tree (depth 3) ---"
		for _, l in ipairs(treeLines(storage, 3, 60)) do
			lines[#lines + 1] = l
		end
	end
	write(OUT .. "/01_storage_tree.txt", table.concat(lines, "\n") .. "\n")
	summary[#summary + 1] = "Storage children: " .. (storage and #storage:GetChildren() or 0)
end

task.wait()

-- 02 CosmeticsStuff deep
do
	local storage = RepSt:FindFirstChild("Storage")
	local cos = storage and storage:FindFirstChild("CosmeticsStuff")
	local lines = {
		"=== CosmeticsStuff ===",
		"path=" .. safeName(cos),
		"",
	}
	if cos then
		lines[#lines + 1] = "TOP children: " .. childSummary(cos, 200)
		lines[#lines + 1] = ""
		for _, ch in ipairs(cos:GetChildren()) do
			lines[#lines + 1] = string.format(
				"-- %s [%s] kids=%d sample=%s",
				ch.Name,
				ch.ClassName,
				#ch:GetChildren(),
				childSummary(ch, 15)
			)
			-- Sample first SurfaceAppearance / ModuleScript props
			local n = 0
			for _, d in ipairs(ch:GetDescendants()) do
				if d:IsA("SurfaceAppearance") then
					n += 1
					if n <= 8 then
						local cmap = ""
						pcall(function()
							cmap = tostring(d.ColorMap)
						end)
						lines[#lines + 1] = string.format("   SA %s ColorMap=%s", d.Name, cmap)
					end
				elseif d:IsA("ModuleScript") and n < 12 then
					lines[#lines + 1] = "   ModuleScript " .. d:GetFullName()
				end
			end
			if n > 8 then
				lines[#lines + 1] = "   ... SA total under folder ≈ " .. n .. "+"
			end
			lines[#lines + 1] = ""
			task.wait()
		end
		lines[#lines + 1] = "--- full tree depth 4 ---"
		for _, l in ipairs(treeLines(cos, 4, 100, "", 0, {}, { n = 0, max = 6000 })) do
			lines[#lines + 1] = l
		end
	else
		lines[#lines + 1] = "NOT FOUND — deep search:"
		local hit = RepSt:FindFirstChild("CosmeticsStuff", true)
		lines[#lines + 1] = "deep=" .. safeName(hit)
	end
	write(OUT .. "/02_cosmetics_stuff.txt", table.concat(lines, "\n") .. "\n")
	summary[#summary + 1] = "CosmeticsStuff=" .. tostring(cos ~= nil)
end

task.wait()

-- 03 / 04 RepPBR + CasePBRs name lists
do
	local storage = RepSt:FindFirstChild("Storage")
	local cos = storage and storage:FindFirstChild("CosmeticsStuff")
	local rep = cos and cos:FindFirstChild("RepPBR")
	local case = cos and cos:FindFirstChild("CasePBRs")
	write(OUT .. "/03_reppbr_names.txt", listSurfaceAppearances(rep, "RepPBR") .. "\n")
	write(OUT .. "/04_casepbrs_names.txt", listSurfaceAppearances(case, "CasePBRs") .. "\n")
	summary[#summary + 1] = "RepPBR=" .. tostring(rep and #rep:GetChildren() or 0)
	summary[#summary + 1] = "CasePBRs=" .. tostring(case and #case:GetChildren() or 0)
end

task.wait()

-- 05 Events (UpdateClient etc.)
do
	local lines = { "=== Events / remotes touching cosmetics ===", "" }
	local function scan(root, label)
		if not root then
			return
		end
		lines[#lines + 1] = "-- " .. label .. " " .. safeName(root)
		for _, d in ipairs(root:GetDescendants()) do
			local n = string.lower(d.Name)
			if string.find(n, "cosmetic", 1, true)
				or string.find(n, "skin", 1, true)
				or string.find(n, "case", 1, true)
				or string.find(n, "updateclient", 1, true)
				or string.find(n, "inventory", 1, true)
				or d.Name == "UpdateClient"
			then
				lines[#lines + 1] = string.format("  %s [%s]", d:GetFullName(), d.ClassName)
			end
		end
		lines[#lines + 1] = ""
	end
	scan(RepSt:FindFirstChild("Events"), "ReplicatedStorage.Events")
	scan(RepSt, "ReplicatedStorage (name filter)")
	-- Try peek UpdateClient type
	local ev = RepSt:FindFirstChild("Events")
	ev = ev and ev:FindFirstChild("UpdateClient")
	if ev then
		lines[#lines + 1] = "UpdateClient class=" .. ev.ClassName
		lines[#lines + 1] = "Tip: Cobalt / firesignal OnClientEvent carries equippedCosmeticData + cosmeticData.Skins"
	end
	write(OUT .. "/05_events.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 06 / 07 getgc skin catalog
do
	local map = {} -- gun -> { display -> texId }
	local rows = {}
	local other = {} -- non-skin-ish tables with similar keys
	local scanned = 0
	local hits = 0

	if typeof(getgc) == "function" then
		print("[VG:dump] getgc scan…")
		local ok, gc = pcall(getgc, true)
		if ok and typeof(gc) == "table" then
			for _, v in ipairs(gc) do
				scanned += 1
				if scanned % 400 == 0 then
					task.wait()
				end
				if typeof(v) ~= "table" then
					continue
				end
				local ok2, tex, name, disp, rarity, skinClass = pcall(function()
					return v.TextureID, v.ItemName, v.DisplayName, v.Rarity, v.SkinClass
				end)
				if ok2 and typeof(tex) == "number" and tex > 1000
					and typeof(name) == "string" and name ~= ""
					and typeof(disp) == "string" and disp ~= ""
				then
					hits += 1
					map[name] = map[name] or {}
					if not map[name][disp] then
						map[name][disp] = tex
						rows[#rows + 1] = {
							item = name,
							display = disp,
							tex = tex,
							rarity = typeof(rarity) == "string" and rarity or nil,
							class = typeof(skinClass) == "string" and skinClass or nil,
						}
					end
				else
					local ok3, a, b, c = pcall(function()
						return v.ItemName or v.Name, v.DisplayName or v.Title, v.AssetId or v.Id or v.TextureID
					end)
					if ok3 and typeof(a) == "string" and typeof(b) == "string"
						and (typeof(c) == "number" or typeof(c) == "string")
						and (v.CaseName or v.Charm or v.Emote or v.CosmeticType or v.Type == "Case")
						and #other < 500
					then
						other[#other + 1] = string.format("%s | %s | %s", tostring(a), tostring(b), tostring(c))
					end
				end
			end
		else
			warn("[VG:dump] getgc failed", gc)
		end
	else
		warn("[VG:dump] getgc not available")
	end

	table.sort(rows, function(a, b)
		if a.item == b.item then
			return a.display < b.display
		end
		return a.item < b.item
	end)

	local txt = {
		"-- Criminality skin TextureID dump " .. stamp,
		"-- format: ItemName | DisplayName | TextureID | rarity= | class=",
		"",
	}
	for _, r in ipairs(rows) do
		txt[#txt + 1] = string.format(
			"%s | %s | %d | rarity=%s | class=%s",
			r.item,
			r.display,
			r.tex,
			tostring(r.rarity or "?"),
			tostring(r.class or "?")
		)
	end
	write(OUT .. "/07_gc_skins.txt", table.concat(txt, "\n") .. "\n")

	local jsonOk, json = pcall(function()
		return HttpService:JSONEncode(map)
	end)
	if jsonOk then
		write(OUT .. "/06_gc_skins.json", json)
		write("VG_CrimSkinIds.json", json)
		write("VG_CrimSkinIds.txt", table.concat(txt, "\n") .. "\n")
	else
		write(OUT .. "/06_gc_skins.json", "{}")
	end

	local oLines = {
		"=== other cosmetic-like GC tables (heuristic, capped) ===",
		"count=" .. #other,
		"",
	}
	for i = 1, math.min(#other, 400) do
		oLines[#oLines + 1] = other[i]
	end
	write(OUT .. "/08_gc_other_cosmetics.txt", table.concat(oLines, "\n") .. "\n")

	local gunCount = 0
	for _ in pairs(map) do
		gunCount += 1
	end
	summary[#summary + 1] = "getgc scanned=" .. scanned
	summary[#summary + 1] = "skin rows=" .. #rows
	summary[#summary + 1] = "guns in map=" .. gunCount
	print("[VG:dump] getgc skins=", #rows, "guns=", gunCount, "hits=", hits)
end

task.wait()

-- 09 ModuleScripts under Storage that smell like cosmetics
do
	local lines = { "=== ModuleScripts (name filter) under ReplicatedStorage ===", "" }
	local storage = RepSt:FindFirstChild("Storage")
	local roots = { storage, RepSt:FindFirstChild("Modules"), RepSt }
	local seen = {}
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("ModuleScript") and not seen[d] then
					local n = string.lower(d.Name)
					if string.find(n, "cosmetic", 1, true)
						or string.find(n, "skin", 1, true)
						or string.find(n, "case", 1, true)
						or string.find(n, "pbr", 1, true)
						or string.find(n, "inventory", 1, true)
					then
						seen[d] = true
						lines[#lines + 1] = d:GetFullName()
						-- try require (may fail / side-effect — wrapped)
						local rok, res = pcall(require, d)
						if rok and typeof(res) == "table" then
							local keys = {}
							local i = 0
							for k in pairs(res) do
								i += 1
								if i <= 30 then
									keys[#keys + 1] = tostring(k)
								end
							end
							lines[#lines + 1] = "  require OK keys(" .. i .. "): " .. table.concat(keys, ", ")
						else
							lines[#lines + 1] = "  require: " .. tostring(res)
						end
						task.wait()
					end
				end
			end
		end
	end
	write(OUT .. "/09_modules.txt", table.concat(lines, "\n") .. "\n")
end

task.wait()

-- 10 ViewModels
do
	local lines = { "=== ViewModels ===", "" }
	local folder = RepFirst:FindFirstChild("ViewModels")
	lines[#lines + 1] = "ReplicatedFirst.ViewModels=" .. safeName(folder)
	if folder then
		lines[#lines + 1] = "children: " .. childSummary(folder, 80)
	end
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("ViewModel")
	lines[#lines + 1] = "CurrentCamera.ViewModel=" .. safeName(vm)
	if vm then
		for _, l in ipairs(treeLines(vm, 3, 40)) do
			lines[#lines + 1] = l
		end
	end
	write(OUT .. "/10_viewmodels.txt", table.concat(lines, "\n") .. "\n")
end

summary[#summary + 1] = ""
summary[#summary + 1] = "Done. Folder: " .. OUT .. "/"
summary[#summary + 1] = "Also wrote VG_CrimSkinIds.json + .txt at workspace root (merge into Vanguard CrimSkinIds)."
write(OUT .. "/00_summary.txt", table.concat(summary, "\n") .. "\n")

print("[VG:dump] DONE →", OUT)
print(table.concat(summary, "\n"))
