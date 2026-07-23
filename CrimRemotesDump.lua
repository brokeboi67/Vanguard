--[[
  CrimRemotesDump.lua — list ALL remotes (yellow lightning in Dex)

  Classes:
    RemoteEvent, UnreliableRemoteEvent, RemoteFunction

  Run in-game (any executor with writefile). Writes:

    VG_RemotesDump/
      00_summary.txt
      01_all_remotes.txt          ← full paths, sorted
      02_by_folder.txt            ← grouped under Events / Events2 / …
      03_names_only.txt           ← Name\tClass\tParentPath
      04_keywords.txt             ← cash/ban/skin/case/… hits

  Safe: read-only scan, no FireServer / InvokeServer.
]]

local HttpService = game:GetService("HttpService")
local RepSt = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local OUT = "VG_RemotesDump"
local stamp = os.date("%Y-%m-%d %H:%M:%S")

local REMOTE_CLASSES = {
	RemoteEvent = true,
	UnreliableRemoteEvent = true,
	RemoteFunction = true,
}

local KEYWORDS = {
	"cash", "money", "bank", "buy", "sell", "shop", "dealer", "stock",
	"ban", "kick", "admin", "mod", "owner", "backdoor", "exploit",
	"skin", "case", "cosmetic", "unbox", "equip", "inventory", "slot",
	"damage", "kill", "ammo", "reload", "gun", "melee", "weapon",
	"teleport", "tp", "spawn", "respawn", "char", "ragdoll", "down",
	"crate", "safe", "loot", "pickup", "drop", "give", "add",
	"trade", "gift", "product", "purchase", "robux",
	"aim", "silent", "hitbox", "fire", "shoot",
}

local function ensureFolder(path)
	if typeof(makefolder) == "function" then
		pcall(makefolder, path)
	end
end

local function write(path, text)
	if typeof(writefile) ~= "function" then
		warn("[VG:remotes] no writefile — printing head only")
		print(text:sub(1, 2000))
		return false
	end
	local ok, err = pcall(writefile, path, text)
	if not ok then
		warn("[VG:remotes] write fail", path, err)
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

local function isRemote(inst)
	if not inst then
		return false
	end
	if REMOTE_CLASSES[inst.ClassName] then
		return true
	end
	-- fallback for odd executors / future classes
	local ok, isaRE = pcall(function()
		return inst:IsA("RemoteEvent")
	end)
	local ok2, isaRF = pcall(function()
		return inst:IsA("RemoteFunction")
	end)
	return (ok and isaRE) or (ok2 and isaRF)
end

local function keywordHit(name)
	local lower = string.lower(tostring(name or ""))
	local hits = {}
	for _, kw in ipairs(KEYWORDS) do
		if string.find(lower, kw, 1, true) then
			hits[#hits + 1] = kw
		end
	end
	return hits
end

ensureFolder(OUT)
print("[VG:remotes] scanning…", stamp)

local roots = {
	{ game, "DataModel (full GetDescendants — may be heavy)" },
}

-- Prefer service-by-service if full DM is too big / filtered
local services = {
	"ReplicatedStorage",
	"ReplicatedFirst",
	"Workspace",
	"Players",
	"StarterGui",
	"StarterPlayer",
	"Lighting",
	"SoundService",
	"Chat",
	"TextChatService",
	"Teams",
	"FriendService",
}

local found = {}
local seen = {}

local function addRemote(inst)
	if not isRemote(inst) then
		return
	end
	local full = safeFull(inst)
	if seen[full] then
		return
	end
	seen[full] = true
	local parent = inst.Parent
	found[#found + 1] = {
		name = inst.Name,
		class = inst.ClassName,
		full = full,
		parent = parent and safeFull(parent) or "<nil>",
		parentName = parent and parent.Name or "",
		keywords = keywordHit(inst.Name),
	}
end

-- Scan services explicitly (more reliable than one giant GetDescendants)
for _, svcName in ipairs(services) do
	local ok, svc = pcall(function()
		return game:GetService(svcName)
	end)
	if ok and svc then
		print("[VG:remotes] service", svcName)
		addRemote(svc)
		local okD, descs = pcall(function()
			return svc:GetDescendants()
		end)
		if okD and typeof(descs) == "table" then
			local n = 0
			for _, d in ipairs(descs) do
				n += 1
				if n % 800 == 0 then
					task.wait()
				end
				addRemote(d)
			end
		end
		task.wait()
	end
end

-- Also walk PlayerGui / character if present
local lp = Players.LocalPlayer
if lp then
	for _, folderName in ipairs({ "PlayerGui", "Backpack", "PlayerScripts" }) do
		local f = lp:FindFirstChild(folderName)
		if f then
			for _, d in ipairs(f:GetDescendants()) do
				addRemote(d)
			end
		end
	end
end

table.sort(found, function(a, b)
	if a.class == b.class then
		return a.full < b.full
	end
	return a.class < b.class
end)

local byClass = {}
for _, r in ipairs(found) do
	byClass[r.class] = (byClass[r.class] or 0) + 1
end

-- 01 all
do
	local lines = {
		"-- ALL remotes " .. stamp,
		"-- Class | Name | FullPath",
		"",
	}
	for _, r in ipairs(found) do
		lines[#lines + 1] = string.format("%s | %s | %s", r.class, r.name, r.full)
	end
	write(OUT .. "/01_all_remotes.txt", table.concat(lines, "\n") .. "\n")
end

-- 02 by folder (group on parent path)
do
	local groups = {}
	for _, r in ipairs(found) do
		local key = r.parent
		groups[key] = groups[key] or {}
		table.insert(groups[key], r)
	end
	local keys = {}
	for k in pairs(groups) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local lines = { "=== Remotes by parent folder ===", "" }
	for _, key in ipairs(keys) do
		lines[#lines + 1] = "## " .. key
		for _, r in ipairs(groups[key]) do
			lines[#lines + 1] = string.format("  [%s] %s", r.class, r.name)
		end
		lines[#lines + 1] = ""
	end
	write(OUT .. "/02_by_folder.txt", table.concat(lines, "\n") .. "\n")
end

-- 03 names only (easy grep)
do
	local lines = { "Name\tClass\tParent", "" }
	for _, r in ipairs(found) do
		lines[#lines + 1] = string.format("%s\t%s\t%s", r.name, r.class, r.parent)
	end
	write(OUT .. "/03_names_only.txt", table.concat(lines, "\n") .. "\n")
end

-- 04 keywords
do
	local lines = { "=== Keyword hits ===", "" }
	local any = false
	for _, r in ipairs(found) do
		if #r.keywords > 0 then
			any = true
			lines[#lines + 1] = string.format(
				"%s [%s] kw=%s | %s",
				r.name,
				r.class,
				table.concat(r.keywords, ","),
				r.full
			)
		end
	end
	if not any then
		lines[#lines + 1] = "(none)"
	end
	write(OUT .. "/04_keywords.txt", table.concat(lines, "\n") .. "\n")
end

-- 00 summary + json
do
	local summary = {
		"VG Remotes Dump " .. stamp,
		"total=" .. #found,
		"",
	}
	for cls, n in pairs(byClass) do
		summary[#summary + 1] = cls .. "=" .. n
	end
	summary[#summary + 1] = ""
	summary[#summary + 1] = "Events folder kids:"
	local ev = RepSt:FindFirstChild("Events")
	if ev then
		for _, ch in ipairs(ev:GetChildren()) do
			summary[#summary + 1] = string.format("  %s [%s]", ch.Name, ch.ClassName)
		end
	else
		summary[#summary + 1] = "  <no ReplicatedStorage.Events>"
	end
	summary[#summary + 1] = ""
	summary[#summary + 1] = "Events2 folder kids:"
	local ev2 = RepSt:FindFirstChild("Events2")
	if ev2 then
		for _, ch in ipairs(ev2:GetChildren()) do
			summary[#summary + 1] = string.format("  %s [%s]", ch.Name, ch.ClassName)
		end
	else
		summary[#summary + 1] = "  <no ReplicatedStorage.Events2>"
	end
	write(OUT .. "/00_summary.txt", table.concat(summary, "\n") .. "\n")

	local payload = {}
	for _, r in ipairs(found) do
		payload[#payload + 1] = {
			name = r.name,
			class = r.class,
			full = r.full,
			parent = r.parent,
			keywords = r.keywords,
		}
	end
	local jok, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if jok then
		write(OUT .. "/05_all_remotes.json", json)
	end
end

print("[VG:remotes] DONE total=", #found)
for cls, n in pairs(byClass) do
	print(" ", cls, n)
end
print("[VG:remotes] →", OUT .. "/")
print("[VG:remotes] Tip: open 04_keywords.txt first, then 01_all_remotes.txt")
print("[VG:remotes] DO NOT FireServer random remotes — many are honeypots (BanPlayer, AddCash, …)")
